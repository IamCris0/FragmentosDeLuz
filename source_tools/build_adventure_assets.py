import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1] if Path(__file__).parent.name == 'source_tools' else Path(__file__).parent / 'production'
ASSETS = ROOT / 'godot/assets'
for name in ['characters', 'environment', 'props', 'audio', 'ui', 'enemies']:
    (ASSETS / name).mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
for o in list(scene.objects):
    bpy.data.objects.remove(o, do_unlink=True)
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1
rng = random.Random(807)


def material(name, code, emission=0, metallic=0, rough=.8):
    def lin(x): return x / 12.92 if x < .04045 else ((x+.055)/1.055)**2.4
    rgb = tuple(lin(int(code[i:i+2], 16)/255) for i in (0, 2, 4))
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.diffuse_color = (*rgb, 1)
    m.use_backface_culling = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    for key, val in [('Base Color', (*rgb, 1)), ('Roughness', rough), ('Metallic', metallic),
                     ('Emission Color', (*rgb, 1)), ('Emission Strength', emission)]:
        bsdf.inputs[key].default_value = val
    return m


skin = material('Warm_Skin', 'D9A77F', rough=.85)
tunic = material('Indigo_Tunic', '2F3A56')
cloth = material('Trouser_Cloth', '535F64')
leather = material('Boot_Leather', '765138')
pack = material('Moss_Canvas', '4A775F')
hair = material('Chestnut_Hair', '493025')
hair_light = material('Hair_Highlight', '6F4930')
gold = material('Engraved_Brass', 'C7A653', metallic=.7, rough=.35)
teal = material('Teal_Engraving', '4ECDC4', emission=1.2, rough=.3)
violet = material('Echo_Violet', '8267D6', emission=1.1, rough=.35)
shadow = material('Echo_Shadow', '243042', emission=.18, rough=.72)
eye = material('Eyes', '171B1D', rough=.25)
white = material('Eye_White', 'E5DAC5', rough=.4)
stone = [material('Carved_Stone_%d' % i, c) for i,c in enumerate(['74888B','596E78','91A3A2','485A69','A9B2AA'])]
wood = material('Ancient_Wood', '5E493B')
rock = [material('Cliff_Rock_%d' % i,c) for i,c in enumerate(['4A505B','5C6067','6A706F','3F4653'])]
leaf = [material('Leaf_%d' % i,c) for i,c in enumerate(['276B54','397E53','519559','255B54'])]
all_objects = []
skin_bind = {}
flex_bind = {}


def finish(obj, name, mat, bone=None):
    obj.name = name
    if obj.type == 'MESH':
        obj.data.name = name + '_Mesh'
        obj.data.materials.append(mat)
        if not obj.data.uv_layers:
            obj.data.uv_layers.new(name='UVMap')
    all_objects.append(obj)
    if bone: skin_bind[obj] = bone
    return obj


def cube(name, pos, size, mat, bevel=.025, bone=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Carved_Edges','BEVEL'); mod.width=bevel; mod.segments=3
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj,name,mat,bone)


def ellipsoid(name, pos, scale, mat, bone=None, subdiv=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1, location=pos)
    obj=bpy.context.object; obj.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bone:
        for polygon in obj.data.polygons: polygon.use_smooth=True
    return finish(obj,name,mat,bone)


def tube(name, a, b, r1, r2, mat, bone=None, vertices=12):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r1, radius2=r2, depth=(b-a).length, location=(a+b)*.5)
    obj=bpy.context.object; obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    if bone:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        obj.modifiers.new('Soft_Normals','WEIGHTED_NORMAL')
    return finish(obj,name,mat,bone)


def mesh(name, verts, faces, mats):
    data=bpy.data.meshes.new(name+'_Mesh'); data.from_pydata(verts,[],faces); data.update()
    bm=bmesh.new(); bm.from_mesh(data); bmesh.ops.recalc_face_normals(bm,faces=bm.faces); bm.to_mesh(data); bm.free()
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj)
    finish(obj,name,mats[0])
    for m in mats[1:]: data.materials.append(m)
    for p in data.polygons: p.material_index=p.index%len(mats)
    return obj


def export(objects,path,animated=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,
        export_apply=not animated,export_animations=animated,export_animation_mode='ACTIONS',
        export_cameras=False,export_lights=False,export_draco_mesh_compression_enable=False)


def organic_limb(name, rings, mat, upper, lower, joint_z, blend=.075):
    verts=[]; faces=[]; count=24
    for center,rx,ry in rings:
        for i in range(count):
            a=i*math.tau/count
            verts.append((center[0]+rx*math.cos(a),center[1]+ry*math.sin(a),center[2]))
    for j in range(len(rings)-1):
        for i in range(count):
            faces.append((j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i))
    faces.extend([tuple(reversed(range(count))),tuple(range((len(rings)-1)*count,len(rings)*count))])
    obj=mesh(name,verts,faces,[mat])
    for p in obj.data.polygons:p.use_smooth=True
    flex_bind[obj]=(upper,lower,joint_z,blend)
    return obj


# Continuous ring topology blends across joints; rigid accessories retain their shape.
organic_limb('Tailored_Tunic', [((0,0,z),rx,ry) for z,rx,ry in [(1.0,.19,.128),(1.06,.192,.135),(1.2,.218,.149),(1.30,.22,.137),(1.34,.15,.106)]],tunic,'spine_03','hips',1.05,.11)
verts=[]
for z,rx,ry in [(.86,.265,.18),(1.00,.19,.13),(1.24,.22,.145)]:
    verts += [(rx*math.cos(i*math.tau/12),ry*math.sin(i*math.tau/12),z) for i in range(12)]
faces=[]
for k in range(2):
    for i in range(12): faces.append((k*12+i,k*12+(i+1)%12,(k+1)*12+(i+1)%12,(k+1)*12+i))
skirt=mesh('Tunic_Skirt',verts,faces,[tunic]);skin_bind[skirt]='hips'
cube('Leather_Belt',(0,-.012,1.01),(.42,.295,.065),leather,.015,'hips')
cube('Brass_Buckle',(.025,-.166,1.01),(.075,.022,.060),gold,.01,'hips')
tube('Neck',(0,0,1.32),(0,0,1.45),.069,.066,skin,'neck')
head_obj=ellipsoid('Head',(0,-.008,1.565),(.139,.121,.162),skin,'head',4)
for vertex in head_obj.data.vertices:
    if vertex.co.z<-.04: vertex.co.x*=1+vertex.co.z*1.6
ellipsoid('Cheek_L',(.052,-.121,1.535),(.026,.009,.018),skin,'head',2)
ellipsoid('Cheek_R',(-.052,-.121,1.535),(.026,.009,.018),skin,'head',2)
ellipsoid('Nose',(0,-.123,1.55),(.024,.029,.031),skin,'head',2)
for side,sign in [('L',1),('R',-1)]:
    ellipsoid('Ear_'+side,(sign*.127,0,1.565),(.025,.033,.049),skin,'head',2)
    ellipsoid('EyeWhite_'+side,(sign*.05,-.110,1.585),(.032,.014,.029),white,'head',2)
    ellipsoid('Iris_'+side,(sign*.05,-.123,1.584),(.017,.008,.021),eye,'head',2)
    ellipsoid('EyeCatch_'+side,(sign*.045,-.13,1.594),(.005,.003,.006),white,'head',1)
    brow=tube('Brow_'+side,(sign*.020,-.118,1.626),(sign*.077,-.105,1.622),.008,.009,hair,'head',6)
    shoulder=(sign*.24,0,1.32); elbow=(sign*.30,-.005,1.105); wrist=(sign*.32,-.012,.945)
    organic_limb('Sleeve_'+side,[(shoulder,.087,.084),((sign*.25,0,1.29),.094,.084),((sign*.28,0,1.20),.077,.072)],tunic,'upper_arm_'+side,'upper_arm_'+side,0.,1.)
    tube('Sleeve_Piping_'+side,(sign*.275,0,1.218),(sign*.28,0,1.20),.080,.078,pack,'upper_arm_'+side,20)
    organic_limb('Arm_'+side,[(shoulder,.061,.061),((sign*.27,0,1.24),.059,.055),((sign*.297,-.002,1.14),.047,.048),(elbow,.047,.046),((sign*.307,-.006,1.07),.048,.045),(wrist,.034,.034)],skin,'upper_arm_'+side,'forearm_'+side,1.105,.075)
    ellipsoid('Glove_'+side,(sign*.32,-.012,.911),(.048,.043,.066),cloth,'hand_'+side)
    ellipsoid('Fingers_'+side,(sign*.322,-.018,.868),(.038,.034,.040),skin,'hand_'+side)
    thigh=(sign*.117,0,.92); knee=(sign*.119,-.012,.52); ankle=(sign*.12,.012,.15)
    organic_limb('Trouser_'+side,[(thigh,.09,.095),((sign*.117,0,.78),.09,.086),((sign*.119,-.008,.57),.062,.063),(knee,.064,.063),((sign*.12,-.007,.46),.065,.066),((sign*.12,.006,.28),.056,.058),(ankle,.048,.05)],cloth,'thigh_'+side,'shin_'+side,.52,.10)
    tube('Boot_Cuff_'+side,(sign*.12,.005,.16),(sign*.12,.005,.235),.068,.063,leather,'shin_'+side,16)
    for z in [.095,.13]: tube('Boot_Stitch_'+side,(sign*.12-.041,-.152,z),(sign*.12+.041,-.152,z),.004,.004,gold,'foot_'+side,6)
    cube('Boot_'+side,(sign*.12,-.045,.093),(.135,.245,.158),leather,.033,'foot_'+side)
    ellipsoid('Boot_Toe_'+side,(sign*.12,-.17,.08),(.073,.064,.049),leather,'foot_'+side,2)
    ellipsoid('Knee_Soft_'+side,(sign*.119,-.017,.525),(.068,.034,.054),cloth,'shin_'+side,2)
    cube('Sole_'+side,(sign*.12,-.05,.02),(.146,.255,.035),hair,.015,'foot_'+side)
    cube('Boot_Trim_'+side,(sign*.12,-.115,.16),(.055,.012,.065),teal,.013,'foot_'+side)
    tube('BackpackStrap_'+side,(sign*.145,-.12,1.33),(sign*.16,-.15,1.08),.019,.019,pack,'spine_03',6)
ellipsoid('Hair_Cap',(0,.025,1.662),(.144,.128,.092),hair,'head',3)
def lock(name,base,tip,width,depth):
    b,t=Vector(base),Vector(tip); axis=(t-b).normalized()
    cross=axis.cross(Vector((0,1,0))).normalized(); other=axis.cross(cross).normalized()
    vs=[b+cross*width,b+other*depth,b-cross*width,b-other*depth,t]
    obj=mesh(name,vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],[hair,hair,hair_light])
    skin_bind[obj]='head'
for i in range(15):
    a=i*math.tau/15
    lock('Layered_Lock_%d'%i,(.10*math.cos(a),.025+.09*math.sin(a),1.70),(.158*math.cos(a+.12),.026+.139*math.sin(a+.12),1.58+rng.uniform(-.035,.035)),.035,.025)
for i in range(6):
    x=-.105+i*.04
    lock('Swept_Fringe_%d'%i,(x,-.067,1.709),(x-.025,-.137,1.636-abs(x)*.10),.030,.024)
lock('Crown_Accent',(0,.035,1.719),(.065,.014,1.785),.036,.025)
tube('Mouth',(-.029,-.117,1.501),(.029,-.117,1.503),.0028,.0028,leather,'head',8)
for sign in [-1,1]:
    tube('Collar_%d'%sign,(sign*.082,-.090,1.34),(sign*.027,-.147,1.26),.008,.008,gold,'spine_03',8)
    tube('Tunic_Seam_%d'%sign,(sign*.08,-.143,1.19),(sign*.195,-.132,1.09),.003,.003,pack,'spine_03',6)
cube('Canvas_Backpack',(0,.195,1.205),(.29,.18,.32),pack,.055,'backpack')
cube('Backpack_Pocket',(0,.292,1.12),(.235,.043,.11),pack,.018,'backpack')
cube('Backpack_Clasp',(0,.296,1.28),(.046,.02,.095),leather,.01,'backpack')
ellipsoid('Backpack_Flap',(0,.25,1.34),(.15,.07,.053),pack,'backpack',3)
ellipsoid('Compass',(0,.311,1.23),(.036,.012,.036),gold,'backpack',3)
ellipsoid('Compass_Face',(0,.323,1.23),(.027,.004,.027),white,'backpack',2)
tube('Compass_Needle',(-.012,.328,1.218),(.012,.328,1.242),.003,.003,hair,'backpack',6)
for sign in [-1,1]:
    tube('Vial_%d'%sign,(sign*.094,.311,1.09),(sign*.094,.311,1.20),.018,.018,teal,'vials',8)
    tube('VialCap_%d'%sign,(sign*.094,.311,1.195),(sign*.094,.311,1.211),.021,.021,gold,'vials',8)
cube('Scanner_Body',(.345,-.015,.99),(.07,.08,.11),gold,.01,'forearm_L')
cube('Scanner_Screen',(.384,-.015,.996),(.012,.058,.066),teal,.004,'forearm_L')

body_objects=list(all_objects)
for character_piece in body_objects:
    if character_piece.type == 'MESH':
        for polygon in character_piece.data.polygons:
            polygon.use_smooth = True
        if character_piece.name.startswith(('Head','Cheek','Arm','Trouser','Tailored','Sleeve','Neck','Hair_Cap','Glove','Fingers')):
            mod = character_piece.modifiers.new('Presentation_Softening','WEIGHTED_NORMAL')
            mod.weight = 70
bpy.ops.object.armature_add(enter_editmode=True,location=(0,0,0))
rig=bpy.context.object;rig.name='Adventurer_Rig'
rig.data.edit_bones.remove(rig.data.edit_bones[0])
bones={}
def bone(name,head,tail,parent=None):
    b=rig.data.edit_bones.new(name);b.head=head;b.tail=tail
    if parent: b.parent=bones[parent]
    bones[name]=b
bone('root',(0,0,0),(0,0,.2))
bone('hips',(0,0,.89),(0,0,1.02),'root')
for i in range(1,6): bone('spine_%02d'%i,(0,0,1.0+(i-1)*.064),(0,0,1.0+i*.064),'hips' if i==1 else 'spine_%02d'%(i-1))
bone('neck',(0,0,1.32),(0,0,1.44),'spine_05');bone('head',(0,0,1.44),(0,0,1.72),'neck')
for side,sign in [('L',1),('R',-1)]:
    bone('shoulder_'+side,(0,0,1.32),(sign*.24,0,1.32),'spine_05')
    bone('upper_arm_'+side,(sign*.24,0,1.32),(sign*.30,0,1.105),'shoulder_'+side)
    bone('forearm_'+side,(sign*.30,0,1.105),(sign*.32,0,.945),'upper_arm_'+side)
    bone('hand_'+side,(sign*.32,0,.945),(sign*.32,0,.87),'forearm_'+side)
    bone('fingers_'+side,(sign*.32,0,.89),(sign*.32,0,.85),'hand_'+side)
    bone('thigh_'+side,(sign*.117,0,.92),(sign*.119,-.012,.52),'hips')
    bone('shin_'+side,(sign*.119,-.012,.52),(sign*.12,.012,.15),'thigh_'+side)
    bone('foot_'+side,(sign*.12,.012,.15),(sign*.12,-.15,.06),'shin_'+side)
bone('backpack',(0,.15,1.1),(0,.15,1.3),'spine_03')
bone('vials',(0,.3,1.1),(0,.3,1.2),'backpack')
bone('scanner',(.36,0,.98),(.38,0,1.06),'forearm_L')
bpy.ops.object.mode_set(mode='OBJECT')
for obj,bn in skin_bind.items():
    obj.parent=rig
    group=obj.vertex_groups.new(name=bn);group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    mod=obj.modifiers.new('Deform','ARMATURE');mod.object=rig
for obj,(upper,lower,joint_z,blend) in flex_bind.items():
    obj.parent=rig
    groups=[obj.vertex_groups.new(name=n) for n in [upper,lower]]
    for v in obj.data.vertices:
        weight=max(0,min(1,(v.co.z-joint_z)/blend*.5+.5))
        if weight>0:groups[0].add([v.index],weight,'REPLACE')
        if weight<1:groups[1].add([v.index],1-weight,'REPLACE')
    mod=obj.modifiers.new('Deform','ARMATURE');mod.object=rig
rig.animation_data_create()
clips=[('idle',120),('walk',32),('run',24),('jump',30),('interact',48),('fall',36),('land',18),('wave',72),('pulse',36),('hurt',24)]
scene.render.fps=30
for name,length in clips:
    rig.animation_data.action=None
    action=bpy.data.actions.new(name);rig.animation_data.action=action
    for frame in sorted(set(list(range(1,length+1,2))+[length+1])):
        phase=math.tau*(frame-1)/length
        for pb in rig.pose.bones:
            pb.rotation_mode='XYZ';pb.rotation_euler=(0,0,0);pb.location=(0,0,0)
        if name in ['walk','run']:
            strength=.62 if name=='walk' else .95
            for side,sgn in [('L',1),('R',-1)]:
                rig.pose.bones['thigh_'+side].rotation_euler.x=math.sin(phase)*strength*sgn
                rig.pose.bones['shin_'+side].rotation_euler.x=max(0,-math.sin(phase)*sgn)*1.05
                rig.pose.bones['upper_arm_'+side].rotation_euler.x=-math.sin(phase)*strength*.7*sgn
                rig.pose.bones['forearm_'+side].rotation_euler.x=-.22-(.45 if name=='run' else .12)*max(0,math.sin(phase)*sgn)
                rig.pose.bones['foot_'+side].rotation_euler.x=-.16*math.sin(phase)*sgn
            rig.pose.bones['hips'].location.y=-.012+abs(math.sin(phase))*.027
            rig.pose.bones['hips'].rotation_euler.z=math.sin(phase)*.045
            rig.pose.bones['spine_03'].rotation_euler.y=math.sin(phase)*.07
            rig.pose.bones['spine_03'].rotation_euler.x=.10 if name=='run' else .025
        elif name=='jump':
            rig.pose.bones['thigh_L'].rotation_euler.x=-.45
            rig.pose.bones['thigh_R'].rotation_euler.x=.18
            for side in ['L','R']:rig.pose.bones['upper_arm_'+side].rotation_euler.x=-.4
        elif name=='fall':
            for side,sign in [('L',1),('R',-1)]:
                rig.pose.bones['upper_arm_'+side].rotation_euler.z=sign*.22
                rig.pose.bones['shin_'+side].rotation_euler.x=.32
        elif name=='land':
            amount=math.sin(math.pi*min((frame-1)/length,1))
            rig.pose.bones['hips'].location.y=-.07*amount
            for side in ['L','R']:
                rig.pose.bones['thigh_'+side].rotation_euler.x=-.28*amount
                rig.pose.bones['shin_'+side].rotation_euler.x=.5*amount
        elif name=='wave':
            rig.pose.bones['upper_arm_R'].rotation_euler.x=-1.3
            rig.pose.bones['forearm_R'].rotation_euler.x=-.6
            rig.pose.bones['hand_R'].rotation_euler.z=math.sin(phase*3)*.25
            rig.pose.bones['head'].rotation_euler.z=math.sin(phase)*.035
        elif name=='pulse':
            amount=math.sin(math.pi*min((frame-1)/length,1))
            rig.pose.bones['spine_03'].rotation_euler.x=-.10*amount
            rig.pose.bones['upper_arm_L'].rotation_euler.x=-1.18*amount
            rig.pose.bones['upper_arm_R'].rotation_euler.x=-.78*amount
            rig.pose.bones['forearm_L'].rotation_euler.x=-.45-.5*amount
            rig.pose.bones['forearm_R'].rotation_euler.x=-.22-.35*amount
            rig.pose.bones['hand_L'].rotation_euler.z=.25*amount
            rig.pose.bones['hand_R'].rotation_euler.z=-.18*amount
            rig.pose.bones['head'].rotation_euler.x=-.05*amount
        elif name=='hurt':
            amount=math.sin(math.pi*min((frame-1)/length,1))
            rig.pose.bones['hips'].location.y=-.025*amount
            rig.pose.bones['spine_03'].rotation_euler.z=.15*amount
            rig.pose.bones['upper_arm_L'].rotation_euler.z=.38*amount
            rig.pose.bones['upper_arm_R'].rotation_euler.z=-.38*amount
        elif name=='interact':
            rig.pose.bones['upper_arm_L'].rotation_euler.x=-math.sin(math.pi*(frame-1)/length)*1.1
            rig.pose.bones['forearm_L'].rotation_euler.x=-.2
        else:
            rig.pose.bones['spine_03'].rotation_euler.x=math.sin(phase)*.016
            rig.pose.bones['head'].rotation_euler.y=math.sin(phase)*.045
            for side,sign in [('L',1),('R',-1)]:
                rig.pose.bones['upper_arm_'+side].rotation_euler.z=sign*.06
                rig.pose.bones['forearm_'+side].rotation_euler.x=-.12
        rig.pose.bones['backpack'].rotation_euler.x=math.sin(phase*2)*(.035 if name in ['walk','run'] else .008)
        rig.pose.bones['vials'].rotation_euler.z=math.sin(phase*2+.4)*.04
        for pb in rig.pose.bones:
            pb.keyframe_insert('rotation_euler',frame=frame)
            if pb.name=='hips':pb.keyframe_insert('location',frame=frame)
    action.use_fake_user=True
rig.animation_data.action=bpy.data.actions.get('idle')
scene.frame_set(1)
# Joining skinned pieces preserves groups and reduces runtime draw submissions.
bpy.ops.object.select_all(action='DESELECT')
for obj in body_objects:obj.select_set(True)
bpy.context.view_layer.objects.active=body_objects[0]
bpy.ops.object.join()
body_objects=[bpy.context.object]
body_objects[0].name='Neri_Surface'
all_objects=list(body_objects)
export([rig]+body_objects,ASSETS/'characters/adventurer.glb',True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/adventurer.blend'))
for obj in body_objects:obj.data.calc_loop_triangles()
triangles=sum(len(o.data.loop_triangles) for o in body_objects)
for o in body_objects:o.hide_set(True);o.hide_render=True
rig.hide_set(True)

# Modular environment set. The editable source retains one asset per named group.
asset_groups={}
def group_asset(name,callback):
    start=len(all_objects);callback();objects=all_objects[start:]
    for ob in objects:ob.hide_set(False)
    collection=bpy.data.collections.new(name)
    scene.collection.children.link(collection)
    for ob in objects:
        for old_collection in list(ob.users_collection):old_collection.objects.unlink(ob)
        collection.objects.link(ob)
    if name not in ['chest','lever']:
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects:ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        combined=bpy.context.object
        combined.name=name
        combined.data.name=name+'_Mesh'
        all_objects[start:]=[combined]
        objects=[combined]
    category = 'enemies' if name in ['echo_sentinel'] else ('props' if name in ['portal_ring','chest','lever','platform'] else 'environment')
    export(objects,ASSETS/category/(name+'.glb'))
    asset_groups[name]=len(objects)
    for ob in objects:ob.hide_set(True)
    for ob in objects:
        if ob.parent not in objects:ob.location.x+=len(asset_groups)*7


def make_column():
    cube('Pillar_Base',(0,0,.12),(.85,.85,.24),stone[1],.07)
    tube('Pillar_Shaft',(0,0,.22),(0,0,2.8),.27,.245,stone[0],vertices=10)
    for z in [.35,.53,2.45,2.63]:tube('Pillar_Band',(0,0,z-.05),(0,0,z+.05),.32,.32,stone[2],vertices=10)
    cube('Pillar_Capital',(0,0,2.8),(.72,.72,.2),stone[2],.05)
    for i in range(4):
        z=.85+i*.36
        for a,b in [((-.055,-.27,z-.06),(0,-.28,z+.05)),((0,-.28,z+.05),(.055,-.27,z-.04)),((0,-.28,z+.05),(0,-.28,z+.13))]:
            tube('Carved_Rune',a,b,.008,.008,teal,vertices=6)
group_asset('column',make_column)

def make_arch():
    for s in [-1,1]:
        cube('Gate_Foot',(s*2,0,.2),(1.05,1.25,.4),stone[1],.08)
        for i in range(5):cube('Gate_Pier',(s*2,0,.65+i*.68),(.7,1,.64),stone[i%3],.045)
        cube('Gate_Cap',(s*2,0,4),(1,1.25,.25),stone[2],.05)
    for i in range(13):
        a=math.pi*i/12
        ob=cube('Arch_Voussoir',(1.98*math.cos(a),0,3.3+1.98*math.sin(a)),(.47,1.0,.73),stone[i%3],.035)
        ob.rotation_euler.y=math.pi/2-a
        if 1<i<11:
            glyph=cube('Arch_Rune',(1.96*math.cos(a),-.514,3.3+1.96*math.sin(a)),(.13,.017,.2),teal,.02)
            glyph.rotation_euler.y=math.pi/2-a
group_asset('entrance_arch',make_arch)

def make_rock():
    v=[]
    for z,r in [(-5,.9),(-2.7,3.6),(-.4,4.8),(0,4.6)]:
        for i in range(14):
            a=i*math.tau/14;rj=r*rng.uniform(.85,1.12);v.append((rj*math.cos(a),rj*math.sin(a),z+rng.uniform(-.12,.08)))
    f=[tuple(range(42,56)),tuple(reversed(range(14)))]
    for k in range(3):
        for i in range(14):
            a=k*14+i;b=k*14+(i+1)%14;f.extend([(a,b,b+14),(a,b+14,a+14)])
    mesh('Floating_Cliff',v,f,rock)
group_asset('island_rock',make_rock)

def make_tree():
    tube('Trunk',(0,0,0),(0,0,2.7),.23,.10,wood,vertices=9)
    for i in range(7):
        a=i*math.tau/7;x,y=math.cos(a),math.sin(a)
        tube('Branch',(0,0,1.3),(x,y,2.65),.095,.03,wood,vertices=6)
        ellipsoid('Canopy',(x*.7,y*.7,2.7+rng.uniform(-.2,.4)),(.95,.8,.7),leaf[i%4],subdiv=2)
    ellipsoid('Crown',(0,0,3.4),(1,.95,.8),leaf[1],subdiv=2)
group_asset('tree',make_tree)

def make_fern():
    for i in range(9):
        a=i*math.tau/9
        for j in range(1,5):
            r=j*.12;z=math.sin(j*.6)*.4
            ob=ellipsoid('Fern_Leaf',(math.cos(a)*r,math.sin(a)*r,z),(.095,.17,.025),leaf[i%4],subdiv=1)
            ob.rotation_euler.z=a
group_asset('fern',make_fern)

def make_portal():
    cube('Portal_Base',(0,0,.2),(3.5,.85,.4),stone[2],.1)
    for i in range(24):
        a=i*math.tau/24
        ob=cube('Portal_Segment',(1.52*math.cos(a),0,1.92+1.52*math.sin(a)),(.39,.48,.34),stone[i%3],.035)
        ob.rotation_euler.y=-a
        rune=ellipsoid('Portal_Glyph',(1.51*math.cos(a),-.252,1.92+1.51*math.sin(a)),(.055,.023,.09),teal,subdiv=1)
        rune.rotation_euler.y=-a
group_asset('portal_ring',make_portal)

def make_chest():
    cube('Chest_Body',(0,0,.07),(.6,.4,.12),stone[1],.025)
    for s in [-1,1]:
        cube('Chest_Wall',(s*.275,0,.23),(.055,.4,.27),stone[1],.012)
        cube('Chest_Front',(0,s*.178,.23),(.5,.045,.27),stone[1],.012)
    lid=cube('Chest_Lid',(0,0,.41),(.62,.43,.16),stone[2],.055)
    lid.data.transform(lid.matrix_world)
    lid.matrix_world=Matrix.Translation((0,.20,.35))
    lid.data.transform(lid.matrix_world.inverted())
    for x in [-.22,.22]:
        cube('Chest_Band',(x,0,.20),(.04,.42,.29),gold,.008)
        band=cube('Lid_Band',(x,0,.465),(.05,.43,.075),gold,.008)
        transform=band.matrix_world.copy();band.parent=lid;band.matrix_world=transform
    cube('Chest_Lock',(0,-.23,.3),(.085,.035,.105),gold,.015)
group_asset('chest',make_chest)

def make_lever():
    cube('Lever_Plinth',(0,0,.5),(.46,.32,1),stone[2],.035)
    pivot=bpy.data.objects.new('LeverPivot',None);scene.collection.objects.link(pivot)
    pivot.location=(0,-.22,.49);finish(pivot,'LeverPivot',gold)
    arm=tube('Lever_Arm',(0,-.22,.49),(0,-.46,.85),.027,.027,gold,vertices=12)
    handle=tube('Lever_Handle',(-.14,-.46,.85),(.14,-.46,.85),.045,.045,wood,vertices=12)
    for obj in [arm,handle]:
        transform=obj.matrix_world.copy();obj.parent=pivot;obj.matrix_world=transform
    ellipsoid('Lever_Glyph',(0,-.171,.92),(.065,.016,.075),teal,subdiv=1)
group_asset('lever',make_lever)

def make_platform():
    cube('Platform_Stone',(0,0,-.15),(2,2,.3),stone[2],.07)
    for x in [-.7,.7]:cube('Platform_Levitation',(x,0,-.29),(.05,1.5,.03),teal,.01)
group_asset('platform',make_platform)

def make_enemy():
    ellipsoid('Echo_Core',(0,0,1.0),(.28,.20,.38),shadow,subdiv=3)
    ellipsoid('Echo_Heart',(0,-.035,1.02),(.13,.09,.20),teal,subdiv=2)
    for i in range(7):
        a=i*math.tau/7
        height=.78+rng.uniform(-.08,.12)
        radius=.42+rng.uniform(-.05,.06)
        shard=tube('Echo_Shard_%d'%i,
            (math.cos(a)*.14,math.sin(a)*.14,1.02),
            (math.cos(a)*radius,math.sin(a)*radius,height+rng.uniform(.25,.55)),
            .035,.005,violet,vertices=5)
        shard.rotation_euler.z += rng.uniform(-.3,.3)
    for i in range(5):
        a=i*math.tau/5+0.35
        tube('Echo_Trail_%d'%i,(math.cos(a)*.16,math.sin(a)*.16,.72),(math.cos(a)*.55,math.sin(a)*.55,.22),.022,.006,teal,vertices=6)
    ellipsoid('Echo_Crown',(0,.02,1.38),(.19,.12,.08),violet,subdiv=2)
    for eye_x in [-.065,.065]:
        ellipsoid('Echo_Eye_%s'%str(eye_x),(eye_x,-.18,1.08),(.034,.014,.04),teal,subdiv=1)
group_asset('echo_sentinel',make_enemy)

for ob in all_objects:
    ob.hide_set(False)
    if ob not in body_objects:ob.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/environment_library.blend'))
(ROOT/'blender/production_metrics.json').write_text(json.dumps({'rig_bones':len(bones),'character_meshes':len(body_objects),'character_triangles':triangles,
    'animations':[name for name,length in clips],'assets':asset_groups},indent=2),encoding='utf8')
print('ADVENTURE_ASSETS_COMPLETE',len(bones),asset_groups)
