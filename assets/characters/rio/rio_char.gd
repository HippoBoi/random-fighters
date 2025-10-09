extends CharacterBody3D

@export var maxHp = 200.0;
@export var hp = 200.0;
@export var baseArmor = 14.5;
@export var baseDmg = 17.0;
@export var baseAttackRange = 3.2;
@export var baseAttackSpeed = 3.5;
@export var baseSpeed = 6.0;
@export var cooldownReduction = 0;
var shield = 0;

const BASIC_ATTACK_COOLDOWN = 280;
const CHARACTER_NAME = "Rio";
const Q_COOLDOWN = 6.0;
const W_COOLDOWN = 12.0;
const E_COOLDOWN = 9.0;
const R_COOLDOWN = 50.0;
const Q_MAX_RANGE = 8.0;

var primaryDesc = ""
var primaryIcon = "res://assets/sprites/rio_abilities/rio_primary.png";
var secondaryDesc = "";
var secondaryIcon = "res://assets/sprites/rio_abilities/rio_secondary.png";
var tertiaryDesc = "";
var tertiaryIcon = "res://assets/sprites/rio_abilities/rio_tertiary.png";
var ultiDesc = "";
var ultiIcon = "res://icon.svg";

var qTimer = 0;
var wTimer = 0;
var eTimer= 0;
var rTimer = 0;
var isRanged = false;

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
var speedMultiplier = 0;

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
var basicDamageDealt = false;
var basicAttackTimer = 0;
var basicAttackMoment = BASIC_ATTACK_COOLDOWN * 0.9;
var onAction = false;
var overrideBasic = false;
var usingPrimary = false;
var usingSecondary = false;
var usingTertiary = false;
var usingUlti = false;
var primaryTimer = 0;
var primaryAnimationTimer = 0;
var secondaryTimer = 0;
var tertiaryTimer = 0;
var ultiTimer = 0;
var ultiTarget = null;
var playingUltiSound = false;
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

var basicAnimList = ["basic_01", "basic_02"];
var basicAnimPos = 0;

var playedSecondaryOutline = false;
var playedSecondaryCircle = false;
var primaryMoveToTarget: Vector3;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $rio_armature
@onready var animPlayer = $AnimationPlayer

func _ready() -> void:
	if (is_multiplayer_authority()):
		var gameScene = get_parent();
		if (gameScene.name == "Game"):
			gameScene.myCharacter = self;
			
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
		if (Engine.get_physics_frames() % 60 == 0):
			rpc("syncPosition", global_position);
			rpc("syncTarget", target);
		
		PlayerFunc.updateState(self, delta);
		
		if (Input.is_action_just_pressed("rightClick")):
			PlayerFunc.onRightClick(self);
	
		if (Input.is_action_just_pressed("stop_movement") and not (onAction or stunned)):
			PlayerFunc.stopKeyPressed(self, animPlayer);
		
		if (Input.is_action_just_pressed("shop")):
			PlayerFunc.shopToggle(self);
		
		if (Input.is_action_just_pressed("closeMenu")):
			PlayerFunc.shopToggle(self, true);
		
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
			
			if (action) and not (usingSecondary):
				if not (onAction or stunned or dead):
					action.call();
				else:
					bufferedInput = action;
		
		if (basicAttacking and basicAttackTimer <= basicAttackMoment and not basicDamageDealt and target):
			var path = "res://assets/sounds/characters/rhay/rhay_basic_attack.ogg";
			basicDamageDealt = true;
			
			PlayerFunc.dealDamage(self, target, dmg, "hit_01");
			rpc("syncSound", path);
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (usingSecondary):
		speed -= 2.0;
		speed = max(0, speed);
		
		updateCirclePositions();
	
	if (usingPrimary):
		primaryTimer -= delta;
		moveTo = global_position;
		
		if (primaryTimer < 0.45):
			moveTo = primaryMoveToTarget;
			
			if (moveTo == null or target or primaryTimer <= 0):
				cancelSecondary();
	
	if (primaryAnimationTimer):
		primaryAnimationTimer -= delta;
	
	if (secondaryTimer > 0):
		secondaryTimer -= delta;
		
		if not (playedSecondaryOutline):
			playedSecondaryOutline = true;
			$RiotOuterCircle/animPlayer.play("outline");
		
		if (secondaryTimer <= 0.7 and not playedSecondaryCircle):
			playedSecondaryCircle = true;
			$RioWCircle/animPlayer.play("slash");
	else:
		if (usingSecondary):
			usingSecondary = false;
			onAction = false;
			playedSecondaryCircle = false;
			playedSecondaryOutline = false;
		
	if (tertiaryTimer > 0):
		tertiaryTimer -= delta;
		moveTo = global_position;
	else:
		if (usingTertiary):
			usingTertiary = false;
			onAction = false;
	
	if (ultiTimer > 0):
		ultiTimer -= delta;
		moveTo = global_position;
	else:
		if (usingUlti):
			usingUlti = false;
			onAction = false;
	
	if (bufferedMoveTo and moveTo == null):
		moveTo = bufferedMoveTo;
		bufferedMoveTo = null;
	
	if (moveTo):
		PlayerFunc.moveChar(self, delta, moveTo);
	
	move_and_slide();
	
	# handle animations
	if (onAction or basicAttacking):
		return;
	
	if not (usingSecondary) and not (primaryAnimationTimer > 0):
		if (velocity != Vector3.ZERO):
			if not (animPlayer.current_animation == "run"):
				animPlayer.play("run");
		else:
			if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
				animPlayer.play("idle");

func updateCirclePositions():
	$RioWCircle.global_position.x = global_position.x;
	$RioWCircle.global_position.z = global_position.z;
	
	$RiotOuterCircle.global_position.x = global_position.x;
	$RiotOuterCircle.global_position.z = global_position.z;

func updateHealthSize():
	var UILoaded = has_node("CharacterUI");
	if not (UILoaded):
		return;
	
	var charUI = get_node("CharacterUI");
	var healthBar = charUI.get_node("HealthUI/SubViewport/emptyBar/healthBar");
	var shieldBar = charUI.get_node("HealthUI/SubViewport/emptyBar/shieldBar");
	healthBar.scale.x = hp / maxHp;
	shieldBar.scale.x = shield / maxHp;

func basicAttack():
	basicDamageDealt = false;
	basicAttacking = true;

@rpc("call_local", "any_peer", "reliable")
func playBasicAttack():
	if (usingSecondary):
		return;
	
	basicAttacking = true;
	basicAttackTimer = BASIC_ATTACK_COOLDOWN;
	animPlayer.play(basicAnimList[basicAnimPos]);
	basicAnimPos += 1;
	if (basicAnimPos >= basicAnimList.size()):
		basicAnimPos = 0;

func _setup_primary():
	if not (mousePos):
		return;
	
	rpc("primary_ability", mousePos.position, global_position);

@rpc("call_local", "reliable")
func primary_ability(_moveTo, _global_pos):
	var direction = (_moveTo - _global_pos).normalized();
	primaryTimer = 0.75;
	primaryAnimationTimer = primaryTimer + 0.4;
	usingPrimary = true;
	onAction = true;
	
	primaryMoveToTarget = _global_pos + direction * Q_MAX_RANGE;
	primaryMoveToTarget.y = _global_pos.y;
	moveTo = primaryMoveToTarget;
	
	qTimer = Q_COOLDOWN - cooldownReduction;
	speedOffset = 7.5;
	
	animPlayer.play("q_ability");
	syncRotation(moveTo);

func _setup_secondary():
	rpc("secondary_ability");

@rpc("call_local", "reliable")
func secondary_ability():
	wTimer = W_COOLDOWN;
	secondaryTimer = 1.8;
	usingSecondary = true;
	
	animPlayer.play("w_action");
	
func _setup_tertiary():
	rpc("tertiary_ability");

@rpc("call_local", "reliable")
func tertiary_ability():
	usingTertiary = true;
	onAction = true;
	tertiaryTimer = 2.0;
	animPlayer.play("e_ability");
	eTimer = E_COOLDOWN;

func _setup_ultimate():
	rpc("ultimate_ability");

@rpc("call_local", "reliable")
func ultimate_ability():
	usingUlti = true;
	onAction = true;
	ultiTimer = 2.0;
	rTimer = R_COOLDOWN;

@rpc("call_local")
func cancelSecondary():
	usingPrimary = false;
	onAction = false;
	speedOffset = 0;

@rpc("call_local")
func cancelUlti():
	moveTo = global_position;
	usingUlti = false;
	onAction = false;
	playingUltiSound = false;
	ultiTarget = null;
	moveTo = null;
	speedOffset = 0;
	
@rpc("call_local", "any_peer", "reliable")
func syncTarget(_target):
	target = _target;

@rpc("call_local", "any_peer", "reliable")
func syncHealth(curHealth, curShield, damaged = false, attackerId: String = ""):
	hp = curHealth;
	shield = curShield;
	PlayerFunc.updateHealthSize(self, damaged);
	
	if not (attackerId.is_empty()):
		var oldAttackerPos = assistedInKill.find(attackerId);
		if (oldAttackerPos != -1):
			assistedInKill.remove_at(oldAttackerPos);
		
		assistedInKill.append(attackerId);

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

@rpc("call_local", "any_peer")
func syncSound(soundPath: String):
	var sound = load(soundPath);
	PlayerFunc.playSound(self, sound);

@rpc("call_local")
func showChatText(newText):
	print("Rhay: ", newText);

@rpc("call_local", "any_peer", "reliable")
func onItemPurchase(item: Dictionary):
	PlayerFunc.grantItemStats(self, item)

func onCollision():
	pass;

func _onSlashTouched(other) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (other.team != team):
			qTimer = 0;
			PlayerFunc.dealDamage(self, other, (dmg + 0.5));
