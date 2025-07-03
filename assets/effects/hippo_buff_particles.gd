extends Node3D

func _on_timer_timeout() -> void:
	$buffParticles.emitting = false;

func _on_timer_2_timeout() -> void:
	queue_free();
