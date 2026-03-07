extends Node3D

@onready var cloudsNode = $Clouds

var activeClouds = [];
var timer = 0;
var cloudBaseSpeed = 1;

func _physics_process(delta: float) -> void:
	timer += delta;
	
	if (timer <= 1):
		return;
		
	timer = 0;
	
	if (randi_range(0, 1) == 1):
		return;
	
	var clouds = cloudsNode.get_children();
	var selectedCloud = clouds[randi_range(0, len(clouds) - 1)];
	var cloud = selectedCloud.duplicate();
	var cloudScale = randf_range(0.7, 1.75);
	var randPosition = clouds[randi_range(0, len(clouds) - 1)].global_position;
	var yOffset = randf_range(-6.0, 2.0);
	var zOffset = randf_range(-50.0, 50.0);
	add_child(cloud);
	
	cloud.name = str(len(activeClouds));
	cloud.speed = randf_range(0.35, 2.2);
	cloud.global_position = randPosition + Vector3(0, yOffset, zOffset);
	cloud.scale = Vector3(cloudScale, cloudScale, cloudScale);
	activeClouds.append(cloud);
