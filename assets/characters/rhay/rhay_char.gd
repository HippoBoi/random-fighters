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

@onready var slashHitbox = $slashHitbox;

const BASIC_ATTACK_COOLDOWN = 300;
const CHARACTER_NAME = "Rhay";
const Q_COOLDOWN = 6.5;
const W_COOLDOWN = 10.0;
const E_COOLDOWN = 8.0;
const R_COOLDOWN = 1.0;
const W_MAX_RANGE = 5.5;
const R_MAX_RANGE = 8.2;

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
var usingSecondary = false;
var usingTertiary = false;
var primaryTimer = 0;
var secondaryTimer = 0;
var tertiaryTimer = 0;
var ultiTimer = 0;
var usingUlti = false;
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
	var offset = deg_to_rad(180);
	targetRotation += offset;

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
			PlayerFunc.stopKeyPressed(self, animPlayer);
		
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
		
		if (basicAttacking and basicAttackTimer <= basicAttackMoment and not basicDamageDealt and target):
			var sound = preload("res://assets/sounds/characters/rhay/rhay_basic_attack.ogg");
			basicDamageDealt = true;
			
			PlayerFunc.dealDamage(self, target, dmg, "hit_01");
			PlayerFunc.playSound(self, sound);
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (primaryTimer > 0):
		primaryTimer -= delta;
	else:
		dmgOffset = 0;
		overrideBasic = false;
	
	if (usingSecondary == true):
		secondaryTimer -= delta;
		
		if (moveTo == null or target or secondaryTimer <= 0):
			cancelSecondary();
	if (usingUlti):
		if (moveTo == null or target):
			cancelUlti();
		else:
			ultimate_ability(moveTo, global_position);
		
	if (tertiaryTimer > 0):
		tertiaryTimer -= delta;
		moveTo = global_position;
		
		if (tertiaryTimer <= 0.55 and not $e_slash/AnimationPlayer.is_playing()):
			var sound = preload("res://assets/sounds/characters/rhay/rhay_slash.ogg");
			PlayerFunc.playSound(self, sound);
			$e_slash/AnimationPlayer.play("slash");
		if (tertiaryTimer <= 0.45):
			slashHitbox.get_node("MeshInstance3D/Area3D").monitoring = true;
	else:
		if (usingTertiary):
			usingTertiary = false;
			onAction = false;
			# cancel Q damage and basic attack
			overrideBasic = false;
			dmgOffset = 0;
			
			slashHitbox.get_node("MeshInstance3D").visible = false;
			slashHitbox.get_node("MeshInstance3D/Area3D").monitoring = false;
	
	if not (overrideBasic):
		$q_particles.emitting = false;
		$q_ground_particles.emitting = false;
	
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
	if (overrideBasic == false):
		basicAttacking = true;
		basicAttackTimer = BASIC_ATTACK_COOLDOWN;
		animPlayer.play(basicAnimList[basicAnimPos]);
		basicAnimPos += 1;
		if (basicAnimPos >= basicAnimList.size()):
			basicAnimPos = 0;
	else:
		var sound = preload("res://assets/sounds/characters/rhay/rhay_big_hit.ogg");
		PlayerFunc.playSound(self, sound);
		
		dmgOffset = 0;
		overrideBasic = false;
		basicAttacking = true;
		basicAttackTimer = BASIC_ATTACK_COOLDOWN * 0.5;
		animPlayer.play("e_ability");

func _setup_primary():
	rpc("primary_ability");

@rpc("call_local", "reliable")
func primary_ability():
	overrideBasic = true;
	basicAttacking = false;
	primaryTimer = 4.0;
	dmgOffset = baseDmg * 1.2;
	basicAttackTimer = 0;
	qTimer = Q_COOLDOWN - cooldownReduction;
	
	$q_particles.emitting = true;
	$q_ground_particles.emitting = true;

func _setup_secondary():
	if (mousePos.is_empty()):
		return;
	
	rpc("secondary_ability", mousePos.position, global_position);

@rpc("call_local", "reliable")
func secondary_ability(_moveTo, _global_pos):
	var direction = (_moveTo - _global_pos).normalized();
	var distance = _global_pos.distance_to(_moveTo);
	usingSecondary = true;
	secondaryTimer = 0.5;
	usingUlti = false;
	onAction = true;
	target = null;
	
	if (distance > W_MAX_RANGE):
		moveTo = _global_pos + direction * W_MAX_RANGE;
	else:
		moveTo = _moveTo;
	moveTo.y = _global_pos.y;
	wTimer = W_COOLDOWN - cooldownReduction;
	speedOffset = 7.5;
	
	$w_dash_particles/sparkParticle.emitting = true;
	$w_dash_particles/meshParticles.emitting = true;
	
	var sound = preload("res://assets/sounds/characters/rhay/rhay_jump.ogg");
	PlayerFunc.playSound(self, sound);
			
	animPlayer.play("w_ability");
	syncRotation(moveTo);
	
func _setup_tertiary():
	if (mousePos.is_empty()):
		return;
	
	rpc("tertiary_ability", mousePos.position);

@rpc("call_local", "reliable")
func tertiary_ability(_mousePos):
	dmgOffset = 0;
	eTimer = E_COOLDOWN;
	tertiaryTimer = 0.7;
	target = null;
	usingTertiary = true;
	onAction = true;
	animPlayer.play("q_ability");
	
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

func _setup_ultimate():
	if not (hovering):
		return;
	
	ultiTarget = hovering;
	moveTo = ultiTarget.global_position;
	moveTo.y = global_position.y;
	
	rpc("ultimate_ability", moveTo, global_position);

@rpc("call_local", "reliable")
func ultimate_ability(_moveTo, _global_pos):
	if (_moveTo == null):
		return;
	
	moveTo = _moveTo;
	moveTo.y = _global_pos.y;
	
	usingUlti = true;
	usingSecondary = false;
	target = null;
		
	var distance = _global_pos.distance_to(_moveTo);
	if (distance < R_MAX_RANGE):
		if not (playingUltiSound):
			var sound = preload("res://assets/sounds/characters/rhay/rhay_big_jump.ogg");
			PlayerFunc.playSound(self, sound);
			
			playingUltiSound = true;
		
		rTimer = R_COOLDOWN - cooldownReduction;
		speedOffset = 15;
		onAction = true;
		
		$w_dash_particles/sparkParticle.emitting = true;
		$w_dash_particles/meshParticles.emitting = true;
		$r_trail.emitting = true;
		animPlayer.play("q_ability_001");

@rpc("call_local")
func cancelSecondary():
	usingSecondary = false;
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
	print("Rhay: ", newText);

func _onSlashTouched(other) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (other.team != team):
			qTimer = 0;
			PlayerFunc.dealDamage(self, other, (dmg + 0.5));
