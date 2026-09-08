extends Node3D

var character: CharacterBody3D;
var dmg: float = 0.0;
var team: int = 0;
var timer: float = 0.5;
var deathTimer: float = 0.5;
var die: bool = false;

var dealtInitial = false;
var dealtExplosion = false;

func fire(_character, _team: int, _dmg: float, _targetPos: Vector3):
	# TODO: finish this tween when the projectile model gets added
	var tween = get_tree().create_tween();
	$initialHitbox.global_position = _targetPos;
	$explosionHitbox.global_position = _targetPos;
	
	character = _character;
	dmg = _dmg;
	team = _team;

func _initialDamage():
	dealtInitial = true;
	# debug ---
	$initialHitbox/MeshInstance3D.visible = true;
	# ---------
	$initialHitbox/MeshInstance3D/Area3D.monitoring = true;

func _explode():
	dealtExplosion = true;
	die = true;
	
	# debug ---
	$explosionHitbox/MeshInstance3D.visible = true;
	# ---------
	$explosionHitbox/MeshInstance3D/Area3D.monitoring = true;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	timer -= delta;
	
	if (die):
		deathTimer -= delta;
	
	if (timer <= 0.25 and not dealtInitial):
		_initialDamage();
	
	if (timer <= 0 and not dealtExplosion):
		_explode();
	
	if (deathTimer <= 0):
		queue_free();

func _onTouch(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 0.75;
		if (other.team != team):
			PlayerFunc.dealDamage(character, other, totalDmg);

func _onTouchSlow(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 0.25;
		if (other.team != team):
			PlayerFunc.dealDamage(character, other, totalDmg);
			PlayerFunc.slowTarget(other, 0.45);
