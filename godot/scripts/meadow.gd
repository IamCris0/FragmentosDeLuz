@tool
extends MultiMeshInstance3D

@export var field_extent: Vector2=Vector2(24,22)
@export var field_seed: int=1926


func _ready() -> void:
	if not multimesh:return
	var random:=RandomNumberGenerator.new()
	random.seed=field_seed
	for i in multimesh.instance_count:
		var side:float=1. if i%2 else -1.
		var point:=Vector3(side*random.randf_range(4.3,field_extent.x*.43),.035,random.randf_range(-field_extent.y*.39,field_extent.y*.39))
		var basis:=Basis(Vector3.UP,random.randf_range(0,TAU)).scaled(Vector3.ONE*random.randf_range(.65,1.7))
		multimesh.set_instance_transform(i,Transform3D(basis,point))
