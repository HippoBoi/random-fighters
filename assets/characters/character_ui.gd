extends Node3D

const INVINCIBLE_COLOR := Color(1.0, 0.85, 0.1, 1.0)
const DAMAGED_COLOR := Color(1.0, 0.65, 0.45, 1.0)
const SHIELD_DAMAGED_COLOR := Color(0.6, 0.4, 0.71, 1.0)
const DAMAGE_FLASH_DURATION := 0.1

@onready var health_bar: ColorRect = $HealthUI/SubViewport/emptyBar/healthBar
@onready var shield_bar: ColorRect = $HealthUI/SubViewport/emptyBar/shieldBar

var base_health_color := Color(0.768589, 0.169974, 0.18192, 1.0)
var base_shield_color := Color(0.544652, 0.696886, 0.835219, 1.0)
var invincible := false
var color_tween: Tween

func _ready() -> void:
	base_shield_color = shield_bar.color
	_apply_current_colors()

func setBaseHealthColor(new_color: Color) -> void:
	base_health_color = new_color
	_stop_color_tween()
	_apply_current_colors()

func setInvincible(enabled: bool) -> void:
	invincible = enabled
	_stop_color_tween()
	_apply_current_colors()

func flashDamage(shielded: bool) -> void:
	_stop_color_tween()

	if (invincible):
		_apply_current_colors()
		return

	health_bar.color = SHIELD_DAMAGED_COLOR if shielded else DAMAGED_COLOR
	color_tween = create_tween()
	color_tween.tween_property(health_bar, "color", base_health_color, DAMAGE_FLASH_DURATION)

func _stop_color_tween() -> void:
	if (color_tween and color_tween.is_valid()):
		color_tween.kill()

	color_tween = null

func _apply_current_colors() -> void:
	if not (is_node_ready()):
		return

	health_bar.color = INVINCIBLE_COLOR if invincible else base_health_color
	shield_bar.color = INVINCIBLE_COLOR if invincible else base_shield_color
