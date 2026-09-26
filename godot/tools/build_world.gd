extends SceneTree

var world: Node3D
var rng := RandomNumberGenerator.new()
var stone: Array[StandardMaterial3D] = []
var grass: StandardMaterial3D
var teal: StandardMaterial3D
var gold: StandardMaterial3D
var paving: StandardMaterial3D


func _initialize() -> void:
	build.call_deferred()


func attach(parent: Node, node: Node, title: String) -> Node:
	node.name = title
	parent.add_child(node)
	node.owner = world
	return node


func mat(color: String, emission: float = 0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.85
	material.emission_enabled = emission > 0
	material.emission = Color(color)
	material.emission_energy_multiplier = emission
	return material


func model(parent: Node, path: String, title: String, pos: Vector3, scale_value: Vector3 = Vector3.ONE) -> Node3D:
	var packed: PackedScene = load("res://assets/" + path + ".glb")
	assert(packed != null, "Asset missing: " + path)
	var node: Node3D = attach(parent, packed.instantiate(), title)
	node.position = pos
	node.scale = scale_value
	return node


func box(parent: Node, title: String, pos: Vector3, size: Vector3, material: Material, collision: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
	attach(parent, body, title)
	body.position = pos
	var shape := BoxMesh.new()
	shape.size = size
	var visual: MeshInstance3D = attach(body, MeshInstance3D.new(), "Mesh")
	visual.mesh = shape
	visual.material_override = material
	if collision:
		var collider: CollisionShape3D = attach(body, CollisionShape3D.new(), "CollisionShape3D")
		var primitive := BoxShape3D.new()
		primitive.size = size
		collider.shape = primitive
	return body


func cylinder(parent: Node, title: String, pos: Vector3, radius: float, height: float, material: Material, collision: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
	attach(parent,body,title)
	body.position=pos
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=12
	var visual: MeshInstance3D=attach(body,MeshInstance3D.new(),"Mesh")
	visual.mesh=mesh
	visual.material_override=material
	if collision:
		var collider: CollisionShape3D=attach(body,CollisionShape3D.new(),"CollisionShape3D")
		var shape:=CylinderShape3D.new()
		shape.radius=radius
		shape.height=height
		collider.shape=shape
	return body


func lighting(parent: Node, pos: Vector3, color: Color, energy: float = 1.4, radius: float = 5.0) -> void:
	var light: OmniLight3D=attach(parent,OmniLight3D.new(),"OmniLight3D")
	light.position=pos
	light.light_color=color
	light.light_energy=energy
	light.omni_range=radius


func label3d(parent: Node, caption: String, pos: Vector3, color: Color = Color("c6efe1")) -> void:
	var title: Label3D=attach(parent,Label3D.new(),"Inscription")
	title.text=caption
	title.position=pos
	title.font_size=36
	title.pixel_size=.006
	title.modulate=color
	title.outline_modulate=Color("142423")
	title.outline_size=10
	title.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	title.visibility_range_end=19
	title.visibility_range_end_margin=2


func island(parent: Node, title: String, center: Vector3, extent: Vector2) -> Node3D:
	var zone: Node3D=attach(parent,Node3D.new(),title)
	zone.position=center
	model(zone,"environment/island_rock","IslandCliff",Vector3(0,-.2,0),Vector3(extent.x/9,1.5,extent.y/9))
	var ground:StaticBody3D=attach(zone,StaticBody3D.new(),"Ground")
	var outline:=PackedVector3Array()
	var xhalf:float=extent.x*.5
	var zhalf:float=extent.y*.5
	for p in [Vector2(-xhalf+3,-zhalf),Vector2(xhalf-3,-zhalf),Vector2(xhalf,-zhalf+3),Vector2(xhalf,zhalf-3),Vector2(xhalf-3,zhalf),Vector2(-xhalf+3,zhalf),Vector2(-xhalf,zhalf-3),Vector2(-xhalf,-zhalf+3)]:
		outline.append(Vector3(p.x,-.02,p.y))
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(8):
		for vertex in [Vector3(0,-.02,0),outline[i],outline[(i+1)%8]]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(vertex.x,vertex.z)*.2)
			surface.add_vertex(vertex)
	var ground_mesh:MeshInstance3D=attach(ground,MeshInstance3D.new(),"Mesh")
	ground_mesh.mesh=surface.commit()
	ground_mesh.material_override=grass
	var ground_shape:CollisionShape3D=attach(ground,CollisionShape3D.new(),"CollisionShape3D")
	var convex:=ConvexPolygonShape3D.new()
	var points:=outline.duplicate()
	for point in outline:points.append(point-Vector3.UP*.5)
	convex.points=points
	ground_shape.shape=convex
	for x in range(-int(extent.x/2)+1,int(extent.x/2),2):
		for z in range(-int(extent.y/2)+1,int(extent.y/2),2):
			if abs(x)<4 or abs(z)<3 or title=="Puzzle":
				var tile:=box(zone,"Flagstone",Vector3(x,.005,z),Vector3(1.98,.06,1.98),paving,false)
				tile.rotation.y=rng.randf_range(-.012,.012)
	for i in range(30):
		var x:float=rng.randf_range(-extent.x*.47,extent.x*.47)
		var z:float=rng.randf_range(-extent.y*.47,extent.y*.47)
		if absf(x)<3.8:continue
		model(zone,"environment/fern","Fern",Vector3(x,.05,z),Vector3.ONE*rng.randf_range(.8,1.8))
	for i in range(12):
		var side:int=1 if i%2 else -1
		var pos:=Vector3(side*rng.randf_range(extent.x*.32,extent.x*.40),-.08,rng.randf_range(-extent.y*.35,extent.y*.35))
		var boulder:=model(zone,"environment/island_rock","WeatheredBoulder",pos,Vector3(.20,.14,.16))
		boulder.rotation.z=PI
	for side in [-1,1]:
		for i in range(3):
			box(zone,"BoundaryStone",Vector3(side*(extent.x*.5-.35),.35,-extent.y*.25+i*3),Vector3(.45,.7,2.8),stone[2])
	for side in [-1,1]:
		for i in range(4):
			var z:float=-extent.y*.4+i*extent.y*.23
			var point:=Vector3(side*(extent.x*.5-.8),0,z)
			if i%2==0:
				model(zone,"environment/tree","WindTree",point,Vector3.ONE*rng.randf_range(1,1.7))
			else:
				model(zone,"environment/column","AncientColumn",point,Vector3.ONE*rng.randf_range(.6,1.4))
			cylinder(zone,"TrunkCollision",point+Vector3.UP, .32,2,stone[1],true).get_node("Mesh").hide()
	dress_zone(zone,extent)
	# Fase 6: raíces de cristal, enredaderas y acantilado pintado (scripts/island_dressing.gd).
	var dressing:Node3D=attach(zone,Node3D.new(),"Dressing")
	dressing.set_script(load("res://scripts/island_dressing.gd"))
	dressing.set("extent",extent)
	dressing.set("dressing_seed",{"Entrance":11,"Puzzle":23,"Elevated":37,"PortalFinal":51}.get(title,7))
	return zone


func dress_zone(zone: Node3D, extent: Vector2) -> void:
	var vegetation:MultiMeshInstance3D=attach(zone,MultiMeshInstance3D.new(),"Meadow")
	var blade:=ArrayMesh.new()
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(3):
		var angle:float=k*PI/3.
		for point in [Vector3(-.04,0,0),Vector3(.03,.38,0),Vector3(.06,0,0)]:
			surface.set_uv(Vector2(.5,point.y/.38))
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point.rotated(Vector3.UP,angle))
	blade=surface.commit()
	var leaf_material:=ShaderMaterial.new()
	leaf_material.shader=load("res://shaders/foliage.gdshader")
	leaf_material.set_shader_parameter("tint",Color("387d53"))
	leaf_material.set_shader_parameter("flexibility",.24)
	blade.surface_set_material(0,leaf_material)
	var multi:=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.mesh=blade
	multi.instance_count=650
	vegetation.multimesh=multi
	vegetation.set_script(load("res://scripts/meadow.gd"))
	vegetation.set("field_extent",extent)
	vegetation.set("field_seed",1926+int(extent.x))
	vegetation.visibility_range_end=55
	for side in [-1,1]:
		for z in [-extent.y*.3,extent.y*.3]:
			var p:=Vector3(side*3.4,0,z)
			var plinth:=cylinder(zone,"LanternPlinth",p+Vector3.UP*.3,.22,.6,stone[2],false)
			var flame:=cylinder(plinth,"AmberGlass",Vector3(0,.5,0),.115,.33,mat("ffc779",2.),false)
			cylinder(plinth,"LanternCap",Vector3(0,.69,0),.19,.08,stone[1],false)
			var light:OmniLight3D=attach(flame,OmniLight3D.new(),"LanternLight")
			light.light_color=Color("ffc680")
			light.light_energy=1.1
			light.omni_range=4.
		banner(zone,Vector3(side*(extent.x*.5-1.8),0,0),Color("214f52") if side==1 else Color("653952"))
	var motes:GPUParticles3D=attach(zone,GPUParticles3D.new(),"LightMotes")
	motes.position.y=1.5
	motes.amount=42
	motes.lifetime=9.
	motes.preprocess=5.
	motes.visibility_aabb=AABB(Vector3(-extent.x*.5,-2,-extent.y*.5),Vector3(extent.x,6,extent.y))
	var motion:=ParticleProcessMaterial.new()
	motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents=Vector3(extent.x*.4,1.,extent.y*.4)
	motion.gravity=Vector3(.015,.012,.005)
	motion.direction=Vector3(.5,.5,0)
	motion.initial_velocity_min=.06
	motion.initial_velocity_max=.12
	motion.scale_min=.015
	motion.scale_max=.035
	motes.process_material=motion
	var point:=SphereMesh.new()
	point.radial_segments=4
	point.rings=2
	point.radius=.5
	point.height=1.
	point.material=mat("e7c880",1.4)
	motes.draw_pass_1=point


func banner(parent: Node3D, p: Vector3, dye: Color) -> void:
	cylinder(parent,"BannerPole",p+Vector3.UP*1.8,.045,3.6,stone[1],false)
	box(parent,"BannerCrossbar",p+Vector3(0,3.35,0),Vector3(1.25,.06,.06),stone[2],false)
	var cloth:MeshInstance3D=attach(parent,MeshInstance3D.new(),"Banner")
	var grid:=PlaneMesh.new()
	grid.orientation=PlaneMesh.FACE_Z
	grid.size=Vector2(1.,1.7)
	grid.subdivide_width=10
	grid.subdivide_depth=16
	cloth.mesh=grid
	cloth.position=p+Vector3(0,2.45,.07)
	var fabric:=ShaderMaterial.new()
	fabric.shader=load("res://shaders/banner.gdshader")
	fabric.set_shader_parameter("dye",dye)
	cloth.material_override=fabric


func walkway(parent: Node3D, title: String, a: Vector3, b: Vector3, width: float) -> void:
	# The same closed wedge supplies the visible surface and physical volume.
	var vertices:=PackedVector3Array()
	for p in [a,b]:
		vertices.append(p+Vector3(-width*.5,0,0))
		vertices.append(p+Vector3(width*.5,0,0))
	for i in range(4):
		var p:Vector3=vertices[i]
		vertices.append(Vector3(p.x,minf(a.y,b.y)-.35,p.z))
	var body:StaticBody3D=attach(parent,StaticBody3D.new(),title)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center:Vector3=(a+b)*.5-Vector3.UP*.2
	for face in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
		for tri in [[face[0],face[1],face[2]],[face[0],face[2],face[3]]]:
			var p:Vector3=vertices[tri[0]]
			var q:Vector3=vertices[tri[1]]
			var r:Vector3=vertices[tri[2]]
			var normal:Vector3=(q-p).cross(r-p).normalized()
			if normal.dot((p+q+r)/3.-center)<0:normal=-normal
			if (q-p).cross(r-p).dot(normal)>0:
				var temp:Vector3=q
				q=r
				r=temp
			for v in [p,q,r]:
				surface.set_normal(normal)
				surface.set_uv(Vector2(v.x,v.z)*.35)
				surface.add_vertex(v)
	var mesh:MeshInstance3D=attach(body,MeshInstance3D.new(),"Mesh")
	mesh.mesh=surface.commit()
	mesh.material_override=paving
	var shape:CollisionShape3D=attach(body,CollisionShape3D.new(),"CollisionShape3D")
	var hull:=ConvexPolygonShape3D.new()
	hull.points=vertices
	shape.shape=hull
	for side in [-1,1]:
		for i in range(10):
			var p:Vector3=a.lerp(b,(i+.5)/10.)+Vector3(side*(width*.5+.04),.075,0)
			var trim:=box(parent,"RampCoping",p,Vector3(.16,.15,a.distance_to(b)/10.),stone[2],false)
			trim.rotation.x=-atan2(b.y-a.y,b.z-a.z)


func crystal_cluster(parent: Node, point: Vector3, count: int = 3) -> void:
	for i in range(count):
		var crystal:Node3D=model(parent,"props/crystal_energy","Crystal",point+Vector3(rng.randf_range(-.55,.55),.45,rng.randf_range(-.5,.5)),Vector3.ONE*rng.randf_range(.8,2.0))
		crystal.rotation.z=rng.randf_range(-.3,.3)
	lighting(parent,point+Vector3.UP,Color("43c9c8"),.8,3.5)


func interactable(parent: Node, title: String, pos: Vector3, kind: String, prompt_value: String, asset: String) -> StaticBody3D:
	var body:StaticBody3D=attach(parent,StaticBody3D.new(),title)
	body.position=pos
	body.set_script(load("res://scripts/interactable.gd"))
	body.set("kind",kind)
	body.set("prompt",prompt_value)
	model(body,asset,"Visual",Vector3.ZERO)
	var collision:CollisionShape3D=attach(body,CollisionShape3D.new(),"CollisionShape3D")
	var shape:=BoxShape3D.new()
	shape.size=Vector3(.6,1,.5)
	collision.shape=shape
	collision.position.y=.5
	var area:Area3D=attach(body,Area3D.new(),"InteractionArea")
	area.collision_layer=0
	var sensor:CollisionShape3D=attach(area,CollisionShape3D.new(),"CollisionShape3D")
	var sphere:=SphereShape3D.new()
	sphere.radius=2.4
	sensor.shape=sphere
	return body


func fragment(parent: Node, id: int, pos: Vector3, puzzle: bool=false) -> void:
	var area:Area3D=attach(parent,Area3D.new(),"Fragment_%d"%id)
	area.position=pos
	area.collision_layer=0
	area.collision_mask=2
	area.set_script(load("res://scripts/fragment.gd"))
	area.set("fragment_id",StringName("fragment_%d"%id))
	area.set("requires_puzzle",puzzle)
	model(area,"props/fragment_collectible","Visual",Vector3.ZERO,Vector3.ONE*2)
	var collision:CollisionShape3D=attach(area,CollisionShape3D.new(),"CollisionShape3D")
	var sphere:=SphereShape3D.new()
	sphere.radius=.7
	collision.shape=sphere
	lighting(area,Vector3.ZERO,Color("f9c74f"),1.2,2.5)
	var particles:GPUParticles3D=attach(area,GPUParticles3D.new(),"GPUParticles3D")
	particles.emitting=false
	particles.one_shot=true
	particles.explosiveness=1
	particles.amount=24
	particles.lifetime=.5
	var particle_material:=ParticleProcessMaterial.new()
	particle_material.direction=Vector3.UP
	particle_material.spread=180
	particle_material.initial_velocity_min=.8
	particle_material.initial_velocity_max=2
	particle_material.gravity=Vector3(0,-1,0)
	particle_material.scale_min=.025
	particle_material.scale_max=.06
	particles.process_material=particle_material
	var particle_mesh:=SphereMesh.new()
	particle_mesh.radius=.5
	particle_mesh.height=1
	particle_mesh.material=gold
	particles.draw_pass_1=particle_mesh


func enemy(parent: Node, title: String, pos: Vector3, patrol: float = 2.8, hp: int = 2, tutorial: bool = false) -> Area3D:
	var body:Area3D=attach(parent,Area3D.new(),title)
	body.position=pos
	body.set_script(load("res://scripts/guardian_sentinel.gd" if title == "BeaconEcho" else "res://scripts/enemy_sentinel.gd"))
	body.set("patrol_radius",patrol)
	body.set("health",hp)
	body.set("tutorial_enemy",tutorial)
	model(body,"enemies/echo_sentinel","Visual",Vector3.ZERO,Vector3.ONE)
	var collision:CollisionShape3D=attach(body,CollisionShape3D.new(),"CollisionShape3D")
	var sphere:=SphereShape3D.new()
	sphere.radius=.85
	collision.shape=sphere
	collision.position.y=1.0
	var light:OmniLight3D=attach(body,OmniLight3D.new(),"CoreLight")
	light.position=Vector3(0,1.05,0)
	light.light_color=Color("8267d6")
	light.light_energy=1.2
	light.omni_range=4.5
	return body


## Fase 6: Memoria de Auralia coleccionable (interactable "memory" con visual de scripts/memory_orb.gd).
func memory_orb(parent: Node, id: String, pos: Vector3, text: String) -> void:
	var body:StaticBody3D=attach(parent,StaticBody3D.new(),"EchoMemory_"+id.get_slice("_",1))
	body.position=pos
	body.set_script(load("res://scripts/interactable.gd"))
	body.set("kind","memory")
	body.set("item_id",id)
	body.set("prompt","Escuchar recuerdo")
	body.set("story_text",text)
	var visual:Node3D=attach(body,Node3D.new(),"Visual")
	visual.set_script(load("res://scripts/memory_orb.gd"))
	var collision:CollisionShape3D=attach(body,CollisionShape3D.new(),"CollisionShape3D")
	var core:=SphereShape3D.new()
	core.radius=.3
	collision.shape=core
	collision.position.y=1.15
	var area:Area3D=attach(body,Area3D.new(),"InteractionArea")
	area.collision_layer=0
	var sensor:CollisionShape3D=attach(area,CollisionShape3D.new(),"CollisionShape3D")
	var sphere:=SphereShape3D.new()
	sphere.radius=2.4
	sensor.shape=sphere


func bridge(parent: Node, start_z: float, end_z: float, y: float, x: float = 0) -> void:
	box(parent,"BridgeFloor",Vector3(x,y-.18,(start_z+end_z)*.5),Vector3(4,.35,absf(end_z-start_z)),stone[1])
	for i in range(int(absf(end_z-start_z))):
		box(parent,"BridgePaving",Vector3(x,y+.025,maxf(start_z,end_z)-i-.5),Vector3(3.92,.05,.94),paving,false)
	for side in [-1,1]:
		for i in range(0,int(absf(end_z-start_z))+1,3):
			var pos:=Vector3(x+side*1.85,y+.55,maxf(start_z,end_z)-i)
			box(parent,"BridgePost",pos,Vector3(.3,1.1,.3),stone[2])
		box(parent,"BridgeRail",Vector3(x+side*1.9,y+.7,(start_z+end_z)*.5),Vector3(.12,.14,absf(end_z-start_z)),stone[2])


func clockwork(parent: Node3D, p: Vector3) -> void:
	var gear:Node3D=attach(parent,Node3D.new(),"ResonanceGear")
	gear.position=p
	var ring:MeshInstance3D=attach(gear,MeshInstance3D.new(),"CarvedWheel")
	var torus:=TorusMesh.new()
	torus.inner_radius=.95
	torus.outer_radius=1.18
	torus.rings=32
	torus.ring_segments=8
	ring.mesh=torus
	ring.rotation.x=PI*.5
	ring.material_override=stone[2]
	for i in range(12):
		var a:float=i*TAU/12.
		var tooth:=box(gear,"GearTooth",Vector3(cos(a)*1.18,sin(a)*1.18,0),Vector3(.3,.2,.23),stone[1],false)
		tooth.rotation.z=a
	for i in range(6):
		var spoke:=box(gear,"Spoke",Vector3.ZERO,Vector3(.07,2.,.09),stone[0],false)
		spoke.rotation.z=i*PI/6.
	var core:=cylinder(gear,"Core",Vector3.ZERO,.22,.28,teal,false)
	core.rotation.x=PI*.5


func sanctuary_architecture(parent: Node3D) -> void:
	var ruin:Node3D=attach(parent,Node3D.new(),"BeaconRuins")
	ruin.position=Vector3(0,0,-8)
	for side in [-1,1]:
		for i in range(7):
			var p:=Vector3(side*3.2,i*.8+.4,0)
			box(ruin,"ButtressStone",p,Vector3(1.15,.77,1.4),stone[i%4],false)
		model(ruin,"environment/column","TowerColumn",Vector3(side*2.6,0,-2),Vector3(1.3,2.7,1.3))
		var fallen:=model(ruin,"environment/column","BrokenFinial",Vector3(side*3.5,5.5,0),Vector3(.7,.8,.7))
		fallen.rotation.z=side*.17
	for i in range(8):
		var width:float=5.8-i*.45
		box(ruin,"BeaconCrown",Vector3(0,5.5+i*.38,-1.5),Vector3(width,.35,1.6),stone[i%4],false)
	model(ruin,"props/crystal_energy","BeaconHeart",Vector3(0,8.9,-1.5),Vector3.ONE*3.5)
	lighting(ruin,Vector3(0,7,-.6),Color("58cab4"),2.,8.)


func build() -> void:
	rng.seed=1926
	world=Node3D.new()
	world.name="MainIsland"
	world.set_script(load("res://scripts/adventure.gd"))
	for c in ["677a7c","53686f","889593","465d63"]:stone.append(mat(c))
	paving=mat("b9c8c7")
	if ResourceLoader.exists("res://assets/environment/stone_painted.png"):
		paving.albedo_texture=load("res://assets/environment/stone_painted.png")
		paving.uv1_scale=Vector3.ONE*.65
	grass=mat("24543c")
	teal=mat("4ecdc4",1.5)
	gold=mat("f9c74f",1.5)
	var environment:WorldEnvironment=attach(world,WorldEnvironment.new(),"WorldEnvironment")
	var env:=Environment.new()
	env.background_mode=Environment.BG_SKY
	var sky:=Sky.new()
	var sky_mat:=ProceduralSkyMaterial.new()
	sky_mat.sky_top_color=Color("407d9f")
	sky_mat.sky_horizon_color=Color("efb992")
	sky_mat.ground_horizon_color=Color("efb992")
	sky_mat.ground_bottom_color=Color("647f99")
	sky_mat.sky_curve=.18
	sky.sky_material=sky_mat
	if ResourceLoader.exists("res://assets/environment/auralia_sky.png"):
		var panorama:=PanoramaSkyMaterial.new()
		panorama.panorama=load("res://assets/environment/auralia_sky.png")
		panorama.energy_multiplier=.5
		sky.sky_material=panorama
	env.sky=sky
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("91b5ce")
	env.ambient_light_energy=.28
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled=true
	env.ssao_radius=.55
	env.ssao_intensity=.8
	env.glow_enabled=true
	env.glow_intensity=.7
	env.tonemap_exposure=.86
	env.fog_enabled=true
	env.fog_light_color=Color("788caa")
	env.fog_density=.0028
	env.fog_sky_affect=.07
	environment.environment=env
	var sun:DirectionalLight3D=attach(world,DirectionalLight3D.new(),"Sun")
	sun.rotation_degrees=Vector3(-30,-38,0)
	sun.light_color=Color("ffdeb0")
	sun.light_energy=.9
	sun.light_angular_distance=0.0
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=65
	sun.shadow_bias=.05
	sun.shadow_normal_bias=1.0
	var zones:Node3D=attach(world,Node3D.new(),"Zones")
	var entrance:=island(zones,"Entrance",Vector3.ZERO,Vector2(24,22))
	var puzzle:=island(zones,"Puzzle",Vector3(0,0,-32),Vector2(22,20))
	for side in [-1,1]:clockwork(puzzle,Vector3(side*8.4,1.6,-8))
	var elevated:=island(zones,"Elevated",Vector3(0,4,-61),Vector2(16,18))
	var portal_zone:=island(zones,"PortalFinal",Vector3(0,4,-86),Vector2(22,20))
	sanctuary_architecture(portal_zone)
	model(entrance,"environment/entrance_arch","AncientEntrance",Vector3(0,0,2))
	# Fase 6: Luma es el espíritu del prólogo (luma_spirit.glb) con animación procedural.
	var luma:=interactable(entrance,"Luma",Vector3(-3.5,0,-1),"luma","Hablar con Luma","characters/luma_spirit")
	luma.get_node("Visual").rotation.y=.4
	luma.get_node("Visual").set_script(load("res://scripts/luma_spirit.gd"))
	label3d(luma,"Luma",Vector3(0,2.25,0))
	fragment(entrance,0,Vector3(5,1,-2))
	fragment(entrance,1,Vector3(-7,1,-7))
	enemy(entrance,"TutorialEcho",Vector3(0,0,-8.2),2.2,1,true)
	for point in [Vector3(4,0,3),Vector3(-5,0,-8),Vector3(9,0,-5)]:crystal_cluster(entrance,point)
	bridge(world,-11,-22,0)
	for i in range(3):
		var body:=interactable(puzzle,"Resonator_%d"%i,Vector3((i-1)*5,0,-1),"resonator","Activar "+["SOL","OLA","ESTRELLA"][i],"environment/column")
		body.set("rune_index",i)
		body.get_node("Visual").scale=Vector3(.8,.46,.8)
		model(body,"props/crystal_energy","ResonanceCrystal",Vector3(0,2.0,0),Vector3.ONE*1.8)
		label3d(body,["☀","≈","✦"][i],Vector3(0,3.1,0),Color("dfeebc"))
		label3d(body,["SOL","OLA","ESTRELLA"][i],Vector3(0,2.72,0))
		lighting(body,Vector3(0,2,0),Color("4ecdc4"),1,4)
	fragment(puzzle,2,Vector3(0,1,-6),true)
	var chest:=interactable(puzzle,"RelicChest",Vector3(-7,0,-6),"chest","Abrir reliquia","props/chest")
	chest.set("item_id","fragment_3")
	var chest_animation:AnimationPlayer=attach(chest,AnimationPlayer.new(),"AnimationPlayer")
	var library:=AnimationLibrary.new()
	var opening:=Animation.new()
	opening.length=.6
	var track:int=opening.add_track(Animation.TYPE_VALUE)
	opening.track_set_path(track,NodePath("Visual/Chest_Lid:rotation:x"))
	opening.track_insert_key(track,0,0.0)
	opening.track_insert_key(track,.6,-1.8)
	library.add_animation("open",opening)
	chest_animation.add_animation_library("",library)
	var lever:=interactable(puzzle,"LiftLever",Vector3(6,0,-6),"lever","Accionar ascensor","props/lever")
	enemy(puzzle,"GardenEcho_A",Vector3(-4,0,-7.5),3.1,2)
	enemy(puzzle,"GardenEcho_B",Vector3(5,0,3.2),3.4,2)
	var memory:=interactable(puzzle,"MemoryStone",Vector3(7,0,5),"memory","Leer inscripción","environment/column")
	memory.set("item_id","garden_hint")
	memory.set("story_text","El agua recuerda. El sol despierta. La estrella guía.\n\nOLA → SOL → ESTRELLA\n\nUna nota fuera de lugar devuelve el jardín al silencio.")
	memory.get_node("Visual").scale=Vector3(.65,.6,.65)
	var gate:=box(puzzle,"PuzzleGate",Vector3(0,1.8,-9.4),Vector3(4,3.6,.4),mat("3ba6ab",.25))
	var barrier_material:=ShaderMaterial.new()
	barrier_material.shader=load("res://shaders/barrier.gdshader")
	gate.get_node("Mesh").material_override=barrier_material
	for endpoints in [[Vector3(-5,2,-1),Vector3(0,2,-1)],[Vector3(0,2,-1),Vector3(5,2,-1)]]:
		var a:Vector3=endpoints[0]
		var b:Vector3=endpoints[1]
		var beam:=cylinder(puzzle,"RuneBeam",(a+b)*.5,.018,a.distance_to(b),teal,false)
		beam.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	for i in range(16):
		box(world,"AscendStep",Vector3(0,float(i)*.25-.12,-42.3-float(i)*.65),Vector3(4,.25,.68),stone[i%4],false)
	var ramp:=box(world,"AscentCollisionRamp",Vector3(0,2.05,-47.3),Vector3(4,.3,12.4),stone[0])
	ramp.rotation.x=atan2(4,10.4)
	ramp.get_node("Mesh").hide()
	fragment(elevated,4,Vector3(-4,1,-2))
	fragment(elevated,5,Vector3(4,3.0,4))
	enemy(elevated,"SkyEcho",Vector3(0,0,-6.5),3.2,2)
	box(elevated,"LiftBalcony",Vector3(4,1.8,4),Vector3(3,.3,3),stone[2])
	var lift:AnimatableBody3D=attach(elevated,AnimatableBody3D.new(),"MovingPlatform")
	lift.position=Vector3(4,.15,7)
	lift.set_script(load("res://scripts/moving_platform.gd"))
	model(lift,"props/platform","Visual",Vector3.ZERO)
	var lift_shape:CollisionShape3D=attach(lift,CollisionShape3D.new(),"CollisionShape3D")
	var platform_box:=BoxShape3D.new()
	platform_box.size=Vector3(2,.3,2)
	lift_shape.shape=platform_box
	lift_shape.position.y=-.15
	attach(lift,AnimationPlayer.new(),"AnimationPlayer")
	walkway(elevated,"BalconyRamp",Vector3(4,-.025,-6),Vector3(4,1.95,2.55),3.)
	for side in [-1,1]:
		model(elevated,"environment/column","BalconySupport",Vector3(4+side*1.2,0,5),Vector3(.5,.63,.5))
	bridge(world,-70,-76,4)
	var portal:=interactable(portal_zone,"Portal",Vector3(0,0,-4),"portal","Activar el faro","props/portal_ring")
	portal.get_node("CollisionShape3D").shape.size=Vector3(3.5,.35,.9)
	portal.get_node("CollisionShape3D").position.y=.2
	var vortex:MeshInstance3D=attach(portal,MeshInstance3D.new(),"Vortex")
	var quad:=QuadMesh.new()
	quad.size=Vector2(2.65,2.65)
	vortex.mesh=quad
	vortex.position=Vector3(0,1.92,.04)
	var swirl:=ShaderMaterial.new()
	swirl.shader=load("res://shaders/portal.gdshader")
	vortex.material_override=swirl
	lighting(portal,Vector3(0,2,1),Color("8e81d9"),2,7)
	fragment(portal_zone,6,Vector3(-6,1,2))
	enemy(portal_zone,"BeaconEcho",Vector3(4,0,1.5),3.8,3)
	model(portal_zone,"environment/entrance_arch","FarGate",Vector3(0,0,-5),Vector3.ONE*1.3)
	for z in [-7,0,7]:
		for side in [-1,1]:
			model(portal_zone,"environment/column","SanctuaryPillar",Vector3(side*5,0,z),Vector3(1,1.5,1))
			crystal_cluster(portal_zone,Vector3(side*6,0,z),2)
	# Fase 6: cinco Memorias de Auralia.
	memory_orb(entrance,"lore_1",Vector3(-5.5,0,4.5),"Los faroleros de Auralia cantaban al encender la luz. Decían que el faro no iluminaba el camino: lo recordaba.")
	memory_orb(puzzle,"lore_2",Vector3(-5.8,0,6.5),"Aquí crecían jardines que sonaban con el viento. Cada flor guardaba una nota, y cada nota, un nombre.")
	memory_orb(puzzle,"lore_3",Vector3(-7.0,0,-2.5),"Los engranajes no movían piedras: movían mareas de luz. Cuando se detuvieron, las islas empezaron a alejarse unas de otras.")
	memory_orb(elevated,"lore_4",Vector3(-4.0,0,1.5),"Desde el Paso del Cielo, los viajeros veían otras islas brillar como faroles lejanos. Esperaban una señal para volver.")
	memory_orb(portal_zone,"lore_5",Vector3(-3.2,0,3.4),"La noche de la fractura, alguien envió una señal imposible desde el faro. Nadie supo quién. Luma nunca dejó de escucharla.")
	for i in range(18):
		var x:float=rng.randf_range(28,65)*(1 if i%2 else -1)
		var backdrop:=model(world,"environment/island_rock","DistantIsland",Vector3(x,rng.randf_range(-15,12),rng.randf_range(-130,35)),Vector3.ONE*rng.randf_range(.6,2.2))
		if i%3==0:model(backdrop,"environment/entrance_arch","DistantRuins",Vector3.ZERO,Vector3.ONE*.6)
	for point in [Vector3(10,-8,-5),Vector3(-9,-7,-36),Vector3(9,-5,-90)]:
		var waterfall:MeshInstance3D=attach(world,MeshInstance3D.new(),"Waterfall")
		var ribbon:=QuadMesh.new()
		ribbon.size=Vector2(2.3,18)
		waterfall.mesh=ribbon
		waterfall.position=point
		var water_material:=ShaderMaterial.new()
		water_material.shader=load("res://shaders/waterfall.gdshader")
		waterfall.material_override=water_material
	var player:CharacterBody3D=attach(world,CharacterBody3D.new(),"Player")
	player.set_script(load("res://scripts/player_controller.gd"))
	player.position=Vector3(0,.2,7)
	player.collision_layer=2
	player.floor_snap_length=.35
	var player_shape:CollisionShape3D=attach(player,CollisionShape3D.new(),"CollisionShape3D")
	var capsule:=CapsuleShape3D.new()
	capsule.radius=.27
	capsule.height=1.75
	player_shape.shape=capsule
	player_shape.position.y=.875
	var appearance:=model(player,"characters/neri_quaternius","Visual",Vector3.ZERO)
	appearance.rotation.y=PI
	var pivot:Node3D=attach(player,Node3D.new(),"CameraPivot")
	pivot.position.y=1.4
	var arm:SpringArm3D=attach(pivot,SpringArm3D.new(),"SpringArm3D")
	arm.rotation_degrees.x=-13
	arm.spring_length=4.4
	arm.margin=.18
	var arm_shape:=SphereShape3D.new()
	arm_shape.radius=.18
	arm.shape=arm_shape
	var camera:Camera3D=attach(arm,Camera3D.new(),"Camera3D")
	camera.fov=65
	camera.near=.07
	camera.far=230
	camera.current=true
	attach(player,AnimationTree.new(),"AnimationTree")
	var hud:CanvasLayer=attach(world,CanvasLayer.new(),"HUDLayer")
	hud.set_script(load("res://scripts/adventure_hud.gd"))
	hud.call("build_ui")
	set_hud_owners(hud)
	var audio:Node=attach(world,Node.new(),"AudioManager")
	audio.set_script(load("res://scripts/audio_manager.gd"))
	var life:Node=attach(world,Node.new(),"EnvironmentLife")
	life.set_script(load("res://scripts/environment_life.gd"))
	var birds:Node3D=attach(world,Node3D.new(),"AmbientLife")
	birds.set_script(load("res://scripts/ambient_life.gd"))
	DirAccess.make_dir_recursive_absolute("res://scenes/zones")
	for zone_node in zones.get_children():
		save_component(zone_node,"res://scenes/zones/"+str(zone_node.name).to_snake_case()+".tscn")
	save_component(player,"res://assets/characters/player.tscn")
	save_component(hud,"res://assets/ui/hud.tscn")
	var packed:=PackedScene.new()
	assert(packed.pack(world)==OK)
	var path:String="res://scenes/main_island.tscn"
	assert(ResourceSaver.save(packed,path)==OK)
	print("WORLD_BUILT ",world.find_children("*","",true,false).size()," nodes")
	world.free()
	quit()


func set_hud_owners(parent: Node) -> void:
	for child in parent.get_children():
		child.owner=world
		set_hud_owners(child)


func save_component(node: Node, path: String) -> void:
	for child in node.find_children("*","",true,false):
		if child.owner==world: child.owner=node
	var packed:=PackedScene.new()
	assert(packed.pack(node)==OK)
	assert(ResourceSaver.save(packed,path)==OK)
	var parent:Node=node.get_parent()
	var slot:int=node.get_index()
	var title:String=node.name
	parent.remove_child(node)
	node.free()
	var saved:PackedScene=load(path)
	var replacement:Node=saved.instantiate()
	replacement.name=title
	parent.add_child(replacement)
	parent.move_child(replacement,slot)
	replacement.owner=world
