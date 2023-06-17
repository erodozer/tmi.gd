extends Node
class_name Tmi

class EventType:
	const CHAT_MESSAGE = "message"
	const DELETE_MESSAGE = "delete-message"
	const FOLLOW = "follow"
	const SUBSCRIPTION = "subscription"
	const REDEEM = "redeem"
	const RAID = "raid"
	const USER_CHANGED = "userstate"
	const USER_DELETED = "user-deleted"

@export var credentials: TwitchCredentials

@export_category("Features")
@export var enable_bttv_emotes = false
@export var enable_7tv_emotes = false
@export var include_profile_images = false
@export var include_pronouns = false

@onready var irc: TwitchIrc = %Irc
@onready var twitch_api: TwitchApi = %TwitchAPI

var _emotes = []

enum ConnectionStatus {
	NOT_CONNECTED,
	PARTIAL,
	CONNECTED
}

signal credentials_updated(credentials: TwitchCredentials)
signal command(type, event)
signal connection_status_changed(status: ConnectionStatus)

func _set_credentials(c: TwitchCredentials):
	if c == null:
		return
		
	credentials = c
	
	credentials_updated.emit(credentials)
	
	start(true)

func _ready():
	if credentials:
		_set_credentials(await twitch_api.refresh_token(credentials))
		
		var token_refresher = Timer.new()
		token_refresher.timeout.connect(
			func():
				_set_credentials(await twitch_api.refresh_token(credentials))
				return
		)
		add_child(token_refresher)
		token_refresher.start(30.0 * 60.0) # refresh every 30 minutes
		
	var prev_connection_state = ConnectionStatus.NOT_CONNECTED
	var connection_poller = Timer.new()
	connection_poller.timeout.connect(
		func():
			var curr_connection_state = connection_state()
			if prev_connection_state != curr_connection_state:
				connection_status_changed.emit(curr_connection_state)
			prev_connection_state = curr_connection_state
	)
	add_child(connection_poller)
	connection_poller.start(1.0)
		
func start(soft = false):
	for i in get_children():
		if i is TwitchEventStream:
			i.credentials = credentials
			i.connect_to_server(soft)

func connection_state() -> ConnectionStatus:
	var streams = get_children().filter(func (i): return i is TwitchEventStream)
	
	var states = streams.map(func (i): return i.connection_state)\
		.filter(func (i): return i == TwitchEventStream.ConnectionState.STARTED)
		
	if len(states) == len(streams):
		return ConnectionStatus.CONNECTED
	elif len(states) > 0:
		return ConnectionStatus.PARTIAL
	
	return ConnectionStatus.NOT_CONNECTED
