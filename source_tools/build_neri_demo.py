"""Skin the supplied textured Meshy character. Run with Blender --background --python.

Preserve the supplied UV/PBR maps and transfer the existing 65-bone/11-clip rig.
The original source files are never modified.
"""
import bmesh
import bpy
import hashlib
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source_assets/neri_meshy/neri_rigged_input.glb"
TEXTURED = ROOT / "referencias-assets/09_modelo_neri/Meshy_AI_Young_Explorer_with_C_0926205022_generate.glb"
OUTPUT = ROOT / "godot/assets/characters/neri_quaternius.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
scene = bpy.context.scene
rig = next(obj for obj in scene.objects if obj.type == "ARMATURE")
body = next(obj for obj in scene.objects if obj.type == "MESH" and obj.vertex_groups)
donor = body
actions = list(bpy.data.actions)
assert len(rig.data.bones) == 65
assert len(actions) == 11

# Transfer in rest space, not in the pose left active by the glTF importer.
rig.data.pose_position = "REST"
existing = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(TEXTURED))
body = next(obj for obj in bpy.data.objects if obj not in existing and obj.type == "MESH")
body.name = "Neri_TexturedSurface"
assert body.data.uv_layers, "The textured source must include UVs"
textures = [node.image for material in body.data.materials for node in material.node_tree.nodes
            if node.type == "TEX_IMAGE" and node.image]
assert len(textures) >= 3, "Expected base color, normal and metallic/roughness maps"

def rest_bounds(obj):
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return ([min(point[i] for point in points) for i in range(3)],
            [max(point[i] for point in points) for i in range(3)])

source_bounds = rest_bounds(body)
target_bounds = rest_bounds(donor)
scale = (target_bounds[1][2] - target_bounds[0][2]) / (source_bounds[1][2] - source_bounds[0][2])
source_center = [(source_bounds[0][i] + source_bounds[1][i]) / 2 for i in range(3)]
target_center = [(target_bounds[0][i] + target_bounds[1][i]) / 2 for i in range(3)]
for vertex in body.data.vertices:
    point = body.matrix_world @ vertex.co
    vertex.co = [(point[i] - source_center[i]) * scale + target_center[i] for i in range(3)]
body.matrix_world.identity()

# Abort if a future source is a different pose or character instead of silently
# skinning unrelated geometry with the previous character's weights.
surface = BVHTree.FromPolygons([v.co for v in donor.data.vertices],
                               [list(p.vertices) for p in donor.data.polygons])
distances = [surface.find_nearest(vertex.co)[3] for vertex in body.data.vertices]
assert max(distances) < 0.045, "Source differs from the rig's rest mesh; manual retargeting required"
print("TEXTURE_ALIGNMENT", scale, max(distances), sum(distances) / len(distances), flush=True)

# glTF's split normals created unwelded facets even on the face and hands.
if body.data.has_custom_normals:
    body.data.normals_split_custom_set([(0, 0, 0)] * len(body.data.loops))
mesh = bmesh.new()
mesh.from_mesh(body.data)
bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.000001)
bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
mesh.to_mesh(body.data)
mesh.free()
for polygon in body.data.polygons:
    polygon.use_smooth = True
body.data.update()

bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
body.data.calc_loop_triangles()
source_triangles = len(body.data.loop_triangles)
# Keep the detailed face/hair silhouette while reducing the dense generated body.
detail = body.vertex_groups.new(name="PreserveFaceDetail")
detail.add([v.index for v in body.data.vertices if v.co.z > 0.53], 1.0, "REPLACE")
decimate = body.modifiers.new("DemoTriangleBudget", "DECIMATE")
decimate.ratio = min(1.0, 40000 / source_triangles)
decimate.vertex_group = detail.name
decimate.vertex_group_factor = 1.0
decimate.invert_vertex_group = True
bpy.ops.object.modifier_apply(modifier=decimate.name)
body.vertex_groups.remove(body.vertex_groups["PreserveFaceDetail"])
for group in donor.vertex_groups:
    body.vertex_groups.new(name=group.name)
transfer = body.modifiers.new("RestSurfaceWeights", "DATA_TRANSFER")
transfer.object = donor
transfer.use_vert_data = True
transfer.data_types_verts = {"VGROUP_WEIGHTS"}
transfer.vert_mapping = "POLYINTERP_NEAREST"
transfer.layers_vgroup_select_src = "ALL"
transfer.layers_vgroup_select_dst = "NAME"
bpy.ops.object.modifier_apply(modifier=transfer.name)

# A stylized face has no facial rig. Heat weights on the small disconnected
# details pulled the face towards nearby neck/arm bones during animation.
head_group = body.vertex_groups.get("Head")
neck_group = body.vertex_groups.get("neck_01")
for vertex in body.data.vertices:
    if vertex.co.z <= 0.53:
        continue
    influence = min(1.0, max(0.0, (vertex.co.z - 0.53) / 0.055))
    for group in list(vertex.groups):
        body.vertex_groups[group.group].remove([vertex.index])
    head_group.add([vertex.index], influence, "REPLACE")
    neck_group.add([vertex.index], 1.0 - influence, "REPLACE")

# Limit and normalize influences for Godot's default four-weight skinning.
bpy.ops.object.vertex_group_limit_total(limit=4)
bpy.ops.object.vertex_group_normalize_all(lock_active=False)
assert all(vertex.groups and abs(sum(g.weight for g in vertex.groups) - 1.0) < 0.001
           for vertex in body.data.vertices), "Unweighted or unnormalized vertex"
skin = body.modifiers.new("NeriSkin", "ARMATURE")
skin.object = rig
body.parent = rig
bpy.data.objects.remove(donor, do_unlink=True)
rig.data.pose_position = "POSE"

rig.animation_data_create()
idle = bpy.data.actions["idle"]
rig.animation_data.action = idle
rig.animation_data.action_slot = idle.slots[0]
scene.frame_set(0)
bpy.context.view_layer.update()

def bounds():
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    evaluated_mesh = evaluated.to_mesh()
    points = [evaluated.matrix_world @ vertex.co for vertex in evaluated_mesh.vertices]
    result = [[min(point[i] for point in points) for i in range(3)],
              [max(point[i] for point in points) for i in range(3)]]
    evaluated.to_mesh_clear()
    return result

# The supplied rig was centered at the pelvis: its soles were 0.89 m below
# the gameplay origin. Move the entire hierarchy, preserving skin bind matrices.
before = bounds()
grounding = bpy.data.objects.new("NeriGrounding", None)
scene.collection.objects.link(grounding)
for obj in [rig, body]:
    if obj.parent is None:
        obj.parent = grounding
grounding.location.z = -before[0][2] + 0.012
bpy.context.view_layer.update()
after = bounds()
assert 0.0 <= after[0][2] <= 0.03
assert 1.60 <= after[1][2] <= 1.90

# Adult-sourced clips sink the shorter character's feet into the floor. Bake a
# vertical-only correction into the root bone, leaving gameplay motion untouched.
grounded_clips = {"idle", "walk", "run", "land", "interact", "wave", "pulse", "hurt", "dodge"}
root_bone = rig.pose.bones["root"]
root_rest_location = root_bone.location.copy()
floor_corrections = {}
for action in actions:
    if action.name not in grounded_clips:
        continue
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    root_bone.location = root_rest_location
    start, end = action.frame_range
    corrections = []
    dense_lifts = []
    for tick in range(int(start * 4), int(end * 4) + 1):
        frame = tick / 4
        scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        lift = max(0.0, 0.012 - bounds()[0][2])
        dense_lifts.append((frame, lift))
        if tick % 4 == 0:
            corrections.append((frame, root_bone.location.copy()))
    for frame, location in corrections:
        # Include the interval on both sides: fast rotating toes can reach lower
        # between authored frames, even when both endpoint poses clear the floor.
        lift = max(value for sample, value in dense_lifts if abs(sample - frame) <= 1)
        root_bone.location = location + root_bone.bone.matrix_local.to_3x3().inverted() @ Vector((0, 0, lift))
        root_bone.keyframe_insert("location", frame=frame)
    for layer in action.layers:
        for strip in layer.strips:
            channelbag = strip.channelbag(rig.animation_data.action_slot)
            if channelbag:
                for curve in channelbag.fcurves:
                    if curve.data_path == 'pose.bones["root"].location':
                        for key in curve.keyframe_points:
                            key.interpolation = "LINEAR"
    floor_corrections[action.name] = max(item[1] for item in dense_lifts)

samples = {}
for action in actions:
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    root_bone.location = root_rest_location
    start, end = action.frame_range
    clip_bounds = []
    for index in range(9):
        frame = start + (end - start) * index / 8
        scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        limits = bounds()
        assert all(abs(value) < 3 for corner in limits for value in corner), action.name
        if action.name in grounded_clips:
            assert limits[0][2] >= -0.02, (action.name, limits)
        clip_bounds.append(limits)
    samples[action.name] = clip_bounds

rig.animation_data.action = idle
rig.animation_data.action_slot = idle.slots[0]
scene.frame_set(0)
bpy.ops.object.select_all(action="DESELECT")
for obj in [grounding, rig, body]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", use_selection=True,
    export_animations=True, export_animation_mode="ACTIONS", export_skins=True,
    export_cameras=False, export_lights=False)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "blender/neri_demo.blend"))
body.data.calc_loop_triangles()
report = {"character": "Neri - textured Meshy demo", "source": str(TEXTURED.relative_to(ROOT)),
          "textured_source_sha256": hashlib.sha256(TEXTURED.read_bytes()).hexdigest(),
          "rig_source": str(SOURCE.relative_to(ROOT)),
          "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          "source_triangles": source_triangles, "rest_alignment_max_distance": max(distances),
          "grounded_clip_max_lift": floor_corrections,
          "textures": [{"name": img.name, "size": list(img.size)} for img in textures],
          "triangles": len(body.data.loop_triangles), "bones": len(rig.data.bones),
          "animations": [action.name for action in actions], "grounding_offset": grounding.location.z,
          "idle_bounds_before": before, "idle_bounds_after": after, "animation_bounds": samples,
          "rights": "User-supplied Meshy mesh; verify generation-plan rights before distribution. UAL animations: CC0."}
(ROOT / "blender/neri_demo_metrics.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("NERI_DEMO_BUILD", json.dumps({key: value for key, value in report.items() if key != "animation_bounds"}))
