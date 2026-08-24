extends CharacterBody3D

@export var maxHp = 210.0;
@export var hp = 210.0;
@export var baseArmor = 24;
@export var baseDmg = 26.0;
@export var baseAttackRange = 8.0;
@export var baseAttackSpeed = 4.0;
@export var baseSpeed = 5.0;
@export var cooldownReduction = 0;
var shield = 0;

const BASIC_ATTACK_COOLDOWN = 300;
const CHARACTER_NAME = "Mystery";
const MAX_Q_COOLDOWN = 6.0;
const MAX_W_COOLDOWN = 18.5;
const MAX_E_COOLDOWN = 9.5;
const MAX_R_COOLDOWN = 75.0;
const MAX_R_SLASH_COOLDOWN = 1.75;

var Q_COOLDOWN = 6.0;
var W_COOLDOWN = 18.5;
var E_COOLDOWN = 9.5;
var R_COOLDOWN = 75.0;
const W_MAX_RANGE = 5.0;
const TRAVEL_SPEED = 0.5;

var primaryDesc = "Cast for 1.5 seconds and fire a small projectile dealing 100% of your DAMAGE."
var primaryIcon = "res://assets/sprites/mystery_abilities/mistery_primary.png";
var secondaryDesc = "Spawn a storm in the position of your mouse. Enemies will be hit and slowed by 11% every second";
var secondaryIcon = "res://assets/sprites/mystery_abilities/mistery_secondary.png";
var tertiaryDesc = "Damage an enemy by 75% of your DAMAGE or shield an ally by 50% of your DAMAGE. Target anyone regardless of distance";
var tertiaryIcon = "res://assets/sprites/mystery_abilities/mistery_tertiary.png";
var ultiDesc = "Replace all your abilities for a strong projectile that stuns and damages two times for a total of 175% of your DAMAGE";
var ultiIcon = "res://assets/sprites/mystery_abilities/mistery_ultimate.png";

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
var basicAttackMoment = BASIC_ATTACK_COOLDOWN * 0.9;
var basicTarget = null;
var onAction = false;
var usingPrimary = false;
var usingSecondary = false;
var usingTertiary = false;
var usingUltimate = false;
var usingUltiSlash = false;
var primaryTimer = 0;
var secondaryTimer = 0;
var tertiaryTimer = 0;
var ultimateTimer = 0;
var ultiSlashTimer = 0;
var bufferedTarget = null;
var bufferedInput = null;

var basicAnimList = ["basic_01", "basic_02"];
var basicAnimPos = 0;
var basicDamageDealt = false;

var alreadyHit = [];

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

var storedMousePos = null;

var usedPrimaryProjectile = false;
var primaryProjectile = null;

var usedUltiProjectile = false;

var usedShield = false;
var shieldTarget = null;
var shieldTargetIsEnemy = false;

var holdingSecondary = false;
var usingStorm = false;
var godMode = false;
var stormInstance = null;
var stormTimer = 0;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $mystery_armature;
@onready var animPlayer = $AnimationPlayer2;

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
			PlayerFunc.stopCharacter(self);
		
		if (Input.is_action_just_pressed("shop")):
			PlayerFunc.shopToggle(self);
		
		if (Input.is_action_just_pressed("closeMenu")):
			PlayerFunc.shopToggle(self, true);
		
		if (Input.is_anything_pressed()):
			var action = null;
			
			if (Input.is_action_just_pressed("primary") and qTimer <= 0):
				action = Callable(self, "_setup_primary");
			if (Input.is_action_just_pressed("secondary") and wTimer <= 0 and not holdingSecondary):
				action = Callable(self, "_setup_secondary");
			if (Input.is_action_just_pressed("tertiary") and eTimer <= 0):
				action = Callable(self, "_setup_tertiary");
			if (Input.is_action_just_pressed("ultimate") and rTimer <= 0):
				action = Callable(self, "_setup_ultimate");
			
			if (action):
				if not (onAction or stunned or dead):
					if (usingUltimate == false):
						action.call();
					else:
						_setup_ulti_slash();
				else:
					bufferedInput = action;
		
		if (basicAttacking and basicAttackTimer <= basicAttackMoment and not basicDamageDealt and target):
			basicDamageDealt = true;
			rpc("showBasicAttack", target.global_position);
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (usingStorm):
		speed *= 0.6;
	
	if (primaryTimer > 0):
		primaryTimer -= delta;
		moveTo = global_position;
		
		if (primaryTimer > 0.75 and primaryTimer <= 0.9):
			if not (usedPrimaryProjectile):
				_spawn_q_projectile(storedMousePos);
			
			$q_particles.emitting = true;
			$q_slash/AnimationPlayer.play("slash");
	else:
		if (usingPrimary):
			usingPrimary = false;
			onAction = false;
			usedPrimaryProjectile = false;
	
	if (secondaryTimer > 0):
		secondaryTimer -= delta;
		moveTo = global_position;
		
		if (secondaryTimer <= 1.0 and storedMousePos and not usingStorm):
			_spawn_w_storm(storedMousePos);
	else:
		if (usingSecondary):
			usingSecondary = false;
			onAction = false;
	
	if (stormTimer > 0):
		stormTimer -= delta;
	else:
		if (usingStorm):
			_kill_previous_storm();
			wTimer = W_COOLDOWN - cooldownReduction;
			usingStorm = false;
	
	if (tertiaryTimer > 0):
		tertiaryTimer -= delta;
		moveTo = global_position;
		
		if (tertiaryTimer < 0.4 and not usedShield):
			usedShield = true;
			
			var sound = load("res://assets/sounds/characters/mystery/mystery_spell_curse.ogg");
			PlayerFunc.playSound(self, sound);
			
			if (is_instance_valid(shieldTarget)):
				if (shieldTargetIsEnemy):
					PlayerFunc.dealDamage(self, shieldTarget, 15 + (dmg * 0.75), "hit_02");
				else:
					_show_shield_model(shieldTarget);
					PlayerFunc.grantShield(self, shieldTarget, 6 + (dmg * 0.55), "heal_01");
	else:
		if (usingTertiary):
			onAction = false;
			usingTertiary = false;
			usedShield = false;
			shieldTargetIsEnemy = false;
			shieldTarget = null;
	
	if (ultimateTimer > 0):
		ultimateTimer -= delta;
		
		if (ultimateTimer >= 15):
			moveTo = global_position;
		if (ultimateTimer < 15.0 and godMode == false):
			$r_mesh.visible = true;
			$r_particles.emitting = true;
			godMode = true;
			onAction = false;
	else:
		if (usingUltimate):
			$r_mesh.visible = false;
			$r_particles.emitting = false;
			usingUltimate = false;
			onAction = false;
			godMode = false;
			speedOffset = 0;
			dmgOffset = 0;
			
			Q_COOLDOWN = MAX_Q_COOLDOWN;
			W_COOLDOWN = MAX_W_COOLDOWN;
			E_COOLDOWN = MAX_E_COOLDOWN;
	
	if (ultiSlashTimer > 0):
		ultiSlashTimer -= delta;
		moveTo = global_position;
		
		if (ultiSlashTimer):
			if (ultiSlashTimer < 0.55):
				if not (usedUltiProjectile):
					_spawn_r_projectile(storedMousePos);
				
				$q_particles.emitting = true;
				$q_slash/AnimationPlayer.play("slash");
	else:
		if (usingUltiSlash):
			usingUltiSlash = false;
			usedUltiProjectile = false;
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
	
	if (velocity != Vector3.ZERO):
		if not (usingStorm or usingUltimate):
			if not (animPlayer.current_animation == "run"):
				animPlayer.play("run");
		elif (usingStorm):
			if not (animPlayer.current_animation == "w_run"):
				animPlayer.play("w_run");
		else:
			if not (animPlayer.current_animation == "r_idle"):
				animPlayer.play("r_idle");
	else:
		if not (usingStorm or usingUltimate):
			if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
				animPlayer.play("idle");
		elif (usingStorm):
			if not (animPlayer.is_playing() and animPlayer.current_animation != "w_run"):
				animPlayer.play("w_idle");
		else:
			if not (animPlayer.current_animation == "r_idle"):
				animPlayer.play("r_idle");

func _setHitbox(hitbox: Node3D, enable: bool = true):
	var mesh = hitbox.get_node("MeshInstance3D");
	mesh.visible = enable;
	var area3D: Area3D = mesh.get_node("Area3D");
	area3D.monitoring = enable;

func _kill_previous_storm():
	if (stormInstance):
		stormInstance.kill();
		stormInstance = null;

func _spawn_q_projectile(_mousePos):
	var projectile = preload("res://assets/characters/mystery/mystery_q_projectile.tscn").instantiate();
	get_parent().add_child(projectile);
	
	projectile.global_position = global_position + Vector3(0, 0.75, 0);
	projectile.rotation = rotation;
	projectile.setup(self, dmg);
	
	var sound = load("res://assets/sounds/characters/mystery/mystery_projectile.ogg");
	PlayerFunc.playSound(self, sound);
	
	usedPrimaryProjectile = true;

func _spawn_w_storm(_mousePos):
	_kill_previous_storm();
	
	var storm = preload("res://assets/characters/mystery/w_storm_shadow.tscn").instantiate();
	get_parent().add_child(storm);
	
	storm.global_position = _mousePos;
	storm.global_position.y = 0.25;
	storm.rotation = rotation;
	storm.setup(self, dmg);
	
	stormInstance = storm;
	stormTimer = 12.0;
	usingStorm = true;

func _spawn_r_projectile(_mousePos):
	var projectile = preload("res://assets/characters/mystery/mystery_r_projectile.tscn").instantiate();
	get_parent().add_child(projectile);
	
	projectile.global_position = global_position + Vector3(0, 1.25, 0);
	projectile.rotation = rotation;
	projectile.setup(self, dmg);
	
	var sound = load("res://assets/sounds/characters/mystery/mystery_projectile.ogg");
	PlayerFunc.playSound(self, sound);
	
	usedUltiProjectile = true;

func _show_shield_model(_target: CharacterBody3D):
	if not (is_instance_valid(_target)):
		return;

	var existingShield = _target.get_node_or_null("MysteryShieldEffect");
	if (existingShield):
		return;

	var shieldModel = preload("res://assets/characters/mystery/mystery_shield.tscn").instantiate();
	shieldModel.name = "MysteryShieldEffect";
	shieldModel.position = Vector3(0, 1.65, 0);
	_target.add_child(shieldModel);

	var lifetimeTimer = Timer.new();
	lifetimeTimer.wait_time = 0.1;
	lifetimeTimer.autostart = true;
	lifetimeTimer.timeout.connect(func():
		if not (is_instance_valid(_target) and is_instance_valid(shieldModel)):
			return;

		if (_target.shield <= 0 or _target.dead):
			shieldModel.queue_free();
	);
	shieldModel.add_child(lifetimeTimer);

func basicAttack():
	if not (target):
		return;
	
	basicDamageDealt = false;
	basicAttacking = true;
	basicTarget = target;

func _onBasicTouched():
	var path = "res://assets/sounds/characters/mystery/mystery_basic_hit.ogg";
	rpc("syncSound", path);
	
	PlayerFunc.dealDamage(self, basicTarget, dmg);

func _setup_primary():
	if (mousePos.is_empty()):
		return;
	
	rpc("primary_ability", mousePos.position);

func _setup_secondary():
	if (mousePos.is_empty()):
		return;
	
	rpc("secondary_ability", mousePos.position, usingStorm);

func _setup_tertiary():
	if not (hovering):
		return;
	
	shieldTarget = hovering;
	
	rpc("tertiary_ability", shieldTarget.get_multiplayer_authority());

func _setup_ultimate():
	rpc("ultimate_ability");

func _setup_ulti_slash():
	if (mousePos.is_empty()):
		return;
	
	rpc("ultimate_slash", mousePos.position);

@rpc("call_local", "reliable")
func primary_ability(_mousePos):
	qTimer = Q_COOLDOWN - cooldownReduction;
	primaryTimer = 1.2;
	usingPrimary = true;
	onAction = true;
	storedMousePos = _mousePos;
	
	var sound = load("res://assets/sounds/characters/mystery/mystery_slash.ogg");
	PlayerFunc.playSound(self, sound);
	
	animPlayer.play("q_ability");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local", "reliable")
func secondary_ability(_mousePos, _usingStorm):
	if not (_usingStorm):
		wTimer = 1.0;
		secondaryTimer = 1.5;
		usingSecondary = true;
		onAction = true;
		storedMousePos = _mousePos;
		
		var sound = load("res://assets/sounds/characters/mystery/mystery_storm_start.ogg");
		PlayerFunc.playSound(self, sound);
		
		animPlayer.play("w_ability");
		simulateMove(null, global_position);
		rpc("syncRotation", _mousePos);
	else:
		_kill_previous_storm();
		wTimer = W_COOLDOWN - cooldownReduction;
		usingStorm = false;

@rpc("call_local", "reliable")
func tertiary_ability(_targetId: int):
	var gameScene = get_parent();
	if not (gameScene.has_method("get_character_by_id")):
		return;

	shieldTarget = gameScene.get_character_by_id(str(_targetId));
	if not (is_instance_valid(shieldTarget)):
		return;

	shieldTargetIsEnemy = shieldTarget.team != team;
	eTimer = E_COOLDOWN - cooldownReduction;
	eTimer = clamp(eTimer, 4.0, E_COOLDOWN);
	tertiaryTimer = 0.8;
	usingTertiary = true;
	onAction = true;
	target = null;
	moveTo = null;
	
	var sound = load("res://assets/sounds/characters/mystery/mystery_spell.ogg");
	PlayerFunc.playSound(self, sound);
	
	animPlayer.play("e_ability");
	rpc("syncRotation", shieldTarget.global_position);

@rpc("call_local", "reliable")
func ultimate_ability():
	rTimer = R_COOLDOWN - cooldownReduction;
	qTimer = 0;
	wTimer = 0;
	eTimer = 0;
	
	speedOffset = +(baseSpeed * 0.25);
	dmgOffset = baseDmg * 0.1;
	ultimateTimer = 15.5;
	
	usingUltimate = true;
	onAction = true;
	
	animPlayer.play("r_ability");

@rpc("call_local", "reliable")
func ultimate_slash(_mousePos = null):
	Q_COOLDOWN = MAX_R_SLASH_COOLDOWN;
	W_COOLDOWN = MAX_R_SLASH_COOLDOWN;
	E_COOLDOWN = MAX_R_SLASH_COOLDOWN;
	
	qTimer = MAX_R_SLASH_COOLDOWN;
	wTimer = MAX_R_SLASH_COOLDOWN;
	eTimer = MAX_R_SLASH_COOLDOWN;
	
	ultiSlashTimer = 1.1;
	usingUltiSlash = true;
	onAction = true;
	storedMousePos = _mousePos;
	
	var sound = load("res://assets/sounds/characters/mystery/mystery_slash.ogg");
	PlayerFunc.playSound(self, sound);
	
	animPlayer.play("r_attack");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local")
func showBasicAttack(_targetPos):
	if not (_targetPos):
		return;
	
	var basic = preload("res://assets/characters/mystery/mysteryBasic.tscn").instantiate();
	get_parent().add_child(basic);
	basic.global_position = global_position + Vector3(0, 2, 0);
	
	var sound = load("res://assets/sounds/characters/mystery/mystery_basic.ogg");
	PlayerFunc.playSound(self, sound);
	
	basic.setTarget(_targetPos);
	if (is_multiplayer_authority()):
		basic.reached_target.connect(_onBasicTouched);

@rpc("call_local", "any_peer", "reliable")
func playBasicAttack():
	basicAttacking = true;
	basicAttackTimer = BASIC_ATTACK_COOLDOWN;
	animPlayer.play(basicAnimList[basicAnimPos]);
	basicAnimPos += 1;
	if (basicAnimPos >= basicAnimList.size()):
		basicAnimPos = 0;

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
	print("Mystery: ", newText);

@rpc("call_local", "any_peer", "reliable")
func onItemPurchase(item: Dictionary):
	PlayerFunc.grantItemStats(self, item)

func onCollision():
	pass;

func _on_papers_touch(other) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if not (isCharacter):
		return;
	
	var paperDmg = dmg * 0.25;
	if (other.team != team):
		PlayerFunc.dealDamage(self, other, paperDmg);

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
				PlayerFunc.dealDamage(self, other, paperDmg);
