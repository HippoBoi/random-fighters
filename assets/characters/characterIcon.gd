extends Sprite3D

@export var size = 3.0;

var parent;

func _ready() -> void:
	parent = get_parent();
	global_rotation.z = -44.7;
	global_scale(Vector3(size, size, size));
	visible = true;

func _physics_process(_delta: float) -> void:
	global_position = parent.global_position;
