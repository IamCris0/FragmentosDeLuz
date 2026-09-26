"""Genera a Luma, la archivista-espíritu de Auralia, como en la viñeta 4 del prólogo.

Uso (desde la raíz del proyecto):
  blender --background --factory-startup --python source_tools/build_luma_spirit.py
  # o con el módulo bpy de PyPI:  python source_tools/build_luma_spirit.py

Salidas:
  blender/luma_spirit.blend
  blender/luma_spirit_metrics.json
  godot/assets/characters/luma_spirit.glb

Todo el modelo es procedural: cabeza con visor oscuro, ojos luminosos, corona dorada con hoja,
collar con gema, túnica en forma de gota que termina en estela y dos aletas-brazo con pivote
en el hombro. Las piezas se exportan como nodos separados para que Godot las anime
(flotación, aleteo, parpadeo, mirada) sin necesidad de esqueleto.
El frente del personaje es -Y en Blender (+Z en glTF/Godot).
"""
import json
import math
import os
import sys

import bpy  # bpy primero: el módulo de PyPI registra bmesh al importarse
import bmesh
from mathutils import Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BLEND = os.path.join(ROOT, "blender", "luma_spirit.blend")
GLB = os.path.join(ROOT, "godot", "assets", "characters", "luma_spirit.glb")
METRICS = os.path.join(ROOT, "blender", "luma_spirit_metrics.json")

HEAD_Z = 1.52


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects, bpy.data.curves):
        for item in list(block):
            block.remove(item)


def material(name: str, color: str, emission: float = 0.0, metallic: float = 0.0,
             roughness: float = 0.5, emission_color: str | None = None, alpha: float = 1.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgb = tuple(int(color[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    bsdf.inputs["Base Color"].default_value = (*[c ** 2.2 for c in rgb], 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if emission > 0.0:
        source = emission_color or color
        erg = tuple(int(source[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        bsdf.inputs["Emission Color"].default_value = (*[c ** 2.2 for c in erg], 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


def new_object(name: str, mesh: bpy.types.Mesh, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def empty(name: str, location: tuple, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.08
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    if parent:
        obj.parent = parent
    return obj


def smooth(mesh: bpy.types.Mesh) -> None:
    for poly in mesh.polygons:
        poly.use_smooth = True


def uv_sphere(name: str, radius: float, segments: int = 32, rings: int = 16) -> bpy.types.Mesh:
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    smooth(mesh)
    return mesh


def oriented_sphere(radius: float, segments: int, rings: int) -> bmesh.types.BMesh:
    """UV sphere whose pole points to -Y, so its rings are clean circles around the face axis."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(-90), 3, "X"))
    return bm


FACE_ANGLE = math.radians(58)


def build_head(parent: bpy.types.Object, shell: bpy.types.Material, face: bpy.types.Material,
               rim: bpy.types.Material) -> bpy.types.Object:
    axis = Vector((0, -1, 0))
    # Shell with a circular opening facing forward.
    bm = oriented_sphere(0.205, 56, 36)
    doomed = [f for f in bm.faces if f.calc_center_median().normalized().dot(axis) > math.cos(FACE_ANGLE)]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    for v in bm.verts:
        v.co.z *= 0.96
    mesh = bpy.data.meshes.new("Luma_Head")
    bm.to_mesh(mesh)
    bm.free()
    smooth(mesh)
    mesh.materials.append(shell)
    head = new_object("Luma_Head", mesh, parent)
    # Dark glassy visor: a slightly recessed spherical cap that closes the opening.
    bm = oriented_sphere(0.197, 56, 36)
    doomed = [f for f in bm.faces if f.calc_center_median().normalized().dot(axis) <= math.cos(FACE_ANGLE + math.radians(4))]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    for v in bm.verts:
        v.co.z *= 0.96
    mesh = bpy.data.meshes.new("Luma_Visor")
    bm.to_mesh(mesh)
    bm.free()
    smooth(mesh)
    mesh.materials.append(face)
    new_object("Luma_Visor", mesh, parent)
    # Glowing rim where shell and visor meet.
    radius = 0.205 * math.sin(FACE_ANGLE)
    bm = bmesh.new()
    minor = 0.0075
    rings_out = []
    for i in range(64):
        a = i / 64 * math.tau
        ring_pts = []
        for k in range(8):
            b = k / 8 * math.tau
            r = radius + math.cos(b) * minor
            ring_pts.append(bm.verts.new((math.cos(a) * r, -0.205 * math.cos(FACE_ANGLE) + math.sin(b) * minor,
                                          math.sin(a) * r * 0.96)))
        rings_out.append(ring_pts)
    for i in range(64):
        for k in range(8):
            bm.faces.new((rings_out[i][k], rings_out[(i + 1) % 64][k], rings_out[(i + 1) % 64][(k + 1) % 8],
                          rings_out[i][(k + 1) % 8]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Luma_FaceRim")
    bm.to_mesh(mesh)
    bm.free()
    smooth(mesh)
    mesh.materials.append(rim)
    new_object("Luma_FaceRim", mesh, parent)
    return head


def build_eyes(parent: bpy.types.Object, glow: bpy.types.Material) -> None:
    for side, label in ((-1, "L"), (1, "R")):
        pivot = empty("Luma_EyePivot_" + label, (side * 0.062, -0.186, 0.012), parent)
        mesh = uv_sphere("Luma_Eye_" + label, 1.0, 20, 12)
        mesh.materials.append(glow)
        eye = new_object("Luma_Eye_" + label, mesh, pivot)
        eye.scale = (0.024, 0.012, 0.047)


def build_crown(parent: bpy.types.Object, gold: bpy.types.Material, leaf: bpy.types.Material, gem: bpy.types.Material) -> None:
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, radius=0.118, segments=40)
    ring = bm.edges[:]
    extruded = bmesh.ops.extrude_edge_only(bm, edges=ring)
    for v in [e for e in extruded["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += 0.045
    # Coronet points: every fifth top vertex rises.
    tops = sorted([v for v in bm.verts if v.co.z > 0.01], key=lambda v: math.atan2(v.co.y, v.co.x))
    for i, v in enumerate(tops):
        if i % 5 == 0:
            v.co.z += 0.03
    mesh = bpy.data.meshes.new("Luma_Crown")
    bm.to_mesh(mesh)
    bm.free()
    mod_mesh = mesh
    mod_mesh.materials.append(gold)
    crown = new_object("Luma_Crown", mod_mesh, parent)
    crown.location = (0, 0.01, 0.135)
    crown.rotation_euler = (math.radians(-8), 0, 0)
    solid = crown.modifiers.new("Thickness", "SOLIDIFY")
    solid.thickness = 0.012
    solid.offset = 0
    # Gem at the front of the crown.
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=1.0)
    mesh = bpy.data.meshes.new("Luma_CrownGem")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(gem)
    jewel = new_object("Luma_CrownGem", mesh, crown)
    jewel.location = (0, -0.121, 0.03)
    jewel.scale = (0.02, 0.012, 0.026)
    # Leaf sprouting above the crown.
    stem_pivot = empty("Luma_LeafPivot", (0.015, 0.02, 0.19), parent)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=1.0)
    for v in bm.verts:
        t = (v.co.z + 1.0) * 0.5
        taper = math.sin(math.pi * min(1.0, t * 1.05)) ** 0.8
        v.co.x *= taper
        v.co.y *= taper * 0.25
    mesh = bpy.data.meshes.new("Luma_Leaf")
    bm.to_mesh(mesh)
    bm.free()
    smooth(mesh)
    mesh.materials.append(leaf)
    leaf_obj = new_object("Luma_Leaf", mesh, stem_pivot)
    leaf_obj.scale = (0.075, 0.075, 0.12)
    leaf_obj.location = (0.035, 0, 0.1)
    leaf_obj.rotation_euler = (0, math.radians(28), 0)


def lathe(name: str, profile: list, segments: int, sway) -> bpy.types.Mesh:
    bm = bmesh.new()
    rings = []
    for z, r in profile:
        ring = []
        for i in range(segments):
            a = i / segments * math.tau
            x = math.sin(a) * r + sway(z)
            y = -math.cos(a) * r
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    tip = bm.verts.new((sway(profile[-1][0] - 0.04), 0, profile[-1][0] - 0.04))
    for i in range(segments):
        bm.faces.new((rings[-1][(i + 1) % segments], rings[-1][i], tip))
    top_center = bm.verts.new((sway(profile[0][0]), 0, profile[0][0] + 0.01))
    for i in range(segments):
        bm.faces.new((rings[0][i], rings[0][(i + 1) % segments], top_center))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    smooth(mesh)
    return mesh


BODY_PROFILE = [(1.30, 0.045), (1.27, 0.085), (1.22, 0.125), (1.15, 0.155), (1.07, 0.168), (0.99, 0.165),
                (0.91, 0.152), (0.83, 0.128), (0.75, 0.098), (0.68, 0.062), (0.61, 0.034), (0.55, 0.014)]


def body_radius(z: float) -> float:
    for (z0, r0), (z1, r1) in zip(BODY_PROFILE, BODY_PROFILE[1:]):
        if z1 <= z <= z0:
            t = (z0 - z) / (z0 - z1)
            return r0 + (r1 - r0) * t
    return BODY_PROFILE[-1][1]


def tail_sway(z: float) -> float:
    depth = max(0.0, 1.0 - z) / 0.45
    return 0.16 * depth * depth


def trim_curve(name: str, points: list, parent: bpy.types.Object, gold: bpy.types.Material) -> None:
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = 0.0055
    curve.bevel_resolution = 2
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1.0)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(gold)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    obj.select_set(False)
    obj.parent = parent


def surface_point(z: float, angle: float, lift: float = 0.004) -> tuple:
    r = body_radius(z) + lift
    return (math.sin(angle) * r + tail_sway(z), -math.cos(angle) * r, z)


def build_body(parent: bpy.types.Object, robe: bpy.types.Material, gold: bpy.types.Material, gem: bpy.types.Material) -> None:
    mesh = lathe("Luma_Body", BODY_PROFILE, 48, tail_sway)
    mesh.materials.append(robe)
    body = new_object("Luma_Body", mesh, parent)
    # Gold chevrons on the front of the robe, as in the comic.
    for base, spread, label in ((1.17, 0.95, "Upper"), (0.98, 0.8, "Lower")):
        pts = []
        steps = 26
        for i in range(steps + 1):
            a = -spread + 2 * spread * i / steps
            z = base - 0.16 * abs(a) / spread
            pts.append(surface_point(z, a))
        trim_curve("Luma_Trim" + label, pts, body, gold)
    hem = []
    for i in range(49):
        a = i / 48 * math.tau
        hem.append(surface_point(0.8, a))
    trim_curve("Luma_TrimHem", hem, body, gold)
    # Collar with a small crystal, where the head meets the robe.
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=False, radius=0.072, segments=36)
    extruded = bmesh.ops.extrude_edge_only(bm, edges=bm.edges[:])
    for v in [e for e in extruded["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += 0.034
        v.co.x *= 0.86
        v.co.y *= 0.86
    mesh = bpy.data.meshes.new("Luma_Collar")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(gold)
    collar = new_object("Luma_Collar", mesh, parent)
    collar.location = (0, 0, 1.268)
    solid = collar.modifiers.new("Band", "SOLIDIFY")
    solid.thickness = 0.014
    solid.offset = 0
    bm = bmesh.new()
    verts = [bm.verts.new(v) for v in ((0, 0, 1), (0, 0, -1), (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0))]
    for a, b, c in ((0, 2, 4), (0, 4, 3), (0, 3, 5), (0, 5, 2), (1, 4, 2), (1, 3, 4), (1, 5, 3), (1, 2, 5)):
        bm.faces.new((verts[a], verts[b], verts[c]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Luma_CollarGem")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(gem)
    jewel = new_object("Luma_CollarGem", mesh, parent)
    jewel.location = (0, -0.098, 1.285)
    jewel.scale = (0.03, 0.018, 0.042)


def build_fins(parent: bpy.types.Object, fin: bpy.types.Material) -> None:
    for side, label in ((-1, "L"), (1, "R")):
        pivot = empty("Luma_Arm_" + label, (side * 0.125, 0.0, 1.2), parent)
        pivot.rotation_euler = (0, math.radians(side * 32), 0)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=14, radius=1.0)
        for v in bm.verts:
            t = (v.co.x + 1.0) * 0.5  # 0 at shoulder, 1 at tip
            width = math.sin(math.pi * min(1.0, 0.12 + t * 0.9)) ** 0.7
            v.co.z *= width
            v.co.y *= 0.18 * width + 0.05
            v.co.z += 0.18 * t * t  # leaf curls upward at the tip
        for v in bm.verts:
            v.co.x = (v.co.x + 1.0) * 0.5 * side
        mesh = bpy.data.meshes.new("Luma_Fin_" + label)
        bm.to_mesh(mesh)
        bm.free()
        smooth(mesh)
        mesh.materials.append(fin)
        leaf = new_object("Luma_Fin_" + label, mesh, pivot)
        leaf.scale = (0.32, 0.05, 0.075)


def triangle_count() -> int:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    total = 0
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    return total


def main() -> None:
    reset_scene()
    shell = material("Luma_Shell", "a8f4ea", emission=0.9, emission_color="4ecdc4", roughness=0.35)
    face = material("Luma_Face", "0b1419", roughness=0.18, metallic=0.1)
    glow = material("Luma_EyeGlow", "e8fffb", emission=3.2, emission_color="9ff7ec")
    rim = material("Luma_FaceRim", "c8fff7", emission=2.2, emission_color="6ff0e0", roughness=0.3)
    gold = material("Luma_Gold", "d4af37", metallic=0.85, roughness=0.3, emission=0.25, emission_color="f9c74f")
    gem = material("Luma_Gem", "7ff5e6", emission=3.0, emission_color="4ecdc4", roughness=0.1)
    leaf = material("Luma_LeafGlow", "57e6d4", emission=1.6, emission_color="4ecdc4", roughness=0.4)
    robe = material("Luma_Robe", "1f9a8f", emission=0.35, emission_color="1abfb3", roughness=0.55)
    fin = material("Luma_FinGlow", "5ad8c9", emission=1.1, emission_color="1abfb3", roughness=0.45)

    root = empty("LumaSpirit", (0, 0, 0))
    float_node = empty("Luma_Float", (0, 0, 0), root)
    head_pivot = empty("Luma_HeadPivot", (0, 0, HEAD_Z), float_node)
    build_head(head_pivot, shell, face, rim)
    build_eyes(head_pivot, glow)
    build_crown(head_pivot, gold, leaf, gem)
    build_body(float_node, robe, gold, gem)
    build_fins(float_node, fin)

    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    triangles = triangle_count()
    os.makedirs(os.path.dirname(GLB), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.export_scene.gltf(filepath=GLB, export_format="GLB", export_apply=True, export_yup=True,
                              export_materials="EXPORT", export_animations=False)
    metrics = {"asset": "luma_spirit", "triangles": triangles,
               "objects": sorted(o.name for o in bpy.context.scene.objects),
               "height_m": 1.9, "front": "-Y Blender / +Z Godot", "blender": bpy.app.version_string}
    with open(METRICS, "w", encoding="utf-8") as handle:
        json.dump(metrics, handle, indent=2, ensure_ascii=False)
    print("LUMA_BUILT", json.dumps(metrics))


if __name__ == "__main__":
    main()
