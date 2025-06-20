extends Node3D


func _on_body_entered(other: Node3D) -> void:
	print("body entered");
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		print("%s COLLIDING!!" % other.name);
		other.onCollission();
