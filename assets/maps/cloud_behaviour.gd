extends MeshInstance3D

@export var speed: float = 0;

func _physics_process(delta: float) -> void:
	if (speed == 0):
		return;
	
	global_position += Vector3((delta + speed) * -0.1, 0, 0);
