extends Node3D

var parent;

func _ready() -> void:
	parent = get_parent();

func _physics_process(_delta: float) -> void:
	global_position = parent.global_position;
