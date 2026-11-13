"""Adapta los modelos de entorno generados con Meshy a las medidas que espera el juego.

Uso (desde la raiz del proyecto):
  blender --background --factory-startup --python-exit-code 1 --python source_tools/build_meshy_environment.py
  # solo algunos:  ... --python source_tools/build_meshy_environment.py -- arch tree

Entradas:  source_assets/meshy_umbral/<nombre>_raw.glb  (salida directa de Meshy, no se modifica)
Salidas:   godot/assets/environment/<destino>.glb, blender/meshy_environment_metrics.json
           artifacts/meshy_preview/<nombre>.png (vista previa, fuera de Git)

Cada modelo se une en una malla, se orienta, se escala a la altura indicada, se centra en X/Y y se
apoya en el suelo (origen en la base, como los modelos procedurales que sustituye). `sink` hunde la
base bajo el suelo; `clear` entierra el arco hasta ocultar la losa que Meshy deja dentro del vano.
"""
import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE = os.path.join(ROOT, "source_assets", "meshy_umbral")
OUT = os.path.join(ROOT, "godot", "assets", "environment")
PREVIEW = os.path.join(ROOT, "artifacts", "meshy_preview")
METRICS = os.path.join(ROOT, "blender", "meshy_environment_metrics.json")

# height: altura visible sobre el suelo (m). wide: el eje mas ancho debe quedar en X.
ASSETS = {
    "arch": {"target": "entrance_arch", "height": 5.65, "wide": True, "sink": 0.0, "clear": True},
    "tree": {"target": "tree", "height": 4.2, "sink": 0.06},
    "column": {"target": "column", "height": 2.9, "sink": 0.02},
    "boulder": {"target": "boulder", "height": 1.0, "wide": True, "sink": 0.08},
}


def load(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SOURCE, name + "_raw.glb"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects:
        o.select_set(o.type == "MESH")
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for other in [o for o in bpy.context.scene.objects if o != obj]:
        bpy.data.objects.remove(other)
    return obj


def bounds(obj):
    points = [v.co for v in obj.data.vertices]
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def move(obj, matrix_fn):
    for v in obj.data.vertices:
        v.co = matrix_fn(v.co)
    obj.data.update()


def opening_floor(obj):
    """Altura de la losa que Meshy deja dentro del vano del arco, medida desde la base."""
    low, high = bounds(obj)
    half = (high.x - low.x) * 0.5
    limit = low.z + (high.z - low.z) * 0.3
    return max(v.co.z for v in obj.data.vertices if abs(v.co.x) < half * 0.15 and v.co.z < limit) - low.z


def render(obj, name):
    os.makedirs(PREVIEW, exist_ok=True)
    scene = bpy.context.scene
    low, high = bounds(obj)
    size = max(high.x - low.x, high.z - low.z)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = size * 1.25
    cam.location = (size * 1.2, -size * 2.5, (high.z + low.z) * 0.5 + size * 0.7)
    target = Vector((0, 0, (high.z + low.z) * 0.5))
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.filepath = os.path.join(PREVIEW, name + ".png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)


def build(name, spec):
    obj = load(name)
    low, high = bounds(obj)
    if spec.get("wide") and (high.y - low.y) > (high.x - low.x):
        move(obj, lambda p: Vector((p.y, -p.x, p.z)))
        low, high = bounds(obj)
    center = (low + high) * 0.5
    move(obj, lambda p: Vector((p.x - center.x, p.y - center.y, p.z - low.z)))
    low, high = bounds(obj)
    # El arco se entierra hasta que su losa queda 4 cm bajo el suelo: el vano queda libre para caminar.
    buried = opening_floor(obj) if spec.get("clear") else 0.0
    scale = (spec["height"] + spec["sink"]) / (high.z - low.z - buried)
    sink = spec["sink"] + buried * scale + (0.04 if buried else 0.0)
    move(obj, lambda p: Vector((p.x * scale, p.y * scale, (p.z - low.z) * scale - sink)))
    obj.name = obj.data.name = spec["target"]
    for material in obj.data.materials:
        material.name = "Meshy_" + spec["target"]
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Roughness"].default_value = 0.9
            bsdf.inputs["Metallic"].default_value = 0.0
    bpy.ops.object.shade_smooth()
    render(obj, name)
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, spec["target"] + ".glb"), export_format="GLB",
                              use_selection=True, export_image_format="JPEG", export_jpeg_quality=90,
                              export_yup=True, export_apply=True)
    low, high = bounds(obj)
    return {"target": spec["target"], "triangles": sum(len(p.vertices) - 2 for p in obj.data.polygons),
            "size_m": [round(high.x - low.x, 3), round(high.y - low.y, 3), round(high.z - low.z, 3)],
            "min_z": round(low.z, 3)}


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = args or list(ASSETS)
    metrics = {}
    if os.path.isfile(METRICS):
        with open(METRICS, encoding="utf-8") as stream:
            metrics = json.load(stream)
    for name in names:
        metrics[name] = build(name, ASSETS[name])
        print("BUILT", name, metrics[name])
    with open(METRICS, "w", encoding="utf-8") as stream:
        json.dump(metrics, stream, indent=2)


main()
