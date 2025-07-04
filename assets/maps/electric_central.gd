extends Node3D

var willBot: Node3D = null;
var animPlayer: AnimationPlayer = null;

var startTimer = 0;
var animTimer = 0;
var started = false;
var idleStarted = false;

func _ready() -> void:
	var isWillBot = has_node("willBot");
	if not (isWillBot):
		print("[WARNING]: NPC didn't load");
		return;
	
	$willLight.light_energy = 0.0;
	willBot = get_node("willBot");
	
	animPlayer = willBot.get_node("AnimationPlayer");
	animTimer = 1.45;
	startTimer = 2.25;

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

func _lightTween():
	await get_tree().create_timer(0.85).timeout;
	
	var tween: Tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO);
	var light = $willLight;
	tween.tween_property(light, "light_energy", 0.6, 0.75);
