extends MeshInstance3D

func _process(_delta: float) -> void:
	if (Engine.get_physics_frames() % 30 == 0):
		$FogParticles.emitting = true;

func _on_fog_entered(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		PlayerFunc.enterFog(other, self);

func _on_fog_exit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		PlayerFunc.leaveFog(other, self);
