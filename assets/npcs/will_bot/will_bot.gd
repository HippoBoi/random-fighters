extends Node3D

func _ready() -> void:
	pass;

@rpc("call_local", "reliable", "any_peer")
func createThunder(_position: Vector3):
	var thunder = preload("res://assets/npcs/will_bot/will_thunder.tscn").instantiate();
	add_child(thunder);
	
	thunder.global_position = _position;
