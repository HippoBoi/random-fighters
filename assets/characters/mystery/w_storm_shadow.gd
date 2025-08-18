extends Node3D

@onready var splashParticles = $splashParticles;
var timer = 0;

func _emitRandomParticle():
	var particles = splashParticles.get_children();
	particles.shuffle();
	particles[0].emitting = true;

func _process(delta: float) -> void:
	timer += delta;
	
	if (timer >= 0.1):
		timer = 0;
		_emitRandomParticle();
