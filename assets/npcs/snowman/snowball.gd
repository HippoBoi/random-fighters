extends Node3D

@export var dmg = 30;
var team = -1;

func _on_player_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (other.team != team):
			PlayerFunc.dealDamage(self, other, dmg);
			PlayerFunc.slowTarget(other, 0.35);

func _on_timer_timeout() -> void:
	queue_free();
