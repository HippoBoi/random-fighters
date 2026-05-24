class_name UserPreferences extends Resource

@export_range(0, 1, 0.05) var musicVolume: float = 1.0;
@export_range(0, 1, 0.05) var soundsVolume: float = 1.0;
@export var wasdMovement: bool = false;
@export var dontShowCreateWarning: bool = false;
@export var controls: Dictionary = {
	"primary" = null,
	"secondary" = null,
	"tertiary" = null,
	"ultimate" = null,
	"space" = null,
	"shop" = null,
	"autoBasic" = null,
	"stop_movement" = null
};

func save():
	ResourceSaver.save(self, "user://settings.tres");

static func loadOrCreate():
	var res: UserPreferences = load("user://settings.tres") as UserPreferences;
	
	if not (res):
		res = UserPreferences.new();
	
	return res;

func resetToDefaults():
	musicVolume = 1.0;
	soundsVolume = 1.0;
	wasdMovement = false;
	controls = {
		"primary" = null,
		"secondary" = null,
		"tertiary" = null,
		"ultimate" = null,
		"space" = null,
		"shop" = null,
		"autoBasic" = null,
		"stop_movement" = null
	};

	InputMap.load_from_project_settings();
	save();
