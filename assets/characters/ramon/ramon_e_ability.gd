extends Node3D

@onready var model = $cup_model;
@onready var particles = $GPUParticles3D;
@onready var hitbox = $hitbox;

const SPEED = 7.0;

var character: CharacterBody3D = null;
var dmg: int = 0;
var team: int;
var targetPos: Vector3;

func setup(_char, _team, _dmg, _pos):
	character = _char;
	team = _team;
	dmg = _dmg;
	targetPos = _pos;

func _physics_process(delta: float) -> void:
	if (targetPos):
		global_position = global_position.lerp(targetPos, SPEED * delta);
	
	if (global_position.distance_to(targetPos) < 0.5):
		_killThing();

func _killThing():
	model.visible = false;
	particles.emitting = true;
	hitbox.get_node("MeshInstance3D").get_node("Area3D").monitoring = true;
	
	await get_tree().create_timer(0.5).timeout;
	queue_free();

func _onTouch(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg;
		if (other.team != team):
			PlayerFunc.dealDamage(character, other, totalDmg * 0.5);
			PlayerFunc.stunTarget(other, 0.25);
