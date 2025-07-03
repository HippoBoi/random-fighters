extends Node3D

const MOVE_COOLDOWN = 8;
const TURN_COOLDOWN = 0.5;

var startTimer = 0;
var moveTimer = 0;
var turnTimer = 0;
var startHippo = false;
var curHippoPos: MeshInstance3D = null;
var hippo: CharacterBody3D = null;
@onready var positions: Node3D = $HippoPos;

func _ready() -> void:
	var isHippo = has_node("hippo");
	if not (isHippo):
		print("[WARNING]: hippo npc didn't load");
		return;
	
	hippo = get_node("hippo");
	startTimer = 6;
	moveTimer = 12;

func _physics_process(delta: float) -> void:
	if (is_multiplayer_authority()):
		if (Engine.get_physics_frames() % 30 == 0):
			_updateHippoSpeed();
		
		_handleTimers(delta);
		
		if (hippo.hp <= 0):
			hippo.rpc("killHippo");
		
		if not (curHippoPos):
			return;
		
		var randomMaxDistance = randi_range(3, 6);
		var distanceToPos = hippo.global_position.distance_to(curHippoPos.global_position);
		if (distanceToPos <= randomMaxDistance and turnTimer <= 0):
			turnTimer = TURN_COOLDOWN;
			curHippoPos = null;
			_moveHippo();

func _handleTimers(delta):
	if (startTimer > 0):
		startTimer -= delta;
	else:
		_setupHippo();
	
	if (moveTimer > 0):
		moveTimer -= delta;
	else:
		moveTimer = MOVE_COOLDOWN;
		_moveHippo();
	
	if (turnTimer > 0):
		turnTimer -= delta;
	else:
		turnTimer = TURN_COOLDOWN;

func _updateHippoSpeed():
	var newSpeed = hippo.speedOffset - 1;
	var finalSpeed = max(0, newSpeed);
	
	hippo.rpc("syncStats", finalSpeed);

func _moveHippo():
	var possiblePos = positions.get_children();
	var posLength = len(possiblePos) - 1;
	var randomPos: MeshInstance3D = possiblePos[randi_range(0, posLength)];
	var moveTo = randomPos.global_position;
	
	curHippoPos = randomPos;
	hippo.rpc("syncPosition", hippo.global_position);
	hippo.rpc("simulateMove", moveTo);

func _setupHippo():
	if (startHippo == false):
		var initialPos: MeshInstance3D = positions.get_node("pos1");
		startHippo = true;
		hippo.global_position = initialPos.global_position;
		
		hippo.rpc("syncPosition", hippo.global_position);
		hippo.rpc("showUI");
		_moveHippo();
