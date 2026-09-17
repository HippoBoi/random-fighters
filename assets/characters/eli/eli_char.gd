extends CharacterBody3D

@export var maxHp = 140.0;
@export var hp = 140.0;
@export var baseArmor = 29;
@export var baseDmg = 29.0;
@export var baseAttackRange = 9.0;
@export var baseAttackSpeed = 4.0;
@export var baseSpeed = 4.8;
@export var cooldownReduction = 0;
var shield = 0;

const BASIC_ATTACK_COOLDOWN = 300;
const CHARACTER_NAME = "Eli";
const Q_COOLDOWN = 5.5;
const Q_MAX_RANGE = 12.0;
const W_COOLDOWN = 9.25;
const E_COOLDOWN = 5.0;
const R_COOLDOWN = 10.0;

var primaryDesc = "HOLD to charge an explosion at your mouse position. RELEASE to fire. Deals 75% / 125% PHYSICAL DAMAGE depending on charge time. Enemies hit are also slowed.";
var primaryIcon = "res://assets/sprites/clean_abilities/clean_ultimate.png";
var secondaryDesc = "Spin around and push enemies away dealing 75% of your PHYSICAL DAMAGE. If used when JET is active, it will deal more DAMAGE instead of pushing enemies.";
var secondaryIcon = "res://assets/sprites/clean_abilities/clean_ultimate.png";
var tertiaryDesc = "Get on your JET which allows you to fly at high speeds and double your PHYSICAL DEFENSE. You can NOT use BASIC ATTACKS while flying. Press again to unmount.";
var tertiaryIcon = "res://assets/sprites/clean_abilities/clean_ultimate.png";
var ultiDesc = "";
var ultiIcon = "res://assets/sprites/clean_abilities/clean_ultimate.png";

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
var basicAttackMoment = BASIC_ATTACK_COOLDOWN * 0.72;
var basicTarget = null;
var basicDamageDealt = false;
var onAction = false;
var overrideBasic = false;
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
var isInvisible = false;
var enemyTeamVision = false;
var fogInstances = [];

var lives = 0;
var level = 1;
var xp = 0;
var tokens = 0;
var respawnTimer = 0;
var assistedInKill = [];

var projectileTarget: Vector3;
var projectileFired: bool = false;

var chargingPrimary: bool = false;
var chargeTime: float = 0.0;
var jetMode: bool = false;

var alreadyHitWind = [];
var alreadyHitSpinDamage = [];

const MAX_CHARGE_TIME: float = 4.0;
const CHARGE_SLOW_AMOUNT: float = 0.4;
const Q_FIRE_CIRCLE_INITIAL_SCALE := Vector3(1.5, 1.5, 1.5);
const Q_FIRE_CIRCLE_FULL_CHARGE_SCALE := Vector3(0.1, 0.5, 0.1);
const R_MAX_DURATION = 5.0;

var basicAnimList = ["basic_01", "basic_02"];
var basicAnimPos = 0;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $placeholder;
@onready var animPlayer = $AnimationPlayer;
@onready var fireMaterial01 = $q_charge_fire/fire1.get_surface_override_material(0) as ShaderMaterial;
@onready var fireMaterial02 = $q_charge_fire/fire2.get_surface_override_material(0) as ShaderMaterial;
@onready var fireCircleMaterial01 = $q_fire_circle.get_surface_override_material(0) as ShaderMaterial;
@onready var qFireCircle = $q_fire_circle;

func _ready() -> void:
	if (is_multiplayer_authority()):
		var gameScene = get_parent();
		if (gameScene.name == "Game"):
			gameScene.myCharacter = self;
			
	name = str(get_multiplayer_authority());
	PlayerFunc.setup(self);

func _physics_process(delta: float) -> void:
	if (is_multiplayer_authority()):
		if (Engine.get_physics_frames() % 60 == 0):
			rpc("syncPosition", global_position);
			rpc("syncTarget", target);
		
		PlayerFunc.updateState(self, delta);
		
		if (Input.is_action_just_pressed("rightClick")):
			PlayerFunc.onRightClick(self);
	
		if (Input.is_action_just_pressed("stop_movement") and not (onAction or stunned or dead)):
			PlayerFunc.stopCharacter(self);
		
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
			
			if (action and not usingUltimate):
				if not (onAction or stunned or dead):
					action.call();
				else:
					bufferedInput = action;
	
	if (basicAttacking and basicAttackTimer <= basicAttackMoment and not basicDamageDealt and target is Node3D):
		basicDamageDealt = true;
		rpc("showBasicAttack", target.global_position);
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (jetMode):
		speed *= 1.35;
		attackRange = 0;
		armor *= 1.5;
	
	if (chargingPrimary):
		if (stunned or dead):
			chargingPrimary = false;
			chargeTime = 0.0;
			rpc("syncCharging", false);
		else:
			chargeTime += delta;
			if (chargeTime > MAX_CHARGE_TIME):
				chargeTime = MAX_CHARGE_TIME;
				if not ($q_charge_fire.visible):
					$q_charge_fire.visible = true;
					# $q_full_fire_circle.visible = true;
					$sparkParticle.emitting = true;
					
					$q_charge_fire.scale = Vector3(0.25, 0.25, 0.25);
					$q_full_fire_circle.scale = Vector3(0.25, 0.25, 0.25);
					
					fireMaterial01.set_shader_parameter("Transparency", 0.0);
					fireMaterial02.set_shader_parameter("Transparency", 0.0);
				
					var tween = get_tree().create_tween().set_parallel();
					tween.tween_property(fireMaterial01, "shader_parameter/Transparency", 0.6, 0.4);
					tween.tween_property(fireMaterial02, "shader_parameter/Transparency", 0.6, 0.4);
					tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
					tween.tween_property($q_charge_fire, "scale", Vector3(0.6, 1.0, 0.6), 0.55);
					tween.tween_property($q_full_fire_circle, "scale", Vector3(0.7, 1.2, 0.7), 0.55);
					
			_update_q_fire_circle_scale();
			
			speedMultiplier = clamp(1.0 - CHARGE_SLOW_AMOUNT, 0.0, 1.0);
			attackRange = 0;
			
			if (is_multiplayer_authority() and Input.is_action_just_released("primary")):
				if (not mousePos.is_empty()):
					var direction = (mousePos.position - global_position).normalized();
					var distance = global_position.distance_to(mousePos.position);
					
					if (distance > Q_MAX_RANGE):
						projectileTarget = global_position + direction * Q_MAX_RANGE;
					else:
						projectileTarget = mousePos.position;
					
					rpc("syncRotation", mousePos.position);
					
					var chargeLevel = chargeTime / MAX_CHARGE_TIME;
					rpc("syncFireProjectile", chargeLevel, projectileTarget);
					
					chargingPrimary = false;
					qTimer = Q_COOLDOWN - cooldownReduction;
					qTimer = clamp(qTimer, 1.25, Q_COOLDOWN);
					
					rpc("syncCharging", false);
	
	if (usingSecondary):
		secondaryTimer -= delta;

		if (secondaryTimer > 0.25):
			moveTo = global_position;
		
		if (secondaryTimer > 0.25 and secondaryTimer <= 0.5):
			_doSpin();
		
		if (secondaryTimer <= 0):
			usingSecondary = false;
			onAction = false;

			$w_hitbox_wind/MeshInstance3D/Area3D.monitoring = false;
			$w_hitbox_damage/MeshInstance3D/Area3D.monitoring = false;
			
			$w_hitbox_wind/MeshInstance3D.visible = false;
			$w_hitbox_damage/MeshInstance3D.visible = false;

	if (usingTertiary):
		tertiaryTimer -= delta;
		moveTo = global_position;

		if (tertiaryTimer <= 0):
			usingTertiary = false;
			onAction = false;
			jetMode = not jetMode;
	
	if (usingUltimate):
		ultimateTimer -= delta;
		
		if (ultimateTimer <= 0):
			usingUltimate = false;
			
			# TODO: enable ulti
			_toggle_toon_shader(true);

	if (bufferedMoveTo and moveTo == null):
		moveTo = bufferedMoveTo;
		bufferedMoveTo = null;
	
	if (moveTo):
		PlayerFunc.moveChar(self, delta, moveTo);
	
	move_and_slide();
	
	# handle animations
	# ELI edit: animations are overriten a lot
	if (onAction or basicAttacking):
		return;
	
	if (animPlayer.current_animation == "r_ability"):
		return;
	
	if (usingSecondary):
		return;
		
	if (usingTertiary):
		return;
	
	if (animPlayer.current_animation == "q_ability") or (animPlayer.current_animation == "e_ability_fire"):
		return;
	
	if (animPlayer.is_playing() and (animPlayer.current_animation == "e_ability" or animPlayer.current_animation == "e_ability_end")):
		return;
	
	if (chargingPrimary):
		if (jetMode):
			if not (animPlayer.current_animation == "e_ability_charging"):
				animPlayer.play("e_ability_charging");
		else:
			if (velocity != Vector3.ZERO):
				if not (animPlayer.current_animation == "q_charging_run"):
					animPlayer.play("q_charging_run");
			else:
				if not (animPlayer.current_animation == "q_charging"):
					animPlayer.play("q_charging");
	
	elif (jetMode):
		if not (animPlayer.current_animation == "e_ability_loop"):
			animPlayer.play("e_ability_loop");
	
	elif (velocity != Vector3.ZERO):
		if not (animPlayer.current_animation == "run"):
			animPlayer.play("run");
	else:
		if not (animPlayer.current_animation == "idle"):
			animPlayer.play("idle");

func _hide_primary_charge_effects() -> void:
	$q_charge_fire.visible = false;
	$q_fire_circle.visible = false;
	$q_full_fire_circle.visible = false;
	$q_particles.emitting = false;

func _fireProjectile(_chargeLevel: float = 0.0, _projectileTarget: Vector3 = Vector3.ZERO):
	_hide_primary_charge_effects();

	if (projectileFired):
		return;
	
	if not (_projectileTarget):
		return;
	
	projectileFired = true;
	
	var damageMultiplier = lerp(0.65, 1.75, _chargeLevel);
	var finalDmg = dmg * damageMultiplier;
	
	var projectile = preload("res://assets/characters/eli/eli_projectile.tscn").instantiate();
	get_parent().add_child(projectile);
	
	projectile.global_position = global_position + Vector3(0, 2, 0);
	projectile.fire(self, team, finalDmg, _projectileTarget, _chargeLevel);

func _doSpin():
	var spinWindHitbox = $w_hitbox_wind;
	var spinDamageHitbox = $w_hitbox_damage;
	var windArea = spinWindHitbox.get_child(0).get_child(0);
	var damageArea = spinDamageHitbox.get_child(0).get_child(0);
	
	$w_particles.emitting = true;
	$explosionParts.emitting = true;

	windArea.monitoring = true;
	damageArea.monitoring = true;

func basicAttack():
	if (jetMode or chargingPrimary):
		return;

	if not (target):
		return;
	
	basicDamageDealt = false;
	basicAttacking = true;
	basicTarget = target;

func _onBasicTouched():
	var path = "res://assets/sounds/characters/eli/eli_basic_hit.ogg";
	PlayerFunc.dealDamage(self, basicTarget, dmg * 1.05, "fire_hit_03");
	rpc("syncSound", path);

@rpc("call_local")
func showBasicAttack(_targetPos):
	if not (_targetPos):
		return;
	
	var basicScene = preload("res://assets/characters/eli/eliBasic.tscn");
	var sound = preload("res://assets/sounds/characters/eli/eli_basic.ogg");
	PlayerFunc.playSound(self, sound);
	
	var basic = basicScene.instantiate();
	get_parent().add_child(basic);
	basic.global_position = global_position + Vector3(0, 2, 0);
	
	basic.setTarget(_targetPos);
	if (is_multiplayer_authority()):
		basic.reached_target.connect(_onBasicTouched);
	
@rpc("call_local", "any_peer", "reliable")
func playBasicAttack():
	if (jetMode or chargingPrimary):
		return;
	
	basicAttacking = true;
	basicAttackTimer = BASIC_ATTACK_COOLDOWN;
	animPlayer.play(basicAnimList[basicAnimPos]);
	basicAnimPos += 1;
	if (basicAnimPos >= basicAnimList.size()):
		basicAnimPos = 0;
	
	attackSpeedOffset = 0;

func _setup_primary():
	chargingPrimary = true;
	chargeTime = 0.0;
	qFireCircle.scale = Q_FIRE_CIRCLE_INITIAL_SCALE;
	projectileFired = false;
	basicAttacking = false;
	basicAttackTimer = 0;
	speedMultiplier = clamp(1.0 - CHARGE_SLOW_AMOUNT, 0.0, 1.0);
	rpc("syncSlow", CHARGE_SLOW_AMOUNT);
	rpc("syncCharging", true);

func _update_q_fire_circle_scale() -> void:
	if not ($q_fire_circle.visible):
		$q_fire_circle.visible = true;
		
		fireCircleMaterial01.set_shader_parameter("Transparency", 0.0);
		
		var fireTween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
		fireTween.tween_property(fireCircleMaterial01, "shader_parameter/Transparency", 0.0, 0.25);
		fireTween.tween_property(fireCircleMaterial01, "shader_parameter/Transparency", 1.0, 2.5);
		
	var chargeRatio = clamp(chargeTime / MAX_CHARGE_TIME, 0.0, 1.0);
	qFireCircle.scale = Q_FIRE_CIRCLE_INITIAL_SCALE.lerp(Q_FIRE_CIRCLE_FULL_CHARGE_SCALE, chargeRatio);

func _setup_secondary():
	rpc("secondary_ability");
	
func _setup_tertiary():
	rpc("tertiary_ability");
	
func _setup_ultimate():
	rpc("ultimate_ability");

func _toggle_toon_shader(enable: bool):
	if (enable):
		for child: MeshInstance3D in $eli_armature/Skeleton3D.get_children():
			if (child.name == "handL" or child.name == "handR"):
				continue;
			
			var toon_shader = preload("res://assets/characters/eli/eli_ulti_material.tres");
			child.set_surface_override_material(0, toon_shader);
	else:
		for child: MeshInstance3D in $eli_armature/Skeleton3D.get_children():
			child.set_surface_override_material(0, null);

@rpc("call_local", "reliable")
func secondary_ability():
	usingSecondary = true;
	onAction = true;
	secondaryTimer = 0.95;
	
	animPlayer.play("w_ability");
	
	wTimer = W_COOLDOWN - cooldownReduction;
	wTimer = clamp(wTimer, 2.5, W_COOLDOWN);

	alreadyHitSpinDamage = [];
	alreadyHitWind = [];

@rpc("call_local", "reliable")
func tertiary_ability():
	if (chargingPrimary):
		return;
	
	usingTertiary = true;
	onAction = true;
	if (jetMode):
		eTimer = E_COOLDOWN - cooldownReduction;
		eTimer = clamp(eTimer, 1.0, E_COOLDOWN);
	else:
		eTimer = 1.0;
	
	tertiaryTimer = 0.5;
	
	$fireParticle01.emitting = not jetMode;
	$fireParticle02.emitting = not jetMode;
	
	if not (jetMode):
		animPlayer.play("e_ability");
	else:
		animPlayer.play("e_ability_end");

@rpc("call_local", "reliable")
func ultimate_ability():
	if (chargingPrimary):
		return;
	
	usingTertiary = false;
	jetMode = false;
	
	usingUltimate = true;
	ultimateTimer = 0.95;
	rTimer = R_COOLDOWN - cooldownReduction;
	rTimer = clamp(rTimer, 10.0, R_COOLDOWN);
	
	$fireParticle01.emitting = false;
	$fireParticle02.emitting = false;
	
	animPlayer.play("r_ability");
	
@rpc("call_local", "any_peer", "reliable")
func syncTarget(_target):
	target = _target;

@rpc("call_local", "any_peer")
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
	PlayerFunc.rotateChar(self, newPos);

@rpc("any_peer")
func syncStun(_isStunned, _stunDuration):
	stunned = _isStunned;
	stunTimer = _stunDuration;

@rpc("any_peer")
func syncSlow(_slowAmount):
	speedMultiplier -= _slowAmount;
	speedMultiplier = clamp(speedMultiplier, 0.0, 1.0);

@rpc("call_local", "any_peer", "reliable")
func syncCharging(_isCharging: bool):
	chargingPrimary = _isCharging;
	
	if (_isCharging == false):
		_hide_primary_charge_effects();
		
		if (jetMode):
			animPlayer.play("e_ability_fire");
		else:
			animPlayer.play("q_ability");
	else:
		chargeTime = 0.0;
		qFireCircle.scale = Q_FIRE_CIRCLE_INITIAL_SCALE;
		projectileFired = false;
		$q_particles.emitting = true;

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
	
	PlayerFunc.rotateChar(self, newPos);
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
	effectInstance.rotation = rotation;

@rpc("any_peer")
func syncRespawn(newHp: float, newPos: Vector3):
	global_position = newPos;
	hp = newHp;
	dead = false;
	isInvisible = false;
	visible = true;
	PlayerFunc.updateHealthSize(self);

@rpc("call_local", "any_peer", "reliable")
func onItemPurchase(item: Dictionary):
	PlayerFunc.grantItemStats(self, item)

@rpc("call_local", "any_peer")
func syncSound(soundPath: String):
	var sound = load(soundPath);
	PlayerFunc.playSound(self, sound);

@rpc("call_local", "any_peer", "reliable")
func syncFireProjectile(_chargeLevel, _projectileTarget):
	_fireProjectile(_chargeLevel, _projectileTarget);

func onCollision():
	pass;

func _on_w_hitbox_hit(other: Node3D, isWind: bool) -> void:
	var isCharacter = "CHARACTER_NAME" in other
	if not (isCharacter):
		return;

	if (other.team == team):
		return;

	var wasHitByWind = alreadyHitWind.has(other);
	var wasHitByDamage = alreadyHitSpinDamage.has(other);
	var baseDamage = dmg * 0.65;
	var dmgMultiplier = 1.0;

	if (jetMode):
		dmgMultiplier = 1.5;
	else:
		if (isWind) and not (wasHitByWind):
			alreadyHitWind.append(other);
			var pushDirection = (other.global_position - global_position).normalized();
			PlayerFunc.moveTarget(other, 0.5, other.global_position + pushDirection * 8, 12);
		
	if not (wasHitByDamage):
		alreadyHitSpinDamage.append(other);
		PlayerFunc.dealDamage(self, other, baseDamage * dmgMultiplier, "fire_hit_01");
