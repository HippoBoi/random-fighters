extends Node

signal startNorayHost;
signal connectToHost;

const PORT: int = 8890;

var ADDRESS: String = EnvLoader.get_env("NORAY_ADDRESS");
var multiplayerPeer: ENetMultiplayerPeer = ENetMultiplayerPeer.new();

var isClient: bool = false;
var isHosting: bool = false;

var gameId: String;

func _ready() -> void:
	print("STARTED NORAY NETWORK!");
	if (isClient):
		setupClientNorayConnection();
	else:
		setupHostNorayConnection();

func _registerWithNoray(ip: String):
	print("register with noray hosted at: %s" % ip);
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
	
	print("finished noray registration");

func createServerPeer(ip: String):
	print("CREATING PEER SERVER WITH NORAY");
	await _registerWithNoray(ip);
	
	startNorayHost.emit();

func createClientPeer(ip: String, _gameId: String):
	print("CREATING PEER CLIENT WITH NORAY");
	
	gameId = _gameId;
	await _registerWithNoray(ip);
	
	setupClientEnetConnection();
	Noray.connect_nat(_gameId);

func handleNorayClientConnect(address: String, port: int):
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer;
	var response = await PacketHandshake.over_enet(peer.host, address, port);
	
	if (response != OK):
		print("[ERROR]: noray handshake failed: %s" % response);
		return response;
	
	return OK;

func _handleConnect(address: String, port: int):
	print("client handle connect to: %s:%s" % [address, port]);
	
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
	
	multiplayer.multiplayerPeer = multiplayerPeer;
	return OK;

func handleNatConnection(address: String, port: int):
	print("attempting nat connection %s:%s" % [address, port]);
	
	var response = await _handleConnect(address, port);
	if (response != OK):
		print("[ERROR]: NAT CONNECTION FAILED.")
		Noray.connect_relay(gameId);
		return OK;
	else:
		print("NAT CONNECTION SUCCESSFUL");
	
	return response;

func handleRelayConnection(address: String, port: int):
	print("attempting relay connection %s:%s" % [address, port]);
	
	return await _handleConnect(address, port);

func setupHostNorayConnection():
	Noray.on_connect_nat.connect(handleNorayClientConnect);
	Noray.on_connect_relay.connect(handleNorayClientConnect);

func setupClientNorayConnection():
	Noray.on_connect_nat.connect(handleNatConnection);
	Noray.on_connect_relay.connect(handleRelayConnection);

func setupClientEnetConnection():
	multiplayer.server_disconnected.connect(_norrayServerDisconnected);

func _norrayServerDisconnected():
	print("well someone disconnected?");
