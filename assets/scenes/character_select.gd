extends Control

@onready var whiteTeamContainer = $WhiteTeamContainer;
@onready var blackTeamContainer = $BlackTeamContainer;
@onready var playerTemplate = $PlayerTemplate;
@onready var characterList = $Characters;
@onready var secondsRemaining = $secondsRemaining;

var playersLength = 0;
var playersLockedIn = [];

var selectedChar = "";
var selectedButton: Button = null;
var gameStarted = false;

signal onCharacterPressed(character);
signal startGame;

var timer = 0.0;
var msTimer = 0;
var timeInSeconds = 60;

func _ready() -> void:
	for character in characterList.get_children():
		var charName = character.name;
		var button: Button = character.get_node("Button");
		button.pressed.connect(_on_character_pressed.bind(charName, button))

func _process(delta: float) -> void:
	timer += delta;
	msTimer += delta;
	if (int(round(timer * 100)) % 32 == 0):
		updateTeams();
	
	if (msTimer >= 1):
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
		var button: Button = character.get_node("Button");
		button.disabled = false;
	
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
					var button: Button = character.get_node("Button");
					button.disabled = true;
			
			playerInfo.get_node("CharacterSplash").texture = load("res://assets/sprites/%s.png" % player.character);
		
		if (player.team == 0):
			blackTeamContainer.add_child(playerInfo);
		else:
			whiteTeamContainer.add_child(playerInfo);

func _on_character_pressed(character: String, button: Button) -> void:
	if (selectedButton):
		selectedButton.disabled = false;
	
	button.disabled = true;
	selectedButton = button;
	
	onCharacterPressed.emit(character);
