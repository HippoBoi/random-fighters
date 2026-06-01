extends Control

signal controls_changed(action);

var buttonRemapping: Button = null;
var userPreferences: UserPreferences;
var controlsConnected = false;

func _ready() -> void:
	userPreferences = UserPreferences.loadOrCreate();

func setup():
	var controlsUI = $ScrollContainer/VBoxContainer/controls/ControlSection;

	update_control_labels();
	if (controlsConnected):
		return;
	
	for element in controlsUI.get_children():
		if not (element is Button):
			continue;
		
		var button: Button = element;
		button.pressed.connect(func():
			_onButtonPressed(button);
		);

	controlsConnected = true;

func update_control_labels():
	var controlsUI = $ScrollContainer/VBoxContainer/controls/ControlSection;

	for element in controlsUI.get_children():
		if not (element is Button):
			continue;

		var button: Button = element;
		var action = InputMap.action_get_events(button.name);
		if (action.is_empty()):
			continue;

		var label = button.get_node("ActionLabel");
		label.text = action[0].as_text().trim_suffix(" (Physical)");

func _onButtonPressed(button: Button):
	buttonRemapping = button;

func _input(event: InputEvent) -> void:
	if not (buttonRemapping):
		return;
	
	if (event is InputEventKey):
		InputMap.action_erase_events(buttonRemapping.name);
		InputMap.action_add_event(buttonRemapping.name, event);
		controls_changed.emit(buttonRemapping.name);
		
		if (userPreferences):
			userPreferences.controls[buttonRemapping.name] = event;
			print(userPreferences.controls);
			userPreferences.save();
		
		buttonRemapping = null;
	setup();
