extends Control

@onready var abilityDescNode = $abilityDesc;
@onready var descriptionText = $abilityDesc/descText;
@onready var descriptionImage = $abilityDesc/descImage;

var primaryDesc = "";
var primaryIcon = "";
var secondaryDesc = "";
var secondaryIcon = "";
var tertiaryDesc = "";
var tertiaryIcon = "";
var ultiDesc = "";
var ultiIcon = "";

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
