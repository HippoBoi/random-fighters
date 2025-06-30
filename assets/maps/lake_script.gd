extends Node3D

var startTimer = 0;
var startHippo = false;

@onready var hippo = $hippo;
@onready var positions = $HippoPos;

func _ready() -> void:
	startTimer = 3;

func _physics_process(delta: float) -> void:
	if (is_multiplayer_authority()):
		if (startTimer > 0):
			startTimer -= delta;
		else:
			_setupHippo();

func _setupHippo():
	if (startHippo == false):
		var initialPos: MeshInstance3D = positions.get_node("pos1");
		startHippo = true;
		hippo.global_position = initialPos.global_position;
		
		hippo.rpc("syncPosition", hippo.global_position);
