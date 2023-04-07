class_name TwitchCredentials
extends Resource

@export var channel: String
@export var bot_id: String
@export var user_id: String
@export var broadcaster_user_id: String

@export var client_id: String
@export var client_secret: String
@export var token: String
@export var refresh_token: String

var get_password = func():
	return "oauth:%s" % token

static func get_fallback_credentials() -> TwitchCredentials:
	var stub = TwitchCredentials.new()
	stub.bot_id = "%s%d" % ["justinfan", randi_range(1000, 80000)]
	stub.get_password = func():
		return "SCHMOOPIIE"
		
	return stub
