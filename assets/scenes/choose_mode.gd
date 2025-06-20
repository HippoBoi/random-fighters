extends Control

signal set_gamemode(gamemode);

var playerId: int;
var alreadySelected = [];
var selectedGameMode = "Unknown";
var selectedMode = false;
var forceMode = "Hippo_Capture";

var blackTeamWins = 0;
var whiteTeamWins = 0;
var pointsToWin = 0;

var DEBUG = false;

@onready var bgModeName = $loopingModeName;
var bgNamesCreated = [];
var bgNamesTimer = 0;

func _ready() -> void:
	_updateTeamWins();
	selectGameMode();

func _process(delta: float) -> void:
	_animate_bg_mode_name(delta);

func _updateTeamWins():
	var blackWinsContainer = $TeamWinsUI/BlackTeam/WinsContainer;
	var whiteWinsContainer = $TeamWinsUI/WhiteTeam/WinsContainer;
	var i = 0;
	
	for point: TextureRect in blackWinsContainer.get_children():
		if (i == blackTeamWins):
			break;
		i += 1;
		
		print("BLACK point: %s" % i);
		point.texture = preload("res://assets/sprites/point.png").duplicate();
	
	i = 0;
	for point: TextureRect in whiteWinsContainer.get_children():
		if (i == whiteTeamWins):
			break;
		i += 1;
		
		print("WHITE point: %s" % i);
		point.texture = preload("res://assets/sprites/point.png").duplicate();
	
	if (blackTeamWins >= pointsToWin - 1):
		$TeamWinsUI/BlackTeam/WinText.modulate = Color(0.93, 0.82, 0.47, 1);
	if (whiteTeamWins >= pointsToWin - 1):
		$TeamWinsUI/WhiteTeam/WinText.modulate = Color(0.93, 0.82, 0.47, 1);

func _getModeName(gamemode: String):
	var _name = "";
	for word in gamemode.split("_"):
		_name += word + " ";
	
	return _name;

func _getModeImage(gamemode: String):
	var image;
	if (gamemode.to_lower() == "free_for_all"):
		image = preload("res://assets/textures/Grass001_1K-JPG_Color.jpg").duplicate();
	elif (gamemode.to_lower() == "foggy_vision"):
		image = preload("res://assets/mapAssets/dark_forest/TCom_Sand_Muddy2_2x2_1K_albedo.png").duplicate();
	elif (gamemode.to_lower() == "hippo_capture"):
		image = preload("res://assets/textures/gameMap_TCom_Rock_CliffLayered_1.5x1.png").duplicate();
	else:
		print("[WARNING]: couldn't find image for gamemode: %s" % gamemode);
		image = preload("res://assets/textures/looping_background.png").duplicate();
	
	return image;

func _getRandomMode():
	var chosenMode = "";
	var gameModes: Array = []
	for mode in Constants.GameModes:
		gameModes.append(mode);
	
	var possibleModes = gameModes.filter(func(mode): 
		return not alreadySelected.has(mode);
	);
	
	chosenMode = possibleModes.pick_random();
	
	if not (chosenMode.is_empty()):
		var _name = _getModeName(str(chosenMode));
	else:
		print("[WARNING]: couldn't select gamemode");
	
	return chosenMode;

func selectGameMode():
	var isHost = playerId == 1;
	if (isHost):
		var _selectedMode = _getRandomMode();
		if not (forceMode.is_empty()):
			_selectedMode = forceMode;
		set_gamemode.emit(_selectedMode);
	
	_animate_mode_selection();

func _animate_bg_mode_name(_delta):
	bgNamesTimer += _delta;
	var decimalTimer = int(round(bgNamesTimer * 100));
	if (not (decimalTimer % 4 == 0) or bgNamesCreated.size() > 12):
		return;
	
	var duration = randi_range(3, 11);
	var yPos = randi_range(-170, 220);
	var newName: RichTextLabel = bgModeName.duplicate();
	var tween = get_tree().create_tween();
	tween.tween_property(newName, "global_position", Vector2(-400, yPos), duration);
	tween.finished.connect(func(): 
		var pos = bgNamesCreated.find(newName);
		bgNamesCreated.remove_at(pos);
		newName.queue_free();
	);
	
	if (selectedMode):
		newName.text = selectedGameMode;
	else:
		newName.modulate = Color(0.6, 0.6, 0.6, 0);
	
	newName.global_position.y = yPos;
	newName.visible = true;
	add_child(newName);
	
	bgNamesCreated.append(newName);

func _make_bg_text_visible():
	for text in bgNamesCreated:
		text.text = selectedGameMode;
		var tween = get_tree().create_tween();
		tween.tween_property(text, "modulate", Color(0.6, 0.6, 0.6, 0.25), 0.5);

func _animate_mode_selection():
	for i in range(60):
		var chosenMode = "";
		var gameModes: Array = [];
		for mode in Constants.GameModes:
			gameModes.append(mode);
		
		var possibleModes = gameModes.filter(func(mode): 
			return not alreadySelected.has(mode);
		);
		
		chosenMode = possibleModes.pick_random();
		
		$modeName.text = _getModeName(chosenMode);
		$modeTexture.texture = _getModeImage(chosenMode);
		
		if not (DEBUG):
			await get_tree().create_timer(0.075).timeout;
	
	selectedMode = true;
	_make_bg_text_visible();
	$modeName.text = _getModeName(selectedGameMode);
	$modeTexture.texture = _getModeImage(selectedGameMode);
