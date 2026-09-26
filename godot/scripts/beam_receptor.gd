extends StaticBody3D
## Fase 7: receptor de luz. Se carga mientras recibe un rayo y, al completarse, se activa para
## siempre (se guarda en la bandera del nivel). Emite activated para abrir puertas o puentes.

signal activated

@export var flag: String = ""
@export var charge_time: float = 0.7
var charge: float = 0.0
var active: bool = false
var hit_frame: int = -10
var gem: MeshInstance3D
var gem_material: ShaderMaterial
var light: OmniLight3D
const Style = preload("res://scripts/crystal_style.gd")


func _ready() -> void:
	add_to_group("beam_receptor")
	gem = find_child("ReceptorGem", true, false) as MeshInstance3D
	gem_material = Style.unique_crystal("violet")
	if gem: gem.material_override = gem_material
	light = OmniLight3D.new()
	light.name = "ReceptorLight"
	light.light_color = Color("b18cff")
	light.light_energy = 0.4
	light.omni_range = 4.0
	light.position.y = 1.3
	add_child(light)
	if flag != "" and GameEvents.level_flag(flag):
		activate(false)


func receive_beam(_emitter: Node, delta: float) -> void:
	hit_frame = Engine.get_physics_frames()
	if active: return
	var previous := charge
	charge = minf(charge + delta, charge_time)
	if previous <= 0.0: GameEvents.sound_requested.emit("receptor_charge")
	if charge >= charge_time: activate(true)


func _physics_process(delta: float) -> void:
	var lit := Engine.get_physics_frames() - hit_frame <= 1
	if not active and not lit: charge = maxf(charge - delta * 0.6, 0.0)
	var amount := 1.0 if active else charge / charge_time
	if gem_material: gem_material.set_shader_parameter("charge", amount)
	if gem: gem.rotation.y += delta * (0.4 + amount * 2.5)
	if light: light.light_energy = 0.4 + amount * 2.2


func activate(animate: bool = true) -> void:
	if active: return
	active = true
	charge = charge_time
	if gem_material:
		gem_material.set_shader_parameter("base_color", Color(1.0, 0.9, 0.6))
		gem_material.set_shader_parameter("glow_color", Color(1.0, 0.72, 0.35))
	if light: light.light_color = Color("ffd98a")
	if flag != "" and not GameEvents.level_flag(flag): GameEvents.set_level_flag(flag)
	if animate: GameEvents.sound_requested.emit("beam_on")
	activated.emit()
