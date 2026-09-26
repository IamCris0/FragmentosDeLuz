"""Repair the supplied Meshy rig for the demo. Run with Blender --background --python.

The committed rigged input preserves the previous retargeting work. This build does
not regenerate the Meshy character or replace it with the older adult model.
"""
import bmesh
import bpy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "source_assets/neri_meshy/neri_rigged_input.glb"
OUTPUT = ROOT / "godot/assets/characters/neri_quaternius.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
scene = bpy.context.scene
rig = next(obj for obj in scene.objects if obj.type == "ARMATURE")
body = next(obj for obj in scene.objects if obj.type == "MESH" and obj.vertex_groups)
actions = list(bpy.data.actions)
assert len(rig.data.bones) == 65
assert len(actions) == 11

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

materials = {material.name: index for index, material in enumerate(body.data.materials)}
for polygon in body.data.polygons:
    center = polygon.center
    previous = body.data.materials[polygon.material_index].name
    if center.z > 0.555 and previous != "Neri_Chestnut":
        polygon.material_index = materials["Neri_Skin"]
    elif center.z < -0.65:
        polygon.material_index = materials["Neri_Sole" if center.z < -0.855 else "Neri_Leather"]
    elif center.z < -0.08 and abs(center.x) < 0.19 and previous == "Neri_Leather":
        polygon.material_index = materials["Neri_Twill"]

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

samples = {}
for action in actions:
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    start, end = action.frame_range
    clip_bounds = []
    for index in range(9):
        frame = start + (end - start) * index / 8
        scene.frame_set(int(frame), subframe=frame % 1)
        bpy.context.view_layer.update()
        limits = bounds()
        assert all(abs(value) < 3 for corner in limits for value in corner), action.name
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
report = {"character": "Neri - Meshy demo repair", "source": str(SOURCE.relative_to(ROOT)),
          "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
          "triangles": len(body.data.loop_triangles), "bones": len(rig.data.bones),
          "animations": [action.name for action in actions], "grounding_offset": grounding.location.z,
          "idle_bounds_before": before, "idle_bounds_after": after, "animation_bounds": samples,
          "rights": "User-supplied Meshy mesh; verify generation-plan rights before distribution. UAL animations: CC0."}
(ROOT / "blender/neri_demo_metrics.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("NERI_DEMO_BUILD", json.dumps({key: value for key, value in report.items() if key != "animation_bounds"}))
