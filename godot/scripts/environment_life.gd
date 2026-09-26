extends Node

var time: float = 0.0
var crystals: Array[Node3D] = []
var crystal_heights: Array[float] = []
var lights: Array[OmniLight3D] = []
var strengths: Array[float] = []
var luma_animator: AnimationPlayer
var wave_clock: float = 0.0
var wave_name: StringName
var idle_name: StringName
var gears: Array[Node3D]=[]
var wind_surfaces: int=0


func _ready() -> void:
	var scene: Node = get_parent()
	apply_foliage(scene)
	for node in scene.get_node("Zones/Puzzle").find_children("ResonanceCrystal", "Node3D", true, false):
		crystals.append(node)
		crystal_heights.append(node.position.y)
	for node in scene.find_children("LanternLight*", "OmniLight3D", true, false):
		lights.append(node)
		strengths.append(node.light_energy)
	luma_animator = scene.get_node("Zones/Entrance/Luma/Visual").find_child("AnimationPlayer",true,false)
	if luma_animator:
		for clip in luma_animator.get_animation_list():
			if "wave" in str(clip): wave_name=clip
			if "idle" in str(clip): idle_name=clip
		if idle_name: luma_animator.play(idle_name)
	Preferences.quality_changed.connect(apply_quality)
	apply_quality(Preferences.quality)
	for gear in scene.find_children("ResonanceGear*","Node3D",true,false):gears.append(gear)
	var luma_visual: Node3D = scene.get_node("Zones/Entrance/Luma/Visual")
	# Fase 6: Luma es un espíritu con materiales propios; el holograma solo aplica al modelo antiguo.
	var legacy_luma: bool = luma_visual.find_child("Luma_Float", true, false) == null
	for piece in (luma_visual.find_children("*","MeshInstance3D",true,false) if legacy_luma else []):
		var hologram:=StandardMaterial3D.new()
		hologram.albedo_color=Color(.12,.48,.43,.8)
		hologram.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		hologram.emission_enabled=true
		hologram.emission=Color(.04,.18,.15)
		piece.material_override=hologram


func apply_foliage(scene: Node) -> void:
	var materials:Dictionary={}
	for piece in scene.find_children("*","MeshInstance3D",true,false):
		if not piece.mesh:continue
		for i in piece.mesh.get_surface_count():
			var old:StandardMaterial3D=piece.mesh.surface_get_material(i) as StandardMaterial3D
			if not old or not "Leaf" in old.resource_name:continue
			var fern:bool="Fern" in str(piece.get_path())
			var key:String=old.resource_name+str(fern)
			if not materials.has(key):
				var material:=ShaderMaterial.new()
				material.shader=load("res://shaders/foliage.gdshader")
				material.set_shader_parameter("tint",old.albedo_color)
				material.set_shader_parameter("flexibility",.12 if fern else .04)
				materials[key]=material
			piece.set_surface_override_material(i,materials[key])
			wind_surfaces+=1


func apply_quality(level: int) -> void:
	var scene: Node=get_parent()
	var environment: Environment=scene.get_node("WorldEnvironment").environment
	environment.ssao_enabled=level>0
	environment.glow_enabled=true
	scene.get_node("Sun").shadow_enabled=level>0
	get_viewport().msaa_3d=Viewport.MSAA_4X if level==2 else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale=.8 if level==0 else 1.
	for motes in scene.find_children("LightMotes", "GPUParticles3D",true,false):motes.amount_ratio=.45 if level==0 else 1.


func _process(delta: float) -> void:
	time += delta
	if GameEvents.puzzle_solved:
		for i in gears.size():gears[i].rotation.z+=delta*.12*(1. if i%2 else -1.)
	for i in crystals.size():
		crystals[i].position.y=crystal_heights[i]+sin(time*1.3+i*1.7)*.08
		crystals[i].rotation.y+=delta*.17
	for i in lights.size():
		lights[i].light_energy=strengths[i]*(1.+sin(time*2.1+i)*.035+sin(time*3.7+i)*.025)
	if not luma_animator: return
	wave_clock-=delta
	var player: Node3D=get_parent().get_node("Player")
	var luma: Node3D=get_parent().get_node("Zones/Entrance/Luma")
	if player.global_position.distance_to(luma.global_position)<6. and wave_clock<=0 and wave_name:
		luma_animator.play(wave_name,.3)
		wave_clock=14.
	elif not luma_animator.is_playing() and idle_name:
		luma_animator.play(idle_name,.3)
