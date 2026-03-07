extends MeshInstance3D

signal grabbed(target: CharacterBody3D);

var character: CharacterBody3D = null;
var team: int;

func setup(_char, _team):
	character = _char;
	team = _team;

func _onTouch(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		if (other.team != team):
			$Area3D.monitoring = false;
			PlayerFunc.stunTarget(other, 0.75);
			grabbed.emit(other.global_position);
