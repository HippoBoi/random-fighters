extends Node3D

@export var secondsToLive := 0.6;
@export var speed = 15.0;

var team = -1;
var dmg = 0;
var ownerInstance = 0;
var timer = 0;

var thunderSpawned = false;

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
	global_position += transform.basis.z * speed * delta;
	
	if (timer > 0.45):
		speed -= delta * speed;
	if (timer > 1.75):
		_spawnThunder();

func _spawnThunder():
	if (thunderSpawned):
		return;
	
	thunderSpawned = true;
	speed -= speed * 0.75;
	
	$MeshInstance3D.visible = false;
	$sparkParticle.visible = false;
	$meshParticles.visible = false;
	$q_hitbox/MeshInstance3D/Area3D.monitoring = false;
	
	$thunder/thunderParticles.emitting = true;
	$thunderExplosion.emitting = true;
	$thunderMeshExplosion.emitting = true;
	$thunder/thunderParticles/hitbox/MeshInstance3D/Area3D.monitoring = true;

func _on_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if not (wasHitBefore):
			alreadyHit.insert(len(alreadyHit), other);
			var totalDmg = dmg;
			if (other.team != team):
				PlayerFunc.dealDamage(ownerInstance, other, totalDmg);
				PlayerFunc.stunTarget(other, 0.5, "fire_hit_01");
				
				_spawnThunder();

func _on_thunder_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if not (wasHitBefore):
			alreadyHit.insert(len(alreadyHit), other);
			var totalDmg = dmg * 0.75;
			if (other.team != team):
				PlayerFunc.dealDamage(ownerInstance, other, totalDmg);
