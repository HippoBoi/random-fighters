extends Node3D

var trainMoment: float = 5;
var trainTimer: float = 0;

func _ready() -> void:
	set_multiplayer_authority(1);

func _physics_process(delta: float) -> void:
	if (is_multiplayer_authority()):
		trainTimer += delta;
		
		if (trainTimer >= trainMoment):
			trainTimer = 0;
			trainMoment = randi_range(3, 6);
			_setupTrainSpawn();

func _setupTrainSpawn():
	var isBig: int = randi_range(0, 2);
	var positions: Array = $trainPositions.get_children();
	
	var randomPos: MeshInstance3D = positions[randi_range(0, len(positions) - 1)];
	
	rpc("spawnTrain", isBig, randomPos.name, randomPos.global_position, randomPos.rotation);

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

@rpc("call_local", "any_peer", "reliable")
func spawnTrain(isBig: int, randomPosName: String, randPos: Vector3, randPosRotation: Vector3):
	var train: CharacterBody3D = null;
	var curLane: MeshInstance3D = null;
	var laneWarning1 = $warningPos1;
	var laneWarning2 = $warningPos2;
	var laneWarning3 = $warningPos3;
	
	if (randomPosName == "1" or randomPosName == "4"):
		curLane = laneWarning1;
	elif (randomPosName == "2" or randomPosName == "6"):
		curLane = laneWarning2;
	elif (randomPosName == "3" or randomPosName == "5"):
		curLane = laneWarning3;
	
	if (isBig != 0):
		train = preload("res://assets/npcs/big_train/big_train.tscn").duplicate().instantiate();
		train.isBig = true;
	else:
		train = preload("res://assets/npcs/small_train/small_train.tscn").duplicate().instantiate();
	
	_animateWarning(curLane);
	add_child(train);
	
	train.global_position = randPos;
	train.rotation = randPosRotation;
