extends Node3D

@export var dmg = 25;
var team = -1;
var timer = 0.0;

func _on_player_hit(other: Node3D) -> void:
	var snowman = get_parent();
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (other.team != team):
			PlayerFunc.dealDamage(snowman, other, dmg);
			PlayerFunc.slowTarget(other, 0.35);

func _process(delta: float) -> void:
	if (timer > 0.0):
		timer -= delta;
		
		if (timer <= 0.75):
			$hitbox.monitoring = false;
		if (timer <= 0.1):
			queue_free();
