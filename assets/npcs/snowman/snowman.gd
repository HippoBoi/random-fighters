extends CharacterBody3D

@export var team = -1;
@export var maxHp = 450.0;
@export var hp = 450.0;
@export var baseArmor = 7.0;
@export var baseDmg = 17.0;
@export var baseAttackRange = 4.0;
@export var baseAttackSpeed = 4.0;
@export var baseSpeed = 4.0;
@export var cooldownReduction = 0;
var shield = 0;

const BASE_ATTACK_TIMER = 3.0;
const CHARACTER_NAME = "SERVER";

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
var attackTimer = 10.0;
var rayOrigin = Vector3();
var rayEnd = Vector3();
var moveTo = Vector3();
var forceMoveTo = Vector3();
var forceMoveSpeed = 5.0;
var bufferedMoveTo = Vector3();
var lastPos = Vector3();
var target = null;
var bufferedInput = null;
var bufferedTarget = null;
var showingUIs = false;
var basicAttacking = false;
var basicDamageDealt = false;
var basicAttackTimer = 0;
var onAction = false;
var usingThrow = false;
var spawnedSnowball = false;
var throwTimer = 0;

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

var gameScene = null;

@onready var camera = get_viewport().get_camera_3d();
@onready var charModel = $snowman_armature;
@onready var animPlayer = $AnimationPlayer;

func _ready() -> void:
	gameScene = get_parent().get_parent().get_parent(); # lolol
	if (gameScene.name != "Game"):
		print("[WARNING SNOW]: couldn't find game scene");
		return;
	set_multiplayer_authority(1);
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
		if (attackTimer > 0 and not usingThrow):
			attackTimer -= delta;
		elif (attackTimer <= 0):
			rpc("snowballThrow");
		
		if (usingThrow):
			throwTimer -= delta;
			_handleThrowTimers();
	
	PlayerFunc.updateGlobally(self, delta);
	
	if (bufferedMoveTo and moveTo == null):
		moveTo = bufferedMoveTo;
		bufferedMoveTo = null;
	
	# handle animations
	if (onAction or basicAttacking):
		return;
	
	if (velocity != Vector3.ZERO):
		if not (animPlayer.current_animation == "run"):
			animPlayer.play("run");
	else:
		if not (animPlayer.is_playing() and animPlayer.current_animation != "run"):
			animPlayer.play("idle");

func _handleThrowTimers():
	if (throwTimer <= 2.0):
		rpc("syncAnimation", "attack");
		
	if (throwTimer <= 1.5 and not spawnedSnowball):
		var character = _getRandomCharacter();
		rpc("_spawnSnowball", character.global_position);
		
	if (throwTimer < 0):
		usingThrow = false;
		spawnedSnowball = false;

func _getRandomCharacter():
	var playersId = [];
	for playerId in Server.playersInfo:
		playersId.append(playerId);
	
	playersId.shuffle();
	var randPlayerId = playersId[0];
	var character = gameScene.get_character_by_id(str(randPlayerId));
	
	return character;

func updateHealthSize():
	var UILoaded = has_node("CharacterUI");
	if not (UILoaded):
		return;
	
	var charUI = get_node("CharacterUI");
	var healthBar = charUI.get_node("HealthUI/SubViewport/emptyBar/healthBar");
	var shieldBar = charUI.get_node("HealthUI/SubViewport/emptyBar/shieldBar");
	healthBar.scale.x = hp / maxHp;
	shieldBar.scale.x = shield / maxHp;

func _onSnowballArrived(_snowball):
	var mesh: MeshInstance3D = _snowball.get_child(0);
	var particles: GPUParticles3D = _snowball.get_child(1);
	var hitbox: Area3D = _snowball.get_node("hitbox");
	var timer: Timer = _snowball.get_node("Timer");
	
	mesh.visible = false;
	particles.emitting = true;
	hitbox.monitoring = true;
	timer.start();

@rpc("call_local", "reliable", "any_peer")
func _spawnSnowball(_moveTo: Vector3):
	var snowball = preload("res://assets/npcs/snowman/snowball.tscn").instantiate();
	var trailParticles = snowball.get_child(2);
	var distance = global_position.distance_to(_moveTo);
	var timeToArrive = distance * 0.025;
	add_child(snowball);
	
	trailParticles.visible = true;
	snowball.global_position = global_position + Vector3(0, 5, 0);
	snowball.team = team;
	
	var tween = get_tree().create_tween();
	tween.tween_property(snowball, "global_position", _moveTo, timeToArrive);
	tween.finished.connect(_onSnowballArrived.bind(snowball));
	spawnedSnowball = true;

@rpc("call_local", "reliable", "any_peer")
func snowballThrow():
	usingThrow = true;
	throwTimer = 4.0;
	attackTimer = BASE_ATTACK_TIMER + randf_range(1.0, 3.0);
	animPlayer.play("charging");

@rpc("call_local", "any_peer", "reliable")
func showUI():
	var charUI = preload("res://assets/characters/structure_ui.tscn").instantiate();
	var healthBar = charUI.get_node("HealthUI/SubViewport/emptyBar/healthBar");
	charUI.get_node("PlayerName/SubViewport/Label").text = "";
	healthBar.color = Color(0.769, 0.17, 0.182);
	add_child(charUI);
	
	var zOffset = -2.0 if team == 0 else 2.0;
	var xOffset = 0.0 if team == 0 else 0.65;
	charUI.global_position.x += xOffset;
	charUI.global_position.y = 5.0;
	charUI.global_position.z += zOffset;

@rpc("call_local")
func syncAnimation(animId: String):
	animPlayer.play(animId);

@rpc("call_local", "any_peer", "reliable")
func syncTarget(_target):
	target = _target;

@rpc("call_local", "any_peer", "reliable")
func syncHealth(curHealth, _shield, damaged = false, attackerId: String = ""):
	hp = curHealth;
	PlayerFunc.updateHealthSize(self, damaged);
	
	var speedAmount = randf_range(2.0, 4.0);
	speedOffset += speedAmount;
	speedOffset = clamp(speedOffset, 0, 20.0);
	
	if not (attackerId.is_empty()):
		var oldAttackerPos = assistedInKill.find(attackerId);
		if (oldAttackerPos != -1):
			assistedInKill.remove_at(oldAttackerPos);
		
		assistedInKill.append(attackerId);
	
@rpc("any_peer")
func syncPosition(newPos):
	global_position = newPos;

@rpc("call_local", "any_peer")
func syncRotation(newPos):
	rotateChar(newPos);

@rpc("call_local", "any_peer")
func syncStats(_speedOffset):
	speedOffset = _speedOffset;

@rpc("call_local", "any_peer", "reliable")
func killHippo():
	if (dead):
		return;
	
	dead = true;
	visible = false;
	moveTo = global_position;
	PlayerFunc.syncMovement(self);
	
	var scene = get_parent().get_parent().get_parent(); # lol
	if (scene.name != "Game"):
		print("[WARNING]: game node not found");
		return;
	
	var invertedAssistsArray: Array = assistedInKill;
	invertedAssistsArray.reverse();
	
	var index = 0;
	var winnerTeam = -1;
	for playerId in assistedInKill:
		if (scene.name != "Game"):
			print("[WARNING]: game node not found");
			return;
		
		var character: CharacterBody3D = scene.get_character_by_id(playerId);
		if (character):
			if (index != 0):
				break;
			
			character.level += 1;
			winnerTeam = character.team;
			
		index += 1;
	
	if (winnerTeam == -1):
		print("[WARNING]: couldn't find team that killed hippo");
		return;
	
	for playerId in Server.playersInfo:
		var playerData = Server.playersInfo[playerId];
		var character = scene.get_character_by_id(str(playerData.playerID));
		
		if (character.team == winnerTeam):
			character.tokens += 5;
			character.hp += character.maxHp / 1.25;
			character.hp = clamp(character.hp, 0, character.maxHp);
			
			var newParticles = preload("res://assets/effects/hippo_buff_particles.tscn").instantiate();
			character.add_child(newParticles);
			
			newParticles.get_node("buffExplosion").emitting = true;
			newParticles.get_node("sparkParticle").emitting = true;
			newParticles.get_node("buffParticles").emitting = true;
	
	var particles = preload("res://assets/characters/dead_particles.tscn").instantiate();
	get_parent().add_child(particles);
	
	particles.global_position = global_position + Vector3(0, 2, 0);
	particles.get_node("pointyParts").emitting = true;
	particles.get_node("spiralParts").emitting = true;

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
	print("SERVER: ", newText);

func onCollision():
	pass;
