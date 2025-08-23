extends Node3D

var fireCircle: Node3D = null;
var bigFireCircle: Node3D = null;
var fireScale = 10.0;
var fireRatio = 1.68;
var timer = 0;
var hurryTimer = 0;

var minFireScale = 2.35;

func _ready() -> void:
	set_multiplayer_authority(1);
	
	fireCircle = preload("res://assets/particles/fire_circle.tscn").instantiate();
	bigFireCircle = preload("res://assets/particles/big_fire_circle.tscn").instantiate();
	add_child(fireCircle);
	add_child(bigFireCircle);
	
	if (is_multiplayer_authority()):
		var possibleZones = $closingZones.get_children();
		possibleZones.shuffle();
		
		var closingZone = possibleZones[0];
		if (closingZone.name == "pos1"):
			minFireScale = 2.6;
		
		rpc("syncPosition", closingZone.global_position, minFireScale);
	
	fireCircle.scale = Vector3(fireScale * fireRatio, 1.5, fireScale * fireRatio);
	bigFireCircle.scale = Vector3(fireScale, 1.0, fireScale);

func _process(delta: float) -> void:
	if (is_multiplayer_authority()):
		timer += delta;
		if (timer >= 11):
			timer = 0;
			hurryTimer = 0.3;
			rpc("syncParameters", fireScale, hurryTimer);
	
	if (hurryTimer > 0):
		hurryTimer -= delta;
		hurryTimer = clamp(hurryTimer, 0, 1);

func _physics_process(delta: float) -> void:
	fireCircle.scale = Vector3(fireScale * fireRatio, 1.5, fireScale * fireRatio);
	bigFireCircle.scale = Vector3(fireScale, 1.0, fireScale);
	
	fireScale -= (delta + hurryTimer) * 0.5;
	fireScale = clamp(fireScale, minFireScale, 50);
	
	if (Engine.get_physics_frames() % 90 == 0 and is_multiplayer_authority()):
		rpc("syncParameters", fireScale, hurryTimer);

@rpc("call_local", "any_peer", "reliable")
func syncPosition(_position: Vector3, _minFireScale: float):
	fireCircle.global_position = _position;
	bigFireCircle.global_position = _position + Vector3(0, -0.035, 0);
	minFireScale = _minFireScale;

@rpc("call_local", "any_peer", "reliable")
func syncParameters(_fireScale: float, _hurryTimer: float):
	fireScale = _fireScale;
	hurryTimer = _hurryTimer;
