extends Node3D

@export var secondsToLive := 0.6;
@export var speed = 15.0;
var minSpeed = 5.0;
var timer = 0;
var timesUp = false;
var dieTimer = 0;

func _ready() -> void:
	$sparkParticle.emitting = true;
	$meshParticles.emitting = true;

func _process(delta: float) -> void:
	timer += delta;
	speed -= (speed * 0.5) * delta;
	global_position += transform.basis.z * speed * delta;
	
	if (speed < minSpeed):
		dieTimer += delta;
		
		if not (timesUp):
			timesUp = true;
			$sparkParticle.emitting = false;
			$meshParticles.emitting = false;
		
		if (dieTimer >= 0.2):
			$sparkParticle.visible = false;
			$dissapear.emitting = true;
		if (dieTimer >= 0.75):
			queue_free();
