extends ColorRect

func _process(delta):
	pass;
	"""
	var global_mouse_pos = get_global_mouse_position();
	var color_rect_global_rect = get_global_rect();

	if color_rect_global_rect.has_point(global_mouse_pos):
		print("Mouse is inside the ColorRect!")
		var local_mouse_pos = get_local_mouse_position()
		print("Local mouse position: ", local_mouse_pos)
	else:
		print("Mouse is outside the ColorRect.")
	"""
