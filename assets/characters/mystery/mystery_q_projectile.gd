extends Node3D

@export var secondsToLive := 0.6;
@export var speed = 15.0;

var team = -1;
var dmg = 0;
var ownerInstance = 0;

var minSpeed = 4.0;
var timer = 0;
var timesUp = false;
var dieTimer = 0;

var alreadyHit = [];

func _ready() -> void:
	$sparkParticle.emitting = true;
	$meshParticles.emitting = true;
	$q_hitbox/MeshInstance3D/Area3D.monitoring = true;
	
func setup(_owner, _dmg):
	ownerInstance = _owner;
	team = _owner.team;
	dmg = _dmg;

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
		
		if (dieTimer >= 0.2 and $sparkParticle.visible):
			var sound = load("res://assets/sounds/characters/mystery/mystery_projectile_pop.ogg");
			PlayerFunc.playSound(ownerInstance, sound);
			
			$sparkParticle.visible = false;
			$dissapear.emitting = true;
		if (dieTimer >= 0.95):
			queue_free();

func _on_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if not (wasHitBefore):
			alreadyHit.insert(len(alreadyHit), other);
			var totalDmg = dmg;
			if (other.team != team):
				PlayerFunc.dealDamage(ownerInstance, other, totalDmg);
