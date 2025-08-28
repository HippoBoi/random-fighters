extends Node

signal startNorayHost;

const PORT: int = 8890;

var ADDRESS: String = EnvLoader.get_env("NORAY_ADDRESS");
var multiplayerPeer: ENetMultiplayerPeer = ENetMultiplayerPeer.new();

var isHosting: bool = false;

func _ready() -> void:
	print("STARTED NORAY NETWORK!");
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

func handleNorayClientConnect(address: String, port: int):
	var peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer;
	var response = await PacketHandshake.over_enet(peer.host, address, port);
	
	if (response != OK):
		print("[ERROR]: noray handshake failed: %s" % response);
		return response;
	
	return OK;

func setupHostNorayConnection():
	Noray.on_connect_nat.connect(handleNorayClientConnect);
	Noray.on_connect_relay.connect(handleNorayClientConnect);
