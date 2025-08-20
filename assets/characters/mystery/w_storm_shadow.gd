extends Node3D

@onready var splashParticles = $splashParticles;
var timer = 0;

var dmg = 0;
var team = -1;
var ownerInstance = null;

var alreadyHit = [];
var hittedTimers = {}; # sooorryyyyy
var keepDamaging = []; # i don't know what im doing

func setup(_owner, _dmg):
	ownerInstance = _owner;
	team = _owner.team;
	dmg = _dmg;

func _emitRandomParticle():
	var particles = splashParticles.get_children();
	particles.shuffle();
	particles[0].emitting = true;

func _process(delta: float) -> void:
	timer += delta;
	
	if (timer >= 0.1):
		timer = 0;
		_emitRandomParticle();
	
	_progressTimers(delta);

func _progressTimers(delta: float):
	for playerHit in alreadyHit:
		if not (hittedTimers[playerHit] > 0):
			print("TIMER RAN OUT")
			alreadyHit.erase(playerHit);
			_on_hit(playerHit);
			continue;
		
		hittedTimers[playerHit] -= delta;
		print(hittedTimers[playerHit]);

func _on_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if not (wasHitBefore):
			alreadyHit.append(other);
			keepDamaging.append(other);
			hittedTimers[other] = 0.5;
			
			var tickDamage = dmg * 0.25;
			if (other.team != team):
				PlayerFunc.dealDamage(self, other, tickDamage);
				PlayerFunc.slowTarget(other, 0.1);

func _on_hit_exit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if not (isCharacter):
		return;
	
	if (keepDamaging.find(other)):
		keepDamaging.erase(other);
		print("REMOVING: %s" % other.CHARACTER_NAME);
