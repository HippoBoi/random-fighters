extends Node3D

var multiplayerPeer: ENetMultiplayerPeer = ENetMultiplayerPeer.new();
var norayNetwork: Node = null;

const LOCALHOST: String = "127.0.0.1";
const PORT: int = 8890;
var ADDRESS: String;

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

var lobbyScene: Control = null;

var DEBUG = true;

func _ready() -> void:
	ADDRESS = EnvLoader.get_env("NORAY_ADDRESS");

func _process(delta: float) -> void:
	if not (connected):
		return;
	if (startRoundTimer > 0 and roundStarted == false and not curGameMode.is_empty()):
		startRoundTimer -= delta;
		
		if (startRoundTimer <= 0.1):
			rpc("startRound", curGameMode);
	
	timer += delta;
	if (int(round(timer * 100)) % 32 == 0):
		rpc("syncData", multiplayerPeer.get_unique_id(), username, curTeam, curCharacter);

func _on_name_input(new_text: String) -> void:
	username = new_text;

func _on_game_input_changed(new_text: String) -> void:
	gameIdInput = new_text;

func _on_host(_port: int, _username: String, _team: String, isLocal := true) -> void:
	var useUPnP: bool = false;
	
	if not (isLocal and DEBUG):
		if not (norayNetwork):
			norayNetwork = preload("res://assets/scenes/noray_network.tscn").instantiate();
			add_child(norayNetwork);
			
			norayNetwork.isClient = false;
			norayNetwork.setup(self);
			norayNetwork.startNorayHost.connect(startNorayHost);
		
		await norayNetwork.createServerPeer(ADDRESS);
	
	if (not (norayNetwork) or norayNetwork.isHosting == false):
		print("[main][WARNING]: NORAY NETWORKING FAILED. STARTING UPNP SERVER");
		useUPnP = true;
		
		_hostWithUPnP(_port);
	
	username = _username;
	curTeam = int(_team);
	
	addPlayer(1);
	connected = true;
	
	multiplayer.peer_connected.connect(
		func(newPlayerID):
			rpc("addPlayer", newPlayerID);
			rpc_id(newPlayerID, "addPreviousPlayers", Server.playersInfo);
			addPlayer(newPlayerID);
	);
	multiplayer.peer_disconnected.connect(
		func(playerID):
			rpc("disconnectPlayer", playerID);
	);
	
	if not (isLocal):
		lobbyScene.hostMatch(ADDRESS, PORT, curGameId, useUPnP);
	
	updateUI("Server");

func _hostWithUPnP(_port):
	print("host...")
	multiplayerPeer.create_server(_port);
	multiplayer.multiplayer_peer = multiplayerPeer;

func _joinPressed(ip := LOCALHOST, port := PORT, _gameId := curGameId, _username := "noname", _team := "1", _useUPnP := true):
	username = _username;
	curTeam = int(_team);
	# print("joining team: %s" % curTeam);
	# print("GAME ID: %s" % _gameId);
	
	if not (_useUPnP):
		if not (norayNetwork):
			norayNetwork = preload("res://assets/scenes/noray_network.tscn").instantiate();
			add_child(norayNetwork);
			
			norayNetwork.isClient = true;
			norayNetwork.natConnection.connect(handleNatConnection);
			norayNetwork.relayConnection.connect(handleRelayConnection);
			norayNetwork.setup(self);
		
		norayNetwork.createClientPeer(ip, _gameId);
	else:
		print("USING UPNP TO JOIN: %s:%s" % [ip, port]);
		multiplayerPeer.create_client(ip, port);
		multiplayer.multiplayer_peer = multiplayerPeer;
	
	updateUI("Client");

func startHost(port: int, _username: String, _team: String, _isLocal: bool):
	print("CALL TO HOST ON PORT: %s" % port);
	_on_host(port, _username, _team, _isLocal);
	
	get_node("Lobby").visible = false;

func startClient(ip: String, port: int, _gameId: String, _username: String, _team: String, _useUPnP: bool):
	print("client joining: %s:%s, gameId: %s, useUPnP: %s" % [ip, port, _gameId, _useUPnP]);
	_joinPressed(ip, port, _gameId, _username, _team, _useUPnP);
	
	get_node("Lobby").visible = false;

func addCharacter(playerID, character = ""):
	var preloadedCharacter = null;
	
	var path = "res://assets/characters/%s/%s.tscn" % [character, character];
	preloadedCharacter = load(path);
		
	var selectedChar = preloadedCharacter.instantiate();
	var playerList = Server.playersInfo;
	playerList[playerID].charInstance = selectedChar;
	
	selectedChar.set_multiplayer_authority(playerID);
	add_child(selectedChar);

func preloadCharacter(playerId, character: String = ""):
	if (character.is_empty()):
		return;
	
	var preloadedCharacter = null;
	var path = "res://assets/characters/%s/%s.tscn" % [character, character];
	preloadedCharacter = load(path);
	
	var selectedChar = preloadedCharacter;
	var playerList = Server.playersInfo;
	playerList[playerId].charInstance = selectedChar;

func _selectCharacter(character):
	var playerId = multiplayerPeer.get_unique_id();
	curCharacter = character;
	rpc("updateSelectedCharacter", playerId, character);

func updateUI(_side: String) -> void:
	$UI.visible = false;
	
	var charSelect = preload("res://assets/scenes/characterSelect.tscn").instantiate();
	charSelect.onCharacterPressed.connect(_selectCharacter);
	charSelect.startGame.connect(onStartGame);
	add_child(charSelect);

func returnToLobby():
	var isLobby = has_node("Lobby");
	var lobby = null;
	if not (isLobby):
		return;
		
	$UI.playIntro();
	
	await get_tree().create_timer(0.25).timeout;
	lobby = get_node("Lobby");
	lobby.queue_free();

func onStartGame() -> void:
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
	startRoundTimer = 10.0;
	if (DEBUG):
		startRoundTimer = 2.0;
	
	for i in range(4):
		rpc("updateGameMode", gameMode);
		await get_tree().create_timer(0.1).timeout;

func _onRoundVictory(winnerTeam: int):
	rpc("syncRoundVictory", winnerTeam);

func _onSyncTeamWins(blackTeamWins: int, whiteTeamWins: int):
	rpc("syncTeamWins", blackTeamWins, whiteTeamWins);

func _onTeamWonGame(_teamThatWon: int):
	rpc("teamHasWon", _teamThatWon);

func _onReturnToLobby():
	multiplayerPeer.close();
	
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
	curTeam = -1;
	curCharacter = "";
	curGameMode = "";
	totalPlayers = 0;
	timer = 0;
	startRoundTimer = 0.0;
	playersLockedIn = [];
	selectedCharacters = [];
	Server.playersInfo = {};
	
	$UI.visible = true;

func startNorayHost():
	var response = OK;
	
	response = multiplayerPeer.create_server(Noray.local_port);
	multiplayer.multiplayer_peer = multiplayerPeer;
	
	if (response == OK):
		norayNetwork.isHosting = true;
		print("HOST SUCCESS!!!!!")
	else:
		print("failed to start host: %s, %s" % [Noray.local_port, response]);

func connectToNorayHost(address: String, port: int):
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
	return OK;

func handleNatConnection(address: String, port: int):
	print("attempting nat connection %s:%s" % [address, port]);
	
	var response = await connectToNorayHost(address, port);
	if (response != OK):
		print("[ERROR]: NAT CONNECTION FAILED.")
		return response;
	
	print("NAT CONNECTION SUCCESSFUL");
	return response;

func handleRelayConnection(address: String, port: int):
	var response = await connectToNorayHost(address, port);
	if (response != OK):
		print("[ERROR]: RELAY CONNECTION FAILED.")
		norayNetwork.useNatConnection(curGameId);
		return response;
		
	print("CONNECTION SUCCESS!!!")
	return response;

func setupClientNorayConnection():
	Noray.on_connect_nat.connect(handleNatConnection);
	Noray.on_connect_relay.connect(handleRelayConnection);

func setupClientEnetConnection():
	multiplayer.server_disconnected.connect(_norrayServerDisconnected);

func _norrayServerDisconnected():
	print("well someone disconnected?");

@rpc
func addNewPlayerCharacter(newPlayerID):
	addCharacter(newPlayerID);

@rpc
func addPlayer(playerId):
	var character = null;
	var myTeam = 0;
	
	if (playerId == multiplayerPeer.get_unique_id()):
		myTeam = curTeam;
		connected = true;
	
	var playerInfo = PlayerData.new(playerId, username, character, character, myTeam);
	Server.playersInfo[playerId] = playerInfo;

@rpc("call_local", "any_peer")
func updateSelectedCharacter(playerId, character: String):
	var playerList = Server.playersInfo;
	var charSelect = null;
	
	if (has_node("CharSelect")):
		charSelect = get_node("CharSelect");
	
	playerList[playerId].character = character;
	selectedCharacters.insert(len(selectedCharacters), character);
	
	var findLockedPlayer = playersLockedIn.find(playerId);
	var hasPlayerLocked = true if findLockedPlayer != -1 else false;
	if (not (hasPlayerLocked) and not character.is_empty()):
		playersLockedIn.insert(len(playersLockedIn), playerId);
	
	if (len(playersLockedIn) >= len(playerList)):
		if not (charSelect):
			return;
		
		if (charSelect.timeInSeconds > 10):
			charSelect.timeInSeconds = 10;
			
			if (DEBUG):
				charSelect.timeInSeconds = 2;
	
	charSelect.updateTeams();
	
	preloadCharacter(playerId, character);

@rpc("any_peer")
func syncData(playerId, _username, _team, _character):
	var playerList = Server.playersInfo;
	var isPlayer = playerList[playerId];
	
	if (isPlayer):
		playerList[playerId].username = _username;
		playerList[playerId].team = _team;
		updateSelectedCharacter(playerId, _character);
	else:
		print("couldnt find player, adding it to list");
		var character = null;
		var playerInfo = PlayerData.new(playerId, _username, character, character, _team);
		Server.playersInfo[playerId] = playerInfo;

@rpc
func addPreviousCharacters(playersList):
	for playerID in playersList.keys():
		addCharacter(playerID);

@rpc
func addPreviousPlayers(playersList):
	for playerID in playersList.keys():
		addPlayer(playerID);

@rpc("authority", "call_local")
func disconnectPlayer(playerID):
	if (Server.playersInfo.has(playerID)):
		# var character = Server.playersInfo[playerID].charInstance;
		# if (character):
		#	 character.queue_free();
		
		Server.playersInfo.erase(playerID);
		print("removed: ", playerID);

@rpc("call_local")
func updateGameMode(gameMode: String):
	var isScene = has_node("Game");
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.setGameMode(gameMode);

@rpc("any_peer", "call_local")
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
	
	var playerId = multiplayerPeer.get_unique_id();
	var gameScene = preload("res://assets/scenes/gameScene.tscn").instantiate();
	gameScene.gameModeSelected.connect(_gameModeSelected);
	gameScene.roundVictory.connect(_onRoundVictory);
	gameScene.syncTeamWins.connect(_onSyncTeamWins);
	gameScene.teamWonGame.connect(_onTeamWonGame);
	gameScene.returnToLobby.connect(_onReturnToLobby);
	gameScene.playerId = playerId;
	gameScene.DEBUG = DEBUG;
	add_child(gameScene);

@rpc("any_peer", "call_local", "reliable")
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

@rpc("any_peer", "call_local", "reliable")
func syncRoundVictory(winnerTeam: int):
	if not (roundStarted):
		return;
	
	print("ROUND HAS ENDED");
	roundStarted = false;
	
	var isScene = has_node("Game");
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.onRoundVictory(winnerTeam);

@rpc("reliable")
func syncTeamWins(_blackTeamWins: int, _whiteTeamWins: int):
	var isScene = has_node("Game");
	
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.blackTeamWins = _blackTeamWins;
		gameScene.whiteTeamWins = _whiteTeamWins;

@rpc("reliable", "call_local")
func teamHasWon(_teamThatHasWon: int):
	var isScene = has_node("Game");
	
	if (isScene):
		var gameScene = get_node("Game");
		gameScene.endGame(_teamThatHasWon);
