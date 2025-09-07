extends MeshInstance3D

func _on_timer_timeout() -> void:
	var tween = get_tree().create_tween();
	var material: Material = self.get_surface_override_material(0);
	var shaderMaterial = material.next_pass;
	
	tween.tween_property(material, "albedo_color", Color(0.917, 0, 0.244, 0.0), 0.5);
	tween.tween_property(shaderMaterial, "shader_parameter/Transparency", 0.0, 0.5);
	
	$Timer2.start();

func _on_timer_2_timeout() -> void:
	queue_free();
