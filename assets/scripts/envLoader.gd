extends Node

var env_vars := {};

func _ready():
	load_env_file(".env");

func load_env_file(path: String):
	var file = FileAccess.open(path, FileAccess.READ);
	if (file):
		while not (file.eof_reached()):
			var line = file.get_line().strip_edges();
			if (line.begins_with("#") or line == ""):
				continue;
			var parts = line.split("=", false);
			if (parts.size() == 2):
				env_vars[parts[0]] = parts[1];
		file.close();
	else:
		push_warning(".env file not found!");

func get_env(key: String, default := "") -> String:
	return env_vars.get(key, default);
