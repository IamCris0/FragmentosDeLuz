"""Fase 7: modelos del Capítulo II (archipiélago) generados por procedimientos en Blender.

Uso (desde la raíz del proyecto):
  blender --background --factory-startup --python source_tools/build_chapter2_assets.py
  # o con el módulo bpy de PyPI:  python source_tools/build_chapter2_assets.py [nombre ...]

Salidas (godot/assets/...):
  environment/crystal_spire.glb, crystal_shard.glb, cave_rock.glb, rock_arch.glb, cloud_stone.glb,
  environment/windmill.glb (nodos Tower + Blades), observatory_dome.glb
  props/prism.glb (PrismBase + PrismHead), beam_emitter.glb, beam_receptor.glb, valve.glb (ValveBody + ValveWheel),
  props/telescope.glb (TelescopeMount + TelescopeTube), star_pillar.glb (PillarBody + PillarGem), star_key.glb
  enemies/vigia.glb, cefiro.glb, heraldo.glb
  characters/maren_echo.glb
  blender/chapter2_assets.blend y blender/chapter2_assets_metrics.json

Convenciones: el frente de cada modelo es -Y en Blender (+Z en Godot); la «salida» de prismas y
emisores es +Y en Blender (-Z en Godot). Los materiales cuyo nombre empieza por «Crystal» o
contiene «Gem»/«Glow» se sustituyen en Godot por shaders propios (scripts/crystal_style.gd).
"""
import json
import math
import os
import random
import sys

import bpy  # bpy primero: el módulo de PyPI registra bmesh al importarse
import bmesh
from mathutils import Matrix, Quaternion, Vector, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
ASSETS = os.path.join(ROOT, "godot", "assets")
BLEND = os.path.join(ROOT, "blender", "chapter2_assets.blend")
METRICS = os.path.join(ROOT, "blender", "chapter2_assets_metrics.json")
rng = random.Random(2607)
MATERIALS: dict = {}
built: dict = {}
offset_x = [0.0]


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb(code: str) -> tuple:
    def lin(x: float) -> float:
        return x / 12.92 if x < 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return tuple(lin(int(code[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def mat(name: str, color: str, emission: float = 0.0, metallic: float = 0.0, rough: float = 0.6,
        emission_color: str | None = None) -> bpy.types.Material:
    if name in MATERIALS:
        return MATERIALS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*srgb(color), 1.0)
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*srgb(color), 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*srgb(emission_color or color), 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    MATERIALS[name] = m
    return m


# --- Construcción con bmesh ---------------------------------------------------------------------

class Builder:
    """Acumula geometría en un bmesh con índices de material por cara."""

    def __init__(self, materials: list):
        self.bm = bmesh.new()
        self.materials = materials

    def face(self, verts: list, index: int):
        f = self.bm.faces.new(verts)
        f.material_index = index
        return f

    def ring(self, center: Vector, basis: Matrix, radius_x: float, radius_y: float, sides: int, phase: float = 0.0) -> list:
        out = []
        for i in range(sides):
            a = phase + math.tau * i / sides
            local = Vector((math.cos(a) * radius_x, math.sin(a) * radius_y, 0.0))
            out.append(self.bm.verts.new(center + basis @ local))
        return out

    def prism(self, a, b, r1: float, r2: float, sides: int, index: int, tip: float = 0.0, cap_index: int | None = None,
              phase: float = 0.0, squash: float = 1.0, bottom_tip: float = 0.0):
        a = Vector(a)
        b = Vector(b)
        axis = (b - a)
        length = axis.length
        direction = axis.normalized() if length > 1e-6 else Vector((0, 0, 1))
        basis = direction.to_track_quat("Z", "Y").to_matrix()
        lower = self.ring(a, basis, r1, r1 * squash, sides, phase)
        upper = self.ring(b, basis, r2, r2 * squash, sides, phase)
        for i in range(sides):
            j = (i + 1) % sides
            self.face([lower[i], lower[j], upper[j], upper[i]], index)
        cap = index if cap_index is None else cap_index
        if tip > 0:
            apex = self.bm.verts.new(b + direction * tip)
            for i in range(sides):
                self.face([upper[i], upper[(i + 1) % sides], apex], index)
        elif r2 > 1e-4:
            self.face(list(upper), cap)
        if bottom_tip > 0:
            apex = self.bm.verts.new(a - direction * bottom_tip)
            for i in range(sides):
                self.face([lower[(i + 1) % sides], lower[i], apex], index)
        elif r1 > 1e-4:
            self.face(list(reversed(lower)), cap)

    def box(self, center, size, index: int, rot: tuple = (0, 0, 0)):
        c = Vector(center)
        m = (Matrix.Rotation(rot[2], 3, "Z") @ Matrix.Rotation(rot[1], 3, "Y") @ Matrix.Rotation(rot[0], 3, "X"))
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        corners = [Vector((sx * hx, sy * hy, sz * hz)) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
        v = [self.bm.verts.new(c + m @ p) for p in corners]
        for quad in [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]:
            self.face([v[k] for k in quad], index)

    def sphere(self, center, radius: float, index: int, scale=(1, 1, 1), subdiv: int = 2, rough: float = 0.0, seed: float = 0.0):
        temp = bmesh.new()
        bmesh.ops.create_icosphere(temp, subdivisions=subdiv, radius=radius)
        mapping = {}
        c = Vector(center)
        for vert in temp.verts:
            p = vert.co.copy()
            if rough > 0:
                n = noise.noise(p * 1.7 + Vector((seed, seed * 0.7, seed * 1.3)))
                p = p * (1.0 + rough * n)
            p = Vector((p.x * scale[0], p.y * scale[1], p.z * scale[2]))
            mapping[vert] = self.bm.verts.new(c + p)
        for f in temp.faces:
            self.face([mapping[v] for v in f.verts], index)
        temp.free()

    def torus(self, center, major: float, minor: float, index: int, segments: int = 32, sides: int = 8,
              axis: str = "Z", tilt: float = 0.0):
        c = Vector(center)
        orient = {"Z": Matrix.Identity(3), "Y": Matrix.Rotation(math.pi / 2, 3, "X"), "X": Matrix.Rotation(math.pi / 2, 3, "Y")}[axis]
        orient = orient @ Matrix.Rotation(tilt, 3, "X")
        rings = []
        for i in range(segments):
            a = math.tau * i / segments
            center_i = Vector((math.cos(a) * major, math.sin(a) * major, 0))
            radial = Vector((math.cos(a), math.sin(a), 0))
            ring = []
            for k in range(sides):
                b = math.tau * k / sides
                p = center_i + radial * math.cos(b) * minor + Vector((0, 0, math.sin(b) * minor))
                ring.append(self.bm.verts.new(c + orient @ p))
            rings.append(ring)
        for i in range(segments):
            j = (i + 1) % segments
            for k in range(sides):
                l = (k + 1) % sides
                self.face([rings[i][k], rings[j][k], rings[j][l], rings[i][l]], index)

    def star(self, center, radius: float, inner: float, depth: float, index: int, points: int = 4, facing: str = "Y"):
        c = Vector(center)
        orient = {"Y": Matrix.Rotation(math.pi / 2, 3, "X"), "Z": Matrix.Identity(3), "X": Matrix.Rotation(math.pi / 2, 3, "Y")}[facing]
        rim = []
        for i in range(points * 2):
            a = math.pi / 2 + i * math.pi / points
            r = radius if i % 2 == 0 else inner
            rim.append(self.bm.verts.new(c + orient @ Vector((math.cos(a) * r, math.sin(a) * r, 0))))
        front = self.bm.verts.new(c + orient @ Vector((0, 0, depth)))
        back = self.bm.verts.new(c + orient @ Vector((0, 0, -depth)))
        n = len(rim)
        for i in range(n):
            self.face([front, rim[i], rim[(i + 1) % n]], index)
            self.face([back, rim[(i + 1) % n], rim[i]], index)

    def lathe(self, profile: list, sides: int, index: int, center=(0, 0, 0), wobble: float = 0.0, seed: float = 0.0):
        c = Vector(center)
        rings = []
        for (r, z) in profile:
            ring = []
            for i in range(sides):
                a = math.tau * i / sides
                rr = r * (1.0 + wobble * noise.noise(Vector((math.cos(a) * 2 + seed, math.sin(a) * 2, z))))
                ring.append(self.bm.verts.new(c + Vector((math.cos(a) * rr, math.sin(a) * rr, z))))
            rings.append(ring)
        for k in range(len(rings) - 1):
            for i in range(sides):
                j = (i + 1) % sides
                self.face([rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]], index)
        if profile[0][0] > 1e-4: self.face(list(reversed(rings[0])), index)
        if profile[-1][0] > 1e-4: self.face(list(rings[-1]), index)

    def finish(self, name: str, origin=(0, 0, 0)) -> bpy.types.Object:
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        data = bpy.data.meshes.new(name + "_Mesh")
        self.bm.to_mesh(data)
        self.bm.free()
        for m in self.materials: data.materials.append(m)
        data.uv_layers.new(name="UVMap")
        o = Vector(origin)
        if o.length > 0: data.transform(Matrix.Translation(-o))
        obj = bpy.data.objects.new(name, data)
        bpy.context.scene.collection.objects.link(obj)
        obj.location = o
        return obj


def export(name: str, category: str, objects: list) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(ASSETS, category, name + ".glb")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_animations=False, export_cameras=False, export_lights=False)
    tris = 0
    for obj in objects:
        if obj.type == "MESH":
            obj.data.calc_loop_triangles()
            tris += len(obj.data.loop_triangles)
    built[name] = {"file": os.path.relpath(path, ROOT), "nodes": [o.name for o in objects], "triangles": tris}
    for obj in objects:
        obj.location.x += offset_x[0]
    offset_x[0] += 16.0
    print("ASSET", name, tris, "tris")


# --- Materiales -----------------------------------------------------------------------------------

def palette() -> dict:
    return {
        "crystal": mat("Crystal_Violet", "B89BFF", emission=1.2, rough=0.1, emission_color="8F6BFF"),
        "crystal_teal": mat("Crystal_Teal", "8FF3E4", emission=1.2, rough=0.1, emission_color="3FC7B9"),
        "cave": mat("Cave_Stone", "4A4760", rough=0.9),
        "cave_dark": mat("Cave_Stone_Dark", "34324A", rough=0.95),
        "stone": mat("Carved_Stone", "7B8B8E", rough=0.85),
        "stone_light": mat("Pale_Stone", "A9B4AE", rough=0.8),
        "brass": mat("Engraved_Brass", "C9A54E", metallic=0.75, rough=0.35),
        "gold_glow": mat("Glow_Gold", "FFD98A", emission=2.5, rough=0.3),
        "teal_glow": mat("Glow_Teal", "4ECDC4", emission=1.8, rough=0.3),
        "lens": mat("Lens_Gem", "FFF1C9", emission=3.0, rough=0.05, emission_color="FFE6A8"),
        "wood": mat("Ancient_Wood", "6A503C", rough=0.85),
        "sail": mat("Sail_Cloth", "EDE3CC", rough=0.9),
        "roof": mat("Roof_Tile", "3E7C87", rough=0.7),
        "moss": mat("Cloud_Moss", "5FA07A", rough=0.9),
        "copper": mat("Dome_Copper", "4E9C92", metallic=0.55, rough=0.45),
        "night": mat("Night_Marble", "2C3552", rough=0.4),
        "echo_dark": mat("Echo_Shadow", "242A40", emission=0.15, rough=0.7),
        "echo_violet": mat("Crystal_Echo", "8267D6", emission=1.4, rough=0.25),
        "echo_eye": mat("Glow_Echo_Eye", "FFB36B", emission=3.0, rough=0.2),
        "cefiro_skin": mat("Cefiro_Skin", "CFEDEA", rough=0.55),
        "cefiro_glow": mat("Glow_Cefiro", "7FF0DE", emission=2.2, rough=0.3),
        "eclipse": mat("Eclipse_Black", "151222", metallic=0.3, rough=0.35),
        "eclipse_fire": mat("Glow_Eclipse", "FF9A5A", emission=3.2, rough=0.3),
        "maren": mat("Maren_Light", "CFE8FF", emission=0.8, rough=0.5),
        "maren_lantern": mat("Glow_Lantern", "FFD98A", emission=3.5, rough=0.3),
    }


# --- Recursos ---------------------------------------------------------------------------------------

def crystal_cluster(b: Builder, count: int, height: float, spread: float, base_index: int, crystal_index: int,
                    base_radius: float, seed: int) -> None:
    local = random.Random(seed)
    b.sphere((0, 0, 0.05), base_radius, base_index, scale=(1.0, 1.0, 0.38), subdiv=2, rough=0.35, seed=seed)
    b.prism((0, 0, -0.1), (0, 0, height), height * 0.13, height * 0.115, 6, crystal_index, tip=height * 0.2,
            phase=local.random())
    for i in range(count - 1):
        a = math.tau * i / (count - 1) + local.uniform(-0.3, 0.3)
        lean = local.uniform(0.25, 0.6)
        length = height * local.uniform(0.3, 0.72)
        start = Vector((math.cos(a) * spread * local.uniform(0.25, 0.6), math.sin(a) * spread * local.uniform(0.25, 0.6), -0.05))
        direction = Vector((math.cos(a) * math.sin(lean), math.sin(a) * math.sin(lean), math.cos(lean)))
        r = length * local.uniform(0.11, 0.16)
        b.prism(start, start + direction * length, r, r * 0.9, 6, crystal_index, tip=length * 0.22, phase=local.random())


def build_crystal_spire(p):
    b = Builder([p["crystal"], p["cave"]])
    crystal_cluster(b, 8, 3.6, 1.2, 1, 0, 1.15, 11)
    export("crystal_spire", "environment", [b.finish("CrystalSpire")])


def build_crystal_shard(p):
    b = Builder([p["crystal"], p["cave"]])
    crystal_cluster(b, 6, 1.1, 0.5, 1, 0, 0.45, 23)
    export("crystal_shard", "environment", [b.finish("CrystalShard")])


def build_cave_rock(p):
    b = Builder([p["cave"], p["crystal"], p["cave_dark"]])
    b.sphere((0, 0, 1.6), 1.0, 0, scale=(1.35, 1.15, 2.0), subdiv=3, rough=0.32, seed=3.1)
    b.sphere((0.9, 0.3, 0.6), 0.8, 2, scale=(1.0, 0.9, 0.9), subdiv=2, rough=0.35, seed=7.7)
    b.sphere((-0.8, -0.4, 0.4), 0.7, 2, scale=(1.1, 0.9, 0.8), subdiv=2, rough=0.35, seed=9.2)
    for k, (x, y, z, dx, dy) in enumerate([(0.9, -0.6, 2.4, 0.8, -0.5), (-1.0, 0.2, 2.9, -0.9, 0.2), (0.3, 0.9, 3.4, 0.2, 0.8)]):
        start = Vector((x, y, z))
        direction = Vector((dx, dy, 0.6)).normalized()
        b.prism(start, start + direction * 0.7, 0.13, 0.11, 6, 1, tip=0.18)
    export("cave_rock", "environment", [b.finish("CaveRock")])


def build_rock_arch(p):
    b = Builder([p["cave"], p["crystal"], p["cave_dark"]])
    for i in range(15):
        t = i / 14.0
        a = math.pi * t
        x = -3.2 * math.cos(a)
        z = 0.2 + 4.2 * math.sin(a)
        size = 1.05 - 0.35 * math.sin(a)
        b.sphere((x, 0, z), size, 0 if i % 3 else 2, scale=(1.0, 1.1, 0.95), subdiv=2, rough=0.35, seed=i * 1.7)
        if 3 <= i <= 11 and i % 2 == 1:
            start = Vector((x, 0, z - size * 0.8))
            b.prism(start, start + Vector((0, 0, -0.6 - 0.4 * (i % 3))), 0.12, 0.1, 6, 1, tip=0.2)
    export("rock_arch", "environment", [b.finish("RockArch")])


def build_cloud_stone(p):
    b = Builder([p["moss"], p["stone"], p["crystal_teal"]])
    b.lathe([(2.15, 0.0), (2.2, -0.12), (2.05, -0.35)], 10, 0, wobble=0.03, seed=1.0)
    b.lathe([(2.05, -0.35), (1.7, -0.8), (1.0, -1.4), (0.35, -2.0), (0.0, -2.3)], 10, 1, wobble=0.12, seed=4.0)
    for k in range(3):
        a = k * 2.1
        start = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, -1.2))
        b.prism(start, start + Vector((math.cos(a) * 0.2, math.sin(a) * 0.2, -0.7)), 0.14, 0.12, 6, 2, tip=0.2)
    export("cloud_stone", "environment", [b.finish("CloudStone")])


def build_prism(p):
    base = Builder([p["stone"], p["brass"], p["teal_glow"]])
    base.prism((0, 0, 0), (0, 0, 0.12), 0.55, 0.55, 8, 0, phase=math.pi / 8)
    base.prism((0, 0, 0.12), (0, 0, 0.82), 0.38, 0.32, 8, 0, phase=math.pi / 8)
    base.torus((0, 0, 0.84), 0.36, 0.05, 1, segments=24, sides=6)
    base.torus((0, 0, 0.45), 0.36, 0.022, 2, segments=24, sides=5)
    base_obj = base.finish("PrismBase")
    head = Builder([p["brass"], p["crystal"], p["gold_glow"]])
    head.prism((0, 0, 0.86), (0, 0, 0.94), 0.34, 0.34, 16, 0)
    for side in (-1, 1):
        head.box((side * 0.34, 0, 1.28), (0.06, 0.12, 0.72), 0)
        head.sphere((side * 0.34, 0, 1.66), 0.07, 0, subdiv=1)
    # Prisma triangular: una arista hacia atrás (-Y) y una cara plana hacia la salida (+Y).
    head.prism((0, 0, 0.98), (0, 0, 1.62), 0.3, 0.3, 3, 1, phase=-math.pi / 2)
    # Flecha dorada que señala la dirección de salida del rayo.
    head.face([head.bm.verts.new(Vector(v)) for v in [(-0.13, 0.28, 0.95), (0.13, 0.28, 0.95), (0.0, 0.5, 0.95)]], 2)
    head.face([head.bm.verts.new(Vector(v)) for v in [(0.0, 0.5, 0.95), (0.13, 0.28, 0.95), (-0.13, 0.28, 0.95)]], 2)
    head_obj = head.finish("PrismHead", origin=(0, 0, 0.9))
    export("prism", "props", [base_obj, head_obj])


def build_beam_emitter(p):
    b = Builder([p["stone"], p["brass"], p["lens"], p["teal_glow"]])
    b.prism((0, 0, 0), (0, 0, 0.9), 0.48, 0.4, 6, 0, phase=math.pi / 6)
    b.box((0, 0, 1.0), (0.7, 0.7, 0.18), 0)
    b.prism((0, -0.45, 1.25), (0, 0.35, 1.25), 0.3, 0.26, 12, 1)
    for y in (-0.3, 0.0, 0.25):
        b.torus((0, y, 1.25), 0.3, 0.035, 1, segments=20, sides=5, axis="Y")
    b.prism((0, 0.35, 1.25), (0, 0.42, 1.25), 0.22, 0.22, 16, 2)
    b.torus((0, -0.1, 1.25), 0.36, 0.02, 3, segments=20, sides=4, axis="Y")
    export("beam_emitter", "props", [b.finish("BeamEmitter")])


def build_beam_receptor(p):
    body = Builder([p["stone"], p["brass"], p["teal_glow"]])
    body.prism((0, 0, 0), (0, 0, 0.15), 0.5, 0.5, 8, 0, phase=math.pi / 8)
    body.prism((0, 0, 0.15), (0, 0, 0.9), 0.3, 0.24, 8, 0, phase=math.pi / 8)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        body.prism((math.cos(a) * 0.22, math.sin(a) * 0.22, 0.9), (math.cos(a) * 0.36, math.sin(a) * 0.36, 1.55), 0.035, 0.03, 5, 1)
    body.torus((0, 0, 1.22), 0.38, 0.03, 1, segments=24, sides=5)
    body.torus((0, 0, 0.55), 0.29, 0.02, 2, segments=20, sides=4)
    body_obj = body.finish("ReceptorBody")
    gem = Builder([p["crystal"]])
    gem.sphere((0, 0, 1.24), 0.26, 0, subdiv=1)
    gem_obj = gem.finish("ReceptorGem", origin=(0, 0, 1.24))
    export("beam_receptor", "props", [body_obj, gem_obj])


def build_windmill(p):
    tower = Builder([p["stone_light"], p["wood"], p["roof"], p["stone"]])
    tower.prism((0, 0, 0), (0, 0, 6.0), 1.7, 1.15, 8, 0, phase=math.pi / 8)
    tower.prism((0, 0, 2.9), (0, 0, 3.15), 1.5, 1.48, 8, 1, phase=math.pi / 8)
    tower.prism((0, 0, 5.9), (0, 0, 6.15), 1.45, 1.45, 8, 1, phase=math.pi / 8)
    tower.prism((0, 0, 6.1), (0, 0, 7.4), 1.65, 0.1, 8, 2, tip=0.5, phase=math.pi / 8)
    tower.box((0, -1.45, 0.9), (0.9, 0.3, 1.8), 1)
    tower.box((0, -1.2, 4.3), (0.5, 0.2, 0.7), 3)
    tower.prism((0, -1.0, 5.2), (0, -1.55, 5.2), 0.22, 0.2, 10, 1)
    tower_obj = tower.finish("Tower")
    blades = Builder([p["wood"], p["sail"], p["brass"]])
    hub = Vector((0, -1.7, 5.2))
    blades.prism(hub + Vector((0, 0.15, 0)), hub + Vector((0, -0.25, 0)), 0.34, 0.3, 10, 2)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        radial = Vector((math.cos(a), 0, math.sin(a)))
        side = Vector((-math.sin(a), 0, math.cos(a)))
        blades.prism(hub + radial * 0.2, hub + radial * 4.1, 0.07, 0.05, 6, 0)
        for t in (1.2, 2.2, 3.2, 4.0):
            p0 = hub + radial * t
            blades.box(p0 + side * 0.42, (0.05, 0.05, 0.05), 0)
        # Vela: cuadrilátero con grosor (dos caras) desplazado a un lado del brazo.
        corners = [hub + radial * 1.0 + side * 0.08, hub + radial * 4.0 + side * 0.08, hub + radial * 4.0 + side * 0.95,
                   hub + radial * 1.0 + side * 0.85]
        front = [blades.bm.verts.new(c + Vector((0, -0.03, 0))) for c in corners]
        back = [blades.bm.verts.new(c + Vector((0, 0.03, 0))) for c in corners]
        blades.face(front, 1)
        blades.face(list(reversed(back)), 1)
        for i in range(4):
            j = (i + 1) % 4
            blades.face([front[i], back[i], back[j], front[j]], 1)
    blades_obj = blades.finish("Blades", origin=tuple(hub))
    export("windmill", "environment", [tower_obj, blades_obj])


def build_valve(p):
    body = Builder([p["stone"], p["brass"], p["teal_glow"]])
    body.box((0, 0, 0.35), (0.9, 0.7, 0.7), 0)
    body.prism((0, 0, 0.7), (0, 0, 1.5), 0.16, 0.16, 12, 1)
    body.prism((0, 0, 1.5), (0, -0.35, 1.5), 0.13, 0.13, 12, 1)
    body.torus((0, 0, 1.0), 0.19, 0.03, 2, segments=16, sides=4)
    body_obj = body.finish("ValveBody")
    wheel = Builder([p["brass"], p["teal_glow"]])
    center = Vector((0, -0.42, 1.5))
    wheel.torus(center, 0.38, 0.045, 0, segments=28, sides=6, axis="Y")
    for k in range(5):
        a = k * math.tau / 5
        wheel.prism(center, center + Vector((math.cos(a) * 0.36, 0, math.sin(a) * 0.36)), 0.025, 0.025, 5, 0)
    wheel.sphere(center, 0.08, 1, subdiv=1)
    wheel_obj = wheel.finish("ValveWheel", origin=tuple(center))
    export("valve", "props", [body_obj, wheel_obj])


def build_observatory_dome(p):
    b = Builder([p["stone_light"], p["copper"], p["brass"], p["night"]])
    radius = 7.0
    for k in range(12):
        # La columna 3 (+Y en Blender, la entrada en Godot tras girar la cúpula 180°) se omite:
        # así la rampa llega a un pórtico abierto en vez de chocar con una columna.
        if k == 3:
            continue
        a = k * math.tau / 12
        c = Vector((math.cos(a) * radius, math.sin(a) * radius, 0))
        b.prism(c, c + Vector((0, 0, 5.2)), 0.42, 0.36, 8, 0, phase=math.pi / 8)
        b.box(c + Vector((0, 0, 0.18)), (1.1, 1.1, 0.36), 0, rot=(0, 0, a))
        b.box(c + Vector((0, 0, 5.3)), (0.95, 0.95, 0.25), 2, rot=(0, 0, a))
    b.torus((0, 0, 5.55), radius, 0.35, 0, segments=36, sides=6)
    b.torus((0, 0, 5.95), radius - 0.1, 0.12, 2, segments=36, sides=5)
    rings = 7
    segments = 36
    verts = []
    for r in range(rings + 1):
        phi = (math.pi / 2) * r / rings
        row = []
        for s in range(segments):
            theta = math.tau * s / segments
            row.append(b.bm.verts.new(Vector((math.cos(theta) * math.cos(phi) * radius, math.sin(theta) * math.cos(phi) * radius,
                                              6.0 + math.sin(phi) * radius * 0.82))))
        verts.append(row)
    for r in range(rings):
        for s in range(segments):
            # Rendija del telescopio: se omite una cuña de la cúpula orientada hacia -Y.
            if s in (26, 27) and r < rings - 1: continue
            t = (s + 1) % segments
            b.face([verts[r][s], verts[r][t], verts[r + 1][t], verts[r + 1][s]], 1 if (s % 3) else 2)
    export("observatory_dome", "environment", [b.finish("ObservatoryDome")])


def build_telescope(p):
    mount = Builder([p["stone"], p["brass"], p["night"]])
    mount.prism((0, 0, 0), (0, 0, 0.5), 1.4, 1.3, 12, 0)
    mount.prism((0, 0, 0.5), (0, 0, 1.6), 0.55, 0.45, 10, 2)
    for side in (-1, 1):
        mount.box((side * 0.85, 0, 2.3), (0.22, 0.5, 1.6), 1)
    mount.torus((0, 0, 0.55), 1.3, 0.06, 1, segments=32, sides=5)
    mount_obj = mount.finish("TelescopeMount")
    tube = Builder([p["brass"], p["night"], p["lens"], p["copper"]])
    pivot = Vector((0, 0, 2.8))
    tilt = math.radians(28)
    direction = Vector((0, math.cos(tilt), math.sin(tilt)))
    back = pivot - direction * 2.2
    front = pivot + direction * 4.8
    tube.prism(back, front, 0.5, 0.72, 16, 1)
    for t in (0.0, 0.3, 0.62, 0.95):
        c = back.lerp(front, t)
        tube.torus(c, 0.52 + 0.22 * t, 0.06, 0, segments=24, sides=5, axis="Y", tilt=-tilt)
    tube.prism(front, front + direction * 0.06, 0.66, 0.66, 16, 2)
    tube.prism(back - direction * 0.4, back, 0.18, 0.4, 12, 3)
    for side in (-1, 1):
        tube.prism(pivot + Vector((side * 0.55, 0, 0)), pivot + Vector((side * 0.78, 0, 0)), 0.14, 0.14, 8, 0)
    tube_obj = tube.finish("TelescopeTube", origin=tuple(pivot))
    export("telescope", "props", [mount_obj, tube_obj])


def build_star_pillar(p):
    body = Builder([p["stone_light"], p["brass"], p["night"]])
    body.prism((0, 0, 0), (0, 0, 0.35), 0.75, 0.72, 8, 2, phase=math.pi / 8)
    body.prism((0, 0, 0.35), (0, 0, 2.9), 0.42, 0.32, 8, 0, phase=math.pi / 8)
    for z in (0.7, 1.6, 2.5):
        body.torus((0, 0, z), 0.4 - z * 0.03, 0.045, 1, segments=20, sides=5)
    body.prism((0, 0, 2.9), (0, 0, 3.05), 0.5, 0.5, 8, 1, phase=math.pi / 8)
    body.torus((0, 0, 3.55), 0.55, 0.04, 1, segments=28, sides=5, axis="Y")
    body_obj = body.finish("PillarBody")
    gem = Builder([p["gold_glow"]])
    gem.star((0, 0, 3.55), 0.42, 0.13, 0.12, 0, points=4, facing="Y")
    gem_obj = gem.finish("PillarGem", origin=(0, 0, 3.55))
    export("star_pillar", "props", [body_obj, gem_obj])


def build_star_key(p):
    b = Builder([p["brass"], mat("Key_Gem", "E8DBFF", emission=2.6, rough=0.05, emission_color="B89BFF")])
    b.torus((0, 0, 0.32), 0.3, 0.045, 0, segments=32, sides=6, axis="Y")
    b.star((0, 0, 0.32), 0.24, 0.08, 0.06, 1, points=4, facing="Y")
    b.prism((0, 0, 0.02), (0, 0, -0.62), 0.04, 0.035, 8, 0)
    for z, w in ((-0.4, 0.16), (-0.54, 0.22)):
        b.box((0.08, 0, z), (w, 0.05, 0.06), 0)
    b.sphere((0, 0, 0.66), 0.05, 0, subdiv=1)
    for k in range(8):
        a = k * math.tau / 8
        b.sphere((math.cos(a) * 0.36, 0, 0.32 + math.sin(a) * 0.36), 0.035, 0, subdiv=1)
    export("star_key", "props", [b.finish("StarKey")])


def build_vigia(p):
    c = Vector((0, 0, 1.3))
    body = Builder([p["echo_dark"], p["echo_violet"]])
    body.sphere(c, 0.34, 0, subdiv=2, rough=0.08, seed=2.0)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        start = c + Vector((math.cos(a) * 0.3, 0.1, math.sin(a) * 0.3))
        body.prism(start, start + Vector((math.cos(a) * 0.45, 0.25, math.sin(a) * 0.45)), 0.06, 0.05, 5, 1, tip=0.15)
    body.prism(c + Vector((0, 0, -0.3)), c + Vector((0, 0, -0.75)), 0.08, 0.03, 6, 1, tip=0.18)
    body_obj = body.finish("VigiaBody", origin=tuple(c))
    eye = Builder([p["echo_eye"], p["eclipse"]])
    eye.prism(c + Vector((0, -0.28, 0)), c + Vector((0, -0.36, 0)), 0.2, 0.17, 16, 0)
    eye.prism(c + Vector((0, -0.36, 0)), c + Vector((0, -0.38, 0)), 0.07, 0.07, 10, 1)
    eye_obj = eye.finish("VigiaEye", origin=tuple(c))
    ring_a = Builder([p["brass"]])
    ring_a.torus(c, 0.55, 0.025, 0, segments=36, sides=5, axis="Z", tilt=0.35)
    ring_a_obj = ring_a.finish("VigiaRingA", origin=tuple(c))
    ring_b = Builder([p["echo_violet"]])
    ring_b.torus(c, 0.68, 0.02, 0, segments=36, sides=4, axis="X")
    ring_b_obj = ring_b.finish("VigiaRingB", origin=tuple(c))
    export("vigia", "enemies", [body_obj, eye_obj, ring_a_obj, ring_b_obj])


def build_cefiro(p):
    c = Vector((0, 0, 0.95))
    body = Builder([p["cefiro_skin"], p["cefiro_glow"], p["echo_dark"]])
    body.sphere(c, 0.5, 0, scale=(0.9, 1.3, 0.36), subdiv=2)
    body.prism(c + Vector((0, 0.5, 0)), c + Vector((0, 2.0, 0.15)), 0.1, 0.01, 6, 0, tip=0.1)
    body.sphere(c + Vector((0, 1.9, 0.14)), 0.08, 1, subdiv=1)
    for side in (-1, 1):
        body.sphere(c + Vector((side * 0.16, -0.5, 0.06)), 0.055, 1, subdiv=1)
    body.sphere(c + Vector((0, -0.1, 0.13)), 0.16, 1, scale=(0.8, 1.6, 0.4), subdiv=1)
    body_obj = body.finish("CefiroBody", origin=tuple(c))
    wings = []
    for side, label in ((-1, "L"), (1, "R")):
        w = Builder([p["cefiro_skin"], p["cefiro_glow"]])
        root_front = c + Vector((side * 0.35, -0.62, 0))
        mid_front = c + Vector((side * 1.0, -0.25, 0.04))
        tip = c + Vector((side * 1.7, 0.55, 0.12))
        root_back = c + Vector((side * 0.35, 0.62, 0))
        outline = (root_front, mid_front, tip, root_back)
        top = [w.bm.verts.new(v + Vector((0, 0, 0.035))) for v in outline]
        bottom = [w.bm.verts.new(v - Vector((0, 0, 0.035))) for v in outline]
        w.face(top if side > 0 else list(reversed(top)), 0)
        w.face(list(reversed(bottom)) if side > 0 else bottom, 0)
        for i in range(4):
            j = (i + 1) % 4
            w.face([top[i], bottom[i], bottom[j], top[j]], 0)
        w.prism(root_front.lerp(mid_front, 0.2), mid_front, 0.025, 0.02, 4, 1)
        w.prism(mid_front, tip, 0.02, 0.01, 4, 1)
        wings.append(w.finish("CefiroWing" + label, origin=tuple(c + Vector((side * 0.3, 0, 0)))))
    export("cefiro", "enemies", [body_obj] + wings)


def build_heraldo(p):
    core = Builder([p["eclipse"], p["eclipse_fire"]])
    core.sphere((0, 0, 0), 1.0, 0, subdiv=3, rough=0.05, seed=5.0)
    for k in range(6):
        a = k * math.tau / 6
        core.prism(Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.0)), Vector((math.cos(a) * 1.05, math.sin(a) * 1.05, 0.0)),
                   0.14, 0.1, 6, 1)
    core_obj = core.finish("HeraldoCore")
    mask = Builder([p["stone_light"], p["eclipse_fire"], p["brass"]])
    for row in range(3):
        z = 0.45 - row * 0.4
        mask.box((0, -1.02 - row * 0.02, z), (1.1 - row * 0.18, 0.12, 0.34), 0, rot=(0.15 * (row - 1), 0, 0))
    for side in (-1, 1):
        mask.box((side * 0.25, -1.12, 0.12), (0.22, 0.05, 0.07), 1)
    mask.box((0, -1.1, 0.72), (0.12, 0.08, 0.3), 2)
    mask_obj = mask.finish("HeraldoMask")
    corona = Builder([p["eclipse"], p["gold_glow"], p["eclipse_fire"]])
    corona.torus((0, 0, 0), 2.2, 0.12, 0, segments=48, sides=6, axis="Y")
    corona.torus((0, 0, 0), 2.45, 0.035, 1, segments=48, sides=4, axis="Y")
    for k in range(16):
        a = k * math.tau / 16
        radial = Vector((math.cos(a), 0, math.sin(a)))
        length = 0.9 if k % 2 == 0 else 0.5
        corona.prism(radial * 2.25, radial * (2.25 + length), 0.1, 0.02, 4, 2 if k % 2 == 0 else 0, tip=0.12)
    corona_obj = corona.finish("HeraldoCorona")
    shards = []
    for k in range(6):
        s = Builder([p["echo_violet"], p["eclipse"]])
        a = k * math.tau / 6
        center = Vector((math.cos(a) * 1.8, 0.6, math.sin(a) * 1.8))
        direction = Vector((math.cos(a), -0.2, math.sin(a))).normalized()
        s.prism(center - direction * 0.35, center + direction * 0.35, 0.16, 0.12, 5, 0, tip=0.25, bottom_tip=0.2)
        shards.append(s.finish("HeraldoShard_%d" % k, origin=tuple(center)))
    export("heraldo", "enemies", [core_obj, mask_obj, corona_obj] + shards)


def build_maren(p):
    b = Builder([p["maren"], p["maren_lantern"], p["brass"]])
    b.lathe([(0.02, 0.0), (0.42, 0.02), (0.38, 0.35), (0.3, 0.8), (0.24, 1.2), (0.2, 1.38), (0.14, 1.48)], 12, 0, wobble=0.06, seed=3.0)
    b.sphere((0, -0.02, 1.6), 0.13, 0, scale=(0.95, 1.0, 1.1), subdiv=2)
    b.sphere((0, 0.03, 1.63), 0.18, 0, scale=(1.0, 1.05, 1.1), subdiv=2)
    for side in (-1, 1):
        b.prism((side * 0.2, -0.02, 1.36), (side * 0.3, -0.18, 1.02), 0.07, 0.055, 6, 0)
    b.prism((0.34, -0.2, 0.05), (0.34, -0.2, 1.75), 0.022, 0.022, 6, 2)
    b.prism((0.34, -0.2, 1.75), (0.34, -0.2, 1.8), 0.1, 0.1, 8, 2)
    b.sphere((0.34, -0.2, 1.9), 0.09, 1, subdiv=2)
    b.torus((0.34, -0.2, 1.9), 0.11, 0.012, 2, segments=16, sides=4)
    export("maren_echo", "characters", [b.finish("MarenEcho")])


ASSETS_TO_BUILD = {
    "crystal_spire": build_crystal_spire, "crystal_shard": build_crystal_shard, "cave_rock": build_cave_rock,
    "rock_arch": build_rock_arch, "cloud_stone": build_cloud_stone, "prism": build_prism,
    "beam_emitter": build_beam_emitter, "beam_receptor": build_beam_receptor, "windmill": build_windmill,
    "valve": build_valve, "observatory_dome": build_observatory_dome, "telescope": build_telescope,
    "star_pillar": build_star_pillar, "star_key": build_star_key, "vigia": build_vigia, "cefiro": build_cefiro,
    "heraldo": build_heraldo, "maren_echo": build_maren,
}


def main() -> None:
    args = [a for a in sys.argv[sys.argv.index("--") + 1:]] if "--" in sys.argv else [a for a in sys.argv[1:] if not a.endswith(".py")]
    selected = [a for a in args if a in ASSETS_TO_BUILD] or list(ASSETS_TO_BUILD)
    reset_scene()
    p = palette()
    for name in selected:
        ASSETS_TO_BUILD[name](p)
    os.makedirs(os.path.dirname(BLEND), exist_ok=True)
    if len(selected) == len(ASSETS_TO_BUILD):
        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    previous = {}
    if os.path.exists(METRICS):
        with open(METRICS, encoding="utf-8") as handle: previous = json.load(handle)
    previous.update(built)
    with open(METRICS, "w", encoding="utf-8") as handle:
        json.dump(previous, handle, indent=2, ensure_ascii=False)
    print("CHAPTER2_ASSETS", len(built))


main()
