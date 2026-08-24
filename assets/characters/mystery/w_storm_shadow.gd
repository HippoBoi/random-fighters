extends Node3D

@onready var splashParticles = $splashParticles;
var timer = 0;
var soundTimer = 0;
var startDeath = false;
var deathTimer = 0;

var dmg = 0;
var team = -1;
var ownerInstance = null;

var alreadyHit = [];
var hittedTimers = {}; # sooorryyyyy
var keepDamaging = []; # i don't know what im doing

func _ready() -> void:
	$MeshInstance3D.set("shader_parameter/transparency", 1.0);

func setup(_owner, _dmg):
	ownerInstance = _owner;
	team = _owner.team;
	dmg = _dmg;

func _emitRandomParticle():
	if (startDeath):
		return;
	
	var particles = splashParticles.get_children();
	particles.shuffle();
	particles[0].emitting = true;

func _process(delta: float) -> void:
	timer += delta;
	
	if (timer >= 0.1):
		timer = 0;
		_emitRandomParticle();
	
	_progressTimers(delta);
	
	if (startDeath):
		deathTimer += delta;
		
		if (deathTimer >= 1.0):
			queue_free();
	
	_loopSound(delta);

func _loopSound(delta):
	if (soundTimer > 0 or startDeath):
		soundTimer -= delta;
		return;
	
	var sound = load("res://assets/sounds/characters/mystery/mystery_storm.ogg");
	PlayerFunc.playSound(ownerInstance, sound);
	soundTimer = 0.5;

func _progressTimers(delta: float):
	for playerHit in alreadyHit:
		if not (hittedTimers[playerHit] > 0):
			alreadyHit.erase(playerHit);
			_on_hit(playerHit, true);
			continue;
		
		hittedTimers[playerHit] -= delta;

func _on_hit(other: Node3D, forced: bool = false) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if not (forced):
			keepDamaging.append(other);
		
		var wasHitBefore = alreadyHit.has(other);
		var inHitbox = keepDamaging.has(other);
		
		if not (wasHitBefore) and (inHitbox):
			alreadyHit.append(other);
			hittedTimers[other] = 0.5;
			
			var tickDamage = dmg * 0.25;
			if (other.team != team):
				PlayerFunc.dealDamage(ownerInstance, other, tickDamage);
				PlayerFunc.slowTarget(other, 0.09);

func _on_hit_exit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if not (isCharacter):
		return;
	
	if (keepDamaging.has(other)):
		keepDamaging.erase(other);

func kill():
	$hitbox/Area3D.monitoring = false;
	$parts.emitting = false;
	var tween = get_tree().create_tween();
	tween.tween_property($MeshInstance3D.get_surface_override_material(0), "shader_parameter/transparency", 0.0, 0.25);
	startDeath = true;
