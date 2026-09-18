extends Control

@onready var whiteTeamContainer = $MultiplayerOnly/WhiteTeamContainer;
@onready var blackTeamContainer = $MultiplayerOnly/BlackTeamContainer;
@onready var playerTemplate = $PlayerTemplate;
@onready var characterScroll = $CharacterScroll;
@onready var characterList = $CharacterScroll/Characters;
@onready var secondsRemaining = $MultiplayerOnly/secondsRemaining;

const CHARACTER_FOLDER = "res://assets/characters";
const CHARACTERS_PER_ROW = 3;
const VISIBLE_ROWS = 3.1;

const CHARACTER_DISPLAY_NAMES = {
	"ale": "Ale",
	"clean": "Clean",
	"eli": "Eli",
	"mystery": "Mystery",
	"nephi": "Nephi",
	"ramon": "Ramón",
	"rhay_v2": "Rhay",
	"rio": "Rio",
	"shugo": "Shugo",
};

var playersLength = 0;
var playersLockedIn = [];

var selectedChar = "";
var selectedButton: Button = null;
var gameStarted = false;
var singlePlayer: bool = false;

var characterNames: Array[String] = [];

signal onCharacterPressed(character);
signal startGame;
signal exitCharacterSelect;

var timer = 0.0;
var msTimer = 0;
var timeInSeconds = 60;

func _ready() -> void:
	_generate_characters();

	for character in characterList.get_children():
		var charName = character.name;
		var button: Button = character.get_node("Button");
		button.pressed.connect(_on_character_pressed.bind(charName, button))

		var hexagon: TextureRect = character.get_node("Hexagon");
		button.mouse_entered.connect(_on_character_hover.bind(button, hexagon, true))
		button.mouse_exited.connect(_on_character_hover.bind(button, hexagon, false))

	if (singlePlayer):
		$StartButton.visible = true;
		$StartButton.disabled = true;
		$StartButton.pressed.connect(_on_start_button_pressed);
		$QuitButton.visible = true;
		$QuitButton.pressed.connect(_on_quit_button_pressed);

		$MultiplayerOnly.visible = false;

func _generate_characters() -> void:
	characterNames = _get_character_names();

	var template = characterList.get_node("CharacterTemplate");
	template.visible = false;

	for i in characterNames.size():
		var character = template.duplicate();
		character.name = characterNames[i];
		_set_character_splash(character, characterNames[i]);
		character.get_node("CharacterName").text = _display_name(characterNames[i]);
		character.visible = true;

		var hexagon: TextureRect = character.get_node("Hexagon");
		hexagon.material = hexagon.material.duplicate();
		character.set_meta("hexagon_modulate", hexagon.modulate);
		character.set_meta("splash_modulate", character.get_node("CharacterSplash").modulate);

		characterList.add_child(character);

	template.free();

	_position_characters();

func _get_character_names() -> Array[String]:
	var names: Array[String] = [];
	var dir = DirAccess.open(CHARACTER_FOLDER);
	if (dir == null):
		push_error("[character_select]: could not open characters folder %s" % CHARACTER_FOLDER);
		return names;

	dir.list_dir_begin();
	var entry = dir.get_next();
	while (entry != ""):
		if (dir.current_is_dir() and entry != "." and entry != ".."):
			names.append(entry);
		entry = dir.get_next();

	return names;

func _display_name(folder: String) -> String:
	if (CHARACTER_DISPLAY_NAMES.has(folder)):
		return CHARACTER_DISPLAY_NAMES[folder];
	return folder.capitalize();

func _set_character_splash(character: Control, folder: String) -> void:
	var texture = load("res://assets/sprites/%s.png" % folder);
	if (texture is Texture2D):
		character.get_node("CharacterSplash").texture = texture;

func _position_characters() -> void:
	var characters = characterList.get_children();
	var count = characters.size();
	if (count == 0):
		return;

	var viewportSize = characterScroll.size;
	var columns = CHARACTERS_PER_ROW;
	var rows = ceili(float(count) / float(columns));
	var cellWidth = viewportSize.x / float(columns);
	var cellHeight = viewportSize.y / float(VISIBLE_ROWS);
	var templateSize = characters[0].size;

	for i in count:
		var col = i % columns;
		var row = i / columns;
		var cellCenter = Vector2(
			cellWidth * col + cellWidth / 2.0,
			cellHeight * row + cellHeight / 2.0
		);
		characters[i].position = cellCenter - templateSize / 2.0;

	characterList.custom_minimum_size = Vector2(viewportSize.x, float(rows) * cellHeight);

func _process(delta: float) -> void:
	timer += delta;
	msTimer += delta;
	if not (singlePlayer) and (int(round(timer * 100)) % 32 == 0):
		updateTeams();
	
	if not (singlePlayer) and (msTimer >= 1):
		msTimer = 0;
		timeInSeconds -= 1;
		secondsRemaining.text = str(timeInSeconds);
	
	if (timeInSeconds <= 0 and not gameStarted):
		gameStarted = true;
		startGame.emit();

func updateTeams():
	for child in blackTeamContainer.get_children():
		child.queue_free();
	for child in whiteTeamContainer.get_children():
		child.queue_free();
	for character in characterList.get_children():
		_set_character_disabled(character, false);
	
	var playerList = Server.playersInfo;
	playersLength = 0;
	
	for playerId in playerList:
		var playerInfo = playerTemplate.duplicate();
		var player = playerList[playerId];
		playerInfo.name = str(player.playerID);
		playerInfo.get_node("PlayerUsername").text = player.username;
		playerInfo.visible = true;
		playersLength += 1;
		
		if (player.character):
			for character in characterList.get_children():
				if (character.name == player.character):
					_set_character_disabled(character, true);
			
			playerInfo.get_node("CharacterSplash").texture = load("res://assets/sprites/%s.png" % player.character);
		
		if (player.team == 0):
			blackTeamContainer.add_child(playerInfo);
		else:
			whiteTeamContainer.add_child(playerInfo);

func _set_character_disabled(character: Control, disabled: bool) -> void:
	var button: Button = character.get_node("Button");
	button.disabled = disabled;

	var hexagon: TextureRect = character.get_node("Hexagon");
	var splash: TextureRect = character.get_node("CharacterSplash");

	if (disabled):
		var hex = hexagon.modulate;
		hexagon.modulate = Color(hex.r, hex.g, hex.b, 50.0 / 255.0);
		var spl = splash.modulate;
		splash.modulate = Color(spl.r, spl.g, spl.b, 90.0 / 255.0);
	else:
		hexagon.modulate = character.get_meta("hexagon_modulate");
		splash.modulate = character.get_meta("splash_modulate");

func _on_character_hover(button: Button, hexagon: TextureRect, shaking: bool) -> void:
	if (button.disabled):
		return;

	if (hexagon.material is ShaderMaterial):
		hexagon.material.set_shader_parameter("shaking", shaking);

func _on_character_pressed(character: String, button: Button) -> void:
	if (selectedButton):
		_set_character_disabled(selectedButton.get_parent(), false);
	
	_set_character_disabled(button.get_parent(), true);
	selectedChar = character;
	selectedButton = button;

	if (singlePlayer):
		$StartButton.disabled = false;
	
	onCharacterPressed.emit(character);

func _on_start_button_pressed() -> void:
	if (selectedChar.is_empty() or gameStarted):
		return;

	gameStarted = true;
	startGame.emit();

func _on_quit_button_pressed() -> void:
	exitCharacterSelect.emit();
