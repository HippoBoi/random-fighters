extends Control

@onready var menu = $Menu
@onready var topRect = $topRect;
@onready var midRect = $midRect;
@onready var bottomRect = $bottomRect;
@onready var RANDOM_text = $Title1;
@onready var FIGHTERS_text = $Title2;
@onready var loopingBG = $loopingBG;

func playIntro():
	RANDOM_text.position = Vector2(26, 10);
	RANDOM_text.scale = Vector2(0.75, 0.75);
	FIGHTERS_text.position = Vector2(73, 70);
	FIGHTERS_text.scale = Vector2(0.75, 0.75);
	
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT);
	tween.set_parallel();
	tween.tween_property(topRect, "position", Vector2(-28, 338), 0.5);
	tween.tween_property(bottomRect, "position", Vector2(0, 0), 0.5);
	tween.tween_property(midRect, "modulate", Color(1, 1, 1, 1), 0.5);
	
	tween.tween_property(RANDOM_text, "position", Vector2(26, 18), 0.5);
	tween.tween_property(RANDOM_text, "scale", Vector2(1.1, 1.1), 0.5);
	tween.tween_property(FIGHTERS_text, "position", Vector2(73, 77), 0.5);
	tween.tween_property(FIGHTERS_text, "scale", Vector2(1.1, 1.1), 0.5);
	tween.tween_property(loopingBG, "modulate", Color(0.336, 0.39, 0.434, 1), 0.5);
	
	$Menu/nameInput.visible = true;
	$Menu/nameInputText.visible = true;
	
	var buttons = menu.get_node("menuButtons");
	for button in buttons.get_children():
		button.position.y = 360;
	
	tween = get_tree().create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT);
	tween.set_parallel(false);
	var i = 0;
	var finalYPos = -80;
		
	for button in buttons.get_children():
		tween.tween_property(button, "position:y", finalYPos + (55 * i), 0.2);
		i += 1;

func playLeave():
	var tween = get_tree().create_tween();
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.set_parallel();
	tween.tween_property(topRect, "position", Vector2(300, 550), 0.5);
	tween.tween_property(bottomRect, "position", Vector2(-100, -450), 0.5);
	tween.tween_property(midRect, "modulate", Color(1, 1, 1, 0), 0.5);
	
	tween.tween_property(RANDOM_text, "position", Vector2(26, 18), 0.5);
	tween.tween_property(RANDOM_text, "scale", Vector2(0.6, 0.6), 0.5);
	tween.tween_property(FIGHTERS_text, "position", Vector2(65, 47), 0.5);
	tween.tween_property(FIGHTERS_text, "scale", Vector2(0.55, 0.55), 0.5);
	tween.tween_property(loopingBG, "modulate", Color(1, 1, 1, 0.05), 0.5);
	
	$Menu/nameInput.visible = false;
	$Menu/nameInputText.visible = false;
	
	var buttons = menu.get_node("menuButtons");
	var finalYPos = 200;
		
	for button in buttons.get_children():
		tween.tween_property(button, "position:y", finalYPos, 0.4);

func _ready() -> void:
	_setupButtons();
	playIntro();

func _setupButtons():
	var buttons = menu.get_node("menuButtons");
	for child in buttons.get_children():
		var button: Button = child;
		button.mouse_entered.connect(func():
			var newSound = AudioStreamPlayer.new();
			button.add_child(newSound);
			
			newSound.stream = preload("res://assets/sounds/menuHover.ogg");
			newSound.pitch_scale = randf();
			newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.5);
			newSound.play();
			newSound.finished.connect(func():
				newSound.queue_free();
			);
		);
		
		button.pressed.connect(func():
			var newSound = AudioStreamPlayer.new();
			button.add_child(newSound);
			
			newSound.stream = preload("res://assets/sounds/menuClick.ogg");
			newSound.pitch_scale = randf();
			newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.5);
			newSound.play();
			newSound.finished.connect(func():
				newSound.queue_free();
			);
		);
