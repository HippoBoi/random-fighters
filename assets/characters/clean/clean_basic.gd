extends Node3D

signal reached_target;

const SPEED = 8.0;
var targetPos = null;

func setTarget(_targetPos):
	targetPos = _targetPos + Vector3(0, 2, 0);

func _physics_process(delta: float) -> void:
	if (targetPos):
		global_position = global_position.lerp(targetPos, SPEED * delta);
		look_at(targetPos, Vector3.UP);
	
	if (global_position.distance_to(targetPos) < 0.5):
		reached_target.emit();
		queue_free();
