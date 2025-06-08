extends Control

@onready var background = $bgColor;
@onready var bars = $bars;
@onready var spinningSquare = $"bars/bar#3/bar#4";
@onready var loopingBg = $loopingBG;

signal transition_finished;

func _playBarsIn():
	for bar: ColorRect in bars.get_children():
		bar.position = Vector2(216, 625);
	
	for bar: ColorRect in bars.get_children():
		var tween = get_tree().create_tween().set_trans(Tween.TRANS_CIRC);
		tween.tween_property(bar, "position", Vector2(-45, 370), 0.5);
		await get_tree().create_timer(0.25).timeout;
	
	return true;

func _playBarSpin():
	spinningSquare.rotation = 0;
	
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO);
	tween.tween_property(spinningSquare, "rotation", 6.3, 1);
	await get_tree().create_timer(1.0).timeout;
	
	return true;

func _playBarsOut():
	for bar: ColorRect in bars.get_children():
		var tween = get_tree().create_tween().set_trans(Tween.TRANS_CIRC);
		tween.tween_property(bar, "position", Vector2(-234, 50), 0.5);
		await get_tree().create_timer(0.25).timeout;
	
	return true;

func _playBackgroundIn():
	background.position = Vector2(250, 596);
	
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_CIRC);
	tween.tween_property(background, "position", Vector2(-210, 112), 0.5);
	
	return true;

func _playBackgroundOut():
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_CIRC);
	tween.tween_property(background, "position", Vector2(-400, -552), 0.5);
	
	await get_tree().create_timer(0.5).timeout;
	
	return true;

func _fadeLoopBackgroundIn():
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO);
	tween.tween_property(loopingBg, "modulate", Color(0.01, 0.01, 0.01, 0.5), 0.5);
	
	return true;

func _fadeLoopBackgroundOut():
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO);
	tween.tween_property(loopingBg, "modulate", Color(0.01, 0.01, 0.01, 0.0), 0.5);
	
	return true;

func _ready() -> void:
	_playBackgroundIn();
	_fadeLoopBackgroundIn();
	await _playBarsIn();
	await get_tree().create_timer(0.1).timeout;
	_playBarSpin();
	await get_tree().create_timer(0.5).timeout;
	await _playBarsOut();
	_fadeLoopBackgroundOut();
	await _playBackgroundOut();
	
	# print("TRANSITION FINISHED")
	transition_finished.emit();
	queue_free();
