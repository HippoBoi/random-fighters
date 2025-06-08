extends Node3D

@export var secondsToLive := 0.6;
var timer = 0;

func _ready() -> void:
	$sparkParticle.emitting = true;
	$meshParticles.emitting = true;

func _process(delta: float) -> void:
	timer += delta;
	
	if (timer >= secondsToLive):
		queue_free();
