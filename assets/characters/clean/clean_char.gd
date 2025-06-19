extends CharacterBody3D

@export var maxHp = 150.0;
@export var hp = 150.0;
@export var baseArmor = 14;
@export var baseDmg = 17.5;
@export var baseAttackRange = 8.0;
@export var baseAttackSpeed = 5.0;
@export var baseSpeed = 5.5;
@export var cooldownReduction = 0;
var shield = 0;

const BASIC_ATTACK_COOLDOWN = 300;
const CHARACTER_NAME = "Clean";
const Q_COOLDOWN = 4.5;
const W_COOLDOWN = 7.5;
const E_COOLDOWN = 14.0;
const R_COOLDOWN = 50.0;
const Q_MAX_RANGE = 5.0;

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
var speedMultiplier = 1.0;

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
var overrideBasic = false;
var usingPrimary = false;
var usingSecondary = false;
var usingTertiary = false;
var usingUltimate = false;
var secondaryTimer = 0;
var tertiaryTimer = 0;
var ultimateTimer = 0;
var ultiTarget = null;
var bufferedTarget = null;
var bufferedInput = null;

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
var tokens = 0;
var respawnTimer = 0;
var assistedInKill = [];

var extraBasics = 0;
var hackerTimer = 0;
var hackerMode = false;
var appliedBuffs = false;

var basicAnimList = ["basic_01", "basic_02"];
var basicAnimPos = 0;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $clean;
@onready var animPlayer = $AnimationPlayerReal
@onready var rainDrops = $codeThunder/rainDrops;
@onready var thunder = $codeThunder/thunder;
@onready var circle = $codeThunder/circle
@onready var wParticles = $w_particles;

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
	
		if (Input.is_action_just_pressed("stop_movement") and not (onAction or stunned or dead)):
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
				if not (onAction or stunned or dead):
					action.call();
				else:
					bufferedInput = action;
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (usingPrimary == true):
		if (moveTo == null):
			cancelDash();
	
	if (usingSecondary):
		secondaryTimer -= delta;
		if (wParticles.visible == false):
			wParticles.visible = true;
			$w_particles/AnimationPlayer.play("attack");
		
		if (secondaryTimer <= 0):
			if (wParticles.visible):
				$w_dissapear.emitting = true;
				wParticles.visible = false;
			
			usingSecondary = false;
			extraBasics = 0;
			attackSpeedOffset = 0;
	
	if (tertiaryTimer > 0):
		tertiaryTimer -= delta;
		moveTo = global_position;
		
		if (tertiaryTimer < 0.2 and thunder.emitting == false):
			hackerTimer = 4.0;
			appliedBuffs = false;
			hackerMode = true;
			rainDrops.emitting = false;
			circle.emitting = false;
			$e_clouds.emitting = true;
			thunder.emitting = true;
	else:
		if (usingTertiary):
			appliedBuffs = false;
			usingTertiary = false;
			onAction = false;
	
	if (ultimateTimer > 0):
		ultimateTimer -= delta;
		moveTo = global_position;
	else:
		if (usingUltimate):
			usingUltimate = false;
			onAction = false;
	
	if (hackerMode):
		if (hackerTimer > 0):
			hackerTimer -= delta;
			
			if not (appliedBuffs):
				_toggle_toon_shader(true);
				appliedBuffs = true;
				speedOffset += 0.75;
		else:
			$e_clouds.emitting = true;
			appliedBuffs = false;
			hackerMode = false;
	else:
		if not (appliedBuffs):
			_toggle_toon_shader(false);
			appliedBuffs = true;
			speedOffset = 0;
	
	if (bufferedMoveTo and moveTo == null):
		moveTo = bufferedMoveTo;
		bufferedMoveTo = null;
	
	if (moveTo):
		PlayerFunc.moveChar(self, delta, moveTo);
	
	move_and_slide();
	
	# handle animations
	if (onAction or basicAttacking):
		return;
	
	if (velocity != Vector3.ZERO):
		if not (animPlayer.current_animation == "run"):
			animPlayer.play("run");
	else:
		if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
			animPlayer.play("idle");

func basicAttack():
	if not (target):
		return;
	
	basicTarget = target;
	rpc("showBasicAttack", target.global_position);

func _onBasicTouched():
	PlayerFunc.dealDamage(self, basicTarget, dmg);

@rpc("call_local")
func showBasicAttack(_targetPos):
	if not (_targetPos):
		return;
	
	var basicScene = preload("res://assets/characters/clean/cleanBasic.tscn");
	if (extraBasics > 0):
		basicScene = preload("res://assets/characters/clean/cleanSpecialBasic.tscn");
	
	var basic = basicScene.instantiate();
	get_parent().add_child(basic);
	basic.global_position = global_position + Vector3(0, 2, 0);
	
	basic.setTarget(_targetPos);
	if (is_multiplayer_authority()):
		basic.reached_target.connect(_onBasicTouched);
	
@rpc("call_local", "any_peer", "reliable")
func playBasicAttack():
	if (extraBasics <= 0):
		basicAttacking = true;
		secondaryTimer = 0;
		basicAttackTimer = BASIC_ATTACK_COOLDOWN;
		animPlayer.play(basicAnimList[basicAnimPos]);
		basicAnimPos += 1;
		if (basicAnimPos >= basicAnimList.size()):
			basicAnimPos = 0;
		
		attackSpeedOffset = 0;
	else:
		extraBasics -= 1;
		basicAttacking = true;
		basicAttackTimer = BASIC_ATTACK_COOLDOWN;
		animPlayer.stop();
		animPlayer.play("basic_special");

func _setup_primary():
	if (mousePos.is_empty()):
		return;
	
	rpc("primary_ability", mousePos.position, global_position);

func _setup_secondary():
	rpc("secondary_ability");
	
func _setup_tertiary():
	if (mousePos.is_empty()):
		return;
	
	rpc("tertiary_ability", mousePos.position);
	
func _setup_ultimate():
	if (mousePos.is_empty()):
		return;
	
	rpc("ultimate_ability", mousePos.position);

func _spawn_e_ray(_mousePos):
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

func _spawn_ulti_laser(_mousePos):
	var direction = (_mousePos - global_position);
	direction.y = 0;
	direction = direction.normalized();
	var targetRotation = atan2(direction.x, direction.z);
	var curRotation = rotation.y;
	var shortestAngle = lerp_angle(curRotation, targetRotation, 1.0);
	
	var laser = preload("res://assets/characters/clean/clean_r_laser.tscn").instantiate();
	get_parent().add_child(laser);
	
	laser.global_position = global_position + Vector3(0, 2, 0);
	laser.rotation = Vector3(rotation.x, shortestAngle, rotation.z);
	laser.setup(self, team, dmg);

func _toggle_toon_shader(enable: bool):
	if (enable):
		for child: MeshInstance3D in $clean/Skeleton3D.get_children():
			var toon_shader = preload("res://assets/characters/clean/hacker_material.tres");
			child.set_surface_override_material(0, toon_shader);
	else:
		for child: MeshInstance3D in $clean/Skeleton3D.get_children():
			child.set_surface_override_material(0, null);
	
	$e_particles/sparkParticle.emitting = enable;
	$e_particles/spinningParts.emitting = enable;

@rpc("call_local", "reliable")
func primary_ability(_moveTo, _global_pos):
	var direction = (_moveTo - _global_pos).normalized();
	var _distance = _global_pos.distance_to(_moveTo);
	usingPrimary = true;
	
	if (target):
		bufferedTarget = target;
		target = null;
		rpc("syncBufferedInputs", null, bufferedTarget);
	
	# this is a fixed distance (not dependant on mouse pos)
	moveTo = _global_pos + direction * Q_MAX_RANGE;
	
	moveTo.y = _global_pos.y;
	qTimer = Q_COOLDOWN - cooldownReduction;
	speedOffset = 7;
	onAction = true;
	animPlayer.play("q_ability");
	syncRotation(moveTo);

@rpc("call_local", "reliable")
func secondary_ability():
	basicAttacking = false;
	usingSecondary = true;
	basicAttackTimer = 0;
	extraBasics = 2;
	attackSpeedOffset = attackSpeed * 2;
	wTimer = W_COOLDOWN - cooldownReduction;
	secondaryTimer = wTimer * 0.5;
	animPlayer.play("w_ability");

@rpc("call_local", "reliable")
func tertiary_ability(_mousePos: Vector3):
	eTimer = E_COOLDOWN - cooldownReduction;
	tertiaryTimer = 0.65;
	usingTertiary = true;
	onAction = true;
	circle.emitting = true;
	
	# _spawn_e_ray(_mousePos);
	
	animPlayer.play("e_ability");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local", "reliable")
func ultimate_ability(_mousePos):
	onAction = true;
	usingUltimate = true;
	ultimateTimer = 2.5;
	rTimer = R_COOLDOWN - cooldownReduction;
	
	_spawn_ulti_laser(_mousePos);
	
	animPlayer.play("r_ability");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local")
func cancelDash():
	usingPrimary = false;
	onAction = false;
	appliedBuffs = false;
	hackerTimer = 0;
	
	speedOffset -= 7;
	speedOffset = clamp(speedOffset, 0, 100);
	
@rpc("call_local", "any_peer", "reliable")
func syncTarget(_target):
	target = _target;

@rpc("call_local", "any_peer", "reliable")
func syncHealth(curHealth, damaged = false, attackerId: String = ""):
	hp = curHealth;
	PlayerFunc.updateHealthSize(self, damaged);
	
	if not (attackerId.is_empty()):
		var oldAttackerPos = assistedInKill.find(attackerId);
		if (oldAttackerPos != -1):
			assistedInKill.remove_at(oldAttackerPos);
		
		assistedInKill.append(attackerId);

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
func syncSlow(_slowAmount):
	speedMultiplier -= _slowAmount;
	speedMultiplier = clamp(speedMultiplier, 0.0, 1.0);

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
	print("Clean: ", newText);
