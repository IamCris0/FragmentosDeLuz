extends StaticBody3D
## Fase 7: emisor de luz de las Grutas. Traza su rayo cada fotograma físico: los prismas lo desvían
## (grupo "prism"), los receptores lo absorben (receive_beam) y cualquier otra superficie lo detiene.

@export var active: bool = true
@export var beam_color: Color = Color(1.0, 0.86, 0.55)
@export var max_segments: int = 8
@export var max_length: float = 42.0
## Altura del haz sobre la base del emisor (coincide con el centro de prismas y receptores).
const BEAM_HEIGHT := 1.25

var segments: Array[MeshInstance3D] = []
var beam_material: ShaderMaterial
var impact: OmniLight3D
var path_points: PackedVector3Array = PackedVector3Array()
var last_target: Node = null


func _ready() -> void:
	add_to_group("beam_emitter")
	beam_material = ShaderMaterial.new()
	beam_material.shader = load("res://shaders/light_beam.gdshader")
	beam_material.set_shader_parameter("beam_color", beam_color)
	impact = OmniLight3D.new()
	impact.name = "BeamImpact"
	impact.light_color = beam_color
	impact.light_energy = 1.6
	impact.omni_range = 3.0
	add_child(impact)
	var lens := OmniLight3D.new()
	lens.name = "LensGlow"
	lens.light_color = beam_color
	lens.light_energy = 1.2
	lens.omni_range = 3.5
	lens.position = Vector3(0, BEAM_HEIGHT, -0.5)
	add_child(lens)


func output_origin() -> Vector3:
	return global_transform * Vector3(0, BEAM_HEIGHT, -0.5)


func _segment(index: int) -> MeshInstance3D:
	while segments.size() <= index:
		var mesh := MeshInstance3D.new()
		mesh.name = "BeamSegment%d" % segments.size()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.075
		tube.bottom_radius = 0.075
		tube.height = 1.0
		tube.radial_segments = 10
		tube.rings = 1
		tube.cap_top = false
		tube.cap_bottom = false
		mesh.mesh = tube
		mesh.material_override = beam_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.top_level = true
		add_child(mesh)
		segments.append(mesh)
	return segments[index]


func _physics_process(delta: float) -> void:
	if not active:
		for segment in segments: segment.hide()
		impact.hide()
		path_points = PackedVector3Array()
		return
	var origin := output_origin()
	var direction := -global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var points := PackedVector3Array([origin])
	var exclude: Array[RID] = [get_rid()]
	var visited: Dictionary = {}
	var space := get_world_3d().direct_space_state
	last_target = null
	for i in max_segments:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_length, 1, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			points.append(origin + direction * max_length)
			break
		var collider: Object = hit.collider
		if collider is Node and (collider as Node).is_in_group("prism") and not visited.has(collider):
			visited[collider] = true
			var center: Vector3 = collider.beam_point()
			center.y = origin.y
			points.append(center)
			origin = center
			direction = collider.output_direction()
			exclude.append((collider as CollisionObject3D).get_rid())
			continue
		points.append(hit.position)
		if collider is Node and collider.has_method("receive_beam"):
			collider.receive_beam(self, delta)
			last_target = collider
		break
	path_points = points
	_draw(points)


func _draw(points: PackedVector3Array) -> void:
	var count := points.size() - 1
	for i in count:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var segment := _segment(i)
		var length := a.distance_to(b)
		if length < 0.01:
			segment.hide()
			continue
		segment.show()
		var basis := Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.FORWARD)
		# CylinderMesh crece en Y: se rota para que su eje Y apunte a lo largo del segmento y se
		# estira solo en ese eje local.
		basis = basis * Basis(Vector3.RIGHT, -PI * 0.5)
		basis = Basis(basis.x, basis.y * length, basis.z)
		segment.global_transform = Transform3D(basis, (a + b) * 0.5)

	for i in range(count, segments.size()):
		segments[i].hide()
	impact.show()
	impact.global_position = points[points.size() - 1]


## Longitud total del haz (para pruebas).
func beam_length() -> float:
	var total := 0.0
	for i in path_points.size() - 1: total += path_points[i].distance_to(path_points[i + 1])
	return total
