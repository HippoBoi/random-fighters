extends GPUParticles3D

const dmg = 10.0;

func _on_hit(other: Node3D) -> void:
	var isCharacter = "CHARACTER_NAME" in other;
	if (isCharacter):
		var totalDmg = dmg * 1.4;
		PlayerFunc.dealDamage(self, other, totalDmg);
		PlayerFunc.stunTarget(other, 1.0);
