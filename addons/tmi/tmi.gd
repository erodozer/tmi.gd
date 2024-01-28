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
	const ROOM_STATE = "roomstate"

@export var credentials: TwitchCredentials

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

## Updates the credentials of the Tmi session and attempts
## to reopen sockets
## 
## Always use this function to replace credentials instead
## of directly setting the property
func set_credentials(c: TwitchCredentials):
	if c == null:
		return
		
	credentials = c
	
	credentials_updated.emit(credentials)
	
	start()

func _ready():
	irc = preload("./streams/irc/irc.gd").new()
	irc.name = "IRC"
	eventsub = preload("./streams/eventsub/eventsub.gd").new()
	eventsub.name = "EventSub"
	irc.tmi = self
	eventsub.tmi = self
	add_child(irc)
	add_child(eventsub)
	
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
	
	if credentials == null:
		credentials = TwitchCredentials.get_fallback_credentials()
		
func start():
	irc.close_stream()
	eventsub.close_stream()
		
	if credentials.token:
		print("[tmi]: attempting to connect to EventSub")
		eventsub.connect_to_server()
	
	# IRC is only useful for unauthenticated sessions
	if not credentials.token:
		print("[tmi]: attempting to connect to IRC")
		irc.connect_to_server()

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

	if obj.is_loading:
		await obj.loaded

func login(credentials: TwitchCredentials):
	if not credentials.client_id:
		print("[tmi/oauth]: Client Id not provided, assuming unauthenticated session")
		set_credentials(credentials)
		return

	if credentials.token:
		push_warning("[tmi/oauth]: Access token provided, assuming authenticated session")
		set_credentials(credentials)
		return
	
	var oauth = get_node("OAuth")
	if oauth == null:
		push_error("Can not login to Twitch, Tmi is missing OAuth service child")
		return
		
	await oauth.login(credentials)
