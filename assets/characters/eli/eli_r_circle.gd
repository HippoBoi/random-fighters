extends Node3D

# simple script to tween the visibility, then destroy

@onready var fireMaterial = $fire1.get_surface_override_material(0);

func _ready():
	await get_tree().create_timer(0.75).timeout;
	
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	tween.tween_property(fireMaterial, "shader_parameter/Transparency", 0.0, 1.5);
	
	await get_tree().create_timer(2.0).timeout;
	
	queue_free();
