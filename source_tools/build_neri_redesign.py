"""Assemble the approved Meshy character and fresh rig into in-place Godot clips.
Run Blender 5.2 --background --factory-startup --python-exit-code 1 --python this_file.
Original generation files remain immutable. Gameplay, not root motion, moves Neri.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source_assets/neri_redesign'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'actions.glb'))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
bodies = [o for o in scene.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)]
for obj in list(scene.objects):
    if obj.type == 'MESH' and obj not in bodies:
        bpy.data.objects.remove(obj, do_unlink=True)  # glTF bone-display helper, not character geometry
source_actions = {a.name: a for a in bpy.data.actions}
for filename in ['walk', 'run']:
    before_objects = set(bpy.data.objects)
    before_actions = set(bpy.data.actions)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / (filename + '.glb')))
    imported = [o for o in bpy.data.objects if o not in before_objects]
    donor = next(o for o in imported if o.type == 'ARMATURE')
    assert list(donor.data.bones.keys()) == list(rig.data.bones.keys())
    action = next(a for a in bpy.data.actions if a not in before_actions)
    action.use_fake_user = True
    source_actions[filename] = action
    for o in imported: bpy.data.objects.remove(o, do_unlink=True)

def set_action(action):
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]

def bounds():
    points = []
    for body in bodies:
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        points.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
        evaluated.to_mesh_clear()
    return [[min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)]]

specs = {
    'idle': ('Idle', 0, 1, 2.0), 'walk': ('walk', 0, 1, None), 'run': ('run', 0, 1, None),
    'jump': ('Regular_Jump', 0.05, 0.42, 0.48),
    'fall': ('Regular_Jump', 0.43, 0.55, 0.8),
    'land': ('Regular_Jump', 0.72, 1, 0.36),
    'interact': ('Male_Bend_Over_Pick_Up', 0, 1, 1.25),
    'wave': ('Wave_One_Hand', 0, 1, 1.8),
    'pulse': ('mage_soell_cast', 0, 1, 0.7),
    'hurt': ('Hit_Reaction', 0, 1, 0.5),
    'dodge': ('Roll_Dodge', 0, 1, 0.5),
}
scene.render.fps = 30
hips = rig.pose.bones['Hips']
root_axes_inverse = (rig.matrix_world.to_3x3() @ hips.bone.matrix_local.to_3x3()).inverted()
report = {'bones': len(rig.data.bones), 'animations': {}, 'source': 'Meshy redesign approved 2026-11-17'}
outputs = []
for name, (source_name, begin, end, duration) in specs.items():
    source = source_actions[source_name]
    set_action(source)
    first, last = source.frame_range
    duration = duration or (last - first) / 30
    frames = max(2, round(duration * 30))
    samples = []
    for frame in range(frames + 1):
        fraction = frame / frames
        if name == 'fall': fraction = (1 - math.cos(fraction * math.tau)) * 0.5
        at = first + (last - first) * (begin + (end - begin) * fraction)
        scene.frame_set(int(at), subframe=at % 1)
        bpy.context.view_layer.update()
        # Preserve limb motion, remove horizontal displacement, then ground the feet.
        center = rig.matrix_world @ hips.matrix.translation
        hips.location += root_axes_inverse @ Vector((-center.x, -center.y, 0))
        bpy.context.view_layer.update()
        limits = bounds()
        hips.location += root_axes_inverse @ Vector((0, 0, 0.012 - limits[0][2]))
        bpy.context.view_layer.update()
        samples.append({p.name: (p.location.copy(), p.rotation_quaternion.copy(), p.scale.copy()) for p in rig.pose.bones})
    action = bpy.data.actions.new('neri_' + name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame, sample in enumerate(samples):
        for bone_name, (location, rotation, scale) in sample.items():
            bone = rig.pose.bones[bone_name]
            bone.rotation_mode = 'QUATERNION'
            bone.location, bone.rotation_quaternion, bone.scale = location, rotation, scale
            for channel in ['location', 'rotation_quaternion', 'scale']:
                bone.keyframe_insert(channel, frame=frame, group=bone_name)
    outputs.append(action)
    report['animations'][name] = {'seconds': frames / 30, 'source': source_name, 'frames': frames + 1}
    print('BAKED', name, flush=True)

for action in list(bpy.data.actions):
    if action not in outputs: bpy.data.actions.remove(action)
set_action(outputs[0])
scene.frame_set(0)
bpy.context.view_layer.update()
limits = bounds()
assert -0.03 < limits[0][2] < 0.05, limits
assert 1.55 < limits[1][2] < 1.95, limits
for body in bodies:
    body.name = 'Neri_Redesigned'
    for polygon in body.data.polygons: polygon.use_smooth = True
report['idle_bounds'] = limits
report['triangles'] = sum(sum(len(p.vertices)-2 for p in body.data.polygons) for body in bodies)
bpy.ops.object.select_all(action='DESELECT')
for obj in list(scene.objects): obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'godot/assets/characters/neri_redesigned.glb'),
    export_format='GLB', use_selection=True, export_animations=True,
    export_animation_mode='ACTIONS', export_skins=True, export_cameras=False, export_lights=False)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'blender/neri_redesigned.blend'))
(ROOT / 'blender/neri_redesigned_metrics.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print('NERI_REDESIGNED', json.dumps(report), flush=True)
