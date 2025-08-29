extends Node

signal startNorayHost;
signal connectToHost;
signal natConnection(address, port);
signal relayConnection(address, port);

const PORT: int = 8890;

var ADDRESS: String = EnvLoader.get_env("NORAY_ADDRESS");
var multiplayerPeer: ENetMultiplayerPeer = ENetMultiplayerPeer.new();

var isClient: bool = false;
var isHosting: bool = false;

var gameId: String;

func setup() -> void:
	print("STARTED NORAY NETWORK!");
	if (isClient):
		setupClientNorayConnection();
	else:
		setupHostNorayConnection();

func _registerWithNoray(ip: String):
	var response = OK;
	
	response = await Noray.connect_to_host(ip, PORT);
	if (response != OK):
		print("[ERROR]: failed noray registration for: %s:%s" % [ip, PORT]);
		return response;
	
	Noray.register_host();
	await Noray.on_pid;
	
	response = await Noray.register_remote();
	if (response != OK):
		print("[ERROR]: failed to register remote %s" % response);
		return response;

func createServerPeer(ip: String):
	await _registerWithNoray(ip);
	
	startNorayHost.emit();

func createClientPeer(ip: String, _gameOid: String):
	await _registerWithNoray(ip);
	
	Noray.connect_relay(_gameOid);
	# connectToHost.emit();

func handleNorayClientConnect(address: String, port: int):
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer;
	var response = await PacketHandshake.over_enet(peer.host, address, port);
	
	if (response != OK):
		print("[ERROR]: noray handshake failed: %s" % response);
		return response;
	
	return OK;

func useNatConnection(_gameOid: String):
	Noray.connect_nat(_gameOid);

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
