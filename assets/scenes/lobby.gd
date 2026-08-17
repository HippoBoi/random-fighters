extends Control

var webSocketUrl = NetworkConfig.MATCHMAKING_SOCKET_URL;
var messageToSend = "";
var currentLobbyId = "";
var currentOwnerId = ""; # lobby owner ID
var currentTeam = "1";
var fakeUser = {};
var mappedUPnPPort: int = -1;

const LOADING_COLOR = Color(1.0, 1.0, 0.5);
const ONLINE_COLOR = Color(0.0, 1.0, 0.5);
const OFFLINE_COLOR = Color(1.0, 0.0, 0.25);

const REQUEST_MATCHES = "REQUEST_MATCHES";
const PLAYER_JOINED = "PLAYER_JOINED";
const PLAYER_DROPPED = "PLAYER_DROPPED";
const JOIN_MATCH = "JOIN_MATCH";
const MATCH_PLAYERS = "MATCH_PLAYERS";
const CHECK_MATCH_READY = "CHECK_MATCH_READY";
const MATCH_READY = "MATCH_READY";
const REQUEST_MATCH_START = "REQUEST_MATCH_START";
const CREATE_MATCHES = "CREATE_MATCHES";
const SWITCH_TEAM = "SWITCH_TEAM";

const BLACK_TEAM = "0";
const WHITE_TEAM = "1";
const JOIN_TIMEOUT: float = 10.0;

var dontShowAgain = false;
var userPreferences: UserPreferences;
var joinRequestTime: float = -1.0;
var currentLobbyUsers = [];
var currentLobbyOwnerId = "";

@onready var statusText = $Status;
@onready var playerAvatar = $PlayerStats/PlayerAvatar;
@onready var playerUsername = $UserInfo/Username;
@onready var serverText = $ServerStatus/Status;
@onready var serverIcon = $ServerStatus/Icon;

signal returnToLobby;
signal startClient(ip, port, username, team);
signal startHost(port, username, team, isLocal);

@onready var _client: WebSocketClient = $WebSocketClient;

func _ready() -> void:
	userPreferences = UserPreferences.loadOrCreate();
	dontShowAgain = userPreferences.dontShowCreateWarning;

	print("attempting server connection");
	playerUsername.text = fakeUser.username;
	$MatchesContainer.visible = true;
	$CreateMatchContainer.visible = false;
	$LobbyContainer.visible = false;

	_updateServerStatus();
	_connectToMatchmakingServer();

func _updateServerStatus():
	serverText.text = "LOADING";
	serverIcon.modulate = LOADING_COLOR;

	var response = await testConnection();

	if (response == OK):
		serverText.text = "ONLINE";
		serverIcon.modulate = ONLINE_COLOR;
	else:
		serverText.text = "OFFLINE";
		serverIcon.modulate = OFFLINE_COLOR;

func _process(delta: float) -> void:
	if (joinRequestTime < 0):
		return;

	joinRequestTime += delta;
	if (joinRequestTime >= JOIN_TIMEOUT):
		joinRequestTime = -1.0;
		_onJoinTimeout();

func _onJoinTimeout():
	print("[lobby][WARNING]: join timed out, returning to match list");
	_leaveMatchLobby();
	statusText.text = "Failed to join match";

func testConnection():
	var ADDRESS = NetworkConfig.NORAY_ADDRESS;
	var PORT = NetworkConfig.NORAY_PORT;

	var response = await Noray.connect_to_host(ADDRESS, PORT);
	if (response != OK):
		return response;

	return response;

func _connectToMatchmakingServer():
	var response = _client.connectToURL(webSocketUrl);
	if (response != OK):
		print("error connecting to websocket: %s" % [webSocketUrl]);
		return;

func _sendMessage(message):
	var jsonMessage = JSON.stringify(message);
	_client.sendMessage(jsonMessage);

func _onWebSocketConnectionClose():
	var _webSocket = _client.getSocket();
	print("CLIENT disconnected, code: %s" % [_webSocket.get_close_code()]);
	print("reason: %s" % [_webSocket.get_close_reason()]);

func _processRecievedMessage(message):
	if (typeof(message) != TYPE_STRING):
		return;

	var responseMsg = str_to_var(message);
	if not (responseMsg):
		return;
	if not (responseMsg.op):
		return;

	print("process msg: %s" % responseMsg.op);
	if (responseMsg.op == REQUEST_MATCHES):
		print(" --------------------- REQUEST_MATCHES -----------------------");

		var matches = responseMsg.response;
		if (matches and matches.size() > 0):
			statusText.text = "Join a Lobby";
			_updateMatchesList(matches);
		else:
			statusText.text = "No matches found!";
	elif (responseMsg.op == MATCH_PLAYERS):
		print("----------------------- MATCH_PLAYERS -----------------------");

		var matchData = responseMsg.response;
		if (matchData and matchData.has("matchInfo")):
			_enterMatchLobby(matchData);
	elif (responseMsg.op == PLAYER_JOINED):
		print("----------------------- PLAYER_JOINED -----------------------");

		var matchData = responseMsg.response;
		if (_isMessageForCurrentLobby(matchData)):
			_updateLobbyData(matchData);
	elif (responseMsg.op == PLAYER_DROPPED):
		print("----------------------- PLAYER_DROPPED -----------------------");

		var matchData = responseMsg.response;
		if (_isMessageForCurrentLobby(matchData)):
			print("player %s dropped from match" % matchData.disconnectedUserId);
			_removeLobbyPlayer(matchData.disconnectedUserId);
	elif (responseMsg.op == MATCH_READY):
		print("------------------------ MATCH_READY -------------------------");

		if (currentOwnerId == fakeUser.playerId):
			print(fakeUser.playerId, " YOU ARE OWNER!!!!, closing!!");
			return;

		print("connecting to: %s, %s" % [responseMsg.response.ip, responseMsg.response.port]);

		statusText.text = "Starting game...";

		var ip = responseMsg.response.ip;
		var port = responseMsg.response.port;
		var gameId = responseMsg.response.gameId;
		var useUPnP = responseMsg.response.useUPnP;
		startClient.emit(ip, port, gameId, fakeUser.username, currentTeam, useUPnP);

		_client.close(1000, "game started normally!");

func _isMessageForCurrentLobby(matchData) -> bool:
	if (currentLobbyId.is_empty()):
		return false;
	if (matchData == null):
		return false;
	if not (matchData.has("matchInfo")) or matchData.matchInfo == null:
		return false;

	var matchInfo = matchData.matchInfo;
	if (matchInfo.has("matchId")):
		return str(matchInfo.matchId) == currentLobbyId;

	return str(matchInfo.get("ownerId", "")) == str(currentLobbyOwnerId);

func _enterMatchLobby(matchData):
	print("entered match!");
	print(matchData);

	if not (matchData.has("matchInfo")) or matchData.matchInfo == null:
		return;
	if (matchData.matchInfo.get("matchId", "") == ""):
		return;

	joinRequestTime = -1.0;
	currentLobbyId = matchData.matchInfo.matchId;
	print("lobby ID: %s" % currentLobbyId);

	currentLobbyUsers = matchData.users if (matchData.has("users") and matchData.users is Array) else [];
	currentLobbyOwnerId = str(matchData.matchInfo.get("ownerId", ""));

	$MatchesContainer.visible = false;
	$CreateMatchContainer.visible = false;
	$LobbyContainer.visible = true;
	statusText.text = "Waiting for players...";
	_refreshLobbyList();

func _updateLobbyData(matchData):
	if (matchData.has("users") and matchData.users is Array):
		currentLobbyUsers = matchData.users;
	if (matchData.has("matchInfo") and matchData.matchInfo):
		currentLobbyOwnerId = str(matchData.matchInfo.get("ownerId", currentLobbyOwnerId));

	_refreshLobbyList();

func _removeLobbyPlayer(playerId):
	var filtered = [];
	for player in currentLobbyUsers:
		if (str(player.get("userId", "")) != str(playerId)):
			filtered.append(player);
	currentLobbyUsers = filtered;

	_refreshLobbyList();

func _refreshLobbyList():
	_buildLobbyPlayerList({
		"users": currentLobbyUsers,
		"matchInfo": { "ownerId": currentLobbyOwnerId },
	});

func _leaveMatchLobby():
	joinRequestTime = -1.0;
	currentLobbyId = "";
	currentOwnerId = "";
	currentTeam = "1";
	currentLobbyUsers = [];
	currentLobbyOwnerId = "";

	$LobbyContainer.visible = false;
	$MatchesContainer.visible = true;
	$MatchesContainer/AvailableMatches.visible = true;
	_loadMatches();

func _buildLobbyPlayerList(matchData):
	for team_player in $LobbyContainer/Teams/BlackTeam.get_children():
		team_player.queue_free();
	for team_player in $LobbyContainer/Teams/WhiteTeam.get_children():
		team_player.queue_free();

	$LobbyContainer/Teams/Ready.visible = false;
	$LobbyContainer/Teams/BlackTeamJoin.visible = false;
	$LobbyContainer/Teams/WhiteTeamJoin.visible = false;
	currentOwnerId = "";

	if (matchData == null):
		return;
	if not (matchData.has("users")) or not (matchData.has("matchInfo")):
		return;

	var matchPlayers = matchData.users;
	var ownerId = matchData.matchInfo.ownerId;

	if (ownerId):
		if (ownerId == fakeUser.playerId):
			$LobbyContainer/Teams/Ready.visible = true;

		currentOwnerId = ownerId;
		print("CURRENT OWNER ID: ", currentOwnerId);

	for player in matchPlayers:
		var button = Button.new();
		button.text = "%s" % player.username;

		var userId: String = player.userId;
		var tagId = userId.right(3);
		var isPlayer = tagId == fakeUser.playerId;
		if (isPlayer):
			fakeUser.username = player.username;
			currentTeam = player.team;

		print("%s: my team is: %s" % [player.username, player.team]);

		if (player.team == BLACK_TEAM):
			$LobbyContainer/Teams/BlackTeam.add_child(button);
			if (isPlayer):
				$LobbyContainer/Teams/BlackTeamJoin.visible = false;
				$LobbyContainer/Teams/WhiteTeamJoin.visible = true;
		elif (player.team == WHITE_TEAM):
			$LobbyContainer/Teams/WhiteTeam.add_child(button);
			if (isPlayer):
				$LobbyContainer/Teams/BlackTeamJoin.visible = true;
				$LobbyContainer/Teams/WhiteTeamJoin.visible = false;
		else:
			if (isPlayer):
				$LobbyContainer/Teams/BlackTeamJoin.visible = true;
				$LobbyContainer/Teams/WhiteTeamJoin.visible = true;
			print("%s: - - - - player has no team - - - -" % player.username);

func _updateMatchesList(matches):
	for lobby_button in $MatchesContainer/AvailableMatches.get_children():
		lobby_button.queue_free();

	for i in range(matches.size()):
		var curMatch = matches[i];
		var button = Button.new();
		button.text = "%s || %s" % [curMatch.matchName, curMatch.ownerName];
		button.pressed.connect(self._joinMatch.bind(curMatch));

		$MatchesContainer/AvailableMatches.add_child(button);
		print(curMatch);

func _joinMatch(game):
	$MatchesContainer/AvailableMatches.visible = false;
	statusText.text = "Joining match...";
	joinRequestTime = 0.0;

	var join_request = {
		"op": JOIN_MATCH,
		"matchId": game.matchId,
		"playerId": fakeUser.playerId,
		"rank": fakeUser.rank,
		"username": fakeUser.username,
	};

	_sendMessage(join_request);

func _loadMatches():
	statusText.text = "Loading matches...";
	$MatchesContainer/CreateMatchButton.disabled = false;

	for lobby_button in $MatchesContainer/AvailableMatches.get_children():
		lobby_button.queue_free();

	var requestMatches = {
		"op": REQUEST_MATCHES
	}
	_sendMessage(requestMatches);

func _onWebSocketConnectedToServer():
	_loadMatches();
	print("client connected!");

func _onWebSocketMessageRecieved(message):
	print("message recieved: %s" % message);
	_processRecievedMessage(message);

func _tween_warning() -> void:
	$WarningContainer/ColorRect2.scale = Vector2(0.1, 0.1);
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT);
	tween.tween_property($WarningContainer/ColorRect2, "scale", Vector2(1, 1), 0.25);

func _on_create_match_pressed() -> void:
	if not (dontShowAgain):
		$WarningContainer.visible = true;
		_tween_warning();

	statusText.text = "Create your Match";
	$MatchesContainer.visible = false;
	$CreateMatchContainer.visible = true;
	$CreateMatchContainer/matchInput.text = "";
	$CreateMatchContainer/maxPlayersInput.value = 10.0;

	var newSound = AudioStreamPlayer.new();
	add_child(newSound);

	newSound.stream = preload("res://assets/sounds/menuClick.ogg");
	newSound.pitch_scale = randf();
	newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.5);
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);

func _onCreateMatch() -> void:
	var matchInput = $CreateMatchContainer/matchInput;
	var maxPlayers = $CreateMatchContainer/maxPlayersInput;
	if (matchInput.text.is_empty()):
		return;

	$CreateMatchContainer/CreateMatch.disabled = true;
	var request = {
		"op": CREATE_MATCHES,
		"ownerId": fakeUser.playerId,
		"ownerName": fakeUser.username,
		"matchName": matchInput.text,
		"maxPlayers": maxPlayers.value,
	};
	_sendMessage(request);

func _close_creating_match(secondsToWait: float = 0.5):
	var newSound = AudioStreamPlayer.new();
	add_child(newSound);

	newSound.stream = preload("res://assets/sounds/menuReturn.ogg");
	newSound.pitch_scale = randf();
	newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.5);
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);

	$CreateMatchContainer.visible = false;
	$MatchesContainer.visible = true;

	for lobby_button in $MatchesContainer/AvailableMatches.get_children():
		lobby_button.queue_free()

	await get_tree().create_timer(secondsToWait).timeout;
	_loadMatches();

func getUPnPAddress(_port = NetworkConfig.NORAY_PORT):
	var upnp = UPNP.new();
	var discoverResult = upnp.discover();

	if (discoverResult == UPNP.UPNP_RESULT_SUCCESS):
		if (upnp.get_gateway() and upnp.get_gateway().is_valid_gateway()):
			var _delete_map_result = upnp.delete_port_mapping(_port);

			var mapResultUDP = upnp.add_port_mapping(_port, 0, "udp-godot", "UDP");
			var mapResultTCP = upnp.add_port_mapping(_port, 0, "tcp-godot", "TCP");

			if (mapResultUDP != OK):
				mapResultUDP = upnp.add_port_mapping(_port, 0, "", "UDP");
			if (mapResultTCP != OK):
				mapResultTCP = upnp.add_port_mapping(_port, 0, "", "TCP");

			if (mapResultUDP == OK or mapResultTCP == OK):
				mappedUPnPPort = _port;

	# startHost.emit(_port, fakeUser.username, currentTeam);

	var external_ip = upnp.query_external_address();
	return external_ip;

func cleanupUPnPMapping():
	if (mappedUPnPPort < 0):
		return;

	var upnp = UPNP.new();
	var discoverResult = upnp.discover();
	if (discoverResult != UPNP.UPNP_RESULT_SUCCESS):
		print("[lobby][WARNING]: failed to discover UPnP gateway for cleanup: %s" % discoverResult);
		mappedUPnPPort = -1;
		return;

	var deleteUDPResult = upnp.delete_port_mapping(mappedUPnPPort, "UDP");
	var deleteTCPResult = upnp.delete_port_mapping(mappedUPnPPort, "TCP");
	if (deleteUDPResult != OK or deleteTCPResult != OK):
		print("[lobby][WARNING]: failed to clean UPnP mappings UDP:%s TCP:%s" % [deleteUDPResult, deleteTCPResult]);

	mappedUPnPPort = -1;

func hostMatch(_matchIp: String, _port: int, _gameOid: String, _useUPnP: bool):
	print("ATTEMPTING TO HOST MATCH, ip: %s, gameId: %s" % [_matchIp, _gameOid]);

	if (_matchIp.is_empty()):
		print("FAILED: couldn't host match");
		return ERR_INVALID_PARAMETER;

	if (currentLobbyId.is_empty()):
		print("FAILED: couldn't host match, no lobby id");
		return ERR_UNCONFIGURED;

	if (_useUPnP):
		_matchIp = getUPnPAddress(_port);
		print("NEW UPNP MATCH IP: %s" % _matchIp);

		if (_matchIp.is_empty()):
			print("FAILED: UPnP could not resolve an external ip");
			cleanupUPnPMapping();
			return ERR_CANT_RESOLVE;

	var request = {
		"op": MATCH_READY,
		"matchId": currentLobbyId,
		"playerId": fakeUser.playerId,
		"MATCH_IP": _matchIp,
		"MATCH_PORT": _port,
		"GAME_ID": _gameOid,
		"USE_UPNP": _useUPnP,
	};

	_sendMessage(request);
	return OK;

func _adminStartMatch() -> void:
	if (currentLobbyId.is_empty()):
		return;

	var matchIp = NetworkConfig.NORAY_ADDRESS;
	var port = NetworkConfig.NORAY_PORT;
	print("matchIp: ", matchIp);

	startHost.emit(port, fakeUser.username, currentTeam, false);

func _on_refresh() -> void:
	_loadMatches();

func _notifyLeaveMatch():
	if (currentLobbyId.is_empty()):
		return;

	var request = {
		"op": PLAYER_DROPPED,
		"matchId": currentLobbyId,
		"playerId": fakeUser.playerId,
	};

	_sendMessage(request);

func _on_leave_match() -> void:
	_notifyLeaveMatch();

	_leaveMatchLobby();

func _onMatchInputChanged(_lines_edited, _idk) -> void:
	var isNameEmpty = $CreateMatchContainer/matchInput.text.is_empty();
	if not (isNameEmpty):
		$CreateMatchContainer/CreateMatch.disabled = false;
	else:
		$CreateMatchContainer/CreateMatch.disabled = true;

func _on_team_join(team: String) -> void:
	print("%s attempting to join team %s" % [fakeUser.username, team]);

	var request = {
		"op": SWITCH_TEAM,
		"matchId": currentLobbyId,
		"playerId": fakeUser.playerId,
		"rank": fakeUser.rank,
		"username": fakeUser.username,
		"newTeam": team
	};

	_sendMessage(request);

func _on_return_pressed() -> void:
	var newSound = AudioStreamPlayer.new();
	add_child(newSound);

	newSound.stream = preload("res://assets/sounds/menuReturn.ogg");
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);

	_notifyLeaveMatch();
	returnToLobby.emit();

func _on_return_hovered() -> void:
	var newSound = AudioStreamPlayer.new();
	add_child(newSound);

	newSound.stream = preload("res://assets/sounds/menuHover.ogg");
	newSound.pitch_scale = randf();
	newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.5);
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);

func _on_warning_close() -> void:
	$WarningContainer.visible = false;

func _on_check_box_toggled(toggled_on: bool) -> void:
	if (toggled_on):
		$WarningContainer/CheckBox.material = null;

	dontShowAgain = toggled_on;

	if (userPreferences):
		userPreferences.dontShowCreateWarning = toggled_on;
		userPreferences.save();
