extends Node
class_name TwitchEventStream

enum ConnectionState {
	NOT_STARTED,
	STARTING,
	STARTED,
	FAILED
}

var credentials: TwitchCredentials
var connection_state: ConnectionState = ConnectionState.NOT_STARTED

# Called when the node enters the scene tree for the first time.
func connect_to_server(soft = false):
	pass

