extends CharacterBody3D

@export var maxHp = 190.0;
@export var hp = 190.0;
@export var baseArmor = 14.0;
@export var baseDmg = 15.5;
@export var baseAttackRange = 3.2;
@export var baseAttackSpeed = 3.5;
@export var baseSpeed = 6.25;
@export var cooldownReduction = 0;
var shield = 0;

@onready var slashHitbox = $slashHitbox;

const BASIC_ATTACK_COOLDOWN = 300;
const CHARACTER_NAME = "Rhay";
const Q_COOLDOWN = 8.5;
const W_COOLDOWN = 7.5;
const E_COOLDOWN = 13.0;
const R_COOLDOWN = 1.0;
const W_MAX_RANGE = 15.0;
const R_MAX_RANGE = 9.25;
const SECONDARY_WINDUP = 0.55;
const W_TELEPORT_WIDTH = 1.5;
const TRAIL_LIFETIME = 1.2;
const TRAIL_PARTICLES = 100;
const ELECTRIC_LIFETIME = 0.3;
const ELECTRIC_PARTICLES = 60;
const ELECTRIC_FLICKER_INTERVAL = 0.08;
const ELECTRIC_DURATION = 1.0;

var primaryDesc = "Empower your BASIC ATTACK and deal 120% of your PHYSICAL DAMAGE."
var primaryIcon = "res://assets/sprites/rhay_abilities/rhay_primary.png";
var secondaryDesc = "Dash to your mouse position, dealing 75% of your PHYSICAL DAMAGE to enemies hit on the way.";
var secondaryIcon = "res://assets/sprites/rhay_abilities/rhay_secondary.png";
var tertiaryDesc = "Slash that deals 95% of your PHYSICAL DAMAGE. Hitting any target will reset your PRIMARY ability.";
var tertiaryIcon = "res://assets/sprites/rhay_abilities/rhay_tertiary.png";
var ultiDesc = "Dash towards an enemy target.";
var ultiIcon = "res://assets/sprites/rhay_abilities/rhay_ultimate.png";

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
var secondaryStartPos = Vector3.ZERO;
var secondaryDestination = Vector3.ZERO;
var secondaryTeleported = false;
var electricTrailActive = false;
var electricTrailTimer = 0;
var trailFlickerTimer = 0;
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

var basicAnimList = ["basic_01", "basic_02"];
var basicAnimPos = 0;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $Armature
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
			
			if (action):
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
	
	if (primaryTimer > 0):
		primaryTimer -= delta;
	else:
		dmgOffset = 0;
		overrideBasic = false;
	
	if (usingSecondary == true):
		secondaryTimer -= delta;
		moveTo = global_position;
		
		if (target):
			cancelSecondary();
		elif (secondaryTimer <= 0 and not secondaryTeleported):
			_perform_teleport();
	if (electricTrailActive):
		electricTrailTimer -= delta;
		trailFlickerTimer -= delta;
		
		if (trailFlickerTimer <= 0):
			trailFlickerTimer = ELECTRIC_FLICKER_INTERVAL;
			_spawn_electric_trail();
		
		if (electricTrailTimer <= 0):
			electricTrailActive = false;
	if (usingUlti):
		ultiTimer -= delta;
		
		if (moveTo == null or target or ultiTimer <= 0):
			cancelUlti();
		else:
			ultimate_ability(moveTo, global_position);
		
	if (tertiaryTimer > 0):
		tertiaryTimer -= delta;
		# moveTo = global_position;
		
	else:
		if (usingTertiary):
			usingTertiary = false;
			onAction = false;
	
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
	qTimer = clamp(qTimer, 2.0, Q_COOLDOWN);
	
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
	secondaryTimer = SECONDARY_WINDUP;
	secondaryTeleported = false;
	usingUlti = false;
	onAction = true;
	target = null;
	
	secondaryStartPos = _global_pos;
	if (distance > W_MAX_RANGE):
		secondaryDestination = _global_pos + direction * W_MAX_RANGE;
	else:
		secondaryDestination = _moveTo;
	secondaryDestination.y = _global_pos.y;
	
	_spawn_teleport_trail();
	
	moveTo = _global_pos;
	velocity = Vector3.ZERO;
	wTimer = W_COOLDOWN - cooldownReduction;
	speedOffset = 0;
	
	$w_dash_particles/sparkParticle.emitting = true;
	$w_dash_particles/meshParticles.emitting = true;
	
	var sound = preload("res://assets/sounds/characters/rhay/rhay_jump.ogg");
	PlayerFunc.playSound(self, sound);
			
	animPlayer.play("w_ability");
	syncRotation(secondaryDestination);

func _perform_teleport():
	secondaryTeleported = true;
	
	global_position = secondaryDestination;
	velocity = Vector3.ZERO;
	moveTo = null;
	
	if (is_multiplayer_authority()):
		rpc("syncPosition", global_position);
	
	$w_dash_particles/sparkParticle.emitting = true;
	$w_dash_particles/meshParticles.emitting = true;
	
	var sound = preload("res://assets/sounds/characters/rhay/rhay_big_jump.ogg");
	var electricSound = preload("res://assets/sounds/characters/rhay/rhay_electricity.ogg");
	PlayerFunc.playSound(self, sound);
	PlayerFunc.playSound(self, electricSound);
	
	if (is_multiplayer_authority()):
		_deal_teleport_damage();
	
	_start_electric_trail();
	usingSecondary = false;
	onAction = false;
	speedOffset = 0;

func _spawn_teleport_trail():
	var trail = $w_trail;
	var start = secondaryStartPos;
	var end = secondaryDestination;
	var mid = (start + end) * 0.5;
	
	var count = TRAIL_PARTICLES;
	var points = PackedVector3Array();
	points.resize(count);
	for i in count:
		var t = float(i) / float(count - 1);
		points[i] = start.lerp(end, t) - mid;
	
	var image = Image.create(count, 1, false, Image.FORMAT_RGBAF);
	for i in count:
		image.set_pixel(i, 0, Color(points[i].x, points[i].y, points[i].z, 1.0));
	
	var mat = trail.process_material as ParticleProcessMaterial;
	mat.emission_point_texture = ImageTexture.create_from_image(image);
	mat.emission_point_count = count;
	trail.lifetime = TRAIL_LIFETIME;
	trail.amount = count;
	trail.global_position = mid;
	trail.emitting = false;
	trail.restart();
	trail.emitting = true;

func _start_electric_trail():
	electricTrailActive = true;
	electricTrailTimer = ELECTRIC_DURATION;
	trailFlickerTimer = 0;
	_spawn_electric_trail();

func _spawn_electric_trail():
	var trail = $w_trail;
	var start = secondaryStartPos;
	var end = secondaryDestination;
	var mid = (start + end) * 0.5;
	var dir = end - start;
	if (dir.length() < 0.0001):
		return;
	dir = dir.normalized();
	
	var right = Vector3.UP.cross(dir);
	if (right.length() < 0.0001):
		right = Vector3.RIGHT;
	right = right.normalized();
	var up = dir.cross(right).normalized();
	
	var count = ELECTRIC_PARTICLES;
	var points = PackedVector3Array();
	points.resize(count);
	for i in count:
		var t = float(i) / float(count - 1);
		var envelope = sin(PI * t);
		var jitterX = randf_range(-0.8, 0.8) * envelope;
		var jitterY = randf_range(-0.3, 0.3) * envelope;
		points[i] = start.lerp(end, t) + right * jitterX + up * jitterY - mid;
	
	var image = Image.create(count, 1, false, Image.FORMAT_RGBAF);
	for i in count:
		image.set_pixel(i, 0, Color(points[i].x, points[i].y, points[i].z, 1.0));
	
	var mat = trail.process_material as ParticleProcessMaterial;
	mat.emission_point_texture = ImageTexture.create_from_image(image);
	mat.emission_point_count = count;
	trail.lifetime = ELECTRIC_LIFETIME;
	trail.amount = count;
	trail.global_position = mid;
	trail.emitting = false;
	trail.restart();
	trail.emitting = true;

func _deal_teleport_damage():
	var gameScene = get_parent();
	if not (gameScene and "addedCharacters" in gameScene):
		return;
	
	var start = secondaryStartPos;
	var end = secondaryDestination;
	var segment = end - start;
	var segmentLength = segment.length();
	if (segmentLength <= 0.0001):
		return;
	
	var direction = segment / segmentLength;
	var teleportDmg = dmg * 1.25;
	
	for enemy in gameScene.addedCharacters:
		if not (is_instance_valid(enemy)) or enemy == self:
			continue;
		
		var isCharacter = "CHARACTER_NAME" in enemy;
		if not (isCharacter):
			continue;
		
		if (enemy.team == team):
			continue;
		
		var toEnemy = enemy.global_position - start;
		var t = clamp(toEnemy.dot(direction), 0.0, segmentLength);
		var closestPoint = start + direction * t;
		var distanceToLine = enemy.global_position.distance_to(closestPoint);
		
		if (distanceToLine <= W_TELEPORT_WIDTH):
			PlayerFunc.dealDamage(self, enemy, teleportDmg, "hit_01");
			PlayerFunc.slowTarget(enemy, 0.75);
	
func _setup_tertiary():
	if (mousePos.is_empty()):
		return;
	
	rpc("tertiary_ability", mousePos.position);

@rpc("call_local", "reliable")
func tertiary_ability(_mousePos):
	dmgOffset = 0;
	eTimer = E_COOLDOWN - cooldownReduction;
	eTimer = clamp(eTimer, 2.0, E_COOLDOWN);
	tertiaryTimer = 0.5;
	target = null;
	usingTertiary = true;
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
			ultiTimer = 0.5;
		
		rTimer = R_COOLDOWN;
		speedOffset = 17;
		onAction = true;
		
		$w_dash_particles/sparkParticle.emitting = true;
		$w_dash_particles/meshParticles.emitting = true;
		$r_trail.emitting = true;
		animPlayer.play("q_ability_001");
	else:
		ultiTimer = 0.5;

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
	
	if not (usingTertiary):
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
			PlayerFunc.dealDamage(self, other, (dmg * 0.95 + 0.5));
