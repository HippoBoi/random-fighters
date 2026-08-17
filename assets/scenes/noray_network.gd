extends Node

signal startNorayHost;
signal connectToHost;
signal natConnection(address, port);
signal relayConnection(address, port);

const PORT: int = NetworkConfig.NORAY_PORT;
const REGISTRATION_TIMEOUT: float = 10.0;

var ADDRESS: String = NetworkConfig.NORAY_ADDRESS;
var multiplayerPeer: ENetMultiplayerPeer = ENetMultiplayerPeer.new();

var isClient: bool = false;
var isHosting: bool = false;

var _awaitSignalDone: bool = false;
var _awaitSignalResult = null;

var main: Node3D;
var gameId: String;

func setup(_mainInstance) -> void:
	print("STARTED NORAY NETWORK!");
	main = _mainInstance;
	
	if (isClient):
		setupClientNorayConnection();
	else:
		setupHostNorayConnection();

func _registerWithNoray(ip: String):
	var response = OK;

	response = await Noray.connect_to_host(ip, PORT, REGISTRATION_TIMEOUT);
	if (response != OK):
		print("[ERROR]: failed noray registration for: %s:%s" % [ip, PORT]);
		return response;

	Noray.register_host();
	var pid = await _await_signal_with_timeout(Noray.on_pid, REGISTRATION_TIMEOUT);
	if (pid == null):
		print("[ERROR]: timed out waiting for noray pid");
		Noray.disconnect_from_host();
		return ERR_TIMEOUT;

	main.curGameId = Noray.oid;

	response = await Noray.register_remote();
	if (response != OK):
		print("[ERROR]: failed to register remote %s" % response);
		return response;

	return OK;

func _await_signal_with_timeout(sig: Signal, timeout: float):
	_awaitSignalDone = false;
	_awaitSignalResult = null;

	sig.connect(_on_awaited_signal, CONNECT_ONE_SHOT);
	var timer = get_tree().create_timer(timeout);
	timer.timeout.connect(_on_awaited_signal_timeout, CONNECT_ONE_SHOT);

	while not _awaitSignalDone:
		await get_tree().process_frame;

	if (sig.is_connected(_on_awaited_signal)):
		sig.disconnect(_on_awaited_signal);

	return _awaitSignalResult;

func _on_awaited_signal(value):
	_awaitSignalDone = true;
	_awaitSignalResult = value;

func _on_awaited_signal_timeout():
	_awaitSignalDone = true;
	_awaitSignalResult = null;

func createServerPeer(ip: String):
	var registration = await _registerWithNoray(ip);
	if (registration != OK):
		print("[ERROR]: NORAY SERVER REGISTRATION FAILED: %s" % registration);
		return registration;

	startNorayHost.emit();
	return OK;

func createClientPeer(ip: String, _gameOid: String):
	var registration = await _registerWithNoray(ip);
	if (registration != OK):
		print("[ERROR]: NORAY CLIENT REGISTRATION FAILED: %s" % registration);
		return registration;

	var relayResult = Noray.connect_relay(_gameOid);
	if (relayResult != OK):
		print("[ERROR]: failed to request noray relay: %s" % relayResult);
		return relayResult;

	return OK;

func handleNorayClientConnect(address: String, port: int):
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer;
	var response = await PacketHandshake.over_enet(peer.host, address, port);
	
	if (response != OK):
		print("[ERROR]: noray handshake failed: %s" % response);
		return response;
	
	return OK;

func useNatConnection(_gameOid: String):
	return Noray.connect_nat(_gameOid);

func handleNatConnection(address: String, port: int):
	natConnection.emit(address, port);

func handleRelayConnection(address: String, port: int):
	relayConnection.emit(address, port);

func setupHostNorayConnection():
	Noray.on_connect_nat.connect(handleNorayClientConnect);
	Noray.on_connect_relay.connect(handleNorayClientConnect);

func setupClientNorayConnection():
	Noray.on_connect_nat.connect(handleNatConnection);
	Noray.on_connect_relay.connect(handleRelayConnection);
