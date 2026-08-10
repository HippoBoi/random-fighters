extends Control

@onready var menu_assets: Control = $MainMenuAssets;
@onready var play_menu_assets: Control = $PlayMenuAssets;
@onready var random_text: TextureRect = $MainMenuAssets/Title1
@onready var fighters_text: TextureRect = $MainMenuAssets/Title2
@onready var left_option_label: Label = $MainMenuAssets/Carousel/SkinsLabel
@onready var right_option_label: Label = $MainMenuAssets/Carousel/OptionsLabel
@onready var left_arrow_button: Button = $MainMenuAssets/Carousel/LeftArrowButton
@onready var selected_option_button: Button = $MainMenuAssets/Carousel/SelectedButton
@onready var right_arrow_button: Button = $MainMenuAssets/Carousel/RightArrowButton
@onready var game_version_label: RichTextLabel = $MainMenuAssets/GameVersion

const TITLE_ROTATION_DURATION: float = 2.0;
const ROTATION = 2;
const CAROUSEL_TRANSITION_DURATION := 0.16
const CAROUSEL_OPTIONS := ["PLAY", "OPTIONS", "SKINS"]
const PLAY = CAROUSEL_OPTIONS[0];
const OPTIONS = CAROUSEL_OPTIONS[1];
const SKINS = CAROUSEL_OPTIONS[2];

signal carousel_option_changed(option: String)

var coolLine1: TextureRect;
var coolLine2: TextureRect;
var coolLine3: TextureRect;
var coolLine4: TextureRect;
var coolLine5: TextureRect;
var coolLine6: TextureRect;

var linesTimer = 0;
var linesSpeed = 50;
var selected_carousel_index := 0
var carousel_is_transitioning := false
var selected_option_position := Vector2.ZERO
var left_option_position := Vector2.ZERO
var right_option_position := Vector2.ZERO

# technical debt alert, will fix this
# TODO: refactor this logic ig
func _handleCoolLines(delta):
	linesTimer += delta * linesSpeed;
	
	var linesCheck = coolLine1 and coolLine2 and coolLine3 and coolLine4 and coolLine5 and coolLine6;

	if not (linesCheck):
		push_error("COULDN'T FIND COOL LINES :(");
		return;
	
	coolLine1.global_position.x = linesTimer;
	coolLine2.global_position.x = linesTimer - 650;

	coolLine3.global_position.x = linesTimer;
	coolLine4.global_position.x = linesTimer - 650;

	coolLine5.global_position.x = linesTimer;
	coolLine6.global_position.x = linesTimer - 650;
	
	if (linesTimer >= 650):
		linesTimer = 0;

func animateTitles() -> void:
	random_text.pivot_offset = random_text.size * 0.5
	fighters_text.pivot_offset = fighters_text.size * 0.5
	random_text.rotation_degrees = ROTATION * -1
	fighters_text.rotation_degrees = ROTATION

	var random_tween := get_tree().create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	random_tween.tween_property(random_text, "rotation_degrees", ROTATION, TITLE_ROTATION_DURATION)
	random_tween.tween_property(random_text, "rotation_degrees", ROTATION * -1, TITLE_ROTATION_DURATION)

	var fighters_tween := get_tree().create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	fighters_tween.tween_property(fighters_text, "rotation_degrees", ROTATION * -1, TITLE_ROTATION_DURATION)
	fighters_tween.tween_property(fighters_text, "rotation_degrees", ROTATION, TITLE_ROTATION_DURATION)

func playIntro() -> void:
	visible = true
	modulate.a = 0.0
	get_tree().create_tween().tween_property(self, "modulate:a", 1.0, 0.25)

func playLeave() -> void:
	get_tree().create_tween().tween_property(self, "modulate:a", 0.0, 0.2)

func _ready() -> void:
	# we are going to trust that, if a single "CoolLines" asset exists,
	# all the others will exist as well. Either way an error will show up
	if (menu_assets.has_node("CoolLines")):
		coolLine1 = menu_assets.get_node("CoolLines");
		coolLine2 = menu_assets.get_node("CoolLines2");
		coolLine3 = play_menu_assets.get_node("CoolLines3");
		coolLine4 = play_menu_assets.get_node("CoolLines4");
		coolLine5 = play_menu_assets.get_node("CoolLines5");
		coolLine6 = play_menu_assets.get_node("CoolLines6");

	var version = ProjectSettings.get_setting("application/config/version")
	game_version_label.text = "V " + version
	$MainMenuAssets/Debug.visible = Constants.DEBUG;

	_setupButtons()
	_setup_carousel()
	playIntro()
	animateTitles()

func _process(delta: float) -> void:
	_handleCoolLines(delta);

func _setupButtons() -> void:
	for button: Button in get_tree().get_nodes_in_group("main_menu_interactive"):
		button.mouse_entered.connect(_play_button_sound.bind(button, "res://assets/sounds/menuHover.ogg"))
		button.pressed.connect(_on_button_pressed.bind(button));

func _setup_carousel() -> void:
	selected_option_position = selected_option_button.position
	left_option_position = left_option_label.position
	right_option_position = right_option_label.position
	selected_option_button.pivot_offset = selected_option_button.size * 0.5

	left_arrow_button.pressed.connect(_cycle_carousel.bind(-1))
	right_arrow_button.pressed.connect(_cycle_carousel.bind(1))
	_refresh_carousel_labels()

func _unhandled_key_input(event: InputEvent) -> void:
	if carousel_is_transitioning:
		return

	var key_event := event as InputEventKey
	if not key_event or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_LEFT:
		_cycle_carousel(-1)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_RIGHT:
		_cycle_carousel(1)
		get_viewport().set_input_as_handled()

func _cycle_carousel(direction: int) -> void:
	if carousel_is_transitioning:
		return

	carousel_is_transitioning = true
	left_arrow_button.disabled = true
	right_arrow_button.disabled = true

	var movement := Vector2(-direction * 42.0, 0.0)
	var tween := get_tree().create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(selected_option_button, "position", selected_option_position + movement, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(selected_option_button, "modulate:a", 0.0, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(selected_option_button, "scale", Vector2(0.88, 0.88), CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(left_option_label, "position", left_option_position + movement, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(left_option_label, "modulate:a", 0.0, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(right_option_label, "position", right_option_position + movement, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(right_option_label, "modulate:a", 0.0, CAROUSEL_TRANSITION_DURATION)
	tween.finished.connect(_finish_carousel_transition.bind(direction, movement))

func _finish_carousel_transition(direction: int, movement: Vector2) -> void:
	selected_carousel_index = posmod(selected_carousel_index + direction, CAROUSEL_OPTIONS.size())
	_refresh_carousel_labels()

	selected_option_button.position = selected_option_position - movement
	selected_option_button.modulate.a = 0.0
	selected_option_button.scale = Vector2(1.08, 1.08)
	left_option_label.position = left_option_position - movement
	left_option_label.modulate.a = 0.0
	right_option_label.position = right_option_position - movement
	right_option_label.modulate.a = 0.0

	var tween := get_tree().create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(selected_option_button, "position", selected_option_position, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(selected_option_button, "modulate:a", 1.0, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(selected_option_button, "scale", Vector2.ONE, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(left_option_label, "position", left_option_position, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(left_option_label, "modulate:a", 0.55, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(right_option_label, "position", right_option_position, CAROUSEL_TRANSITION_DURATION)
	tween.tween_property(right_option_label, "modulate:a", 0.55, CAROUSEL_TRANSITION_DURATION)
	tween.finished.connect(_unlock_carousel)

func _refresh_carousel_labels() -> void:
	selected_option_button.text = CAROUSEL_OPTIONS[selected_carousel_index]
	left_option_label.text = CAROUSEL_OPTIONS[posmod(selected_carousel_index - 1, CAROUSEL_OPTIONS.size())]
	right_option_label.text = CAROUSEL_OPTIONS[posmod(selected_carousel_index + 1, CAROUSEL_OPTIONS.size())]

func _unlock_carousel() -> void:
	carousel_is_transitioning = false
	left_arrow_button.disabled = false
	right_arrow_button.disabled = false
	carousel_option_changed.emit(CAROUSEL_OPTIONS[selected_carousel_index])

func _play_button_sound(button: Button, sound_path: String) -> void:
	var sound := AudioStreamPlayer.new()
	button.add_child(sound)
	sound.stream = load(sound_path)
	sound.pitch_scale = clamp(randf(), 0.75, 1.5)
	sound.play()
	sound.finished.connect(sound.queue_free)

func _on_button_pressed(button: Button):
	_play_button_sound(button, "res://assets/sounds/menuClick.ogg");
	
	if (button.name != "SelectedButton"):
		return;
	
	var selectedOption = CAROUSEL_OPTIONS[selected_carousel_index];
	
	match (selectedOption):
		PLAY:
			_on_play_pressed();
		OPTIONS:
			var mainScript = get_parent();
			mainScript._on_options_pressed();
		_:
			print(selectedOption);

func _on_play_pressed():
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT).set_parallel(true);
	tween.tween_property(menu_assets, "position", Vector2(0, -360), 0.8);
	tween.tween_property(play_menu_assets, "position", Vector2(0, 0), 0.8);
