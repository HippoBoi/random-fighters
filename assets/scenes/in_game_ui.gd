extends Control

signal chat_message_submitted(message);

const ABILITY_KEYBIND_LABELS = {
	"primary": "primaryKeybind",
	"secondary": "secondaryKeybind",
	"tertiary": "tertiaryKeybind",
	"ultimate": "ultiKeybind"
};

@onready var abilityDescNode = $abilityDesc;
@onready var descriptionText = $abilityDesc/descText;
@onready var descriptionImage = $abilityDesc/descImage;
@onready var chatPanel = $chatPanel;
@onready var chatMessages = $chatPanel/messages;
@onready var chatInput = $chatPanel/chatInput;

const MAX_CHAT_MESSAGES = 4;
const MAX_CHAT_MESSAGE_LENGTH = 30;
const CHAT_VISIBLE_SECONDS = 4.0;
const CHAT_FADE_SECONDS = 0.45;
const CHAT_FONT = preload("res://addons/fonts/tl_mussels/TT Mussels Trial Medium.otf");

var chatOpen = false;
var chatFadeVersion = 0;
var chatFadeTween: Tween = null;

var primaryDesc = "";
var primaryIcon = "";
var secondaryDesc = "";
var secondaryIcon = "";
var tertiaryDesc = "";
var tertiaryIcon = "";
var ultiDesc = "";
var ultiIcon = "";

func _ready() -> void:
	close_chat();
	update_ability_keybind_labels();

func update_ability_keybind_labels(_changed_action := "") -> void:
	for action in ABILITY_KEYBIND_LABELS:
		var input_events = InputMap.action_get_events(action);
		if (input_events.is_empty()):
			continue;

		var label = $abilitiesUI.get_node(ABILITY_KEYBIND_LABELS[action]);
		label.text = input_events[0].as_text().trim_suffix(" (Physical)");

func is_chat_open() -> bool:
	return chatOpen;

func open_chat() -> void:
	chatOpen = true;
	chatPanel.visible = true;
	chatPanel.modulate.a = 1.0;
	chatInput.visible = true;
	chatInput.grab_focus();
	chatInput.caret_column = chatInput.text.length();
	_cancel_chat_fade();

func close_chat(clearText := false) -> void:
	chatOpen = false;
	chatPanel.visible = chatMessages.get_child_count() > 0;
	chatInput.visible = false;
	chatInput.release_focus();
	if (clearText):
		chatInput.text = "";

	if (chatPanel.visible):
		_restart_chat_fade_timer();

func submit_chat_message() -> void:
	var message = _sanitize_message(chatInput.text);
	chatInput.text = "";
	close_chat();

	if (message.is_empty()):
		return;

	chat_message_submitted.emit(message);

func add_chat_message(senderName: String, message: String) -> void:
	chatPanel.visible = true;
	chatPanel.modulate.a = 1.0;

	var messageLabel = Label.new();
	messageLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;
	messageLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL;
	messageLabel.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92));
	messageLabel.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9));
	messageLabel.add_theme_constant_override("shadow_offset_x", 1);
	messageLabel.add_theme_constant_override("shadow_offset_y", 1);
	messageLabel.add_theme_font_override("font", CHAT_FONT);
	messageLabel.add_theme_font_size_override("font_size", 10);
	messageLabel.text = "%s: %s" % [senderName, _sanitize_message(message)];
	chatMessages.add_child(messageLabel);

	while (chatMessages.get_child_count() > MAX_CHAT_MESSAGES):
		var oldMessage = chatMessages.get_child(0);
		chatMessages.remove_child(oldMessage);
		oldMessage.queue_free();

	_restart_chat_fade_timer();

func _restart_chat_fade_timer() -> void:
	if (chatOpen):
		return;

	_cancel_chat_fade();
	chatFadeVersion += 1;
	var currentVersion = chatFadeVersion;

	await get_tree().create_timer(CHAT_VISIBLE_SECONDS).timeout;

	if (chatOpen or currentVersion != chatFadeVersion or chatMessages.get_child_count() == 0):
		return;

	chatFadeTween = get_tree().create_tween();
	chatFadeTween.tween_property(chatPanel, "modulate:a", 0.0, CHAT_FADE_SECONDS);
	await chatFadeTween.finished;

	if (chatOpen or currentVersion != chatFadeVersion):
		return;

	chatPanel.visible = false;
	chatPanel.modulate.a = 1.0;

func _cancel_chat_fade() -> void:
	chatFadeVersion += 1;
	if (chatFadeTween):
		chatFadeTween.kill();
		chatFadeTween = null;

func _sanitize_message(message: String) -> String:
	var cleanMessage = message.replace("\n", " ").replace("\r", " ").strip_edges();
	if (cleanMessage.length() > MAX_CHAT_MESSAGE_LENGTH):
		cleanMessage = cleanMessage.substr(0, MAX_CHAT_MESSAGE_LENGTH);

	return cleanMessage;

func _on_primary_mouse_hover() -> void:
	var image = load(primaryIcon);
	descriptionText.text = primaryDesc;
	descriptionImage.texture = image;
	abilityDescNode.visible = true;
	abilityDescNode.position.x = 90;

func _on_secondary_mouse_hover() -> void:
	var image = load(secondaryIcon);
	descriptionText.text = secondaryDesc;
	descriptionImage.texture = image;
	abilityDescNode.visible = true;
	abilityDescNode.position.x = 160;

func _on_tertiary_mouse_hover() -> void:
	var image = load(tertiaryIcon);
	descriptionText.text = tertiaryDesc;
	descriptionImage.texture = image;
	abilityDescNode.visible = true;
	abilityDescNode.position.x = 235;

func _on_ulti_mouse_hover() -> void:
	var image = load(ultiIcon);
	descriptionText.text = ultiDesc;
	descriptionImage.texture = image;
	abilityDescNode.visible = true;
	abilityDescNode.position.x = 310;

func _on_primary_mouse_exit() -> void:
	abilityDescNode.visible = false;

func _on_secondary_mouse_exit() -> void:
	abilityDescNode.visible = false;

func _on_tertiary_mouse_exit() -> void:
	abilityDescNode.visible = false;

func _on_ulti_mouse_exit() -> void:
	abilityDescNode.visible = false;

func updateIcons():
	$abilitiesUI/primaryAbility.texture = load(primaryIcon);
	$abilitiesUI/secondaryAbility.texture = load(secondaryIcon);
	$abilitiesUI/tertiaryAbility.texture = load(tertiaryIcon);
	$abilitiesUI/ultiAbility.texture = load(ultiIcon);

func _on_chat_input_text_submitted(_new_text: String) -> void:
	submit_chat_message();
