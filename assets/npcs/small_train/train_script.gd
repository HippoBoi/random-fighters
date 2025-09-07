extends CharacterBody3D

const SPEED: float = 3.0;

func _process(delta: float) -> void:
	var forwardDirection: Vector3 = global_transform.basis.z;
	global_position += forwardDirection;
