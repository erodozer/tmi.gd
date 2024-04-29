extends Node
class_name Tmi

class EventType:
	const CHAT_MESSAGE = "message"
	const DELETE_MESSAGE = "delete-message"
	const FOLLOW = "follow"
	const SUBSCRIPTION = "subscription"
	const GIFT = "gift"
	const REDEEM = "redeem"
	const RAID = "raid"
	const USER_CHANGED = "userstate"
	const USER_DELETED = "user-deleted"
	const ROOM_STATE = "roomstate"

@export var credentials: TwitchCredentials

var _load_stack = {}
var _enrichable = []

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

# user profiles and caching are a core component of tmi.gd
# services may enrich profiles, but they will persist at this root level

## Length of time in seconds that newly enriched profiles should be cached for.
## This caching is for the profile object as a whole.  Individual services may have their
## own caching policies attached to profiles, which are managed on their own.
## Profiles should have their expiration timestamps extended whenever they appear
## from incoming messages.
## 
## Default: 24 hr
@export var profile_cache_duration = 24 * 3600 # 24 hr default

var _profiles = {}

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
		
	_enrichable = []
	for i in get_children():
		if i.has_method("enrich"):
			_enrichable.append(i)
		
func start():
	irc.close_stream()
	eventsub.close_stream()
		
	# only allow eventsub when listening to self
	if credentials.token and credentials.broadcaster_user_id == credentials.user_id:
		var success = await eventsub.connect_to_server()
		if not success and has_node("OAuth"):
			eventsub.logger.warn("[tmi/sub]: token potentially expired, attempting refresh")
			var oauth = get_node("OAuth") as TmiOAuthService
			oauth.refresh_token()
			# attempt a second time after refreshing
			if credentials.token:
				success = await eventsub.connect_to_server()
		if success:
			return
	
	# IRC is only useful for unauthenticated sessions or
	# listening to other channels when using a standard User Access Token
	await irc.connect_to_server()

func connection_state() -> ConnectionStatus:
	if irc.connection_state == TmiEventStream.ConnectionState.STARTED:
		return ConnectionStatus.IRC
	elif eventsub.connection_state == TmiEventStream.ConnectionState.STARTED:
		return ConnectionStatus.EVENTSUB
	return ConnectionStatus.NOT_CONNECTED

func enrich(obj: TmiAsyncState):
	for i in _enrichable:
		await obj.wait_for(i.name, i.enrich.bind(obj))
	
	return obj

func login(credentials: TwitchCredentials):
	var logger = preload("./logger.gd").new("oauth")
	
	if not credentials.client_id:
		logger.info("Client Id not provided, assuming unauthenticated session")
		await set_credentials(credentials)
		return
		
	if credentials.user_login.begins_with("justintv"):
		logger.info("Anonymous session detected")
		await set_credentials(credentials)
		return

	var oauth = get_node("OAuth")
	if credentials.token:
		logger.info("Access token provided, assuming authenticated session")
		if oauth == null or await oauth.validate_token(credentials):
			await set_credentials(credentials)
			return
		else:
			credentials.token = ""
			logger.warn("Access token invalid, will need to reauthenticate")
	
	if oauth == null:
		logger.error("Can not login to Twitch, Tmi is missing OAuth service child")
		return
		
	await oauth.login(credentials)

func get_user(user_id: String, data: Dictionary) -> TmiUserState:
	var profile = TmiUserState.new()
	profile.id = user_id
	
	var path = "user://profile/%s.profile" % profile.id
	var cached = _profiles.get(profile.id)
	if cached == null:
		if FileAccess.file_exists(path):
			cached = TmiUserState.from_json(FileAccess.get_file_as_string(path))
			_profiles[profile.id] = cached
			
	if cached == null or (cached != null and not cached.is_cached("$self")):
		_profiles[profile.id] = profile
	else:
		profile = cached
	profile.cache("$self", profile_cache_duration)

	for k in data.keys():
		profile.set(k, data[k])
	
	await enrich(profile)
	
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://profile")
	)
	var json = profile.to_json()
	var out = FileAccess.open(path, FileAccess.WRITE_READ)
	out.store_string(json)
	out.close()
	
	return profile
