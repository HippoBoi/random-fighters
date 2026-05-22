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
const Q_COOLDOWN = 7.5;
const W_COOLDOWN = 13.0;
const E_COOLDOWN = 6.0;
const R_COOLDOWN = 10.0; # 60.0
const Q_MAX_RANGE = 12.0;

var primaryDesc = "Jump forward dealing 85% of your PHYSICAL DAMAGE to nearby enemies."
var primaryIcon = "res://assets/sprites/rio_abilities/rio_primary.png";
var secondaryDesc = "Cast for 1.5 seconds and deal 100% of your PHYSICAL DAMAGE in a circle around you.";
var secondaryIcon = "res://assets/sprites/rio_abilities/rio_secondary.png";
var tertiaryDesc = "Throw a spider web in the direction of your mouse. You'll dash into the direction the first enemy hit stunning them for 0.75 seconds.";
var tertiaryIcon = "res://assets/sprites/rio_abilities/rio_tertiary.png";
var ultiDesc = "Make yourself invisible for 5 seconds and gain movement speed. Using any ability will cancel this ability.";
var ultiIcon = "res://assets/sprites/rio_abilities/rio_ultimate.png";

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

var shaderTimer = 0;
var shaderAcc = 0;

var web: MeshInstance3D = null;
var isWebSpawned = false;
var grabbedPlayerPos: Vector3;

var movingToGrabbed = false;
var movingToGrabbedTimer = 0;

var usingInvisShaders = false;
var isInvisible = false;
var invisTimer = 0;
var invisDuration = 5.0;

var alreadyHitByW = {};

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $rio_armature
@onready var animPlayer = $AnimationPlayer
@onready var slashForward = $q_slash_forward/Cube;
@onready var slashBackwards = $q_slash_backwards/Cube;
@onready var wHitboxes = $wHitboxes;

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
		if (PlayerFunc.chatOpen):
			return;
		
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
				if not (onAction or stunned or dead or movingToGrabbed):
					action.call();
				else:
					bufferedInput = action;
		
		if (basicAttacking and basicAttackTimer <= basicAttackMoment and not basicDamageDealt and target):
			var path = "res://assets/sounds/characters/rhay/rhay_basic_attack.ogg";
			basicDamageDealt = true;
			
			PlayerFunc.dealDamage(self, target, dmg, "hit_01");
			rpc("syncSound", path);
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (usingPrimary):
		speed += 11.0;
		
	if (usingSecondary):
		speed -= 2.0;
		speed = max(0, speed);
		
		updateCirclePositions();
		
	if (movingToGrabbed and not usingPrimary):
		speed += 13.0;
	
	if (isInvisible):
		speed += 2.75;
	
	if (primaryTimer > 0):
		primaryTimer -= delta;
		moveTo = global_position;
		
		shaderTimer -= (delta * 16 - shaderAcc);
		shaderAcc += delta * 0.25;
		
		_updateSlashAnimation();
		
		if (primaryTimer < 0.7):
			$qCircleParticles.emitting = true;
		
		if (primaryTimer < 0.5):
			if (movingToGrabbed):
				cancelGrab();
				
			moveTo = primaryMoveToTarget;
			
			slashForward.visible = true;
			slashBackwards.visible = true;
			$qParticles.emitting = true;
			$q_hitbox/MeshInstance3D/Area3D.monitoring = true;
			
			if (moveTo == null or target or primaryTimer <= 0):
				cancelDash();
	else:
		shaderTimer = 20;
		shaderAcc = 0;
		$qParticles.emitting = false;
		$q_hitbox/MeshInstance3D/Area3D.monitoring = false;
		usingPrimary = false;
		slashForward.visible = false;
		slashBackwards.visible = false;
	
	if (primaryAnimationTimer):
		primaryAnimationTimer -= delta;
	
	if (secondaryTimer > 0):
		secondaryTimer -= delta;
		
		if not (playedSecondaryOutline):
			playedSecondaryOutline = true;
			$RiotOuterCircle/animPlayer.play("outline");
		
		if (secondaryTimer <= 0.7 and not playedSecondaryCircle):
			playedSecondaryCircle = true;
			$RioWCircle/animPlayer.play("slash")
		
		if (secondaryTimer > 0.1 and secondaryTimer <= 0.5):
			for hitboxMesh in wHitboxes.get_children():
				var area3D: Area3D = hitboxMesh.get_child(0);
				area3D.monitoring = true;
		
		if (secondaryTimer <= 0.1):
			for hitboxMesh in wHitboxes.get_children():
				var area3D: Area3D = hitboxMesh.get_child(0);
				area3D.monitoring = false;
	else:
		if (usingSecondary):
			usingSecondary = false;
			onAction = false;
			playedSecondaryCircle = false;
			playedSecondaryOutline = false;
		
	if (tertiaryTimer > 0):
		tertiaryTimer -= delta;
		
		if not (isWebSpawned):
			var webScene: PackedScene = load("res://assets/characters/rio/rio_e_web.tscn");
			web = webScene.instantiate();
			web.setup(self, team);
			web.grabbed.connect(onWebGrabbed);
			
			add_child(web);
			web.global_position = $eWebPosition.global_position;
			web.scale.z = 1.0;
			
			isWebSpawned = true;
		
		if not (web):
			return;
		
		if (tertiaryTimer < 0.4 and tertiaryTimer > 0.3):
			web.visible = true;
			web.scale.z += delta + 6;
			web.global_position += web.global_transform.basis.z * (delta + 0.05);
			
		elif (tertiaryTimer <= 0.3 and tertiaryTimer > 0.1):
			web.scale.y -= delta * 0.5;
			web.scale.z -= delta * 0.5;
			web.scale.y = max(0.01, web.scale.y);
			web.scale.z = max(0.01, web.scale.z);
		elif (tertiaryTimer <= 0.1):
			web.global_position += web.global_transform.basis.z * (delta + 0.025);
			web.scale.z += delta - 2.5;
			web.scale.z = max(0.01, web.scale.z);
		
		moveTo = global_position;
	else:
		if (usingTertiary and movingToGrabbed == false):
			cancelGrab();
	
	if (ultiTimer > 0):
		ultiTimer -= delta;
		
		if (ultiTimer < 0.2):
			moveTo = global_position;
			isInvisible = true;
			
			if not (usingInvisShaders):
				_toggle_invis_shader(true);
	else:
		if (usingUlti):
			usingUlti = false;
			onAction = false;
	
	if not (isInvisible):
		if (usingInvisShaders):
			$rParticles2.emitting = true;
			_toggle_invis_shader(false);
	
	if (invisTimer >= invisDuration):
		isInvisible = false;
	else:
		invisTimer += delta;
	
	if (movingToGrabbed):
		movingToGrabbedTimer -= delta;
		moveTo = global_position;
		
		if (movingToGrabbedTimer < 0.85):
			var distanceToGrabbed = global_position.distance_to(grabbedPlayerPos);
			moveTo = grabbedPlayerPos;
			
			if (web):
				web.queue_free();
				web = null;
				isWebSpawned = false;
			
			if (moveTo == null or movingToGrabbedTimer <= 0 or distanceToGrabbed < 1):
				movingToGrabbed = false;
				onAction = false;
				usingTertiary = false;
	
	if (bufferedMoveTo and moveTo == null):
		moveTo = bufferedMoveTo;
		bufferedMoveTo = null;
	
	if (moveTo):
		PlayerFunc.moveChar(self, delta, moveTo);
	
	move_and_slide();
	
	# handle animations
	if (onAction or basicAttacking):
		return;
	
	if not (usingSecondary) and not (primaryAnimationTimer > 0) and not (movingToGrabbed):
		if (velocity != Vector3.ZERO):
			if not (animPlayer.current_animation == "run"):
				animPlayer.play("run");
		else:
			if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
				animPlayer.play("idle");

func _updateSlashAnimation():
	var materialForward: ShaderMaterial = slashForward.get_surface_override_material(0);
	var materialBackwards: ShaderMaterial = slashBackwards.get_surface_override_material(0);
	materialForward.set_shader_parameter("gradient_2_slider", shaderTimer);
	materialBackwards.set_shader_parameter("gradient_2_slider", (shaderTimer - 40) * 0.5);

func _toggle_invis_shader(enable: bool):
	if (enable):
		for child: MeshInstance3D in $rio_armature/Skeleton3D.get_children():
			var shader = preload("res://assets/characters/rio/invis_material.tres");
			child.set_surface_override_material(0, shader);
	else:
		for child: MeshInstance3D in $rio_armature/Skeleton3D.get_children():
			child.set_surface_override_material(0, null);
	
	usingInvisShaders = enable;

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

func onWebGrabbed(_otherPos: Vector3):
	if (movingToGrabbed):
		return;
	
	$qCircleParticles.emitting = true;
	if (web):
		web.get_node("Area3D").monitoring = false;
		web.top_level = true;
	
	movingToGrabbed = true;
	usingTertiary = false;
	onAction = false;
	grabbedPlayerPos = _otherPos;
	movingToGrabbedTimer = 1.0;
	tertiaryTimer = 0;

func _cancel_invisibility():
	if not (isInvisible):
		return;
	
	$rParticles2.emitting = true;
	
	isInvisible = false;
	ultiTimer = 0;
	invisTimer = invisDuration;
	if (usingInvisShaders):
		_toggle_invis_shader(false);

func basicAttack():
	_cancel_invisibility();
	basicDamageDealt = false;
	basicAttacking = true;

@rpc("call_local", "any_peer", "reliable")
func playBasicAttack():
	if (usingSecondary):
		return;
	
	_cancel_invisibility();
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
func primary_ability(_moveTo, _globalPos):
	var direction = (_moveTo - _globalPos).normalized();
	primaryTimer = 0.75;
	primaryAnimationTimer = primaryTimer + 0.4;
	usingPrimary = true;
	onAction = true;
	target = null;
	
	primaryMoveToTarget = _globalPos + direction * Q_MAX_RANGE;
	primaryMoveToTarget.y = _globalPos.y;
	moveTo = primaryMoveToTarget;
	
	qTimer = Q_COOLDOWN - cooldownReduction;
	
	_cancel_invisibility();
	
	animPlayer.play("q_ability");
	syncRotation(moveTo);

func _setup_secondary():
	rpc("secondary_ability");

@rpc("call_local", "reliable")
func secondary_ability():
	wTimer = W_COOLDOWN;
	secondaryTimer = 1.8;
	usingSecondary = true;
	
	_cancel_invisibility();
	
	alreadyHitByW = {};
	animPlayer.play("w_action");
	
func _setup_tertiary():
	if not (mousePos):
		return;
		
	rpc("tertiary_ability", mousePos.position, global_position);

@rpc("call_local", "reliable")
func tertiary_ability(_mousePos, _globalPos):
	isInvisible = false;
	usingTertiary = true;
	onAction = true;
	tertiaryTimer = 0.75;
	animPlayer.play("e_ability");
	eTimer = E_COOLDOWN;
	
	syncRotation(_mousePos);

func _setup_ultimate():
	if not (mousePos):
		return;
	
	rpc("ultimate_ability", mousePos.position);

@rpc("call_local", "reliable")
func ultimate_ability(_mousePos: Vector3):
	usingUlti = true;
	onAction = true;
	ultiTimer = 0.5;
	invisTimer = 0;
	rTimer = R_COOLDOWN;

	var particles = preload("res://assets/characters/rio/r_particles.tscn").instantiate();
	get_parent().add_child(particles);
	
	particles.global_position = global_position;
	particles.emitting = true;
	
	var sound = preload("res://assets/sounds/characters/clean/clean_empower.ogg");
	PlayerFunc.playSound(self, sound);
	
	animPlayer.play("e_ability");
	simulateMove(null, global_position);
	rpc("syncRotation", _mousePos);

@rpc("call_local")
func cancelDash():
	usingPrimary = false;
	onAction = false;
	speedOffset = 0;

@rpc("call_local", "reliable")
func cancelGrab():
	if (web):
		web.queue_free();
		web = null;
	
	isWebSpawned = false;
	movingToGrabbed = false;
	usingTertiary = false;
	onAction = false;
	movingToGrabbedTimer = 0;
	grabbedPlayerPos = Vector3.ZERO;

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
	isInvisible = false;
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

func _on_q_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = (dmg + 10) * 0.85;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg);

func _on_w_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = (dmg + 10) * 1.05;
		
		if (other.team != team and not alreadyHitByW.has(other)):
			PlayerFunc.dealDamage(self, other, totalDmg);
			PlayerFunc.slowTarget(other, 0.35, "slow_effect_02");
			
			alreadyHitByW[other] = true;
