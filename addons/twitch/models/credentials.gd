class_name TwitchCredentials
extends Resource

@export var bot_id: String
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

static func load_from_disk() -> TwitchCredentials:
	if not FileAccess.file_exists("user://tmi_credentials.json"):
		push_error("Tmi credentials have not yet been persisted")
		return null
	
	var file = FileAccess.open("user://tmi_credentials.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	var credentials = TwitchCredentials.new()
	credentials.bot_id = data.bot_id
	credentials.client_id = data.client_id
	credentials.client_secret = data.client_secret
	credentials.token = data.token
	credentials.refresh_token = data.refresh_token
	
	return credentials
	
static func save_to_disk(credentials: TwitchCredentials):
	var file = FileAccess.open("user://tmi_credentials.json", FileAccess.WRITE)
	
	file.store_string(JSON.stringify({
		"bot_id": credentials.bot_id,
		"client_id": credentials.client_id,
		"client_secret": credentials.client_secret,
		"token": credentials.token,
		"refresh_token": credentials.refresh_token
	}))
	file.close()
