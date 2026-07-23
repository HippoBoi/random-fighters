extends Node3D

@export var secondsToLive := 0.6;
var timer = 0;

func _ready() -> void:
	for child in self.get_children():
		child.emitting = true;

func _process(delta: float) -> void:
	timer += delta;
	
	if (timer >= secondsToLive):
		queue_free();
