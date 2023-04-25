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

func connect_to_server(soft = false):
	pass

func set_credentials(c: TwitchCredentials):
	credentials = c
