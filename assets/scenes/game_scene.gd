extends Node3D

var totalPlayers = 0;
var playerId = 0;
var myCharacter = null;
var addedCharacters = [];
var currentGameMode = "";

const BLACK_TEAM = 0;
const WHITE_TEAM = 1;
var blackTeamWins = 0;
var whiteTeamWins = 0;
var pointsToWin = 3;
var teamThatHasWon = -1;

var userPreferences: UserPreferences;

var gameOver = false;
var DEBUG = false;

signal gameModeSelected(gamemode);
signal roundVictory(team);
signal syncTeamWins(blackTeamWins, whiteTeamWins);
signal teamWonGame(teamThatHasWon);
signal returnToLobby;

func _ready() -> void:
	if (currentGameMode.is_empty()):
		_selectGameMode();

	userPreferences = UserPreferences.loadOrCreate();
	$OptionsUI/ScrollContainer/VBoxContainer/wasd/CheckBox.button_pressed = userPreferences.wasdMovement;
	$OptionsUI/ScrollContainer/VBoxContainer/music/musicSlider.value = userPreferences.musicVolume;
	$OptionsUI/ScrollContainer/VBoxContainer/sounds/soundsSlider.value = userPreferences.soundsVolume;

	spawnPlayers();

func _process(_delta: float) -> void:
	if (Input.is_action_pressed("tab")):
		$InGameUI/playerList.visible = true;
	else:
		$InGameUI/playerList.visible = false;

	if (Input.is_action_just_pressed("closeMenu")):
		PlayerFunc.optionsToggle();

func startGameMode(gameMode: String):
	var newMap = null;
	var minimapCamera: Camera3D = $MinimapUI/SubViewport/Camera3D;

	currentGameMode = gameMode;
	PlayerFunc.gameMode = gameMode;

	_clearMap();

	if (gameMode.to_lower() == "free_for_all"):
		newMap = preload("res://assets/maps/battlefield.tscn").instantiate();
		minimapCamera.size = 55.0;

	elif (gameMode.to_lower() == "foggy_vision"):
		newMap = preload("res://assets/maps/dark_forest.tscn").instantiate();
		minimapCamera.size = 47.938;

	elif (gameMode.to_lower() == "hippo_capture"):
		newMap = preload("res://assets/maps/lake.tscn").instantiate();
		minimapCamera.size = 75.0;

	elif (gameMode.to_lower() == "doom_bot"):
		newMap = preload("res://assets/maps/electric_central.tscn").instantiate();
		minimapCamera.size = 75.0;

	elif (gameMode.to_lower() == "snowmen"):
		newMap = preload("res://assets/maps/snowmen.tscn").instantiate();
		minimapCamera.size = 105.0;

	elif (gameMode.to_lower() == "arena"):
		newMap = preload("res://assets/maps/arena.tscn").instantiate();
		minimapCamera.size = 75.0;

	elif (gameMode.to_lower() == "trainwreck"):
		newMap = preload("res://assets/maps/trainwreck.tscn").instantiate();
		minimapCamera.size = 45.0;

	elif (gameMode.to_lower() == "heaven"):
		newMap = preload("res://assets/maps/heaven.tscn").instantiate();
		minimapCamera.size = 65.0;

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
		description = "Watch your step...!"
	elif (gameMode.to_lower() == "hippo_capture"):
		description = "Capture the Hippo!"
	elif (gameMode.to_lower() == "doom_bot"):
		description = "Survive...!"
	elif (gameMode.to_lower() == "snowmen"):
		description = "Destroy enemy snowman!"
	elif (gameMode.to_lower() == "arena"):
		description = "Stay in the area!"
	elif (gameMode.to_lower() == "trainwreck"):
		description = "Look both ways...!"
	elif (gameMode.to_lower() == "heaven"):
		description = "Eliminate the other team!"

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
		return null;

	var character = player.charInstance;
	var charInstance = character.instantiate();

	if (addedCharacters.find(charInstance) != -1):
		print("player %s already spawned character" % player.username);
		return null;

	addedCharacters.insert(len(addedCharacters), charInstance);

	charInstance.set_multiplayer_authority(_playerId);
	charInstance.team = player.team;
	add_child(charInstance);

	var spawn: Node3D = null;
	if (player.team == 0):
		spawn = spawnLocations.get_node("blackTeam");
	elif (player.team == 1):
		spawn = spawnLocations.get_node("whiteTeam");

	if (spawn):
		charInstance.global_position = spawn.global_position;
	else:
		print("(gameScene)[WARNING]: %s does not have a team (is spectator?)" % player.username);

	player.charInstance = charInstance;

	updatePlayerList();

func updatePlayerList():
	totalPlayers = 0;

	for oldPlayer in $InGameUI/playerList.get_children():
		if (oldPlayer.name == "templates"):
			continue ;

		oldPlayer.queue_free();

	var team0 = [];
	var team1 = [];

	for playerID in Server.playersInfo:
		var player = Server.playersInfo[playerID];
		if (player.team == 0):
			team0.append(playerID);
		else:
			team1.append(playerID);

	var sortedPlayers = team0 + team1;
	var index = 0;

	for playerID in sortedPlayers:
		index += 1;

		var playerList = $InGameUI/playerList;
		var templates = playerList.get_node("templates");
		var playerLabel = templates.get_node_or_null("playerLabel");
		var playerIcon = templates.get_node_or_null("playerIcon");
		var kdaLabel = templates.get_node_or_null("kdaLabel");

		if not (playerLabel and playerIcon):
			push_warning("player ID: %s failed to update in player list" % playerID);
			continue ;

		var newText = playerLabel.duplicate();
		var newIcon = playerIcon.duplicate();
		var newKda = kdaLabel.duplicate();
		var newPlayer = Server.playersInfo[playerID];
		var characterIcon = load("res://assets/sprites/character_icons/%s_icon.png" % newPlayer.character);

		var yDistance = 25;
		var yPos = 10 + (index - 1) * yDistance;

		var bg = ColorRect.new();
		bg.position = Vector2(10, yPos - 2);
		bg.size.x = playerList.size.x
		bg.size.y = 24
		bg.position.y = yPos - 2
		bg.position.x = 0

		if (newPlayer.team == 0):
			bg.color = Color(0.1, 0.4, 1.0, 0.25);
		else:
			bg.color = Color(1.0, 0.2, 0.1, 0.25);

		playerList.add_child(bg);

		if (characterIcon):
			newIcon.texture = characterIcon;
			newIcon.position = Vector2(20, yPos - 7);
			newIcon.visible = true;
			playerList.add_child(newIcon);

		newKda.text = "%d / %d / %d" % [newPlayer.kills, newPlayer.deaths, newPlayer.assists];
		newKda.position = Vector2(204, yPos - 4);
		newKda.visible = true;

		newText.name = newPlayer.username;
		newText.text = newPlayer.username;
		newText.position = Vector2(60, yPos);
		newText.visible = true;

		playerList.add_child(newKda);
		playerList.add_child(newText);

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
		_endGameScreen(teamThatHasWon);

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

		if (blackTeamWins >= pointsToWin):
			teamThatHasWon = BLACK_TEAM;
			teamWonGame.emit(teamThatHasWon);
		if (whiteTeamWins >= pointsToWin):
			teamThatHasWon = WHITE_TEAM;
			teamWonGame.emit(teamThatHasWon);

func get_character_by_id(_playerId: String):
	var charLookingFor = null;
	for character in addedCharacters:
		if (character.name == _playerId):
			charLookingFor = character;

	if not (charLookingFor):
		print("(gameScene)[WARNING]: couldn't find character");
		return null;

	return charLookingFor;

func endGame(_teamThatHasWon: int):
	gameOver = true;
	teamThatHasWon = _teamThatHasWon;

func _endGameScreen(_teamThatHasWon):
	var character = get_character_by_id(str(playerId));
	var gameOverScene = preload("res://assets/scenes/end_game.tscn").instantiate();
	add_child(gameOverScene);

	gameOverScene.playerId = playerId;
	gameOverScene.returnToLobby.connect(func():
		returnToLobby.emit();
	);

	var winnersNode = gameOverScene.get_node("Winners");
	var winnersContainer = winnersNode.get_node("WinnersContainer");
	var winnerTeamText = winnersNode.get_node("TeamColor");
	var statusText = gameOverScene.get_node("statusText");
	var loopingStatusText = gameOverScene.get_node("loopingStatus");

	for _playerId in Server.playersInfo:
		var playerData = Server.playersInfo[_playerId];
		var playerChar = get_character_by_id(str(_playerId));
		if (playerChar.team == _teamThatHasWon):
			var newName: RichTextLabel = winnersContainer.get_node("Template").duplicate();
			winnersContainer.add_child(newName);

			newName.text = str(playerData.username);
			newName.visible = true;

	if (_teamThatHasWon == 0):
		winnerTeamText.text = "Black Team";
	else:
		winnerTeamText.text = "White Team";

	if (character.team == _teamThatHasWon):
		statusText.text = "[b]Victory[b]";
		statusText.modulate = Color(0.5, 1.0, 1.0);
		loopingStatusText.text = "Victory";
	else:
		statusText.text = "[b]Defeat[b]";
		statusText.modulate = Color(1.0, 0.25, 0.0);
		loopingStatusText.text = "Defeat";

func _on_shop_button_pressed() -> void:
	PlayerFunc.shopToggle(myCharacter);

func _on_save_and_exit_pressed() -> void:
	PlayerFunc.optionsToggle();

	if (userPreferences):
		userPreferences.save();

func _on_quit_game_pressed() -> void:
	if (userPreferences):
		userPreferences.save();

	PlayerFunc.optionsOpen = false;
	returnToLobby.emit();

func _on_check_box_toggled(toggled_on: bool) -> void:
	if (userPreferences):
		userPreferences.wasdMovement = toggled_on;

func _on_music_slider_value_changed(value: float) -> void:
	if (userPreferences):
		userPreferences.musicVolume = value;

func _on_sounds_slider_value_changed(value: float) -> void:
	if (userPreferences):
		userPreferences.soundsVolume = value;

func _on_reset_defaults() -> void:
	userPreferences.resetToDefaults();
