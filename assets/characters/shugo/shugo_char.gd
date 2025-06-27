extends CharacterBody3D

@export var maxHp = 210.0;
@export var hp = 210.0;
@export var baseArmor = 24;
@export var baseDmg = 29.5;
@export var baseAttackRange = 3.0;
@export var baseAttackSpeed = 4.0;
@export var baseSpeed = 5.0;
@export var cooldownReduction = 0;
var shield = 0;

const BASIC_ATTACK_COOLDOWN = 300;
const MULTIPLE_FORM = true;
const CHARACTER_NAME = "Shugo";
const Q_COOLDOWN = 8.5;
const W_COOLDOWN = 11.0;
const ALT_W_COOLDOWN = 10.0;
const E_COOLDOWN = 7.0;
const ALT_E_COOLDOWN = 13.0;
const R_COOLDOWN = 6.0;
const Q_MAX_RANGE = 5.0;
const ALT_Q_MAX_RANGE = 5.0;

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
var primaryTimer = 0;
var primaryTarget = null;
var primaryCompleted = false;
var secondaryTimer = 0;
var tertiaryTimer = 0;
var usingUlti = false;
var bufferedTarget = null;
var bufferedInput = null;
var playingPrimarySound = false;

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

var swappingTimer = 0;
var swappingForm = false;
var swappedFlag = false;
var humanForm = true;

var alreadyHit = [];

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $Armature;
@onready var animPlayer = $RealAnimPlayerxd;
@onready var kirbyAnimPlayer = $shugo_kirby/AnimationPlayer;
@onready var dashParticles = $dashParticles;
@onready var qHitbox: Area3D = $q_hitbox/MeshInstance3D/Area3D;
@onready var shugoKirby = $shugo_kirby;

func _ready() -> void:
	humanForm = true;
	shugoKirby.visible = false;
	
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
			basicDamageDealt = true;
			PlayerFunc.dealDamage(self, target, (dmg * 0.5) + basicDmgOffset, "hit_01");
			basicDmgOffset = 0;
			basicAttackMoment = defaultAttackMoment;
		
		if (usingPrimary == true and not humanForm):
			if (moveTo == null or target):
				var distance = global_position.distance_to(primaryTarget.global_position);
				if (distance < 4):
					PlayerFunc.dealDamage(self, primaryTarget, dmg * 0.65);
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (humanForm):
		baseArmor = 24;
		baseAttackRange = 3.0;
		baseAttackSpeed = 4.0;
		baseSpeed = 5.0;
	else:
		baseArmor = 14;
		baseAttackRange = 2.25;
		baseAttackSpeed = 5.5;
		baseSpeed = 6.0;
	
	if (usingPrimary == true):
		primaryTimer -= delta;
		
		if (humanForm):
			dashParticles.emitting = true;
			qHitbox.monitoring = true;
			
			if ((moveTo == null or target) or primaryTimer <= 0):
				usingPrimary = false;
				dashParticles.emitting = false;
				qHitbox.monitoring = false;
				cancelDash();
		else:
			if (moveTo == null or target or primaryTimer <= 0):
				cancelPrimary();
			else:
				primary_ability(moveTo, global_position, primaryTarget);
		
	if (usingSecondary):
		secondaryTimer -= delta;
		moveTo = global_position;
		
		if (secondaryTimer <= 0):
			usingSecondary = false;
			onAction = false;
	if (usingTertiary):
		tertiaryTimer -= delta;
		
		if (humanForm):
			moveTo = global_position;
			
			if (tertiaryTimer <= 0.65 and humanForm):
				$e_hitbox/MeshInstance3D/Area3D.monitoring = true;
				var eSlash = $e_slash;
				var anim: AnimationPlayer = eSlash.get_node("AnimationPlayer");
				anim.play("slash");
			
			if (tertiaryTimer <= 0):
				$e_hitbox/MeshInstance3D/Area3D.monitoring = false;
				usingTertiary = false;
				onAction = false;
		else:
			if (tertiaryTimer > 0):
				_manage_alt_e();
				if ($e_spin.visible == false):
					$e_spin.visible = true;
					$e_spin_hitbox/MeshInstance3D/Area3D.monitoring = true;
					$e_spin/AnimationPlayer.play("attack");
					
					$e_spin2.visible = true;
					$e_spin2/AnimationPlayer.play("attack");
			else:
				$e_spin.visible = false;
				$e_spin2.visible = false;
				$e_spin_hitbox/MeshInstance3D/Area3D.monitoring = false;
				$e_hitbox/MeshInstance3D/Area3D.monitoring = false;
				usingTertiary = false;
				onAction = false;
			
	if (swappingTimer > 0):
		swappingTimer -= delta;
		
		if (swappingTimer > 0.5 and swappingTimer <= 0.6):
			$swapParticles.emitting = true;
		elif (swappingTimer <= 0.5 and swappedFlag == false):
			swappedFlag = true;
			swapForm();
	else:
		if (swappingForm):
			swappingForm = false;
			swappedFlag = false;
	
	if (bufferedMoveTo and moveTo == null):
		moveTo = bufferedMoveTo;
		bufferedMoveTo = null;
	
	if (moveTo):
		PlayerFunc.moveChar(self, delta, moveTo);
	
	move_and_slide();
	
	# handle animations
	if (onAction or basicAttacking):
		return;
	
	if not (swappingForm or usingTertiary):
		if (velocity != Vector3.ZERO):
			if (humanForm):
				if not (animPlayer.current_animation == "run"):
					animPlayer.play("run");
			else:
				if not (kirbyAnimPlayer.current_animation == "run"):
					kirbyAnimPlayer.play("run");
		else:
			if (humanForm):
				if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
					animPlayer.play("idle");
			else:
				if not (kirbyAnimPlayer.is_playing() and kirbyAnimPlayer.current_animation != "run"):
					kirbyAnimPlayer.play("idle");

func swapForm():
	dashParticles.emitting = false;
	qHitbox.monitoring = false;
	cancelDash();
	
	usingPrimary = false;
	primaryTimer = 0;
	usingSecondary = false;
	secondaryTimer = 0;
	
	humanForm = not humanForm;
	charModel.visible = not charModel.visible;
	shugoKirby.visible = not shugoKirby.visible;

func _setHitbox(hitbox: Node3D, enable: bool = true):
	hitbox.monitoring = enable;
	
func _manage_alt_e():
	var decimalTimer = int(round(tertiaryTimer * 100));
	
	if (decimalTimer % 4 == 0):
		var eHitbox = $e_spin_hitbox/MeshInstance3D/Area3D;
		var isActive = eHitbox.monitoring;
		if (isActive == false):
			alreadyHit = [];
		
		_setHitbox(eHitbox, not isActive);

func basicAttack():
	basicDamageDealt = false;
	basicAttacking = true;

@rpc("call_local", "any_peer", "reliable")
func playBasicAttack():
	if (overrideBasic == false):
		basicAttacking = true;
		basicAttackTimer = BASIC_ATTACK_COOLDOWN;
		animPlayer.play(basicAnimList[basicAnimPos]);
		kirbyAnimPlayer.play(basicAnimList[basicAnimPos]);
		basicAnimPos += 1;
		if (basicAnimPos >= basicAnimList.size()):
			basicAnimPos = 0;
	else:
		overrideBasic = false;
		basicAttacking = true;
		basicAttackTimer = BASIC_ATTACK_COOLDOWN;
		kirbyAnimPlayer.play("w_ability");

func _setup_primary():
	if (humanForm):
		if (mousePos.is_empty()):
			return;
		
		rpc("primary_ability", mousePos.position, global_position);
	else:
		if not (hovering):
			return;
		
		primaryTarget = hovering;
		moveTo = primaryTarget.global_position;
		moveTo.y = global_position.y;
		
		rpc("primary_ability", moveTo, global_position, hovering);

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

func _spawn_w_trail(_mousePos):
	var direction = (_mousePos - global_position);
	direction.y = 0;
	direction = direction.normalized();
	var targetRotation = atan2(direction.x, direction.z);
	var curRotation = rotation.y;
	var shortestAngle = lerp_angle(curRotation, targetRotation, 1.0);
	
	var attack = preload("res://assets/characters/shugo/shugo_w_ability.tscn").instantiate();
	get_parent().add_child(attack);
	
	attack.global_position = global_position + Vector3(0, 0, 0);
	attack.rotation = Vector3(rotation.x, shortestAngle, rotation.z);
	attack.setup(self, team, dmg);
	
	var attackAnim: AnimationPlayer = attack.get_node("AnimationPlayer");
	attackAnim.play("attack");

func _spawn_e_geysers(_mousePos):
	var direction = (_mousePos - global_position);
	direction.y = 0;
	direction = direction.normalized();
	var targetRotation = atan2(direction.x, direction.z);
	var curRotation = rotation.y;
	var shortestAngle = lerp_angle(curRotation, targetRotation, 1.0);
	
	var attack = preload("res://assets/characters/shugo/shugo_k_e_ability.tscn").instantiate();
	get_parent().add_child(attack);
	
	attack.global_position = global_position + Vector3(0, 0, 0);
	attack.rotation = Vector3(rotation.x, shortestAngle, rotation.z);
	attack.setup(self, team, dmg);
	
	var attackAnim: AnimationPlayer = attack.get_node("AnimationPlayer");
	attackAnim.play("attack");

@rpc("call_local", "reliable")
func primary_ability(_moveTo, _global_pos, _primaryTarget = null):
	if (humanForm):
		var direction = (_moveTo - _global_pos).normalized();
		var _distance = _global_pos.distance_to(_moveTo);
		usingPrimary = true;
		
		if (target):
			bufferedTarget = target;
			target = null;
			rpc("syncBufferedInputs", null, bufferedTarget);
		
		moveTo = _global_pos + direction * Q_MAX_RANGE;
		
		moveTo.y = _global_pos.y;
		qTimer = Q_COOLDOWN - cooldownReduction;
		primaryTimer = 0.5;
		speedOffset = 5;
		onAction = true;
		animPlayer.play("q_ability");
		syncRotation(moveTo);
	else:
		if (_moveTo == null):
			return;
		
		moveTo = _moveTo;
		moveTo.y = _global_pos.y;
		usingPrimary = true;
		target = null;
		
		var distance = _global_pos.distance_to(_moveTo);
		if (distance < ALT_Q_MAX_RANGE):
			if not (playingPrimarySound):
				var sound = preload("res://assets/sounds/characters/rhay/rhay_big_jump.ogg");
				PlayerFunc.playSound(self, sound);
				
				playingPrimarySound = true;
				primaryTimer = 0.5;
			
			qTimer = Q_COOLDOWN - cooldownReduction;
			speedOffset = 10;
			onAction = true;
			
			kirbyAnimPlayer.play("q_ability");
		else:
			primaryTimer = 0.5;

@rpc("call_local", "reliable")
func secondary_ability(_mousePos):
	if (humanForm):
		wTimer = W_COOLDOWN - cooldownReduction;
		secondaryTimer = 0.9;
		usingSecondary = true;
		onAction = true;
		
		_spawn_w_trail(_mousePos);
		
		animPlayer.play("w_ability");
		simulateMove(null, global_position);
		rpc("syncRotation", _mousePos);
	else:
		wTimer = ALT_W_COOLDOWN - cooldownReduction;
		overrideBasic = true;
		basicAttacking = false;
		basicAttackMoment = BASIC_ATTACK_COOLDOWN * 0.5;
		basicDmgOffset = baseDmg * 0.8;
		basicAttackTimer = 0;

@rpc("call_local", "reliable")
func tertiary_ability(_mousePos):
	eTimer = E_COOLDOWN - cooldownReduction;
	if (humanForm):
		target = null;
		usingTertiary = true;
		tertiaryTimer = 1.0;
		onAction = true;
		animPlayer.play("e_ability");
		
		# _spawn_e_geysers(_mousePos);
		
		simulateMove(null, global_position);
		rpc("syncRotation", _mousePos);
	else:
		usingTertiary = true;
		tertiaryTimer = 1.0;
		kirbyAnimPlayer.play("e_ability");

@rpc("call_local", "reliable")
func ultimate_ability():
	rTimer = R_COOLDOWN;
	qTimer -= 3;
	wTimer -= 3;
	eTimer -= 2;
	swappingTimer = 0.85;
	basicDmgOffset = 0;
	swappingForm = true;
	
	$e_spin.visible = false;
	$e_spin2.visible = false;
	$e_spin_hitbox/MeshInstance3D/Area3D.monitoring = false;
	$e_hitbox/MeshInstance3D/Area3D.monitoring = false;
	usingTertiary = false;
	
	animPlayer.play("swap_form");
	kirbyAnimPlayer.play("swap_form");

@rpc("call_local")
func cancelDash():
	onAction = false;
	speedOffset = 0;

@rpc("call_local")
func cancelPrimary():
	moveTo = global_position;
	usingPrimary = false;
	onAction = false;
	primaryTarget = null;
	playingPrimarySound = false;
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
	print("Shugo: ", newText);

@rpc("call_local", "any_peer", "reliable")
func onItemPurchase(item: Dictionary):
	PlayerFunc.grantItemStats(self, item)

func onCollision():
	pass;

func _onSlashTouched(other) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, dmg);

func _on_q_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg + 15.0;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg * 0.3);
			PlayerFunc.moveTarget(other, 1.0, global_position + Vector3(0, 0, -1), 8);

func _on_e_touched(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg + 10.5;
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, totalDmg * 0.45);

func _on_e_spin_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var wasHitBefore = alreadyHit.has(other);
		if not (wasHitBefore):
			alreadyHit.insert(len(alreadyHit), other);
			var totalDmg = dmg * 0.21;
			if (other.team != team):
				PlayerFunc.dealDamage(self, other, totalDmg);
