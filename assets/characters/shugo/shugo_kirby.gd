extends CharacterBody3D

@onready var shugo = $"..";

var team = -1;
var dead = true;

func _ready() -> void:
	team = shugo.team;
