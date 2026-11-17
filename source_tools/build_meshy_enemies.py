"""Monta los enemigos con cuerpos generados en Meshy y las piezas animadas de los modelos anteriores.

Uso (desde la raiz del proyecto):
  blender --background --factory-startup --python-exit-code 1 --python source_tools/build_meshy_enemies.py
  # solo algunos:  ... --python source_tools/build_meshy_enemies.py -- echo cefiro

Entradas (source_assets/meshy_enemies/):
  <nombre>_raw.glb     salida directa de Meshy (frente hacia -Y en Blender, +Z en Godot)
  legacy_<nombre>.glb  modelo procedural anterior; de el se conservan anillos, corona y fragmentos
Salidas: godot/assets/enemies/<nombre>.glb, blender/meshy_enemies_metrics.json,
         artifacts/meshy_preview/<nombre>.png

Los scripts del juego buscan nodos por nombre, asi que se mantienen:
  echo_sentinel          un solo nodo
  VigiaBody, VigiaRingA/B  (VigiaEye desaparece: el ojo va pintado en el cuerpo)
  CefiroBody, CefiroRig  malla continua, tres huesos y tres ciclos de aleteo
  HeraldoCore, HeraldoCorona, HeraldoShard_0..5  (HeraldoMask va incluida en el nucleo)
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Quaternion, Vector

sys.path.insert(0, os.path.dirname(__file__))
from build_meshy_environment import ROOT, bounds, move, render  # noqa: E402

SOURCE = os.path.join(ROOT, "source_assets", "meshy_enemies")
OUT = os.path.join(ROOT, "godot", "assets", "enemies")
METRICS = os.path.join(ROOT, "blender", "meshy_enemies_metrics.json")


def import_glb(path):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.context.scene.objects if o not in before]


def meshy(name, target, scale, center, source_name=None):
    """Importa <name>_raw.glb como una malla centrada en `center` (el origen del objeto queda ahi)."""
    made = import_glb(os.path.join(SOURCE, source_name or name + "_raw.glb"))
    meshes = [o for o in made if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for other in made:
        if other != obj and other.name in bpy.context.scene.objects:
            bpy.data.objects.remove(other)
    low, high = bounds(obj)
    middle = (low + high) * 0.5
    move(obj, lambda p: (p - middle) * scale)
    obj.location = Vector(center)
    obj.name = obj.data.name = target
    for material in obj.data.materials:
        material.name = "Meshy_" + name
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf and not source_name:
            bsdf.inputs["Roughness"].default_value = 0.85
            bsdf.inputs["Metallic"].default_value = 0.0
    bpy.ops.object.shade_smooth()
    return obj


def legacy(name, keep):
    kept = []
    for obj in import_glb(os.path.join(SOURCE, "legacy_%s.glb" % name)):
        if any(obj.name.startswith(prefix) for prefix in keep):
            kept.append(obj)
        else:
            bpy.data.objects.remove(obj)
    return kept


def rig_wings(body):
    """Deform the original mesh without cutting its topology, UVs or shoulder seams."""
    armature = bpy.data.armatures.new("CefiroSkeleton")
    rig = bpy.data.objects.new("CefiroRig", armature)
    bpy.context.scene.collection.objects.link(rig)
    rig.location = body.location.copy()
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = armature.edit_bones.new("Root")
    root.head, root.tail = (0, 0, 0), (0, 0, 0.3)
    for name, side in (("WingL", -1), ("WingR", 1)):
        bone = armature.edit_bones.new(name)
        bone.head, bone.tail = (side * 0.3, 0, 0), (side * 1.3, 0, 0)
        bone.parent = root
    bpy.ops.object.mode_set(mode="OBJECT")
    groups = {name: body.vertex_groups.new(name=name) for name in ("Root", "WingL", "WingR")}
    for vertex in body.data.vertices:
        t = max(0.0, min(1.0, (abs(vertex.co.x) - 0.20) / 0.45))
        weight = t * t * (3.0 - 2.0 * t)
        if weight < 1.0:
            groups["Root"].add([vertex.index], 1.0 - weight, "REPLACE")
        if weight > 0.0:
            groups["WingL" if vertex.co.x < 0 else "WingR"].add([vertex.index], weight, "REPLACE")
    # Keep vertices local to the common body/rig origin.
    body.parent = rig
    body.location = (0, 0, 0)
    modifier = body.modifiers.new("ContinuousWings", "ARMATURE")
    modifier.object = rig
    bpy.context.scene.render.fps = 24
    rig.animation_data_create()
    clips = {}
    for name, frames, amplitude in (("CefiroFlight", 32, 0.40), ("CefiroCharge", 14, 0.52),
                                     ("CefiroRest", 50, 0.12)):
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        for frame in range(frames + 1):
            for bone_name, side in (("WingL", -1), ("WingR", 1)):
                pose = rig.pose.bones[bone_name]
                axis = pose.bone.matrix_local.to_3x3().inverted() @ Vector((0, 1, 0))
                pose.rotation_mode = "QUATERNION"
                pose.rotation_quaternion = Quaternion(axis, -side * math.sin(math.tau * frame / frames) * amplitude)
                pose.keyframe_insert("rotation_quaternion", frame=frame, group=bone_name)
        clips[name] = frames / 24
    rig.animation_data.action = bpy.data.actions["CefiroFlight"]
    rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    bpy.context.scene.frame_set(0)
    return rig, {"bones": len(armature.bones), "clips_seconds": clips,
                 "continuous_mesh": True, "source_vertices": len(body.data.vertices)}


def darken_core(obj, radius):
    """Meshy pinto de blanco media esfera del Heraldo: oscurece lo palido que no pertenece a la mascara."""
    image = next(n.image for m in obj.data.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE")
    width, height = image.size
    pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
    zone = np.zeros((height, width), dtype=bool)
    uvs = obj.data.uv_layers.active.data
    for poly in obj.data.polygons:
        c = poly.center / radius
        if c.y < -0.55 and abs(c.x) < 0.6 and c.z > -0.75:
            continue  # mascara: se respeta
        pts = np.array([[uvs[i].uv.x * width, uvs[i].uv.y * height] for i in poly.loop_indices])
        x0, y0 = np.floor(pts.min(axis=0)).astype(int) - 1
        x1, y1 = np.ceil(pts.max(axis=0)).astype(int) + 1
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, width - 1), min(y1, height - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        a, b, cc = pts[0], pts[1], pts[2]
        den = (b[1] - cc[1]) * (a[0] - cc[0]) + (cc[0] - b[0]) * (a[1] - cc[1])
        if abs(den) < 1e-9:
            continue
        w0 = ((b[1] - cc[1]) * (gx - cc[0]) + (cc[0] - b[0]) * (gy - cc[1])) / den
        w1 = ((cc[1] - a[1]) * (gx - cc[0]) + (a[0] - cc[0]) * (gy - cc[1])) / den
        inside = (w0 >= -0.15) & (w1 >= -0.15) & (1 - w0 - w1 >= -0.15)
        zone[y0:y1 + 1, x0:x1 + 1] |= inside
    rgb = pixels[:, :, :3]
    high, low = rgb.max(axis=2), rgb.min(axis=2)
    pale = zone & (high > 0.2) & ((high - low) / np.maximum(high, 1e-4) < 0.3)
    rgb[pale] = np.array([0.03, 0.03, 0.045], dtype=np.float32)
    image.pixels = pixels.ravel().tolist()
    image.pack()
    return int(pale.sum())


def build_echo():
    # Altura 1.25 m, flota con la base a 0.22 m como el anterior.
    return [meshy("echo", "echo_sentinel", 1.25, (0, 0, 0.22 + 0.625))], {}


def build_vigia():
    kept = legacy("vigia", ("VigiaRing",))
    return [meshy("vigia", "VigiaBody", 1.3, (0, 0, 1.3))] + kept, {}


def build_cefiro():
    # Envergadura 3 m; la cabeza queda 1.1 m por delante del centro de colision.
    body = meshy("cefiro", "CefiroBody", 3.0, (0, 0.35, 0.95))
    rig, metrics = rig_wings(body)
    return [body, rig], metrics


def build_heraldo():
    kept = legacy("heraldo", ("HeraldoCorona", "HeraldoShard"))
    core = meshy("heraldo", "HeraldoCore", 2.15, (0, 0, 0), "heraldo_retextured.glb")
    return [core] + kept, {"texture_source": "heraldo_retextured.glb", "pbr": True}


BUILDERS = {"echo": ("echo_sentinel", build_echo), "vigia": ("vigia", build_vigia),
            "cefiro": ("cefiro", build_cefiro), "heraldo": ("heraldo", build_heraldo)}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    metrics = {}
    if os.path.isfile(METRICS):
        with open(METRICS, encoding="utf-8") as stream:
            metrics = json.load(stream)
    for name in args or list(BUILDERS):
        target, builder = BUILDERS[name]
        bpy.ops.wm.read_factory_settings(use_empty=True)
        objects, extra = builder()
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, target + ".glb"), export_format="GLB",
                                  use_selection=True, export_image_format="JPEG", export_jpeg_quality=90,
                                  export_yup=True, export_apply=False, export_skins=True,
                                  export_animations=True, export_animation_mode="ACTIONS")
        if name == "cefiro":
            bpy.ops.file.pack_all()
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "blender", "cefiro_demo.blend"))
        render(objects[0], name, wide=2.4)
        metrics[name] = dict(extra, nodes=[o.name for o in objects],
                             triangles=sum(len(p.vertices) - 2 for o in objects if o.type == "MESH" for p in o.data.polygons))
        print("BUILT", name, metrics[name])
    with open(METRICS, "w", encoding="utf-8") as stream:
        json.dump(metrics, stream, indent=2)


if __name__ == "__main__":
    main()
