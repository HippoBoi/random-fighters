extends Control

func _playLivesAnimation():
	var livesText = $livesText
	var livesContainer = $livesContainer
	
	livesText.visible = true;
	livesText.modulate = Color(1, 1, 1, 0);
	livesContainer.visible = true;
	livesContainer.modulate = Color(1, 1, 1, 0);
	
	await get_tree().create_timer(0.25).timeout;
	var tween = get_tree().create_tween().set_parallel();
	tween.tween_property(livesText, "modulate", Color(1, 1, 1, 1), 0.25);
	tween.tween_property(livesContainer, "modulate", Color(1, 1, 1, 1), 0.25);
	
	tween = get_tree().create_tween();
	var lastLive = null;
	for live in livesContainer.get_children():
		lastLive = live;
	
	await get_tree().create_timer(1.75).timeout;
	tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	tween.tween_property(lastLive, "modulate", Color(1, 1, 1, 0), 0.45);
	
	await get_tree().create_timer(1.75).timeout;
	tween = get_tree().create_tween().set_parallel();
	tween.tween_property(livesText, "modulate", Color(1, 1, 1, 0), 0.75);
	tween.tween_property(livesContainer, "modulate", Color(1, 1, 1, 0), 0.75);
	await get_tree().create_timer(1.0).timeout;
	
	if (livesContainer.get_children().size() > 1):
		lastLive.queue_free();
	else:
		print("this is last life");
	
	return true;

func _ready() -> void:
	for i in range(3):
		await _playLivesAnimation();
