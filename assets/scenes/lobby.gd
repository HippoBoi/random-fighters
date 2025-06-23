extends Control

var webSocketUrl = EnvLoader.get_env("AWS_SOCKET");
var messageToSend = "";
var currentLobbyId = "";
var currentOwnerId = ""; # lobby owner ID
var currentTeam = "1";
var fakeUser = {};

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

var dontShowAgain = false;

@onready var statusText = $Status;
@onready var playerAvatar = $PlayerStats/PlayerAvatar;
@onready var playerUsername = $UserInfo/Username;

signal returnToLobby;
signal startClient(ip, port, username, team);
signal startHost(port, username, team);

@onready var _client: WebSocketClient = $WebSocketClient;

func _ready() -> void:
	print("attempting server connection");
	playerUsername.text = fakeUser.username;
	$MatchesContainer.visible = true;
	$CreateMatchContainer.visible = false;
	$LobbyContainer.visible = false;
	
	_connectToMatchmakingServer();

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
		
		_enterMatchLobby(responseMsg.response);
	elif (responseMsg.op == PLAYER_JOINED):
		print("----------------------- PLAYER_JOINED -----------------------");
		
		var matchData = responseMsg.response;
		_buildLobbyPlayerList(matchData);
	elif (responseMsg.op == PLAYER_DROPPED):
		print("----------------------- PLAYER_DROPPED -----------------------");
		
		var matchData = responseMsg.response;
		print("player %s dropped from match" % matchData.disconnectedUserId);
		_buildLobbyPlayerList(matchData);
	elif (responseMsg.op == MATCH_READY):
		print("------------------------ MATCH_READY -------------------------");
		
		if (currentOwnerId == fakeUser.playerId):
			print(fakeUser.playerId, " YOU ARE OWNER!!!!, closing!!");
			return;
			
		print("connecting to: %s, %s" % [responseMsg.response.ip, responseMsg.response.port]);
			
		statusText.text = "Starting game...";
		startClient.emit(responseMsg.response.ip, responseMsg.response.port, fakeUser.username, currentTeam);
		
		_client.close(1000, "game started normally!");

func _enterMatchLobby(matchData):
	print("entered match!");
	print(matchData);
	
	currentLobbyId = matchData.matchInfo.matchId;
	print("lobby ID: %s" % currentLobbyId);
	
	$MatchesContainer.visible = false;
	$CreateMatchContainer.visible = false;
	$LobbyContainer.visible = true;
	statusText.text = "Waiting for players...";
	_buildLobbyPlayerList(matchData);

func _leaveMatchLobby():
	print("leaving match!");
	currentLobbyId = "";
	
	$LobbyContainer.visible = false;
	$MatchesContainer.visible = true;
	$MatchesContainer/AvailableMatches.visible = true;
	_loadMatches();

func _buildLobbyPlayerList(matchData):
	for team_player in $LobbyContainer/Teams/BlackTeam.get_children():
		team_player.queue_free();
	for team_player in $LobbyContainer/Teams/WhiteTeam.get_children():
		team_player.queue_free();
	
	var matchPlayers = matchData.users;
	var ownerId = matchData.matchInfo.ownerId;
	
	if (ownerId):
		if (ownerId == fakeUser.playerId):
			$LobbyContainer/Teams/Ready.visible = true;
			print(fakeUser.playerId, " YOU ARE OWNER!!!!!!!!!!!!!!!!!");
		
		currentOwnerId = ownerId;
		print("CURRENT OWNER ID: ", currentOwnerId);
	
	for player in matchPlayers:
		print(player);
		
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
	
	_close_creating_match(1.25);

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

func _hostMatch(_port = 8000):
	print("ATTEMPTING TO HOST MATCH");
	
	var upnp = UPNP.new();
	var discoverResult = upnp.discover();
	
	if (discoverResult == UPNP.UPNP_RESULT_SUCCESS):
		if (upnp.get_gateway() and upnp.get_gateway().is_valid_gateway()):
			var _delete_map_result = upnp.delete_port_mapping(_port);
			
			var mapResultUDP = upnp.add_port_mapping(_port, 0, "udp-godot", "UDP");
			var mapResultTCP = upnp.add_port_mapping(_port, 0, "tcp-godot", "TCP");
			
			if not (mapResultUDP):
				mapResultUDP = upnp.add_port_mapping(_port, 0, "", "UDP");
			if not (mapResultTCP):
				mapResultTCP = upnp.add_port_mapping(_port, 0, "", "TCP");
	
	startHost.emit(_port, fakeUser.username, currentTeam);
	
	var external_ip = upnp.query_external_address();
	return external_ip;

func _adminStartMatch() -> void:
	if (currentLobbyId.is_empty()):
		return;
	
	var port = 8000;
	var matchIp = _hostMatch(port);
	print("matchIp: ", matchIp);
	
	if (matchIp.is_empty()):
		print("FAILED: couldn't host match");
		return;
	
	var request = {
		"op": MATCH_READY,
		"matchId": currentLobbyId,
		"playerId": fakeUser.playerId,
		"MATCH_IP": matchIp,
		"MATCH_PORT": port
	};
	
	_sendMessage(request);

func _on_refresh() -> void:
	_loadMatches();

func _on_leave_match() -> void:
	var request = {
		"op": PLAYER_DROPPED,
		"matchId": currentLobbyId,
		"playerId": fakeUser.playerId,
	};
	
	_sendMessage(request);
	
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
