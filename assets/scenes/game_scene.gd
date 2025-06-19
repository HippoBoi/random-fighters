extends Node3D

var totalPlayers = 0;
var playerId = 0;
var addedCharacters = [];
var currentGameMode = "";

const BLACK_TEAM = 0;
const WHITE_TEAM = 1;
var blackTeamWins = 0;
var whiteTeamWins = 0;
var pointsToWin = 3;
var teamThatHasWon = -1;

var gameOver = false;
var DEBUG = false;

signal gameModeSelected(gamemode);
signal roundVictory(team);
signal syncTeamWins(blackTeamWins, whiteTeamWins);
signal teamWonGame(teamThatHasWon);

func _ready() -> void:
	if (currentGameMode.is_empty()):
		_selectGameMode();
	
	spawnPlayers();
	
func _process(_delta: float) -> void:	
	if (Input.is_action_pressed("tab")):
		$InGameUI/playerList.visible = true;
	else:
		$InGameUI/playerList.visible = false;

func startGameMode(gameMode: String):
	var newMap = null;
	
	currentGameMode = gameMode;
	PlayerFunc.gameMode = gameMode;
	
	_clearMap();
	
	if (gameMode.to_lower() == "free_for_all"):
		newMap = preload("res://assets/maps/battlefield.tscn").instantiate();
		
	elif (gameMode.to_lower() == "foggy_vision"):
		newMap = preload("res://assets/maps/dark_forest.tscn").instantiate();
	
	$Map.add_child(newMap);
	
	await get_tree().create_timer(0.5).timeout;
	
	for _playerId in Server.playersInfo:
		var player = Server.playersInfo[_playerId];
		var character = player.charInstance;
		PlayerFunc.spawnCharacter(character);
	
	var isScene = has_node("choosingMode");
	if (isScene):
		var choosingMode = get_node("choosingMode");
		choosingMode.queue_free();
	
	_introSequence(gameMode)

func _introSequence(gameMode):
	var description: String = _getModeDescription(gameMode);
	var camStartingPos = Vector3(4.8, 9.0, 4.0);
	
	PlayerFunc.tweenCameraToChar(camStartingPos);
	
	$GameInfoUI.visible = true;
	$GameInfoUI/Description.text = description;
	$GameInfoUI/Title.modulate = Color(0, 0, 0, 0);
	$GameInfoUI/Description.modulate = Color(0, 0, 0, 0);
	$GameInfoUI/Panel.modulate = Color(1, 1, 1, 1);
	$GameInfoUI/Panel.scale = Vector2(0.1, 1.0);
	
	await get_tree().create_timer(0.5).timeout;
	
	var tween = get_tree().create_tween();
	tween.tween_property($GameInfoUI/Title, "modulate", Color(1, 1, 1, 1), 1.0);
	await get_tree().create_timer(0.5).timeout;
	tween = get_tree().create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT);
	tween.tween_property($GameInfoUI/Panel, "scale", Vector2(1.0, 1.0), 1.0);
	await get_tree().create_timer(0.25).timeout;
	tween = get_tree().create_tween();
	tween.tween_property($GameInfoUI/Description, "modulate", Color(1, 1, 1, 1), 1.0);
	
	await get_tree().create_timer(3.0).timeout;
	tween = get_tree().create_tween().set_parallel();
	tween.tween_property($GameInfoUI/Title, "modulate", Color(1, 1, 1, 0), 0.6);
	tween.tween_property($GameInfoUI/Panel, "modulate", Color(1, 1, 1, 0), 0.6);
	tween.tween_property($GameInfoUI/Description, "modulate", Color(1, 1, 1, 0), 0.75);
	
	await get_tree().create_timer(1.5).timeout;
	PlayerFunc.gameStarted = true;

func setGameMode(gameMode: String):
	currentGameMode = gameMode;
	var isNode = has_node("choosingMode");
	if (isNode):
		var choosingMode = get_node("choosingMode");
		choosingMode.selectedGameMode = gameMode;

func _selectGameMode():
	var choosingMode = preload("res://assets/scenes/choosing_mode.tscn").instantiate();
	choosingMode.playerId = playerId;
	choosingMode.blackTeamWins = blackTeamWins;
	choosingMode.whiteTeamWins = whiteTeamWins;
	choosingMode.pointsToWin = pointsToWin;
	choosingMode.set_gamemode.connect(func(selectedMode: String):
		gameModeSelected.emit(selectedMode);
	);
	choosingMode.DEBUG = DEBUG;
	add_child(choosingMode);

func _clearMap():
	for child in $Map.get_children():
		child.queue_free();

func _getModeDescription(gameMode: String):
	var description = "uhhh you gotta win!";
	if (gameMode.to_lower() == "free_for_all"):
		description = "Eliminate the other team!"
	elif (gameMode.to_lower() == "foggy_vision"):
		description = "Eliminate the other team!"
	elif (gameMode.to_lower() == "hippo_capture"):
		description = "Capture 5 Hippos"
	
	return description;

func spawnPlayers():
	for playerID in Server.playersInfo:
		await get_tree().create_timer(.25).timeout;
		
		var player = Server.playersInfo[playerID];
		addCharacter(player, playerID);
		
		# print("player loaded: ", player.username, " ID: ", playerID);

func addCharacter(player, _playerId):
	var mapNode = get_node("Map");
	var map = mapNode.get_child(0);
	var spawnLocations = map.get_node("spawnLocations");

	if not (spawnLocations):
		print("[WARNING]: spawn locations not found");
		return;
	
	var character = player.charInstance;
	var charInstance = character.instantiate();
	
	if (addedCharacters.find(charInstance) != -1):
		print("player %s already spawned character" % player.username);
		return;
	
	addedCharacters.insert(len(addedCharacters), charInstance);
	
	charInstance.set_multiplayer_authority(_playerId);
	charInstance.team = player.team;
	add_child(charInstance);
	
	var spawn: Node3D = null
	if (player.team == 0):
		spawn = spawnLocations.get_node("blackTeam");
	elif (player.team == 1):
		spawn = spawnLocations.get_node("whiteTeam");
	
	if (spawn):
		charInstance.global_position = spawn.global_position;
	else:
		print("[WARNING]: %s does not have a team (is spectator?)" % player.username);
	
	player.charInstance = charInstance;
	
	updatePlayerList();

func updatePlayerList():
	totalPlayers = 0;
	
	for oldPlayer in $InGameUI/playerList.get_children():
		oldPlayer.queue_free();
		
	for playerID in Server.playersInfo:
		totalPlayers += 1;
		
		var newText = Label.new();
		var newPlayer = Server.playersInfo[playerID];
		newText.name = newPlayer.username;
		newText.text = newPlayer.username;
		newText.position = Vector2(20, 20 + (totalPlayers - 1) * 25);
		$InGameUI/playerList.add_child(newText);

func _playRoundEndAnimation(winnerTeam: int):
	var ggText: Label = $RoundEndUI/GG;
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_BACK);
	var winnerTeamText = "Black" if winnerTeam == 0 else "White";
	
	$RoundEndUI.visible = true;
	$RoundEndUI/Description.text = winnerTeamText + " team wins this round!!!"
	$RoundEndUI/Description.modulate = Color(1, 1, 1, 0);
	
	ggText.add_theme_font_size_override("font_size", 500);
	tween.tween_property(ggText, "theme_override_font_sizes/font_size", 50, 0.25);
	
	var newSound = AudioStreamPlayer.new();
	add_child(newSound);
	
	newSound.stream = preload("res://assets/sounds/GG_sound_effect.ogg");
	newSound.pitch_scale = randf();
	newSound.pitch_scale = clamp(newSound.pitch_scale, 0.55, 1.75);
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);
	
	await get_tree().create_timer(0.5).timeout;
	
	tween = get_tree().create_tween();
	tween.tween_property($RoundEndUI/Description, "modulate", Color(1, 1, 1, 1), 0.5);
	
	await get_tree().create_timer(6.0).timeout;
	var transition = preload("res://assets/scenes/transition_scene.tscn").instantiate();
	transition.transition_finished.connect(func():
		transition.queue_free();
	);
	add_child(transition);
	
	await get_tree().create_timer(0.5).timeout;
	$RoundEndUI.visible = false;
	
	if not (gameOver):
		_selectGameMode();
	else:
		print("[WARNING]: GAME HAS OVER!!");

func onRoundVictory(winnerTeam: int):
	PlayerFunc.gameStarted = false;
	_playRoundEndAnimation(winnerTeam);
	
	var isHost = playerId == 1;
	if (isHost):
		if (winnerTeam == BLACK_TEAM):
			blackTeamWins += 1;
		else:
			whiteTeamWins += 1;
		
		syncTeamWins.emit(blackTeamWins, whiteTeamWins);
	
		print("[SERVER]: BLACK WINS: ", blackTeamWins);
		print("[SERVER]: WHITE WINS: ", whiteTeamWins);
		
		if (blackTeamWins >= pointsToWin):
			teamThatHasWon = BLACK_TEAM;
			teamWonGame.emit(teamThatHasWon);
		if (whiteTeamWins >= pointsToWin):
			teamThatHasWon = WHITE_TEAM;
			teamWonGame.emit(teamThatHasWon);

func get_character_by_id(playerId: String):
	var charLookingFor = null;
	for character in addedCharacters:
		if (character.name == playerId):
			charLookingFor = character;
	
	if not (charLookingFor):
		print("[WARNING]: couldn't find character");
		return null;
	
	return charLookingFor;

func endGame(_teamThatHasWon: int):
	gameOver = true;
	teamThatHasWon = _teamThatHasWon;
	print("THIS TEAM: %s HAS WON THE GAAEEMMM" % _teamThatHasWon);
