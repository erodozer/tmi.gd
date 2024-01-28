extends Node
class_name TmiEventStream

enum ConnectionState {
	NOT_STARTED,
	STARTING,
	STARTED,
	FAILED
}

var connection_state: ConnectionState = ConnectionState.NOT_STARTED

var tmi

func _init(tmi):
	self.tmi = tmi

func connect_to_server():
	pass

func close_stream():
	pass
