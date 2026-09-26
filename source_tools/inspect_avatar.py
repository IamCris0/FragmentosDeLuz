"""Inspect evaluated avatar bounds with Blender, without changing the source asset."""
import bpy
import json
import sys
from pathlib import Path

args = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(Path(args[0]).resolve()))
rigs = [obj for obj in bpy.data.objects if obj.type == "ARMATURE"]
meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]

def bounds(obj):
    evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    points = [evaluated.matrix_world @ vertex.co for vertex in mesh.vertices]
    result = [[min(point[i] for point in points) for i in range(3)],
              [max(point[i] for point in points) for i in range(3)]]
    evaluated.to_mesh_clear()
    return result

report = {"objects": [{"name": obj.name, "type": obj.type, "location": list(obj.location),
                       "scale": list(obj.scale), "bounds": bounds(obj) if obj.type == "MESH" else None}
                      for obj in bpy.data.objects], "actions": {}, "bones": {}}
report["material_regions"] = {}
for obj in meshes:
    regions = {}
    for index, material in enumerate(obj.data.materials):
        points = [obj.data.vertices[v].co for poly in obj.data.polygons if poly.material_index == index for v in poly.vertices]
        if points:
            regions[material.name] = {"faces": sum(poly.material_index == index for poly in obj.data.polygons),
                "bounds": [[min(point[i] for point in points) for i in range(3)], [max(point[i] for point in points) for i in range(3)]]}
    report["material_regions"][obj.name] = regions
for rig in rigs:
    report["bones"][rig.name] = {bone.name: {"head": list(bone.head_local), "tail": list(bone.tail_local)}
                                for bone in rig.data.bones}
    rig.animation_data_clear()
    for action in bpy.data.actions:
        rig.animation_data_create()
        rig.animation_data.action = action
        if action.slots: rig.animation_data.action_slot = action.slots[0]
        frames = [action.frame_range[0], (action.frame_range[0] + action.frame_range[1]) / 2]
        samples = []
        for frame in frames:
            bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
            samples.append({"frame": frame, "meshes": {obj.name: bounds(obj) for obj in meshes}})
        report["actions"][action.name] = samples
print("AVATAR_INSPECTION " + json.dumps(report))
if len(args) > 1:
    Path(args[1]).parent.mkdir(parents=True, exist_ok=True)
    Path(args[1]).write_text(json.dumps(report, indent=2), encoding="utf-8")
