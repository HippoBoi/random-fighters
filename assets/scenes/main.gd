extends Node3D

var multiplayerPeer: ENetMultiplayerPeer = ENetMultiplayerPeer.new();
var norayNetwork: Node = null;

const LOCALHOST: String = "127.0.0.1";
const PORT: int = NetworkConfig.NORAY_PORT;
const ADDRESS: String = NetworkConfig.NORAY_ADDRESS;
const SINGLE_PLAYER_ID: int = 1;

var username: String = "noname";
var gameIdInput: String;
var curTeam: int = 0;
var curCharacter: String = "";
var curGameMode: String = "";
var curGameId: String = "";
var totalPlayers: int = 0;
var timer: float = 0;
var startRoundTimer: float = 0.0;

var playersLockedIn = [];
var selectedCharacters = [];

var connected = false;
var gameStarted = false;
var roundStarted = false;
var matchHasEnded = false;
var networkDisconnectInProgress = false;
var returnToLobbyInProgress = false;
var enetSignalsConnected = false;
var activeConnectionMode: String = "";
var singlePlayerMatch: bool = false;

var pendingDirectIp: String = "";
var pendingDirectPort: int = 0;
var directFallbackAttempted: bool = false;

var lobbyScene: Control = null;
var mainMenuOptionsUI = null;
var userPreferences: UserPreferences;

func _ready() -> void:
	userPreferences = UserPreferences.loadOrCreate()
	_loadSettings();

func _process(delta: float) -> void:
	if not (connected):
		return;
	if (startRoundTimer > 0 and roundStarted == false and not curGameMode.is_empty()):
		startRoundTimer -= delta;

		if (startRoundTimer <= 0.1):
			if (singlePlayerMatch):
				startRound(curGameMode);
			elif (multiplayer.is_server()):
				rpc("startRound", curGameMode);

	timer += delta;
	if not (singlePlayerMatch) and (int(round(timer * 100)) % 32 == 0):
		rpc("syncData", _getLocalPlayerId(), username, curTeam, curCharacter);

func _loadSettings():
	if not (userPreferences):
		return;

	var controls = userPreferences.controls;
	for action in controls:
		var event = controls[action];
		if (event == null):
			continue;

		InputMap.action_erase_events(action);
		InputMap.action_add_event(action, event);

func _on_name_input(new_text: String) -> void:
	username = new_text;

func _on_game_input_changed(new_text: String) -> void:
	gameIdInput = new_text;

func _on_options_pressed(_port: int = 8890, _username: String = "", _team: String = "0") -> void:
	if (Constants.DEBUG):
		_on_host(_port, _username, _team);
		return;

	if not (mainMenuOptionsUI and is_instance_valid(mainMenuOptionsUI)):
		mainMenuOptionsUI = preload("res://assets/scenes/options_ui.tscn").instantiate();
		add_child(mainMenuOptionsUI);
		mainMenuOptionsUI.setup();
		_connectMainMenuOptionsUI(mainMenuOptionsUI);
	else:
		mainMenuOptionsUI.update_control_labels();

	_syncMainMenuOptionsUI();
	mainMenuOptionsUI.visible = true;

func _connectMainMenuOptionsUI(optionsUI: Control) -> void:
	var saveButton: Button = optionsUI.get_node_or_null("Footer/Save") as Button;
	if not (saveButton):
		saveButton = optionsUI.get_node_or_null("Footer/SaveAndExit") as Button;
	if (saveButton):
		saveButton.pressed.connect(_on_main_menu_options_save_and_exit_pressed);

	var quitButton: Button = optionsUI.get_node_or_null("Footer/QuitGame") as Button;
	if (quitButton):
		quitButton.pressed.connect(_on_main_menu_options_save_and_exit_pressed);

	var exitButton: Button = optionsUI.get_node_or_null("Exit") as Button;
	if (exitButton):
		exitButton.pressed.connect(_on_main_menu_options_save_and_exit_pressed);

	var wasdCheckBox: CheckBox = optionsUI.get_node_or_null("ScrollContainer/VBoxContainer/wasd/CheckBox") as CheckBox;
	if (wasdCheckBox):
		wasdCheckBox.toggled.connect(_on_main_menu_options_wasd_toggled);

	var musicSlider: HSlider = optionsUI.get_node_or_null("ScrollContainer/VBoxContainer/music/musicSlider") as HSlider;
	if (musicSlider):
		musicSlider.value_changed.connect(_on_main_menu_options_music_slider_value_changed);

	var soundsSlider: HSlider = optionsUI.get_node_or_null("ScrollContainer/VBoxContainer/sounds/soundsSlider") as HSlider;
	if (soundsSlider):
		soundsSlider.value_changed.connect(_on_main_menu_options_sounds_slider_value_changed);

	var resetButton: Button = optionsUI.get_node_or_null("ScrollContainer/VBoxContainer/reset/ResetDefaults") as Button;
	if (resetButton):
		resetButton.pressed.connect(_on_main_menu_options_reset_defaults);

func _syncMainMenuOptionsUI() -> void:
	if not (userPreferences and mainMenuOptionsUI and is_instance_valid(mainMenuOptionsUI)):
		return;

	mainMenuOptionsUI.get_node("ScrollContainer/VBoxContainer/wasd/CheckBox").button_pressed = userPreferences.wasdMovement;
	mainMenuOptionsUI.get_node("ScrollContainer/VBoxContainer/music/musicSlider").value = userPreferences.musicVolume;
	mainMenuOptionsUI.get_node("ScrollContainer/VBoxContainer/sounds/soundsSlider").value = userPreferences.soundsVolume;
	mainMenuOptionsUI.update_control_labels();

func _on_main_menu_options_save_and_exit_pressed() -> void:
	if (userPreferences):
		userPreferences.save();

	if (mainMenuOptionsUI and is_instance_valid(mainMenuOptionsUI)):
		mainMenuOptionsUI.visible = false;

func _on_main_menu_options_wasd_toggled(toggled_on: bool) -> void:
	if (userPreferences):
		userPreferences.wasdMovement = toggled_on;

func _on_main_menu_options_music_slider_value_changed(value: float) -> void:
	if (userPreferences):
		userPreferences.musicVolume = value;

func _on_main_menu_options_sounds_slider_value_changed(value: float) -> void:
	if (userPreferences):
		userPreferences.soundsVolume = value;

func _on_main_menu_options_reset_defaults() -> void:
	if not (userPreferences):
		return;

	userPreferences.resetToDefaults();
	_loadSettings();
	_syncMainMenuOptionsUI();

func _on_host(_port: int = 0, _username: String = "", _team: String = "", isLocal := true) -> void:
	var useUPnP: bool = false;
	_resetConnectionState();
	_setSinglePlayerMatch(false);
	PlayerFunc.matchType = Constants.MatchTypes.Versus;

	if not (isLocal and Constants.DEBUG):
		if not (norayNetwork):
			norayNetwork = preload("res://assets/scenes/noray_network.tscn").instantiate();
			add_child(norayNetwork);

			norayNetwork.isClient = false;
			norayNetwork.setup(self);
			norayNetwork.startNorayHost.connect(startNorayHost);

		var norayResult = await norayNetwork.createServerPeer(ADDRESS);
		if (norayResult != OK):
			print("[main][WARNING]: NORAY HOST FAILED: %s. STARTING UPNP SERVER" % norayResult);

	if (not (norayNetwork) or norayNetwork.isHosting == false):
		print("[main][WARNING]: NORAY NETWORKING FAILED. STARTING UPNP SERVER");
		useUPnP = true;
		activeConnectionMode = "upnp";

		var upnpResult = _hostWithUPnP(_port);
		if (upnpResult != OK):
			print("[main][ERROR]: FAILED TO START UPNP SERVER: %s" % upnpResult);
			_returnFromMatchToLobby("host_failed");
			return;
	else:
		activeConnectionMode = "noray";

	username = _username;
	curTeam = int(_team);

	addPlayer(1);
	connected = true;

	_connectEnetSignals();

	if not (isLocal):
		var hostResult = lobbyScene.hostMatch(ADDRESS, PORT, curGameId, useUPnP);
		if (hostResult != OK):
			print("[main][ERROR]: FAILED TO ADVERTISE MATCH: %s" % hostResult);
			_returnFromMatchToLobby("host_failed");
			return;

	startCharacterSelect();

func _hostWithUPnP(_port):
	print("host...")
	multiplayerPeer.close();
	var response = multiplayerPeer.create_server(_port);
	if (response != OK):
		print("[main][ERROR]: failed to create upnp server: %s" % response);
		return response;
	multiplayer.multiplayer_peer = multiplayerPeer;
	return OK;

func _joinGame(ip := LOCALHOST, port := PORT, _gameId := curGameId, _username := "noname", _team := "1", _useUPnP := true):
	_resetConnectionState();
	_setSinglePlayerMatch(false);
	PlayerFunc.matchType = Constants.MatchTypes.Versus;
	username = _username;
	curTeam = int(_team);

	pendingDirectIp = ip;
	pendingDirectPort = port;
	directFallbackAttempted = false;

	if not (_useUPnP):
		activeConnectionMode = "noray";
		if not (norayNetwork):
			norayNetwork = preload("res://assets/scenes/noray_network.tscn").instantiate();
			add_child(norayNetwork);

			norayNetwork.isClient = true;
			norayNetwork.natConnection.connect(handleNatConnection);
			norayNetwork.relayConnection.connect(handleRelayConnection);
			norayNetwork.setup(self);

		_norayClientConnectAsync(ip, _gameId);
	else:
		print("USING UPNP TO JOIN: %s:%s" % [ip, port]);
		_joinDirect(ip, port);

	_connectEnetSignals();
	startCharacterSelect();

func _norayClientConnectAsync(ip: String, _gameId: String) -> void:
	norayNetwork.gameId = _gameId;
	var result = await norayNetwork.createClientPeer(ip, _gameId);
	if (result != OK):
		print("[main][WARNING]: NORAY CLIENT FAILED: %s. FALLING BACK TO DIRECT CONNECTION" % result);
		_fallbackToDirectConnection();

func _fallbackToDirectConnection() -> void:
	if (directFallbackAttempted):
		return;

	directFallbackAttempted = true;
	_joinDirect(pendingDirectIp, pendingDirectPort);

func _joinDirect(ip: String, port: int) -> void:
	if (ip.is_empty() or port <= 0):
		print("[main][ERROR]: cannot join directly, invalid address %s:%s" % [ip, port]);
		_returnFromMatchToLobby("connection_failed");
		return;

	print("[main]: JOINING DIRECTLY: %s:%s" % [ip, port]);
	activeConnectionMode = "direct";

	multiplayerPeer.close();
	var response = multiplayerPeer.create_client(ip, port);
	if (response != OK):
		print("[main][ERROR]: failed to create direct client: %s" % response);
		_returnFromMatchToLobby("connection_failed");
		return;

	multiplayer.multiplayer_peer = multiplayerPeer;

# this "joinPressed" function will double as the "singleplayer" button
# this sucks yes but i don't wanna change it's name since it is also used
# in the multiplayer logic
func _joinPressed(ip := LOCALHOST, port := PORT, _gameId := curGameId, _username := "noname", _team := "1", _useUPnP := true):
	if (Constants.DEBUG):
		_joinGame(ip, port, _gameId, _username, _team, _useUPnP);
		return;

func startHost(port: int, _username: String, _team: String, _isLocal: bool):
	print("CALL TO HOST ON PORT: %s" % port);
	_on_host(port, _username, _team, _isLocal);

	get_node("Lobby").visible = false;

func startClient(ip: String, port: int, _gameId: String, _username: String, _team: String, _useUPnP: bool):
	print("client joining: %s:%s, gameId: %s, useUPnP: %s" % [ip, port, _gameId, _useUPnP]);
	_joinGame(ip, port, _gameId, _username, _team, _useUPnP);

	get_node("Lobby").visible = false;

func _startSinglePlayerMatch(_username: String = "", _team: int = 0) -> void:
	_clearRoundData();
	_setSinglePlayerMatch(true);
	PlayerFunc.matchType = Constants.MatchTypes.Training;
	activeConnectionMode = "singleplayer";

	if not (_username.is_empty()):
		username = _username;
	curTeam = _team;

	addPlayer(SINGLE_PLAYER_ID);
	connected = true;

	startCharacterSelect();

func _setSinglePlayerMatch(enabled: bool) -> void:
	singlePlayerMatch = enabled;
	PlayerFunc.singlePlayer = enabled;

func _getLocalPlayerId() -> int:
	if (singlePlayerMatch):
		return SINGLE_PLAYER_ID;

	return multiplayer.get_unique_id();

func _isValidCharacter(character: String) -> bool:
	if (character.is_empty()):
		return false;
	if (character.contains("/") or character.contains("\\") or character.contains("..")):
		return false;

	return ResourceLoader.exists("res://assets/characters/%s/%s.tscn" % [character, character]);

func addCharacter(playerID, character = ""):
	if not (_isValidCharacter(character)):
		return;

	var preloadedCharacter = null;
	var path = "res://assets/characters/%s/%s.tscn" % [character, character];
	preloadedCharacter = load(path);
	if (preloadedCharacter == null):
		return;

	var selectedChar = preloadedCharacter.instantiate();
	var playerList = Server.playersInfo;
	playerList[playerID].charInstance = selectedChar;

	selectedChar.set_multiplayer_authority(playerID);
	add_child(selectedChar);

func preloadCharacter(playerId, character: String = ""):
	if not (_isValidCharacter(character)):
		return;

	var preloadedCharacter = null;
	var path = "res://assets/characters/%s/%s.tscn" % [character, character];
	preloadedCharacter = load(path);
	if (preloadedCharacter == null):
		return;

	var selectedChar = preloadedCharacter;
	var playerList = Server.playersInfo;
	playerList[playerId].charInstance = selectedChar;

func _selectCharacter(character):
	var playerId = _getLocalPlayerId();
	curCharacter = character;

	if (singlePlayerMatch):
		updateSelectedCharacter(playerId, character);
	else:
		rpc("updateSelectedCharacter", playerId, character);

func startCharacterSelect() -> void:
	$UI.visible = false;

	var charSelect = preload("res://assets/scenes/characterSelect.tscn").instantiate();
	charSelect.singlePlayer = singlePlayerMatch;
	charSelect.onCharacterPressed.connect(_selectCharacter);
	charSelect.startGame.connect(onStartGame);
	charSelect.exitCharacterSelect.connect(_onExitSinglePlayerCharacterSelect);
	add_child(charSelect);

func _onExitSinglePlayerCharacterSelect() -> void:
	if not (singlePlayerMatch):
		return;

	if (has_node("CharSelect")):
		get_node("CharSelect").queue_free();

	_clearRoundData();

func returnToLobby():
	var isLobby = has_node("Lobby");
	var lobby = null;
	if not (isLobby):
		return;

	$UI.playIntro();

	await get_tree().create_timer(0.25).timeout;
	lobby = get_node("Lobby");
	lobby.queue_free();

func _resetConnectionState():
	matchHasEnded = false;
	networkDisconnectInProgress = false;
	returnToLobbyInProgress = false;

func _connectEnetSignals():
	if (enetSignalsConnected):
		return;

	multiplayer.peer_connected.connect(_onPeerConnected);
	multiplayer.peer_disconnected.connect(_onPeerDisconnected);
	multiplayer.connected_to_server.connect(_onConnectedToServer);
	multiplayer.connection_failed.connect(_onConnectionFailed);
	multiplayer.server_disconnected.connect(_onServerDisconnected);
	enetSignalsConnected = true;

func _disconnectEnetSignals():
	if not (enetSignalsConnected):
		return;

	if (multiplayer.peer_connected.is_connected(_onPeerConnected)):
		multiplayer.peer_connected.disconnect(_onPeerConnected);
	if (multiplayer.peer_disconnected.is_connected(_onPeerDisconnected)):
		multiplayer.peer_disconnected.disconnect(_onPeerDisconnected);
	if (multiplayer.connected_to_server.is_connected(_onConnectedToServer)):
		multiplayer.connected_to_server.disconnect(_onConnectedToServer);
	if (multiplayer.connection_failed.is_connected(_onConnectionFailed)):
		multiplayer.connection_failed.disconnect(_onConnectionFailed);
	if (multiplayer.server_disconnected.is_connected(_onServerDisconnected)):
		multiplayer.server_disconnected.disconnect(_onServerDisconnected);

	enetSignalsConnected = false;

func _onPeerConnected(newPlayerID):
	if not (multiplayer.is_server()):
		return;

	rpc("addPlayer", newPlayerID);
	rpc_id(newPlayerID, "addPreviousPlayers", Server.playersInfo);
	addPlayer(newPlayerID);

func _onPeerDisconnected(playerID):
	if not (multiplayer.is_server()):
		return;

	rpc("disconnectPlayer", playerID);

func _onConnectedToServer():
	connected = true;

func _onConnectionFailed():
	_returnFromMatchToLobby("connection_failed");

func _onServerDisconnected():
	if (matchHasEnded or networkDisconnectInProgress):
		return;

	_returnFromMatchToLobby("server_disconnected");

func onStartGame() -> void:
	if (singlePlayerMatch):
		startGame();
	else:
		rpc("startGame");

func onFindMatch():
	$UI.playLeave();

	var randomID = str(randi() % 1000);
	var fakeUser = {
		"playerId": randomID,
		"username": username,
		"rank": 1000
	};

	lobbyScene = preload("res://assets/scenes/lobby.tscn").instantiate();
	lobbyScene.fakeUser = fakeUser;
	lobbyScene.returnToLobby.connect(returnToLobby);
	lobbyScene.startHost.connect(startHost);
	lobbyScene.startClient.connect(startClient);

	add_child(lobbyScene);

func _gameModeSelected(gameMode: String):
	curGameMode = gameMode;

	if (singlePlayerMatch):
		startRoundTimer = 10.0;
		if (Constants.DEBUG):
			startRoundTimer = 2.0;
		updateGameMode(gameMode);
		return;

	if (multiplayer.is_server()):
		_startRoundCountdown(gameMode);
	else:
		rpc_id(1, "requestModeSelect", gameMode);

func _startRoundCountdown(gameMode: String):
	curGameMode = gameMode;
	rpc("updateGameMode", gameMode);

	if (startRoundTimer > 0 or roundStarted):
		return;

	startRoundTimer = 10.0;
	if (Constants.DEBUG):
		startRoundTimer = 2.0;

@rpc("any_peer", "call_remote")
func requestModeSelect(gameMode: String):
	if not (multiplayer.is_server()):
		return;

	_startRoundCountdown(gameMode);

func _onRoundVictory(winnerTeam: int):
	rpc("syncRoundVictory", winnerTeam);

func _onSyncTeamWins(blackTeamWins: int, whiteTeamWins: int):
	rpc("syncTeamWins", blackTeamWins, whiteTeamWins);

func _onTeamWonGame(_teamThatWon: int):
	rpc("teamHasWon", _teamThatWon);

func _onReturnToLobby():
	_returnFromMatchToLobby("manual_return");

func _disconnectMatchNetwork(reason: String = ""):
	if (networkDisconnectInProgress):
		return;

	networkDisconnectInProgress = true;
	connected = false;
	roundStarted = false;
	startRoundTimer = 0.0;

	if (lobbyScene and is_instance_valid(lobbyScene) and lobbyScene.has_method("cleanupUPnPMapping")):
		lobbyScene.cleanupUPnPMapping();

	if (multiplayerPeer):
		multiplayerPeer.close();

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new();
	_disconnectEnetSignals();

	if (norayNetwork and is_instance_valid(norayNetwork)):
		norayNetwork.queue_free();
	norayNetwork = null;
	activeConnectionMode = "";
	pendingDirectIp = "";
	pendingDirectPort = 0;
	directFallbackAttempted = false;

	print("match network disconnected: %s" % reason);

func _returnFromMatchToLobby(reason: String = ""):
	if (returnToLobbyInProgress):
		return;

	returnToLobbyInProgress = true;
	_disconnectMatchNetwork(reason);

	var isScene = has_node("Game");
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.queue_free();

	_clearRoundData();
	returnToLobby();

func _clearRoundData():
	connected = false;
	gameStarted = false;
	roundStarted = false;
	matchHasEnded = false;
	networkDisconnectInProgress = false;
	returnToLobbyInProgress = false;
	activeConnectionMode = "";
	pendingDirectIp = "";
	pendingDirectPort = 0;
	directFallbackAttempted = false;
	_setSinglePlayerMatch(false);
	curTeam = -1;
	curCharacter = "";
	curGameMode = "";
	curGameId = "";
	totalPlayers = 0;
	timer = 0;
	startRoundTimer = 0.0;
	playersLockedIn = [];
	selectedCharacters = [];
	Server.playersInfo = {};
	PlayerFunc.gameStarted = false;
	PlayerFunc.freeCam = false;
	PlayerFunc.shopOpen = false;
	PlayerFunc.optionsOpen = false;
	PlayerFunc.myCharacter = null;
	PlayerFunc.myFogInstances = [];
	PlayerFunc.maxHpStored = {};
	PlayerFunc.tokensStored = {};

	$UI.visible = true;

func startNorayHost():
	if (Noray.local_port < 0):
		print("[main][ERROR]: cannot start host, noray local port not registered: %s" % Noray.local_port);
		return;

	var response = multiplayerPeer.create_server(Noray.local_port);
	if (response != OK):
		print("failed to start host: %s, %s" % [Noray.local_port, response]);
		return;

	multiplayer.multiplayer_peer = multiplayerPeer;
	norayNetwork.isHosting = true;
	print("HOST SUCCESS!!!!!")

func connectToNorayHost(address: String, port: int):
	if (Noray.local_port < 0):
		print("[main][ERROR]: cannot connect via noray, local port not registered");
		return ERR_UNCONFIGURED;

	var udp = PacketPeerUDP.new();
	udp.bind(Noray.local_port);
	udp.set_dest_address(address, port);

	var response = await PacketHandshake.over_packet_peer(udp);
	udp.close();

	if (response != OK):
		print("client packet handshake failed: %s" % response);
		return response;

	response = multiplayerPeer.create_client(address, port, 0, 0, 0, Noray.local_port);

	if (response != OK):
		print("failed create client");
		return response;

	multiplayer.multiplayer_peer = multiplayerPeer;
	_connectEnetSignals();
	return OK;

func handleNatConnection(address: String, port: int):
	print("attempting nat connection %s:%s" % [address, port]);

	var response = await connectToNorayHost(address, port);
	if (response != OK):
		print("[ERROR]: NAT CONNECTION FAILED.")
		_fallbackToDirectConnection();
		return response;

	print("NAT CONNECTION SUCCESSFUL");
	return response;

func handleRelayConnection(address: String, port: int):
	var response = await connectToNorayHost(address, port);
	if (response != OK):
		print("[ERROR]: RELAY CONNECTION FAILED.")
		var natResult = norayNetwork.useNatConnection(norayNetwork.gameId);
		if (natResult != OK):
			print("[main][WARNING]: FAILED TO REQUEST NAT CONNECTION: %s. FALLING BACK TO DIRECT" % natResult);
			_fallbackToDirectConnection();
		return response;

	print("CONNECTION SUCCESS!!!")
	return response;

func setupClientNorayConnection():
	Noray.on_connect_nat.connect(handleNatConnection);
	Noray.on_connect_relay.connect(handleRelayConnection);

func setupClientEnetConnection():
	_connectEnetSignals();

func _norrayServerDisconnected():
	_onServerDisconnected();

@rpc("authority")
func addNewPlayerCharacter(newPlayerID):
	addCharacter(newPlayerID);

@rpc("authority", "call_local")
func addPlayer(playerId):
	var character = null;
	var myTeam = 0;

	if (playerId == _getLocalPlayerId()):
		myTeam = curTeam;
		connected = true;

	var playerInfo = PlayerData.new(playerId, username, character, character, myTeam);
	Server.playersInfo[playerId] = playerInfo;

@rpc("call_local", "any_peer")
func updateSelectedCharacter(playerId, character: String):
	var remoteSender = multiplayer.get_remote_sender_id();
	if (remoteSender != 0 and remoteSender != playerId):
		print("[main][WARNING]: rejected spoofed character selection from peer %s for player %s" % [remoteSender, playerId]);
		return;

	if not (_isValidCharacter(character)):
		return;

	var playerList = Server.playersInfo;
	var charSelect = null;

	if not (playerList.has(playerId)):
		return;

	if (has_node("CharSelect")):
		charSelect = get_node("CharSelect");

	playerList[playerId].character = character;
	selectedCharacters.insert(len(selectedCharacters), character);

	var findLockedPlayer = playersLockedIn.find(playerId);
	var hasPlayerLocked = true if findLockedPlayer != -1 else false;
	if (not (hasPlayerLocked) and not character.is_empty()):
		playersLockedIn.insert(len(playersLockedIn), playerId);

	if (charSelect and len(playersLockedIn) >= len(playerList)):
		if (charSelect.timeInSeconds > 10):
			charSelect.timeInSeconds = 10;

			if (Constants.DEBUG):
				charSelect.timeInSeconds = 2;

	if (charSelect):
		if not (singlePlayerMatch):
			charSelect.updateTeams();
		preloadCharacter(playerId, character);

@rpc("any_peer")
func syncData(playerId, _username, _team, _character):
	var remoteSender = multiplayer.get_remote_sender_id();
	if (remoteSender != 0 and remoteSender != playerId):
		print("[main][WARNING]: rejected spoofed syncData from peer %s for player %s" % [remoteSender, playerId]);
		return;

	var playerList = Server.playersInfo;

	if (playerList.has(playerId)):
		playerList[playerId].username = _username;
		playerList[playerId].team = _team;
		updateSelectedCharacter(playerId, _character);
	else:
		print("couldnt find player, adding it to list");
		var character = null;
		var playerInfo = PlayerData.new(playerId, _username, character, character, _team);
		Server.playersInfo[playerId] = playerInfo;

@rpc("authority")
func addPreviousCharacters(playersList):
	for playerID in playersList.keys():
		addCharacter(playerID);

@rpc("authority")
func addPreviousPlayers(playersList):
	for playerID in playersList.keys():
		addPlayer(playerID);

@rpc("authority", "call_local")
func disconnectPlayer(playerID):
	var playersInfoKey = playerID;
	if not (Server.playersInfo.has(playersInfoKey)):
		var parsedPlayerId = int(str(playerID));
		if (str(parsedPlayerId) == str(playerID) and Server.playersInfo.has(parsedPlayerId)):
			playersInfoKey = parsedPlayerId;
		elif (Server.playersInfo.has(str(playerID))):
			playersInfoKey = str(playerID);

	if (Server.playersInfo.has(playersInfoKey)):
		var character = Server.playersInfo[playersInfoKey].charInstance;
		if (character and is_instance_valid(character) and character is Node):
			character.queue_free();

		Server.playersInfo.erase(playersInfoKey);
		print("removed: ", playerID);

	if (has_node("Game")):
		var gameScene = get_node("Game");
		if (gameScene.has_method("updatePlayerList")):
			gameScene.updatePlayerList();

@rpc("authority", "call_local", "reliable")
func updateGameMode(gameMode: String):
	var isScene = has_node("Game");
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.setGameMode(gameMode);

@rpc("authority", "call_local", "reliable")
func startGame():
	if (gameStarted):
		return;

	gameStarted = true;
	$UI.visible = false;

	var transition = preload("res://assets/scenes/transition_scene.tscn").instantiate();
	transition.transition_finished.connect(func():
		transition.queue_free();
	);
	add_child(transition);

	await get_tree().create_timer(0.5).timeout;

	for i in range(3):
		if (has_node("CharSelect")):
			get_node("CharSelect").queue_free();
		await get_tree().create_timer(0.1).timeout;

	var playerId = _getLocalPlayerId();
	var gameScene = preload("res://assets/scenes/gameScene.tscn").instantiate();
	gameScene.gameModeSelected.connect(_gameModeSelected);
	gameScene.roundVictory.connect(_onRoundVictory);
	gameScene.syncTeamWins.connect(_onSyncTeamWins);
	gameScene.teamWonGame.connect(_onTeamWonGame);
	gameScene.returnToLobby.connect(_onReturnToLobby);
	gameScene.playerId = playerId;
	add_child(gameScene);

@rpc("authority", "call_local", "reliable")
func startRound(gameMode: String):
	if (roundStarted):
		return;

	roundStarted = true;
	startRoundTimer = 0;

	var isScene = has_node("Game");
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.startGameMode(gameMode);

	var transition = preload("res://assets/scenes/transition_scene.tscn").instantiate();
	transition.transition_finished.connect(func():
		transition.queue_free();
	);
	add_child(transition);

	await get_tree().create_timer(0.5).timeout;

@rpc("authority", "call_local", "reliable")
func syncRoundVictory(winnerTeam: int):
	if not (roundStarted):
		return;

	print("ROUND HAS ENDED");
	roundStarted = false;

	var isScene = has_node("Game");
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.onRoundVictory(winnerTeam);

@rpc("authority", "reliable")
func syncTeamWins(_blackTeamWins: int, _whiteTeamWins: int):
	var isScene = has_node("Game");

	if (isScene):
		var gameScene = get_node("Game");
		gameScene.blackTeamWins = _blackTeamWins;
		gameScene.whiteTeamWins = _whiteTeamWins;

@rpc("authority", "reliable", "call_local")
func teamHasWon(_teamThatHasWon: int):
	matchHasEnded = true;
	var isScene = has_node("Game");

	if (isScene):
		var gameScene = get_node("Game");
		gameScene.endGame(_teamThatHasWon);

func _on_training_button_pressed() -> void:
	_startSinglePlayerMatch();

func _on_exit_pressed() -> void:
	get_tree().quit();
