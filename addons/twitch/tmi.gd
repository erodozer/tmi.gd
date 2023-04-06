extends Node
class_name Tmi

@export var channel: String
@export var credentials: TwitchCredentials
@export var autoconnect: bool = false

@export_category("Features")
@export var enable_bttv_emotes = false
@export var enable_7tv_emotes = false
@export var include_profile_images = false
@export var include_pronouns = false

@onready var irc: TwitchIrc = %Irc
@onready var twitch_api: TwitchApi = %TwitchAPI

var _emotes = []

signal credentials_updated(credentials: TwitchCredentials)

func _set_credentials(credentials: TwitchCredentials):
	if credentials == null:
		return
		
	self.credentials = credentials
	irc.credentials = credentials
	irc.channel = channel
	twitch_api.credentials = credentials
	
	credentials_updated.emit(credentials)
	TwitchCredentials.save_to_disk(credentials)
	
	if irc.is_connected:
		irc.connect_to_server()

func _ready():
	if not credentials:
		credentials = TwitchCredentials.load_from_disk()
	
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
		
	if autoconnect:
		irc.connect_to_server()
