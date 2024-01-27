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
@export var channels: Array[String]

@export_category("Features")
@export var enable_bttv_emotes = false
@export var enable_7tv_emotes = false
@export var include_profile_images = false
@export var include_pronouns = false

var _load_stack = {}
var _emotes = []

enum ConnectionStatus {
	NOT_CONNECTED,
	IRC,
	EVENTSUB,
}

signal credentials_updated(credentials: TwitchCredentials)
signal command(type, event)
signal connection_status_changed(status: ConnectionStatus)

var irc: TmiEventStream
var eventsub: TmiEventStream

func _set_credentials(c: TwitchCredentials):
	if c == null:
		return
		
	credentials = c
	
	credentials_updated.emit(credentials)
	
	start(true)

func _ready():
	irc = preload("./streams/irc/irc.gd").new()
	eventsub = preload("./streams/eventsub/eventsub.gd").new()
	irc.tmi = self
	eventsub.tmi = self

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
	
	add_child(irc)
	add_child(eventsub)
	
	if credentials == null:
		credentials = TwitchCredentials.get_fallback_credentials()
		
func start(soft = false):
	if channels.is_empty():
		print("[tmi]: must have at least one channel to connect to")
		return
		
	if credentials.token:
		eventsub.connect_to_server(soft)
	if credentials.token == null:
		irc.connect_to_server(soft)

func connection_state() -> ConnectionStatus:
	if irc.connection_state == TmiEventStream.ConnectionState.STARTED:
		return ConnectionStatus.IRC
	elif eventsub.connection_state == TmiEventStream.ConnectionState.STARTED:
		return ConnectionStatus.EVENTSUB
	return ConnectionStatus.NOT_CONNECTED

func enrich(obj: TmiAsyncState):
	for i in get_children():
		if i.has_method("enrich"):
			obj.wait_for(i.name, i.enrich.bind(obj))

	if not obj.is_loaded:
		await obj.loaded
