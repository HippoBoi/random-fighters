class_name UserPreferences extends Resource

@export_range(0, 1, 0.05) var musicVolume: float = 1.0;
@export_range(0, 1, 0.05) var soundsVolume: float = 1.0;
@export var wasdMovement: bool = false;
@export var dontShowCreateWarning: bool = false;
@export var actionEvents: Dictionary = {};

func save():
	print("SAVING SETTINGS!");
	ResourceSaver.save(self, "user://settings.tres");

static func loadOrCreate():
	var res: UserPreferences = load("user://settings.tres") as UserPreferences;
	
	if not (res):
		res = UserPreferences.new();
	
	return res;
