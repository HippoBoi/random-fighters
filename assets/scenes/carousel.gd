class_name Carousel
extends Panel

signal option_changed(index: int)
signal option_selected(index: int)

@export var transition_duration: float = 0.16
@onready var left_arrow_button: BaseButton = $LeftArrowButton
@onready var right_arrow_button: BaseButton = $RightArrowButton
@onready var selected_slot: BaseButton = $SelectedOption
@onready var left_slot: BaseButton = $LeftOption
@onready var right_slot: BaseButton = $RightOption

var options: Array = []
var selected_index := 0
var is_transitioning := false
var keyboard_enabled := false
var slot_spacing := 0.0

var _selected_position := Vector2.ZERO
var _left_position := Vector2.ZERO
var _right_position := Vector2.ZERO
var _display_handler: Callable

func setup(new_options: Array, display_handler: Callable = Callable()) -> void:
	options = new_options
	_display_handler = display_handler
	selected_index = 0

	_cache_positions()
	left_arrow_button.pressed.connect(_cycle.bind(-1))
	right_arrow_button.pressed.connect(_cycle.bind(1))
	selected_slot.pressed.connect(_on_selected_pressed)

	left_slot.modulate.a = 0.55
	right_slot.modulate.a = 0.55
	_refresh_slots()

func set_active(active: bool) -> void:
	keyboard_enabled = active

func _cache_positions() -> void:
	_selected_position = selected_slot.position
	_left_position = left_slot.position
	_right_position = right_slot.position
	selected_slot.pivot_offset = selected_slot.size * 0.5

	var selected_center_x := _selected_position.x + selected_slot.size.x * 0.5
	var left_center_x := _left_position.x + left_slot.size.x * 0.5
	slot_spacing = selected_center_x - left_center_x

func _unhandled_key_input(event: InputEvent) -> void:
	if not keyboard_enabled or is_transitioning:
		return

	var key_event := event as InputEventKey
	if not key_event or not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_LEFT:
		_cycle(-1)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_RIGHT:
		_cycle(1)
		get_viewport().set_input_as_handled()

func _cycle(direction: int) -> void:
	if is_transitioning or options.is_empty():
		return

	is_transitioning = true
	_set_arrows_disabled(true)

	var movement := Vector2(-direction * slot_spacing, 0.0)
	var tween := get_tree().create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(selected_slot, "position", _selected_position + movement, transition_duration)
	tween.tween_property(selected_slot, "modulate:a", 0.0, transition_duration)
	tween.tween_property(selected_slot, "scale", Vector2(0.8, 0.8), transition_duration)
	tween.tween_property(left_slot, "position", _left_position + movement, transition_duration)
	tween.tween_property(left_slot, "modulate:a", 0.0, transition_duration)
	tween.tween_property(right_slot, "position", _right_position + movement, transition_duration)
	tween.tween_property(right_slot, "modulate:a", 0.0, transition_duration)
	tween.finished.connect(_finish_transition.bind(direction, movement))

func _finish_transition(direction: int, movement: Vector2) -> void:
	selected_index = posmod(selected_index + direction, options.size())
	_refresh_slots()

	selected_slot.position = _selected_position - movement
	selected_slot.modulate.a = 0.0
	selected_slot.scale = Vector2(1.08, 1.08)
	left_slot.position = _left_position - movement
	left_slot.modulate.a = 0.0
	right_slot.position = _right_position - movement
	right_slot.modulate.a = 0.0

	var tween := get_tree().create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(selected_slot, "position", _selected_position, transition_duration)
	tween.tween_property(selected_slot, "modulate:a", 1.0, transition_duration)
	tween.tween_property(selected_slot, "scale", Vector2.ONE, transition_duration)
	tween.tween_property(left_slot, "position", _left_position, transition_duration)
	tween.tween_property(left_slot, "modulate:a", 0.55, transition_duration)
	tween.tween_property(right_slot, "position", _right_position, transition_duration)
	tween.tween_property(right_slot, "modulate:a", 0.55, transition_duration)
	tween.finished.connect(_unlock)

func _refresh_slots() -> void:
	if options.is_empty():
		return

	_apply_option(selected_slot, options[selected_index])
	_apply_option(left_slot, options[posmod(selected_index - 1, options.size())])
	_apply_option(right_slot, options[posmod(selected_index + 1, options.size())])
	option_changed.emit(selected_index)

func _apply_option(slot: Control, option: Variant) -> void:
	if _display_handler.is_valid():
		_display_handler.call(slot, option)
		return

	if option is String:
		if slot is Label:
			slot.text = option
		elif slot is BaseButton:
			slot.text = option
	elif option is Texture2D and slot is BaseButton:
		slot.texture_normal = option
	elif option is Dictionary and option.has("texture") and slot is BaseButton:
		slot.texture_normal = option["texture"]

func _on_selected_pressed() -> void:
	if options.is_empty():
		return

	option_selected.emit(selected_index)

func _unlock() -> void:
	is_transitioning = false
	_set_arrows_disabled(false)

func _set_arrows_disabled(disabled: bool) -> void:
	left_arrow_button.disabled = disabled
	right_arrow_button.disabled = disabled
