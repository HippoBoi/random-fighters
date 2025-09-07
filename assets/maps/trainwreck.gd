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
	var isBig: int = randi_range(0, 1);
	var train: CharacterBody3D = null;
	var positions: Array = $trainPositions.get_children();
	var laneWarning1 = $warningPos1;
	var laneWarning2 = $warningPos2;
	var laneWarning3 = $warningPos3;
	var curLane: MeshInstance3D = null;
	
	trainTimer = 0;
	trainMoment = randi_range(3, 9);
	
	if (isBig == 1):
		train = preload("res://assets/npcs/big_train/big_train.tscn").duplicate().instantiate();
	else:
		train = preload("res://assets/npcs/small_train/small_train.tscn").duplicate().instantiate();
	
	var randomPos: MeshInstance3D = positions[randi_range(0, len(positions) - 1)];
	
	if (randomPos.name == "1" or randomPos.name == "4"):
		curLane = laneWarning1;
	elif (randomPos.name == "2" or randomPos.name == "6"):
		curLane = laneWarning2;
	elif (randomPos.name == "3" or randomPos.name == "5"):
		curLane = laneWarning3;
	
	_animateWarning(curLane);
	add_child(train);
	
	train.global_position = randomPos.global_position;
	train.rotation = randomPos.rotation;
	print("pos: %s, is big: %s, train: %s" % [randomPos, isBig, train]);

func _animateWarning(lane: MeshInstance3D):
	var warning: MeshInstance3D = preload("res://assets/effects/train_warning.tscn").duplicate().instantiate();
	var tween: Tween = get_tree().create_tween().set_parallel(true);
	var material: Material = warning.get_surface_override_material(0);
	var shaderMaterial = material.next_pass;
	
	add_child(warning);
	warning.global_position = lane.global_position;
	warning.rotation = lane.rotation;
	
	tween.tween_property(material, "albedo_color", Color(0.917, 0, 0.244, 0.5), 1.25);
	tween.tween_property(shaderMaterial, "shader_parameter/Transparency", 1.0, 1.0);
