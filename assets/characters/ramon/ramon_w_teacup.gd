extends Node3D

@onready var model = $cup_model;
@onready var particles = $GPUParticles3D;
@onready var hitbox = $hitbox;

var character: CharacterBody3D = null;
var dmg = 0;
var team;

func setup(_char, _team, _dmg):
	character = _char;
	team = _team;
	dmg = _dmg;

func _on_timer_timeout() -> void:
	model.visible = false;
	particles.emitting = true;
	hitbox.get_node("MeshInstance3D").get_node("Area3D").monitoring = true;
	
	await get_tree().create_timer(0.75).timeout;
	queue_free();

func _onTouch(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 0.85;
		if (other.team != team):
			PlayerFunc.dealDamage(character, other, totalDmg);
			PlayerFunc.stunTarget(other, 1.5);
