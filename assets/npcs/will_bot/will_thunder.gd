extends Node3D

const dmg = 30.0;

var warningTimer = 0;
var timer = 0;
var thunderStarted = false;

@onready var light = $thunderParticles/OmniLight3D;

func _ready() -> void:
	warningTimer = 2.0;
	light.light_energy = 0.0;
	$warningParticles.emitting = true;
	$particles.emitting = true;

func _process(delta: float) -> void:
	warningTimer -= delta;
	
	if (warningTimer > 0):
		return;
	
	_startThunder();
	timer += delta;
	
	if (timer >= 0.1 and timer < 0.5):
		$thunderParticles/hitbox/MeshInstance3D/Area3D.monitoring = true;
	if (timer >= 0.5):
		$thunderParticles/hitbox/MeshInstance3D/Area3D.monitoring = false;
	if (timer > 1.5):
		queue_free();
	
	_handleLight(delta);

func _startThunder():
	if (thunderStarted):
		return;
	
	thunderStarted = true;
	$particles.emitting = false;
	$thunderParticles.emitting = true;
	light.light_energy = 1.0;

func _on_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		PlayerFunc.dealDamage(null, other, dmg, "", true);
		PlayerFunc.stunTarget(other, 0.5);

func _handleLight(delta: float):
	light.light_energy -= delta;
	light.light_energy = max(0, light.light_energy);
