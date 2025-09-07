extends CharacterBody3D

var speed: float = 0.1;
var accel: float = 6.0;

func _process(delta: float) -> void:
	var forwardDirection: Vector3 = global_transform.basis.z;
	global_position += (forwardDirection * 0.05) * speed * delta;
	
	speed += accel;
