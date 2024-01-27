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

## creates a stubbed TwitchCredentials using anonymous twitch test accounts
## Only capable of reading IRC messages
static func get_fallback_credentials() -> TwitchCredentials:
	
	var stub = TwitchCredentials.new()
	stub.bot_id = "%s%d" % ["justinfan", randi_range(1000, 80000)]
	stub.get_password = func():
		return "SCHMOOPIIE"
		
	return stub

static func load_from_project_settings() -> TwitchCredentials:
	var credentials = TwitchCredentials.new()
	credentials.client_id = ProjectSettings.get_setting_with_override("application/tmi/client_id")
	credentials.client_secret = ProjectSettings.get_setting_with_override("application/tmi/client_secret")
	credentials.token = ProjectSettings.get_setting_with_override("application/tmi/token")
	credentials.refresh_token = ProjectSettings.get_setting_with_override("application/tmi/refresh_token")
	return credentials

static func load_from_env() -> TwitchCredentials:
	var credentials = TwitchCredentials.new()
	credentials.client_id = OS.get_environment("TWITCH_CLIENT_ID")
	credentials.client_secret = OS.get_environment("TWITCH_CLIENT_SECRET")
	credentials.token = OS.get_environment("TWITCH_TOKEN")
	credentials.refresh_token = OS.get_environment("TWITCH_REFRESH_TOKEN")
	
	return credentials

static func load_from_file(jsonFilePath: String) -> TwitchCredentials:
	var contents = FileAccess.get_file_as_string(jsonFilePath)
	var body = JSON.parse_string(contents)
	
	var credentials = TwitchCredentials.new()
	credentials.client_id = body.client_id
	credentials.client_secret = body.client_secret
	
	return credentials
	
