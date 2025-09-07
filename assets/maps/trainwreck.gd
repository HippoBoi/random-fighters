extends Node3D

var trainMoment: float = 5;
var trainTimer: float = 0;

func _ready() -> void:
	set_multiplayer_authority(1);

func _physics_process(delta: float) -> void:
	if (is_multiplayer_authority()):
		trainTimer += delta;
		
		if (trainTimer >= trainMoment):
			_spawnTrain();
		
		if (Engine.get_physics_frames() % 30 == 0):
			pass;

func _spawnTrain():
	trainTimer = 0;
	trainMoment = randi_range(3, 9);
	
	var isBig: int = randi_range(0, 1);
	var train: CharacterBody3D = null;
	var positions: Array = $trainPositions.get_children();
	if (isBig == 1):
		train = preload("res://assets/npcs/big_train/big_train.tscn").duplicate().instantiate();
	else:
		train = preload("res://assets/npcs/small_train/small_train.tscn").duplicate().instantiate();
	
	var randomPos: MeshInstance3D = positions[randi_range(0, len(positions) - 1)];
	
	add_child(train);
	
	train.global_position = randomPos.global_position;
	train.rotation = randomPos.rotation;
	print("pos: %s, is big: %s, train: %s" % [randomPos, isBig, train]);
