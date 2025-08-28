extends Node;

# thanks chatgpt

var env_vars: Dictionary = {};

func _ready() -> void:
	load_env_file(".env");

func load_env_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_warning(".env file not found: %s" % path);
		return;

	var file := FileAccess.open(path, FileAccess.READ);

	while not file.eof_reached():
		var line: String = file.get_line().strip_edges();
		if line == "" or line.begins_with("#"):
			continue;
		var parts := line.split("=", false, 1);
		if parts.size() == 2:
			var key := parts[0].strip_edges().strip_escapes();
			var value := parts[1].strip_edges().strip_escapes();
			env_vars[key] = value;
	file.close();

func get_env(key: String, default: String = "") -> String:
	return env_vars.get(key, default);
