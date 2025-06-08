extends Control

@onready var horizontalBg = $"../HorizontalBG";
@onready var verticalBg = $"../VerticalBG";

const primColor = Color(1.0, 0, 0, 0.45);
const secColor = Color(0.5, 0.25, 0.4, 0.45);
const tertColor = Color(0.5, 0.1, 0.75, 0.45);
const fortColor = Color(0.25, 0.05, 1.0, 0.45);

func _tween_colors(horColor: Color, verColor: Color):
	var tween = get_tree().create_tween();
	tween.tween_property(horizontalBg, "material:shader_parameter/initial_color", horColor, 1.0);
	tween = get_tree().create_tween();
	tween.tween_property(verticalBg, "material:shader_parameter/initial_color", verColor, 1.0);
	await get_tree().create_timer(1.0).timeout;
	
	return true;

func _play_colors_animation():
	await _tween_colors(primColor, secColor);
	await _tween_colors(secColor, tertColor);
	await _tween_colors(tertColor, fortColor);
	await _tween_colors(fortColor, primColor);
	
	_play_colors_animation();

func _ready() -> void:
	_play_colors_animation();
