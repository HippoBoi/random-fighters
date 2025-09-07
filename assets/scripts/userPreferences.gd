class_name UserPreferences extends Resource

@export_range(0, 1, 0.05) var musicVolume: float = 1.0;
@export_range(0, 1, 0.05) var soundsVolume: float = 1.0;
@export var actionEvents: Dictionary = {};

func save():
	ResourceSaver.save(self, "user://settings.tres");

func loadOrCreate():
	var res = load("user://settings.tres") as UserPreferences;
	
	if not (res):
		res = UserPreferences.new();
	
	return res;
