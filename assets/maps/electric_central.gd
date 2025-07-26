extends Node3D

var willBot: Node3D = null;
var animPlayer: AnimationPlayer = null;

var startTimer = 0;
var animTimer = 0;
var thunderTimer = 0;
var started = false;
var idleStarted = false;
var gameScene = null;

func _ready() -> void:
	gameScene = get_parent().get_parent();
	var isWillBot = has_node("willBot");
	if not (isWillBot):
		print("[WARNING]: NPC didn't load");
		return;
	if not (gameScene.name == "Game"):
		print("[WARNING]: couldn't find game scene");
		return;
	
	$willLight.light_energy = 0.0;
	willBot = get_node("willBot");
	
	animPlayer = willBot.get_node("AnimationPlayer");
	animTimer = 1.45;
	startTimer = 2.25;
	thunderTimer = 7.0;

func _physics_process(delta: float) -> void:
	_handleTimers(delta);
	
	if (is_multiplayer_authority()):
		if (Engine.get_physics_frames() % 30 == 0):
			pass;

func _handleTimers(delta: float):
	if (startTimer > 0):
		startTimer -= delta;
		return;
	else:
		if not (started):
			started = true;
			animPlayer.play("wake_up");
			_lightTween();

	if (animTimer > 0):
		animTimer -= delta;
	else:
		if not (idleStarted):
			idleStarted = true;
			animPlayer.play("idle");
	
	if (thunderTimer > 0):
		thunderTimer -= delta;
	else:
		_willThunderAttack();

func _willThunderAttack():
	var RNG = randi_range(0, 2);
	var focusPlayer = true if RNG == 0 else false;
	var randPos: Vector3; 
	if (focusPlayer):
		var character = _getRandomCharacter();
		randPos = character.global_position;
	else:
		var randX = randi_range(-30, 30);
		var randZ = randi_range(-30, 30);
		randPos = Vector3(randX, 0, randZ);
	
	thunderTimer = 2.0 + randi_range(1, 4);
	willBot.rpc("createThunder", randPos);

func _getRandomCharacter():
	var playersId = [];
	for playerId in Server.playersInfo:
		playersId.append(playerId);
	
	playersId.shuffle();
	var randPlayerId = playersId[0];
	var character = gameScene.get_character_by_id(str(randPlayerId));
	
	return character;

func _lightTween():
	await get_tree().create_timer(0.85).timeout;
	
	var tween: Tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO);
	var light = $willLight;
	tween.tween_property(light, "light_energy", 0.6, 0.75);
