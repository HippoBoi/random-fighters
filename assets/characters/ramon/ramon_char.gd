extends CharacterBody3D

@export var maxHp = 200.0;
@export var hp = 200.0;
@export var baseArmor = 22;
@export var baseDmg = 27.0;
@export var baseAttackRange = 7.0;
@export var baseAttackSpeed = 3.5;
@export var baseSpeed = 5.0;
@export var cooldownReduction = 0;
var shield = 0;

@onready var hitbox1 = $paperHitbox/hirbox1;
@onready var hitbox2 = $paperHitbox/hirbox2;
@onready var hitbox3 = $paperHitbox/hirbox3;
@onready var ultiHitbox = $r_hitbox;
@onready var ultiParticles = $r_hitbox/r_particles;

const BASIC_ATTACK_COOLDOWN = 300;
const CHARACTER_NAME = "Ramón";
const Q_COOLDOWN = 6.0;
const W_COOLDOWN = 10.0;
const E_COOLDOWN = 8.0;
const R_COOLDOWN = 60.0;
const W_MAX_RANGE = 5.0;
const TRAVEL_SPEED = 0.5;

var qTimer = 0;
var wTimer = 0;
var eTimer= 0;
var rTimer = 0;
var isRanged = true;

var dmgOffset = 0;
var dmg = 0;
var armorOffset = 0;
var armor = 0;
var attackRangeOffset = 0;
var attackRange = 0;
var attackSpeedOffset = 0;
var attackSpeed = 0;
var speedOffset = 0;
var speed = 0;

var timer = 0;
var team = -1;
var rayOrigin = Vector3();
var rayEnd = Vector3();
var moveTo = Vector3();
var forceMoveTo = Vector3();
var forceMoveSpeed = 5.0;
var bufferedMoveTo = Vector3();
var lastPos = Vector3();
var mousePos;
var hovering = null;
var target = null;
var showingUIs = false;
var basicAttacking = false;
var basicAttackTimer = 0;
var basicAttackMoment = BASIC_ATTACK_COOLDOWN * 0.5;
var basicTarget = null;
var onAction = false;
var usingPrimary = false;
var usingSecondary = false;
var usingTertiary = false;
var usingUltimate = false;
var primaryTimer = 0;
var secondaryTimer = 0;
var tertiaryTimer = 0;
var ultimateTimer = 0;
var bufferedTarget = null;
var bufferedInput = null;

var basicAnimList = ["basic_01"];
var basicAnimPos = 0;

var alreadyHit = [];

var stunned = false;
var stunnedParts = null;
var stunTimer = 0;
var dead = false;
var inFog = false;
var enemyTeamVision = false;
var fogInstances = [];

var lives = 0;
var level = 1;
var xp = 0;
var respawnTimer = 0;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $Armature
@onready var animPlayer = $AnimationPlayer

func _ready() -> void:
	name = str(get_multiplayer_authority());
	PlayerFunc.setup(self);

func rotateChar(newPos) -> void:
	var direction = (newPos - global_position);
	direction.y = 0;
	direction = direction.normalized();

	var targetRotation = atan2(direction.x, direction.z);

	var curRotation = rotation.y;
	var shortestAngle = lerp_angle(curRotation, targetRotation, 1.0);

	var tween = get_tree().create_tween();
	tween.tween_property(
		self,
		"rotation",
		Vector3(rotation.x, shortestAngle, rotation.z),
		0.18
	);

func _physics_process(delta: float) -> void:
	if (is_multiplayer_authority()):
		if (Engine.get_physics_frames() % 30 == 0):
			rpc("syncPosition", global_position);
			rpc("syncTarget", target);
			rpc("syncHealth", hp);
		
		PlayerFunc.updateState(self, delta);
		
		if (Input.is_action_just_pressed("rightClick")):
			PlayerFunc.onRightClick(self);
	
		if (Input.is_action_just_pressed("stop_movement") and not (onAction or stunned)):
			PlayerFunc.stopCharacter(self);
		
		if (Input.is_anything_pressed()):
			var action = null;
			
			if (Input.is_action_just_pressed("primary") and qTimer <= 0):
				action = Callable(self, "_setup_primary");
			if (Input.is_action_just_pressed("secondary") and wTimer <= 0):
				action = Callable(self, "_setup_secondary");
			if (Input.is_action_just_pressed("tertiary") and eTimer <= 0):
				action = Callable(self, "_setup_tertiary");
			if (Input.is_action_just_pressed("ultimate") and rTimer <= 0):
				action = Callable(self, "_setup_ultimate");
			
			if (action):
				if not (onAction or stunned or usingUltimate or dead):
					action.call();
				else:
					bufferedInput = action;
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (primaryTimer > 0):
		primaryTimer -= delta;
		moveTo = global_position;
		_manage_q_papers();
	else:
		if (usingPrimary):
			_setHitbox(hitbox1, false);
			_setHitbox(hitbox2, false);
			_setHitbox(hitbox3, false);
			usingPrimary = false;
			onAction = false;
			
	if (secondaryTimer > 0):
		secondaryTimer -= delta;
		moveTo = global_position;
	else:
		if (usingSecondary):
			usingSecondary = false;
			onAction = false;
	
	if (tertiaryTimer > 0):
		tertiaryTimer -= delta;
		moveTo = global_position;
	else:
		if (usingTertiary):
			usingTertiary = false;
			onAction = false;
	
	if (ultimateTimer > 0):
		ultimateTimer -= delta;
		
		_manage_r_papers();
	else:
		if (usingUltimate):
			var explosionParts: GPUParticles3D = ultiParticles.get_node("explosionParts");
			usingUltimate = false;
			explosionParts.emitting = false;
			onAction = false;
			speedOffset = 0;
			
			animPlayer.play("idle");
			_setHitbox(ultiHitbox, false);
	
	if (bufferedMoveTo and moveTo == null):
		moveTo = bufferedMoveTo;
		bufferedMoveTo = null;
	
	if (moveTo):
		PlayerFunc.moveChar(self, delta, moveTo);
	
	move_and_slide();
	
	# handle animations
	if (onAction or basicAttacking):
		return;
	
	if !(usingUltimate):
		if (velocity != Vector3.ZERO):
			if not (animPlayer.current_animation == "run"):
				animPlayer.play("run");
		else:
			if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
				animPlayer.play("idle");

func _setHitbox(hitbox: Node3D, enable: bool = true):
	var mesh = hitbox.get_node("MeshInstance3D");
	# mesh.visible = enable;
	var area3D: Area3D = mesh.get_node("Area3D");
	area3D.monitoring = enable;

func basicAttack():
	if not (target):
		return;
	
	basicTarget = target;
	rpc("showBasicAttack", target.global_position);

func _onBasicTouched():
	PlayerFunc.dealDamage(basicTarget, dmg * 0.4);

func _setup_primary():
	if (mousePos.is_empty()):
		return;
	
	rpc("primary_ability", mousePos.position);

func _setup_secondary():
	if (mousePos.is_empty()):
		return;
	
	rpc("secondary_ability", mousePos.position);

func _setup_tertiary():
	if (mousePos.is_empty()):
		return;
	
	rpc("tertiary_ability", mousePos.position);

func _setup_ultimate():
	rpc("ultimate_ability");

func _manage_q_papers():
	if (primaryTimer < 0.6):
		_setHitbox(hitbox1, true);
	if (primaryTimer < 0.48):
		_setHitbox(hitbox1, false);
		_setHitbox(hitbox2, true);
	if (primaryTimer < 0.35):
		_setHitbox(hitbox1, true);
		_setHitbox(hitbox2, false);
	if (primaryTimer < 0.28):
		_setHitbox(hitbox2, true);
	if (primaryTimer < 0.25):
		_setHitbox(hitbox1, false);
		_setHitbox(hitbox3, true);
	if (primaryTimer < 0.15):
		_setHitbox(hitbox3, false);
	if (primaryTimer < 0.05):
		_setHitbox(hitbox3, true);

func _spawn_q_papers(_mousePos):
	var direction = (_mousePos - global_position);
	direction.y = 0;
	direction = direction.normalized();
	var targetRotation = atan2(direction.x, direction.z);
	var curRotation = rotation.y;
	var shortestAngle = lerp_angle(curRotation, targetRotation, 1.0);
	
	var papers = preload("res://assets/characters/ramon/ramon_q_ability.tscn").instantiate();
	get_parent().add_child(papers);
	
	papers.global_position = global_position + Vector3(0, 2, 0);
	papers.rotation = Vector3(rotation.x, shortestAngle, rotation.z);
	papers.get_node("parts").emitting = true;

func _spawn_w_teacup(_mousePos):
	var direction = (_mousePos - global_position);
	direction.y = 0;
	direction = direction.normalized();
	var targetRotation = atan2(direction.x, direction.z);
	var curRotation = rotation.y;
	var shortestAngle = lerp_angle(curRotation, targetRotation, 1.0);
	
	var teacup = preload("res://assets/characters/ramon/ramon_w_teacup.tscn").instantiate();
	get_parent().add_child(teacup);
	
	teacup.global_position = global_position + Vector3(0, 2, 0);
	teacup.rotation = Vector3(rotation.x, shortestAngle, rotation.z);
	teacup.setup(team, dmg);
	
	var teaAnim: AnimationPlayer = teacup.get_node("AnimationPlayer");
	teaAnim.play("attack");

func _spawn_e_ability(_mousePos):
	var direction = (_mousePos - global_position);
	direction.y = 0;
	direction = direction.normalized();
	var targetRotation = atan2(direction.x, direction.z);
	var curRotation = rotation.y;
	var shortestAngle = lerp_angle(curRotation, targetRotation, 1.0);
	
	var teacup = preload("res://assets/characters/ramon/ramon_e_ability.tscn").instantiate();
	get_parent().add_child(teacup);
	
	teacup.global_position = global_position + Vector3(0, 3, 0);
	teacup.rotation = Vector3(rotation.x, shortestAngle, rotation.z);
	teacup.setup(team, dmg, _mousePos);
	
	var teaAnim: AnimationPlayer = teacup.get_node("AnimationPlayer");
	teaAnim.play("attack");

func _spawn_r_explosion():
	var explosion = preload("res://assets/characters/ramon/ramon_r_ability.tscn").instantiate();
	get_parent().add_child(explosion);
	
	explosion.global_position = global_position + Vector3(0, 2, 0);
	explosion.get_node("explosionParts").emitting = true;
	explosion.setup(team, dmg);

func _manage_r_papers():
	var explosionParts: GPUParticles3D = ultiParticles.get_node("explosionParts");
	var decimalTimer = int(round(ultimateTimer * 100));
	
	if (ultimateTimer <= 4):
		explosionParts.emitting = true;
	
	if (decimalTimer % 4 == 0):
		var isActive = ultiHitbox.get_node("MeshInstance3D/Area3D").monitoring;
		if (isActive == false):
			alreadyHit = [];
		
		_setHitbox(ultiHitbox, not isActive);

@rpc("call_local", "reliable")
func primary_ability(_mousePos):
	qTimer = Q_COOLDOWN - cooldownReduction;
	primaryTimer = 0.65;
	usingPrimary = true;
	onAction = true;
	
	_spawn_q_papers(_mousePos);
	animPlayer.play("q_ability");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local", "reliable")
func secondary_ability(_mousePos):
	wTimer = W_COOLDOWN - cooldownReduction;
	secondaryTimer = 0.9;
	usingSecondary = true;
	onAction = true;
	
	_spawn_w_teacup(_mousePos);
	
	animPlayer.play("w_ability");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local", "reliable")
func tertiary_ability(_mousePos):
	eTimer = E_COOLDOWN - cooldownReduction;
	tertiaryTimer = 0.4;
	usingTertiary = true;
	onAction = true;
	
	_spawn_e_ability(_mousePos);
	
	animPlayer.play("e_ability");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local", "reliable")
func ultimate_ability():
	rTimer = R_COOLDOWN - cooldownReduction;
	speedOffset = -(baseSpeed * 0.5);
	ultimateTimer = 5.0;
	usingUltimate = true;
	alreadyHit = [];
	
	_spawn_r_explosion();
	
	animPlayer.play("r_ability");

@rpc("call_local")
func showBasicAttack(_targetPos):
	if not (_targetPos):
		return;
	
	var basic = preload("res://assets/characters/ramon/ramonBasic.tscn").instantiate();
	get_parent().add_child(basic);
	basic.global_position = global_position + Vector3(0, 2, 0);
	
	basic.setTarget(_targetPos);
	if (is_multiplayer_authority()):
		basic.reached_target.connect(_onBasicTouched);

@rpc("call_local", "any_peer", "reliable")
func playBasicAttack():
	basicAttacking = true;
	basicAttackTimer = BASIC_ATTACK_COOLDOWN;
	animPlayer.play("basic_01");

@rpc("call_local", "any_peer", "reliable")
func syncTarget(_target):
	target = _target;

@rpc("call_local", "any_peer", "reliable")
func syncHealth(curHealth, damaged = false):
	hp = curHealth;
	PlayerFunc.updateHealthSize(self, damaged);

@rpc("any_peer", "reliable")
func syncShield(curShield):
	shield = curShield;
	PlayerFunc.updateHealthSize(self);

@rpc
func syncPosition(newPos):
	global_position = newPos;

@rpc("call_local", "any_peer")
func syncRotation(newPos):
	rotateChar(newPos);
	
@rpc("any_peer")
func syncStun(_isStunned, _stunDuration):
	stunned = _isStunned;
	stunTimer = _stunDuration;

@rpc("any_peer")
func syncBufferedInputs(_moveTo = null, _target = null):
	if (_moveTo):
		bufferedMoveTo = _moveTo;
	if (_target):
		bufferedTarget = _target;
		
@rpc("any_peer")
func simulateMove(newPos, _global_pos = Vector3.ZERO):
	if (newPos == null):
		moveTo = _global_pos;
		return;
	
	rotateChar(newPos);
	moveTo = newPos;

@rpc("any_peer", "call_local")
func simulateForcedMove(newPos, moveSpeed = 7.0, _global_pos = Vector3.ZERO):
	if (newPos == null):
		forceMoveTo = _global_pos;
		return;
	
	forceMoveSpeed = moveSpeed;
	forceMoveTo = newPos;

@rpc("call_local", "any_peer")
func syncParticles(effect: String, offset: Vector3 = Vector3(0, 2, 0)):
	var path = "res://assets/effects/%s.tscn" % effect;
	var effectNode = load(path);
	var effectInstance = effectNode.instantiate();
	
	add_child(effectInstance);
	effectInstance.global_position = global_position + offset;

@rpc("any_peer")
func syncRespawn(newHp: float, newPos: Vector3):
	global_position = newPos;
	hp = newHp;
	dead = false;
	visible = true;
	
@rpc("call_local")
func showChatText(newText):
	print("Ramón: ", newText);

func _on_papers_touch(other) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var paperDmg = dmg * 0.25;
		if (other.team != team):
			PlayerFunc.dealDamage(other, paperDmg);

func _on_ulti_touch(other) -> void:
	if (other == self):
		return;
	
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if not (wasHitBefore):
			alreadyHit.insert(len(alreadyHit), other);
			var paperDmg = dmg * 0.25;
			if (other.team != team):
				PlayerFunc.dealDamage(other, paperDmg);
