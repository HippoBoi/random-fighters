extends Node3D

signal reached_target;

const SPEED = 5.0;
const ROTATION_SPEED = 5.0;

var targetPos = null;

func setTarget(_targetPos):
	targetPos = _targetPos + Vector3(0, 1.25, 0);

func _process(delta: float) -> void:
	rotation.x += ROTATION_SPEED * delta;

func _physics_process(delta: float) -> void:
	if (targetPos):
		global_position = global_position.lerp(targetPos, SPEED * delta);
	
	if (global_position.distance_to(targetPos) < 0.5):
		reached_target.emit();
		queue_free();
