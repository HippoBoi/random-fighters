extends Node
class_name WebSocketClient;

var socket = WebSocketPeer.new();
var lastState = WebSocketPeer.STATE_CLOSED;

signal connected_to_server();
signal connection_closed();
signal message_recieved(message);

func poll():
	var state = socket.get_ready_state();
	if (state != socket.STATE_CLOSED):
		socket.poll();
	
	if (lastState != state):
		lastState = state;
		
		if (state == socket.STATE_OPEN):
			connected_to_server.emit();
		elif (state == socket.STATE_CLOSED):
			connection_closed.emit();
	
	while (state == socket.STATE_OPEN and socket.get_available_packet_count()):
		message_recieved.emit(getMessage());

func getMessage():
	if (socket.get_available_packet_count() < 1):
		return null;
	
	var packet = socket.get_packet();
	if (socket.was_string_packet()):
		return packet.get_string_from_utf8();
	
	return bytes_to_var(packet);

func sendMessage(message):
	if (typeof(message) == TYPE_STRING):
		return socket.send_text(message);
	
	return socket.send(var_to_bytes(message));

func connectToURL(url):
	var response = socket.connect_to_url(url);
	if (response != OK):
		return response;
	
	lastState = socket.get_ready_state();
	return OK;

func close(code = 1000, reason = ""):
	socket.close(code, reason);
	lastState = socket.get_ready_state();

func getSocket():
	return socket;

func _process(_delta: float) -> void:
	poll();
