class_name TwitchCredentials
extends Resource

@export var user_login: String
@export var user_id: String
@export var channel: String
@export var broadcaster_user_id: String
@export var client_id: String
@export var client_secret: String
@export var token: String
@export var refresh_token: String
@export var profile: Dictionary

@export_flags("Info", "Follow/Subscriptions", "Shoutout", "Raid", "Hype", "Redeems", "Polls/Predictions", "Goal") var listen_to = 0b11111111

var get_password = func():
	return "oauth:%s" % token
	
func to_json() -> String:
	return JSON.stringify({
		"user_login": user_login,
		"user_id": user_id,
		"broadcaster_user_id": broadcaster_user_id,
		"channel": channel,
		"client_id": client_id,
		"client_secret": client_secret,
		"access_token": token,
		"refresh_token": refresh_token,
		"user_name": profile.get("display_name", user_login),
		"profile_image": profile.get("image", ""),
	}, "  ")

## creates a stubbed TwitchCredentials using anonymous twitch test accounts
## Only capable of reading IRC messages
static func get_fallback_credentials() -> TwitchCredentials:
	
	var stub = TwitchCredentials.new()
	stub.user_login = "%s%d" % ["justinfan", randi_range(1000, 80000)]
	stub.get_password = func():
		return "SCHMOOPIIE"
		
	return stub

static func load_from_project_settings() -> TwitchCredentials:
	var credentials = TwitchCredentials.new()

	var channel = ProjectSettings.get_setting_with_override("application/tmi/channel")
	if channel:
		credentials.channel = channel

	credentials.client_id = ProjectSettings.get_setting_with_override("application/tmi/client_id")

	var secret = ProjectSettings.get_setting_with_override("application/tmi/client_secret")
	if secret:
		credentials.client_secret = secret
	
	var access_token = ProjectSettings.get_setting_with_override("application/tmi/access_token")
	if access_token:
		credentials.token = access_token

		var refresh_token = ProjectSettings.get_setting_with_override("application/tmi/refresh_token")
		if refresh_token:
			credentials.refresh_token = refresh_token

	return credentials

static func load_from_env() -> TwitchCredentials:
	var credentials = TwitchCredentials.new()

	credentials.user_login = OS.get_environment("TWITCH_LOGIN")
	credentials.channel = OS.get_environment("TWITCH_CHANNEL")
	credentials.client_id = OS.get_environment("TWITCH_CLIENT_ID")
	credentials.client_secret = OS.get_environment("TWITCH_CLIENT_SECRET")
	credentials.token = OS.get_environment("TWITCH_TOKEN")
	credentials.refresh_token = OS.get_environment("TWITCH_REFRESH_TOKEN")
	
	return credentials

static func load_from_file(jsonFilePath: String) -> TwitchCredentials:
	if not FileAccess.file_exists(jsonFilePath):
		return null
	
	var contents = FileAccess.get_file_as_string(jsonFilePath)
	var body = JSON.parse_string(contents)
	
	var credentials = TwitchCredentials.new()
	credentials.user_login = body.get("user_login", "")
	credentials.user_id = body.get("user_id", "")
	credentials.channel = body.get("channel", "")
	credentials.broadcaster_user_id = body.get("broadcaster_user_id", "")
	credentials.client_id = body.get("client_id", "")
	credentials.client_secret = body.get("client_secret", "")
	credentials.token = body.get("access_token", "")
	credentials.refresh_token = body.get("refresh_token", "")
	credentials.profile = {
		"display_name": body.get("user_name", credentials.user_login),
		"image": body.get("profile_image", ""),
	}
	return credentials
