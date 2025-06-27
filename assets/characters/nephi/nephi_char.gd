extends CharacterBody3D

@export var maxHp = 220.0;
@export var hp = 220.0;
@export var baseArmor = 28;
@export var baseDmg = 12.5;
@export var baseAttackRange = 3.0;
@export var baseAttackSpeed = 4.0;
@export var baseSpeed = 5.0;
@export var cooldownReduction = 0;
var shield = 0;

const BASIC_ATTACK_COOLDOWN = 300;
const CHARACTER_NAME = "Nephi";
const Q_COOLDOWN = 15.5;
const W_COOLDOWN = 12.0;
const E_COOLDOWN = 20.0;
const ALT_E_COOLDOWN = 2.0;
const R_COOLDOWN = 35.0;
const Q_MAX_RANGE = 5.0;
const ALT_Q_MAX_RANGE = 5.0;
const stunnedHitEffect = "grabbedEffect";

var qTimer = 0;
var wTimer = 0;
var eTimer= 0;
var rTimer = 0;
var isRanged = false;

var dmgOffset = 0;
var basicDmgOffset = 0;
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
var basicAttackTimer = 0;
var basicAttackMoment = BASIC_ATTACK_COOLDOWN * 0.75;
var defaultAttackMoment = BASIC_ATTACK_COOLDOWN * 0.75;
var basicDamageDealt = false;
var onAction = false;
var overrideBasic = false;
var usingPrimary = false;
var usingSecondary = false;
var usingTertiary = false;
var usingUlti = false;
var primaryTimer = 0;
var primaryTarget = null;
var primaryCompleted = false;
var secondaryTimer = 0;
var secondaryShieldTimer = 0;
var secondaryShield = 0;
var tertiaryTimer = 0;
var ultiTimer = 0;
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

var alreadyGrabbed = false;
var alreadyHit = [];

var underground = false;
var spawnedThunder = false;
var electricMode = false;
var electricCooldown = 0;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $Armature;
@onready var animPlayer = $AnimationPlayer2;
@onready var audioPlayer = $AudioStreamPlayer3D;

@onready var q_hitbox1 = $q_hitbox/MeshInstance3D;
@onready var q_hitbox2 = $q_hitbox/MeshInstance3D3;
@onready var q_hitbox3 = $q_hitbox/MeshInstance3D2;

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
			PlayerFunc.stopKeyPressed(self, animPlayer);
		
		if (Input.is_action_just_pressed("shop")):
			PlayerFunc.shopToggle(self);
		
		if (Input.is_anything_pressed()):
			var action = null;
			
			if (Input.is_action_just_pressed("primary") and qTimer <= 0 and not underground):
				action = Callable(self, "_setup_primary");
			if (Input.is_action_just_pressed("secondary") and wTimer <= 0 and not underground):
				action = Callable(self, "_setup_secondary");
			if (Input.is_action_just_pressed("tertiary") and eTimer <= 0):
				action = Callable(self, "_setup_tertiary");
			if (Input.is_action_just_pressed("ultimate") and rTimer <= 0 and not underground):
				action = Callable(self, "_setup_ultimate");
		
			if (action):
				if not (onAction or stunned or dead):
					action.call();
				else:
					bufferedInput = action;
		
		if (basicAttacking and basicAttackTimer <= basicAttackMoment and not basicDamageDealt and target):
			var sound = preload("res://assets/sounds/characters/nephi/nephi_basic_attack.ogg");
			basicDamageDealt = true;
			PlayerFunc.dealDamage(self, target, dmg + basicDmgOffset, "hit_01");
			PlayerFunc.playSound(target, sound);
			basicDmgOffset = 0;
			basicAttackMoment = defaultAttackMoment;
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (usingPrimary):
		primaryTimer -= delta;
		moveTo = global_position;
		
		if (primaryTimer <= 0.5):
			_setHitbox(q_hitbox1);
			_setHitbox(q_hitbox2);
			_setHitbox(q_hitbox3);
		
		if (primaryTimer <= 0):
			usingPrimary = false;
			onAction = false;
			alreadyGrabbed = false;
			
			_setHitbox(q_hitbox1, false);
			_setHitbox(q_hitbox2, false);
			_setHitbox(q_hitbox3, false);
		
		if (alreadyGrabbed):
			_setHitbox(q_hitbox1, false);
			_setHitbox(q_hitbox2, false);
			_setHitbox(q_hitbox3, false);
	
	if (usingSecondary):
		if (shield <= 0):
			usingSecondary = false;
			secondaryTimer = 0;
		
		armorOffset = 20;
		
		if not ($w_shields.visible):
			$w_particles.emitting = true;
			$w_shields.visible = true;
			$w_shields/AnimationPlayer.play("spin");
		
		secondaryTimer -= delta;
		if (secondaryTimer <= 0):
			usingSecondary = false;
	else:
		armorOffset = 0;
		
		if (shield > 0 and secondaryShield > 0):
			shield -= secondaryShield;
			secondaryShield = 0;
		
		if ($w_shields.visible):
			$w_particles.emitting = false;
			$w_shields.visible = false;
			$w_end_particles.emitting = true;
	if (usingTertiary):
		if (tertiaryTimer > 0):
			tertiaryTimer -= delta;
			moveTo = global_position;
			
			if (underground):
				if (tertiaryTimer > 0.15 and tertiaryTimer <= 0.85 and $e_dig_particles.emitting == false):
					$e_dig_particles.emitting = true;
				if (tertiaryTimer <= 0.15):
					$Armature.visible = false;
					$nephi_digging.visible = true;
					$e_dig_particles.emitting = false;
			else:
				if (tertiaryTimer > 0.25 and tertiaryTimer <= 0.3):
					_setHitbox($e_hitboxes/e_hitbox, false);
				if (tertiaryTimer <= 0.25 and $e_dig_particles.emitting):
					$e_dig_particles.emitting = false;
					_setHitbox($e_hitboxes/e_outer_hitbox, true);
					alreadyHit = [];
		else:
			_setHitbox($e_hitboxes/e_hitbox, false);
			_setHitbox($e_hitboxes/e_outer_hitbox, false);
			onAction = false;
			usingTertiary = false;
	
	if (usingUlti):
		moveTo = global_position;
		ultiTimer -= delta;
		
		if (ultiTimer <= 0.3 and not spawnedThunder):
			spawnedThunder = true;
			
			var thunderSound = preload("res://assets/sounds/characters/nephi/nephi_thunder.ogg");
			$nephi_thunder.emitting = true;
			PlayerFunc.playSound(self, thunderSound);
			
			_setHitbox($r_hitboxes/r_outer_hitbox, true);
			
		if (ultiTimer <= 0.2 and not electricMode):
			electricCooldown = 8.0;
			electricMode = true;
			_setHitbox($r_hitboxes/r_outer_hitbox, false);
			_setHitbox($r_hitboxes/r_hitbox, true);
			_toggle_toon_shader(true);
			
		if (ultiTimer <= 0):
			usingUlti = false;
			onAction = false;
			spawnedThunder = false;
	
	if (electricCooldown > 0 and electricMode):
		electricCooldown -= delta;
	else:
		electricMode = false;
		
		_setHitbox($r_hitboxes/r_hitbox, false);
		_toggle_toon_shader(false);
	
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
		if (underground and $dig_trail_particles.emitting == false):
			$dig_trail_particles.emitting = true;
		
		if not (animPlayer.current_animation == "run"):
			animPlayer.play("run");
	else:
		if ($dig_trail_particles.emitting):
			$dig_trail_particles.emitting = false;
			
		if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
			animPlayer.play("idle");

func _setHitbox(hitboxMesh: MeshInstance3D, enable: bool = true):
	# hitboxMesh.visible = enable;
	
	var hitbox: Area3D = hitboxMesh.get_node("Area3D");
	hitbox.monitoring = enable;

func _toggle_toon_shader(enable: bool):
	if (enable):
		var toon_shader = preload("res://assets/materials/electric_material.tres");
		for child: MeshInstance3D in $Armature/Skeleton3D.get_children():
			if (child.name != "eyeL" and child.name != "eyeR" and child.name != "drill"):
				child.set_surface_override_material(0, toon_shader);
			if (child.name == "drill"):
				child.set_surface_override_material(1, toon_shader);
	else:
		for child: MeshInstance3D in $Armature/Skeleton3D.get_children():
			child.set_surface_override_material(0, null);
	
	$r_particles/shockwave.emitting = enable;
	$r_particles/spinningParts.emitting = enable;
	
func basicAttack():
	if (underground):
		if (eTimer <= 0):
			_setup_tertiary();
		return;
	
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
		overrideBasic = false;
		basicAttacking = true;
		basicAttackTimer = BASIC_ATTACK_COOLDOWN;

func _setup_primary():
	if (mousePos.is_empty()):
		return;
	
	rpc("primary_ability", mousePos.position);

func _setup_secondary():
	rpc("secondary_ability");

func _setup_tertiary():
	rpc("tertiary_ability");

func _setup_ultimate():
	rpc("ultimate_ability");

@rpc("call_local", "reliable")
func primary_ability(_mousePos):
	qTimer = Q_COOLDOWN - cooldownReduction;
	onAction = true;
	usingPrimary = true;
	primaryTimer = 1;
	
	animPlayer.play("q_ability");
	
	var hookSound = preload("res://assets/sounds/characters/nephi/nephi_hook.ogg");
	PlayerFunc.playSound(self, hookSound);
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local", "reliable")
func secondary_ability():
	usingSecondary = true;
	wTimer = W_COOLDOWN - cooldownReduction;
	secondaryTimer = 5.0;
	
	shield += maxHp * 0.1;
	secondaryShield = shield;
	secondaryShieldTimer = 5.1;
	
	var shieldSound = preload("res://assets/sounds/characters/nephi/nephi_shield.ogg");
	PlayerFunc.playSound(self, shieldSound);
	syncShield(shield);

@rpc("call_local", "reliable")
func tertiary_ability():
	if not (underground):
		eTimer = ALT_E_COOLDOWN;
		tertiaryTimer = 1.15;
		underground = true;
		onAction = true;
		usingTertiary = true;
		
		speedOffset += 1.0;
		
		var digSound = preload("res://assets/sounds/characters/nephi/nephi_undeground_jump.ogg");
		PlayerFunc.playSound(self, digSound);
		animPlayer.play("e_ability");
	else:
		eTimer = E_COOLDOWN - cooldownReduction;
		tertiaryTimer = 0.5;
		usingTertiary = true;
		onAction = true;
		underground = false;
		
		speedOffset -= 1.0;
		
		$Armature.visible = true;
		$nephi_digging.visible = false;
		$dig_trail_particles.emitting = false;
		$e_dig_particles.emitting = true;
		
		_setHitbox($e_hitboxes/e_hitbox, true);
		
		var digSound = preload("res://assets/sounds/characters/nephi/nephi_undeground_attack.ogg");
		PlayerFunc.playSound(self, digSound);
		animPlayer.play("alt_e_ability");

@rpc("call_local", "reliable")
func ultimate_ability():
	rTimer = R_COOLDOWN - cooldownReduction;
	onAction = true;
	usingUlti = true;
	ultiTimer = 0.5;
	
	animPlayer.play("r_ability");

@rpc("call_local")
func cancelDash():
	onAction = false;
	speedOffset = 0;

@rpc("call_local")
func cancelPrimary():
	usingPrimary = false;
	onAction = false;
	primaryTarget = null;
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
	
	# rotateChar(newPos);
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
	print("Nephi: ", newText);

@rpc("call_local", "any_peer", "reliable")
func onItemPurchase(item: Dictionary):
	PlayerFunc.grantItemStats(self, item)

func onCollision():
	pass;

func _on_q_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg;
		var newPos = Vector3(global_position.x, other.global_position.y, global_position.z);
		if (other.team != team):
			alreadyGrabbed = true;
			PlayerFunc.dealDamage(self, other, totalDmg);
			PlayerFunc.moveTarget(other, 0.5, newPos, 24, stunnedHitEffect);

func _on_e_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		alreadyHit.insert(len(alreadyHit), other);
		var totalDmg = dmg;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg);
			PlayerFunc.stunTarget(other, 1.0, stunnedHitEffect);

func _on_e_outer_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if not (wasHitBefore):
			alreadyHit.insert(len(alreadyHit), other);
			var totalDmg = dmg * 0.55;
			if (other.team != team):
				PlayerFunc.dealDamage(self, other, totalDmg);


func _on_r_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		alreadyHit.insert(len(alreadyHit), other);
		var totalDmg = dmg * 0.75;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg);
			PlayerFunc.slowTarget(other, 0.45, stunnedHitEffect);


func _on_r_outer_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 1.15;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg);
