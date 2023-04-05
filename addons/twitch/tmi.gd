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

var _profiles = []
var _emotes = []

func _ready():
	irc.credentials = credentials
	irc.channel = channel
	twitch_api.credentials = credentials
	
	if credentials:
		await twitch_api.refresh_token()
		var token_refresher = Timer.new()
		token_refresher.timeout.connect(twitch_api.refresh_token)
		add_child(token_refresher)
		token_refresher.start(30.0 * 60.0)
	
	if autoconnect:
		irc.connect_to_server()
