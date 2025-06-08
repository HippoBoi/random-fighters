extends Node3D

@onready var mesh = $explosion_hitbox/MeshInstance3D;
@onready var hitbox = $explosion_hitbox/MeshInstance3D/Area3D;

var dmg: int = 0;
var team: int;

func setup(_team, _dmg,):
	team = _team;
	dmg = _dmg;
	
func _enableHitbox():
	# mesh.visible = true;
	hitbox.monitoring = true;

func _killThing():
	mesh.visible = false;
	hitbox.monitoring = false;
	
	await get_tree().create_timer(0.5).timeout;
	queue_free();

func _onTouch(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 0.8;
		if (other.team != team):
			PlayerFunc.dealDamage(other, totalDmg);
			PlayerFunc.stunTarget(other, 0.7);
