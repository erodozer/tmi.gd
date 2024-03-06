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
var message_queue = []

func connect_to_server():
	pass

func close_stream():
	pass

func poll():
	pass
	
func handle_message(message):
	pass

func _process(delta):
	if tmi._load_stack.is_empty():
		if !message_queue.is_empty():
			var message = message_queue.pop_front()
			handle_message(message)
		
	poll()
