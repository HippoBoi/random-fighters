extends Node3D

@export var secondsToLive := 0.6;
@export var speed = 0.5;
var timer = 0;

func _ready() -> void:
	$sparkParticle.emitting = true;
	$meshParticles.emitting = true;

func _process(delta: float) -> void:
	timer += delta;
	global_position.z += speed * sign(global_position.z);
