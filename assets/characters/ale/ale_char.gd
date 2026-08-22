extends CharacterBody3D

@export var maxHp = 170.0;
@export var hp = 170.0;
@export var maxStamina = 100.0;
@export var stamina = 100.0;
@export var baseArmor = 22.0;
@export var baseDmg = 20.5;
@export var baseAttackRange = 3.2;
@export var baseAttackSpeed = 3.5;
@export var baseSpeed = 5.0;
@export var cooldownReduction = 0;
var shield = 0;

const BASIC_ATTACK_COOLDOWN = 380;
const CHARACTER_NAME = "Ale";
const Q_COOLDOWN = 7.0;
const W_COOLDOWN = 9.0;
const E_COOLDOWN = 2.0;
const R_COOLDOWN = 48.0;
const E_MAX_RANGE = 6.0;
const R_MAX_RANGE = 10.0;
const Q_STAMINA = 22;
const W_STAMINA = 22;
const E_STAMINA = 14;
const R_STAMINA = 30;
const BASIC_STAMINA = 20;

var primaryDesc = "Big forward slash that stuns enemies dealing 124% of your PHYSICAL DAMAGE."
var primaryIcon = "res://assets/sprites/ale_abilities/ale_primary.png";
var secondaryDesc = "Parry attacks with your sword. If any attack hits you during PARRY the attacker will be stunned and recieve the incoming damage.";
var secondaryIcon = "res://assets/sprites/ale_abilities/ale_secondary.png";
var tertiaryDesc = "Roll towards your mouse position.";
var tertiaryIcon = "res://assets/sprites/ale_abilities/ale_tertiary.png";
var ultiDesc = "Slash three times where your mouse is facing dealing 140% of your PHYSICAL DAMAGE per hit and stunning enemies.";
var ultiIcon = "res://assets/sprites/ale_abilities/ale_ultimate.png";

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
var basicAttackMoment = BASIC_ATTACK_COOLDOWN * 0.475;
var onAction = false;
var overrideBasic = false;
var usingPrimary = false;
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
var isInvisible = false;
var enemyTeamVision = false;
var fogInstances = [];

var lives = 0;
var level = 1;
var xp = 0;
var tokens = 0;
var respawnTimer = 0;
var assistedInKill = [];

var staminaRecover = 0.1;
var maxStaminaRecover = 12.0;
var wParticlesEmitting = false;
var usingParry = false;

var basicAnimList = ["basic_01", "basic_02"];
var basicAnimPos = 0;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $ale_armature;
@onready var animPlayer = $AnimationPlayer2;

func _ready() -> void:
	if (is_multiplayer_authority()):
		var gameScene = get_parent();
		if (gameScene.name == "Game"):
			gameScene.myCharacter = self;
	
	name = str(get_multiplayer_authority());
	PlayerFunc.setup(self);

func rotateChar(newPos) -> void:
	if not (newPos):
		return;
	
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
		if (Engine.get_physics_frames() % 15 == 0):
			rpc("syncStamina", stamina);
		
		if (Engine.get_physics_frames() % 45 == 0):
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
			
			if (Input.is_action_just_pressed("primary") and qTimer <= 0 and stamina >= Q_STAMINA / 1.5):
				action = Callable(self, "_setup_primary");
			if (Input.is_action_just_pressed("secondary") and wTimer <= 0 and stamina >= W_STAMINA / 1.5):
				action = Callable(self, "_setup_secondary");
			if (Input.is_action_just_pressed("tertiary") and eTimer <= 0 and stamina >= E_STAMINA / 1.5):
				action = Callable(self, "_setup_tertiary");
			if (Input.is_action_just_pressed("ultimate") and rTimer <= 0 and stamina >= R_STAMINA / 1.5):
				action = Callable(self, "_setup_ultimate");
			
			if (action):
				if not (onAction or stunned or dead):
					action.call();
				else:
					bufferedInput = action;
		
		if (basicAttacking and basicAttackTimer <= basicAttackMoment and not basicDamageDealt and target):
			var dmgMultiplier = min(1.0 + (stamina * 0.015), 1.85);
			var totalDmg = dmg * dmgMultiplier;
			var soundPath = "res://assets/sounds/characters/ale/ale_basic_hit.ogg";
			basicDamageDealt = true;
			
			stamina -= BASIC_STAMINA;
			rpc("syncStamina", stamina, true);
			rpc("syncSound", soundPath); 
			PlayerFunc.dealDamage(self, target, totalDmg, "hit_01");
	
	PlayerFunc.updateGlobally(self, delta);
	
	staminaRecover += 2 * delta;
	staminaRecover = clamp(staminaRecover, 0, maxStaminaRecover);
	stamina += (staminaRecover * delta);
	
	if (primaryTimer > 0):
		primaryTimer -= delta;
		moveTo = global_position;
		
		if (primaryTimer > 0.25 and primaryTimer <= 0.5):
			_setHitbox($q_hitbox/MeshInstance3D/Area3D, true);
			$q_end_particles.emitting = true;
		else:
			_setHitbox($q_hitbox/MeshInstance3D/Area3D, false);
	else:
		if (usingPrimary):
			usingPrimary = false;
			onAction = false;
	
	if (secondaryTimer > 0):
		secondaryTimer -= delta;
		moveTo = global_position;
		usingParry = false;
		
		if (secondaryTimer >= 0.15 and secondaryTimer <= 0.7):
			usingParry = true;
	else:
		if (usingSecondary):
			usingSecondary = false;
			usingParry = false;
			onAction = false;
	
	if (usingTertiary):
		tertiaryTimer -= delta;
		
		if (moveTo == null or tertiaryTimer <= 0):
			usingTertiary = false;
			onAction = false;
			speedOffset -= 6;
			speedOffset = clamp(speedOffset, 0, 100);
	
	if (usingUlti):
		ultiTimer -= delta;
		
		if (ultiTimer > 1.9):
			moveTo = global_position;
		if (ultiTimer <= 1.9):
			moveTo = ultiTarget;
		if (ultiTimer > 0.7 and ultiTimer <= 1.0):
			_setHitbox($r_hitboxes/damage_hitbox/Area3D, true);
		if (ultiTimer > 0.7 and ultiTimer <= 0.8):
			_setHitbox($r_hitboxes/slow_hitbox/Area3D, true);
		if (ultiTimer <= 0.7):
			_setHitbox($r_hitboxes/damage_hitbox/Area3D, false);
			_setHitbox($r_hitboxes/slow_hitbox/Area3D, false);
			
		if (moveTo == null or ultiTimer <= 0):
			usingUlti = false;
			onAction = false;
			speedOffset -= 7;
			speedOffset = clamp(speedOffset, 0, 100);
	
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

func _setHitbox(hitbox: Node3D, enable: bool = true):
	hitbox.monitoring = enable;

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
	if (mousePos.is_empty()):
		return;
	
	rpc("primary_ability", mousePos.position);

@rpc("call_local", "reliable")
func primary_ability(_mousePos):
	qTimer = Q_COOLDOWN - cooldownReduction;
	stamina -= Q_STAMINA;
	primaryTimer = 1.1;
	target = null;
	usingPrimary = true;
	onAction = true;
	animPlayer.play("q_ability");
	$q_hit_warning.visible = true;
	$q_hit_warning/Cube/AnimationPlayer.play("warning");
	
	var sound = preload("res://assets/sounds/characters/ale/ale_slash.ogg");
	PlayerFunc.playSound(self, sound, false);
	
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);
	rpc("syncStamina", stamina, true);

func _setup_secondary():
	if (mousePos.is_empty()):
		return;
	
	rpc("secondary_ability", mousePos.position);

@rpc("call_local", "reliable")
func secondary_ability(_mousePos):
	usingSecondary = true;
	onAction = true;
	secondaryTimer = 1.0;
	wTimer = W_COOLDOWN - cooldownReduction;
	stamina -= W_STAMINA;
	
	var sound = preload("res://assets/sounds/characters/ale/ale_parry.ogg");
	PlayerFunc.playSound(self, sound);
	
	animPlayer.play("w_ability");
	rpc("syncRotation", _mousePos);
	rpc("syncStamina", stamina, true);
	
func _setup_tertiary():
	if (mousePos.is_empty()):
		return;
	
	rpc("tertiary_ability", mousePos.position, global_position);

@rpc("call_local", "reliable")
func tertiary_ability(_moveTo, _global_pos):
	var direction = (_moveTo - _global_pos).normalized();
	usingTertiary = true;
	tertiaryTimer = 0.6;
	
	if (target):
		bufferedTarget = target;
		target = null;
		rpc("syncBufferedInputs", null, bufferedTarget);
	
	moveTo = _global_pos + direction * E_MAX_RANGE;
	moveTo.y = _global_pos.y;
	
	var sound = preload("res://assets/sounds/characters/ale/ale_roll.ogg");
	PlayerFunc.playSound(self, sound);
	
	eTimer = E_COOLDOWN;
	stamina -= E_STAMINA - cooldownReduction;
	speedOffset = 6;
	onAction = true;
	animPlayer.play("e_ability");
	syncRotation(moveTo);
	rpc("syncStamina", stamina, true);

func _setup_ultimate():
	if (mousePos.is_empty()):
		return;
	
	rpc("ultimate_ability", mousePos.position, global_position);

@rpc("call_local", "reliable")
func ultimate_ability(_moveTo, _global_pos):
	var ultAnimPlayer = $NewUltAnimPlayer;
	var direction = (_moveTo - _global_pos).normalized();
	var distance = _global_pos.distance_to(_moveTo);
	usingUlti = true;
	ultiTimer = 2.7;
	
	if (target):
		bufferedTarget = target;
		target = null;
		rpc("syncBufferedInputs", null, bufferedTarget);
	
	if (distance > R_MAX_RANGE):
		ultiTarget = _global_pos + direction * R_MAX_RANGE;
	else:
		ultiTarget = _moveTo;
	ultiTarget.y = _global_pos.y;
	
	var sound = preload("res://assets/sounds/characters/ale/ale_ulti.ogg");
	PlayerFunc.playSound(self, sound, false);
	
	onAction = true;
	rTimer = R_COOLDOWN - cooldownReduction;
	stamina -= R_STAMINA;
	speedOffset = 7;
	ultAnimPlayer.play("r_ability");
	syncRotation(_moveTo);
	rpc("syncStamina", stamina, true);

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
	speedOffset -= 7;
	speedOffset = clamp(speedOffset, 0, 100);
	
@rpc("call_local", "any_peer", "reliable")
func syncTarget(_target):
	target = _target;

@rpc("call_local", "any_peer", "reliable")
func syncHealth(curHealth, curShield, damaged = false, attackerId: String = ""):
	if not (PlayerFunc.canApplyHealthSync()):
		return;

	hp = curHealth;
	shield = curShield;
	PlayerFunc.updateHealthSize(self, damaged);
	
	if not (attackerId.is_empty()):
		var oldAttackerPos = assistedInKill.find(attackerId);
		if (oldAttackerPos != -1):
			assistedInKill.remove_at(oldAttackerPos);
		
		assistedInKill.append(attackerId);

@rpc("call_local", "any_peer")
func syncStamina(_stamina, resetSpeed = false):
	stamina = _stamina;
	stamina = clamp(stamina, 0, maxStamina);
	
	if (resetSpeed):
		staminaRecover = 0.5;
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
	isInvisible = false;
	visible = true;
	PlayerFunc.updateHealthSize(self);

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

@rpc("call_local", "any_peer")
func onParry():
	var sound = preload("res://assets/sounds/characters/ale/ale_parry_success.ogg");
	PlayerFunc.playSound(self, sound);
	
	$w_particles/w_aura_hit.emitting = true;

func onCollision():
	pass;

func _onSlashTouched(other) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (other.team != team):
			qTimer = 0;
			PlayerFunc.dealDamage(self, other, (dmg + 0.5));

func _on_q_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 1.24;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg);
			PlayerFunc.stunTarget(other, 1.0);

func _on_r_hit_slow(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 0.5;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg);
			PlayerFunc.slowTarget(other, 0.5);

func _on_r_hit_damage(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 1.5;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg);
			PlayerFunc.stunTarget(other, 0.5);
