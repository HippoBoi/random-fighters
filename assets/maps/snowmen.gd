extends Node3D
var snowmanBlack = null;
var snowmanWhite = null;

func _ready() -> void:
	if not (is_multiplayer_authority()):
		return;
	
	if (has_node("snowmanBlack")):
		snowmanBlack = get_node("snowmanBlack");
	if (has_node("snowmanWhite")):
		snowmanWhite = get_node("snowmanWhite");
	
	if not (snowmanBlack and snowmanWhite):
		print("[WARNING] failed to load snowmen");
		return;
	
	_setupSnowmen();
	
func _setupSnowmen():
	snowmanBlack.rpc("showUI");
	snowmanWhite.rpc("showUI");
