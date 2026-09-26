"""Build Neri from the CC0 Quaternius base and Universal Animation Library."""
import argparse
import bpy
import bmesh
import json
import math
import shutil
import sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source_assets/quaternius'
SOURCE.mkdir(parents=True, exist_ok=True)
args_parser = argparse.ArgumentParser()
args_parser.add_argument('--base-pack', type=Path)
args_parser.add_argument('--animation-pack', type=Path)
args = args_parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])


def stage_gltf(source, folder, search_root):
    folder.mkdir(parents=True, exist_ok=True)
    data = json.loads(source.read_text(encoding='utf-8'))
    for item in data.get('buffers', []) + data.get('images', []):
        uri = item.get('uri', '')
        if not uri or uri.startswith('data:'):
            continue
        original = source.parent / uri
        if not original.exists():
            normalized = Path(uri).name.replace('_png.png', '.png')
            original = next(search_root.rglob(normalized))
        item['uri'] = original.name
        shutil.copy2(original, folder / original.name)
    (folder / source.name).write_text(json.dumps(data), encoding='utf-8')


if args.base_pack:
    stage_gltf(args.base_pack / 'Base Characters/Godot - UE/Superhero_Male_FullBody.gltf', SOURCE / 'body', args.base_pack)
    stage_gltf(args.base_pack / 'Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_SimpleParted.gltf', SOURCE / 'hair', args.base_pack)
    shutil.copy2(args.base_pack / 'License_Standard.txt', SOURCE / 'LICENSE_characters.txt')
if args.animation_pack:
    shutil.copy2(args.animation_pack / 'Unreal-Godot/UAL1_Standard.glb', SOURCE / 'UAL1_Standard.glb')
    shutil.copy2(args.animation_pack / 'License.txt', SOURCE / 'LICENSE_animations.txt')

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'body/Superhero_Male_FullBody.gltf'))
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.name = 'Neri_Rig'
body = bpy.data.objects['SuperHero_Male']
pieces = [o for o in scene.objects if o.type == 'MESH' and o.vertex_groups]
for ob in list(scene.objects):
    if ob != rig and ob not in pieces:
        bpy.data.objects.remove(ob, do_unlink=True)


def mat(name, color, metallic=0.0, emission=0.0):
    rgb = tuple(int(color[i:i+2], 16) / 255 for i in (0, 2, 4))
    linear = tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*linear, 1)
    m.use_nodes = True
    shader = m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*linear, 1)
    shader.inputs['Roughness'].default_value = .72
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Emission Color'].default_value = (*linear, 1)
    shader.inputs['Emission Strength'].default_value = emission
    return m


skin = mat('Neri_Skin', 'D1A184')
tunic = mat('Neri_Woven_Indigo', '344763')
trouser = mat('Neri_Twill', '485760')
leather = mat('Neri_Leather', '76533C')
canvas = mat('Neri_Canvas', '497967')
brass = mat('Neri_Brass', 'C7AA66', .55)
teal = mat('Neri_Scanner', '48DCCB', .2, .8)
hair_mat = mat('Neri_Chestnut', '513327')
sole = mat('Neri_Sole', '292C32')
body.data.materials.clear()
for m in [skin, tunic, trouser, leather]:
    body.data.materials.append(m)
for p in body.data.polygons:
    z = sum(body.data.vertices[i].co.z for i in p.vertices) / len(p.vertices)
    p.material_index = 3 if z < .25 else (2 if z < 1.03 else 0)
for ob in pieces:
    if ob.name == 'Eyebrows':
        ob.data.materials.clear()
        ob.data.materials.append(hair_mat)

# Preserve the supplied skinning while narrowing the torso and enlarging the head slightly.
def shape_point(point):
    x, y, z = point
    head_weight = max(0.0, min(1.0, (z - 1.49) / .12))
    x *= .87 + .16 * head_weight
    y = .04 + (y - .04) * (.84 + .19 * head_weight)
    z *= .96
    return Vector((x, y, z))


for ob in pieces:
    for v in ob.data.vertices:
        v.co = shape_point(v.co)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for bone in rig.data.edit_bones:
    bone.head = shape_point(bone.head)
    bone.tail = shape_point(bone.tail)
bpy.ops.object.mode_set(mode='OBJECT')


def apply_modifier(obj, modifier):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def garment(name, predicate, material, thickness, cuts=()):
    ob = body.copy()
    ob.data = body.data.copy()
    scene.collection.objects.link(ob)
    ob.name = name
    for mod in list(ob.modifiers):
        ob.modifiers.remove(mod)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not predicate(f.calc_center_median())], context='FACES')
    for point, normal in cuts:
        bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                              plane_co=point, plane_no=normal, dist=.00001, clear_outer=True)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(ob.data)
    bm.free()
    if ob.data.has_custom_normals:
        ob.data.normals_split_custom_set([(0, 0, 0)] * len(ob.data.loops))
    ob.data.materials.clear()
    ob.data.materials.append(material)
    for p in ob.data.polygons:
        p.material_index = 0
    smooth = ob.modifiers.new('Relax tailoring', 'SMOOTH')
    smooth.factor = .75
    smooth.iterations = 7
    apply_modifier(ob, smooth)
    for v in ob.data.vertices:
        v.co += v.normal * thickness
    # A single fabric shell avoids nearly coincident inner faces in shadow maps.
    mod = ob.modifiers.new('Skin', 'ARMATURE')
    mod.object = rig
    pieces.append(ob)
    return ob


shirt = garment('Neri_Tunic', lambda c: .97 < c.z < 1.49 and abs(c.x) < .37 and not (c.z > 1.44 and abs(c.x) < .10), tunic, .025,
                [((0, 0, 1.035), (0, 0, -1)), ((.324, 0, 0), (1, 0, 0)), ((-.324, 0, 0), (-1, 0, 0))])
pants = garment('Neri_Trousers', lambda c: .23 < c.z < 1.02, trouser, .010)
# Skin hidden under clothes is removed to prevent intersections during deformation.
bm = bmesh.new()
bm.from_mesh(body.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < 1.025 or
    (.97 < f.calc_center_median().z < 1.49 and abs(f.calc_center_median().x) < .29)], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(body.data)
bm.free()


def bind(ob, name, material, bone):
    ob.name = name
    ob.data.materials.clear()
    ob.data.materials.append(material)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.parent = rig
    group = ob.vertex_groups.new(name=bone)
    group.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
    arm = ob.modifiers.new('Skin', 'ARMATURE')
    arm.object = rig
    pieces.append(ob)
    return ob


def rounded_box(name, location, size, material, bone, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    ob = bpy.context.object
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = ob.modifiers.new('Sewn edges', 'BEVEL')
    mod.width = bevel
    mod.segments = 4
    apply_modifier(ob, mod)
    return bind(ob, name, material, bone)


def profile(name, rings, material, bone):
    verts = []
    for z, rx, ry in rings:
        for i in range(32):
            angle = math.tau * i / 32
            verts.append((rx * math.cos(angle), .015 + ry * math.sin(angle), z))
    faces = []
    for j in range(len(rings)-1):
        for i in range(32):
            faces.append((j*32+i, j*32+(i+1)%32, (j+1)*32+(i+1)%32, (j+1)*32+i))
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    solid = ob.modifiers.new('Hem thickness', 'SOLIDIFY')
    solid.thickness = .008
    apply_modifier(ob, solid)
    return bind(ob, name, material, bone)


hem = profile('Tunic_Hem', [(.87,.25,.17),(.92,.24,.165),(1.0,.20,.145),(1.035,.20,.14)], tunic, 'pelvis')
for v in hem.data.vertices:
    weight = max(0.0, min(.65, (1.0 - v.co.z) * 5.0))
    if weight > 0:
        bone = 'thigh_l' if v.co.x > 0 else 'thigh_r'
        group = hem.vertex_groups.get(bone) or hem.vertex_groups.new(name=bone)
        group.add([v.index], weight, 'REPLACE')
        hem.vertex_groups['pelvis'].add([v.index], 1.0 - weight, 'REPLACE')
profile('Belt', [(1.014,.183,.127),(1.07,.185,.13)], leather, 'pelvis')
profile('Collar', [(1.425,.103,.081),(1.47,.087,.077),(1.498,.077,.069)], tunic, 'neck_01')
rounded_box('Buckle', (0,-.125,1.041), (.052,.022,.045), brass, 'pelvis', .009)
rounded_box('Canvas_Backpack', (0,.18,1.26), (.285,.18,.33), canvas, 'spine_03', .055)
rounded_box('Backpack_Pocket', (0,.282,1.19), (.23,.04,.115), canvas, 'spine_03', .018)
rounded_box('Backpack_Flap', (0,.262,1.38), (.26,.068,.11), canvas, 'spine_03', .032)
rounded_box('Backpack_Clasp', (0,.307,1.30), (.032,.016,.11), leather, 'spine_03', .005)
for s in [-1,1]:
    bpy.ops.mesh.primitive_torus_add(major_segments=40, minor_segments=8,
        location=(s*.324,.057,1.397), rotation=(0,math.pi/2,0), major_radius=.085, minor_radius=.007)
    bind(bpy.context.object, 'Sleeve_Piping', canvas, 'upperarm_l' if s==1 else 'upperarm_r')
    rounded_box('Shoulder_Strap', (s*.135,-.143,1.30), (.031,.028,.29), canvas, 'spine_03', .012)
    rounded_box('Shoulder_Pad', (s*.14,.027,1.445), (.06,.24,.025), canvas, 'clavicle_l' if s==1 else 'clavicle_r', .012)
    rounded_box('Vial', (s*.086,.313,1.19), (.025,.025,.11), teal, 'spine_03', .012)
    rounded_box('Vial_Cap', (s*.086,.313,1.25), (.033,.034,.023), brass, 'spine_03', .006)
    foot_bone = 'foot_l' if s == 1 else 'foot_r'
    calf_bone = 'calf_l' if s == 1 else 'calf_r'
    rounded_box('Boot_Foot', (s*.099,-.025,.079), (.145,.268,.145), leather, foot_bone, .045)
    rounded_box('Boot_Sole', (s*.099,-.027,.015), (.15,.28,.03), sole, foot_bone, .014)
    cuff = profile('Boot_Cuff', [(.10,.073,.08),(.17,.073,.080),(.28,.080,.090),(.315,.085,.095)], leather, calf_bone)
    for v in cuff.data.vertices:
        v.co.x += s*.099
        v.co.y += .05
    # Bone-space accessories follow the wrist through all imported animations.
    bn = rig.data.bones['lowerarm_l' if s==1 else 'lowerarm_r']
    wrist = bn.tail_local
    if s == 1:
        rounded_box('Scanner', wrist + Vector((-.034,-.012,.04)), (.10,.083,.033), leather, bn.name, .012)
        rounded_box('Scanner_Brass', wrist + Vector((-.034,-.012,.060)), (.084,.071,.014), brass, bn.name, .007)
        rounded_box('Scanner_Lens', wrist + Vector((-.034,-.012,.070)), (.059,.048,.009), teal, bn.name, .006)

# The rigged hairstyle uses the same Head rest transform as the supplied body.
before = set(scene.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'hair/Hair_SimpleParted.gltf'))
imported = set(scene.objects) - before
for ob in imported:
    if ob.type != 'MESH' or not ob.vertex_groups:
        continue
    world = ob.matrix_world.copy()
    ob.parent = None
    for v in ob.data.vertices:
        v.co = shape_point(world @ v.co)
    ob.matrix_world = Matrix.Identity(4)
    ob.data.materials.clear()
    ob.data.materials.append(hair_mat)
    for mod in list(ob.modifiers):
        ob.modifiers.remove(mod)
    ob.vertex_groups.clear()
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bind(ob, 'Neri_Hair', hair_mat, 'Head')
for ob in imported:
    if ob not in pieces:
        bpy.data.objects.remove(ob, do_unlink=True)

before = set(scene.objects)
bpy.ops.import_scene.gltf(filepath=str(SOURCE / 'UAL1_Standard.glb'))
animation_objects = set(scene.objects) - before
source_rig = next(o for o in animation_objects if o.type == 'ARMATURE')
clips = {'idle':'Idle_Loop', 'walk':'Walk_Loop', 'run':'Sprint_Loop', 'jump':'Jump_Start',
         'fall':'Jump_Loop', 'land':'Jump_Land', 'interact':'Interact', 'wave':'Idle_Talking_Loop',
         'pulse':'Spell_Simple_Shoot', 'hurt':'Hit_Chest', 'dodge':'Roll'}
source_actions = {n: bpy.data.actions[n] for n in clips.values()}
rig.animation_data_create()
new_actions = []
for name, source_name in clips.items():
    source_action = source_actions[source_name]
    source_rig.animation_data.action = source_action
    source_rig.animation_data.action_slot = source_action.slots[0]
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    start, end = source_action.frame_range
    if name == 'jump':
        start += (end - start) * .40
    length = {'jump':18, 'land':10, 'interact':21, 'pulse':14, 'hurt':10, 'dodge':15}.get(name, max(2, round(end - start)))
    for frame in range(length+1):
        sample = start + (end - start) * frame / length
        scene.frame_set(math.floor(sample), subframe=sample % 1.0)
        for pb in rig.pose.bones:
            source_bone = source_rig.pose.bones.get(pb.name)
            if not source_bone:
                continue
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = source_bone.rotation_quaternion
            pb.location = source_bone.location * .96 if pb.name == 'pelvis' else Vector((0,0,0))
            pb.scale = Vector((1,1,1))
            pb.keyframe_insert('rotation_quaternion', frame=frame+1)
            if pb.name == 'pelvis':
                pb.keyframe_insert('location', frame=frame+1)
    new_actions.append(action)
for ob in animation_objects:
    bpy.data.objects.remove(ob, do_unlink=True)
for action in list(bpy.data.actions):
    if action not in new_actions:
        bpy.data.actions.remove(action)

for ob in pieces:
    if ob.data.has_custom_normals:
        ob.data.normals_split_custom_set([(0, 0, 0)] * len(ob.data.loops))
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.data.calc_loop_triangles()
# Merge compatible skinned pieces; materials remain separate surfaces for editing.
bpy.ops.object.select_all(action='DESELECT')
for ob in pieces:
    ob.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'Neri_Surface'
pieces = [body]
body.data.calc_loop_triangles()
rig.animation_data.action = bpy.data.actions['idle']
rig.animation_data.action_slot = rig.animation_data.action.slots[0]
scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT')
for ob in [rig] + pieces:
    ob.select_set(True)
bpy.context.view_layer.objects.active = rig
output = ROOT / 'godot/assets/characters/neri_quaternius.glb'
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True,
    export_animations=True, export_animation_mode='ACTIONS', export_skins=True,
    export_cameras=False, export_lights=False)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'blender/neri_quaternius.blend'))
metrics = {'character':'Neri - Quaternius adaptation', 'triangles':sum(len(o.data.loop_triangles) for o in pieces),
           'meshes':len(pieces), 'bones':len(rig.data.bones), 'animations':clips,
           'license':'CC0-1.0', 'sources':['https://quaternius.com/packs/universalbasecharacters.html',
                                        'https://quaternius.com/packs/universalanimationlibrary.html']}
(ROOT / 'blender/neri_quaternius_metrics.json').write_text(json.dumps(metrics, indent=2), encoding='utf-8')
print('NERI_BUILD', json.dumps(metrics))
