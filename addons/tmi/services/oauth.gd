extends TmiService
class_name TmiOAuthService

const utils = preload("../utils.gd")

static var logger = preload("../logger.gd").new("oauth")

# scopes required for overlay relevant EventSub
var REQUIRED_SCOPES = " ".join([
	"openid",
	"chat:read",
	"user:read:chat", "user:bot", "channel:bot",
	"moderator:read:chatters",
	"moderator:read:followers", "channel:read:subscriptions",
	"bits:read",
	"channel:read:redemptions",
	"channel:read:polls", "channel:read:predictions",
	"channel:read:hype_train",
	"channel:read:charity", "channel:read:goals",
	"moderator:read:shoutouts",
])

var peer : StreamPeerTCP
var server : TCPServer

@export var timeout : int = 60.0
@export var tcp_port : int = 3000

var redirect_url : String : 
	get:
		return "http://localhost:%d" % tcp_port
		
@export var force_verify: bool = false

var credentials: TwitchCredentials
var timer: SceneTreeTimer
signal finished

func _ready():
	set_process(false)

func _create_peer() -> StreamPeerTCP:
	return server.take_connection()

func login(credentials: TwitchCredentials):
	self.credentials = credentials
	_start_tcp_server()
	await finished
	print("[tmi/oauth]: login flow completed")

func _start_tcp_server():
	if server != null:
		return
		
	print("[tmi/oauth]: beginning login flow")
	server = TCPServer.new()
	if server.listen(tcp_port) != OK:
		print("[tmi/oauth]: Could not listen to port %d" % tcp_port)
		server = null
		return
	else:
		print("[tmi/oauth]: server is listening on %s" % redirect_url)
		
	set_process(true)
		
	timer = get_tree().create_timer(timeout)
	timer.timeout.connect(
		_stop_server,
		CONNECT_ONE_SHOT
	)

	var query = utils.qs({
		"response_type": " ".join(["token", "id_token"]) if not credentials.client_secret else "code",
		"client_id": credentials.client_id,
		"scope": REQUIRED_SCOPES,
		"redirect_uri": redirect_url,
		"force_verify": force_verify,
		"state": randi(),
		"nonce": randi(),
		"claims": JSON.stringify({
			"userinfo": {
				"picture": null,
				"preferred_username": null,
			}
		}),
	})
	var auth_url = "https://id.twitch.tv/oauth2/authorize?%s" % query
	
	OS.shell_open(auth_url)
		
func _stop_server():
	if server == null:
		return
	if peer == null:
		return
	
	peer.disconnect_from_host()
	peer = null

	server.stop()
	server = null
	
	set_process(false)
	
	finished.emit()

var HTTP_HEADER = """HTTP/1.1 %s
Server: Tmi.gd (Godot Engine 4)
Content-Length: %d
Connection: close
Content-Type: text/html; charset=UTF-8

%s"""

var RETRY_PAGE = """<html>
  <head>
	<title>%s [twitch login]</title>
	<script>
		javascript:window.location = window.location.toString().replace('#','?')
	</script>
  </head>
</html>
""" % [ProjectSettings.get_setting_with_override("application/config/name")]

var REDIRECT_PAGE = """<html>
  <head>
	<title>%s [twitch login]</title>
  </head>
  <body onload="javascript:close()">
	Authorization complete, you may now close this page.
  </body>
</html>
""" % [ProjectSettings.get_setting_with_override("application/config/name")]

func _process(_delta):
	if peer == null:
		peer = server.take_connection()
		return
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	
	peer.poll()
	if peer.get_available_bytes() == 0:
		return
		
	var response = peer.get_utf8_string(peer.get_available_bytes())
	if response == "":
		return
		
	_process_response(response)

func _process_response(response : String):
	if response.contains("favicon"):
		_send_response("404 NOT FOUND", "Not Found")
		return
	
	# parse out the query string parameters
	var start : int = response.strip_escapes().find("?")

	if start < 0:
		print("[tmi/oauth]: Invalid Response received, expecting required data in query parameters.")
		# in case the 
		_send_response("200 OK", RETRY_PAGE)
		return
		
	response = response.substr(start + 1, response.find(" ", start) - start)
	var data = utils.qs_split(response)
	if (data.has("error")):
		_send_response("400 BAD REQUEST", data["error"])
	elif "code" in data:
		_send_response("200 OK", REDIRECT_PAGE)
		await _code_to_token(data["code"])
	elif "id_token" in data:
		await _idtoken_credentials(data["id_token"], data["access_token"])
		_send_response("200 OK", REDIRECT_PAGE)

	_stop_server()

func _send_response(status_code: String, body: String):
	var buf = body.to_utf8_buffer()
	var data = HTTP_HEADER % [status_code, buf.size(), body]
	
	peer.put_data(data.to_utf8_buffer())
	
	peer.disconnect_from_host()
	peer = null
	
func _lookup_channel(access_token, channel):
	var broadcaster = await utils.fetch(
		self,
		"https://api.twitch.tv/helix/users",
		HTTPClient.METHOD_GET,
		{
			"Authorization": "Bearer %s" % access_token,
			"Client-Id": credentials.client_id,
		},
		{
			"login": channel,
		},
		true,
	)
	
	return broadcaster.data.data[0].id
	
func _code_to_token(code: String):
	var result = await utils.fetch(
		self,
		"https://id.twitch.tv/oauth2/token",
		HTTPClient.METHOD_POST,
		{
			"Content-Type": "application/x-www-form-urlencoded",
		},
		{
			"grant_type": "authorization_code",
			"client_id": credentials.client_id,
			"client_secret": credentials.client_secret,
			"code": code,
			"redirect_uri": redirect_url
		},
		true,
	)
	if result.code != 200:
		return
	var body = result.data
	
	var newCredentials = TwitchCredentials.new()
	newCredentials.client_id = credentials.client_id
	newCredentials.client_secret = credentials.client_secret
	newCredentials.token = body.access_token
	newCredentials.refresh_token = body.refresh_token
	
	var payload = await utils.fetch(
		self,
		"https://id.twitch.tv/oauth2/userinfo",
		HTTPClient.METHOD_GET,
		{
			"Authorization": "Bearer %s" % body.access_token,
		},
		{},
		true,
	)
	
	newCredentials.user_id = payload.data.sub
	newCredentials.user_login = payload.data.get("preferred_username", "").to_lower()
	newCredentials.profile = {
		"display_name": payload.data.get("preferred_username", ""),
		"image": payload.data.get("picture", "")
	}
	if credentials.channel:
		newCredentials.channel = credentials.channel
	else:
		newCredentials.channel = newCredentials.user_login
	
	newCredentials.broadcaster_user_id = await _lookup_channel(body.access_token, newCredentials.channel)
	
	await tmi.set_credentials(newCredentials)
	
func _idtoken_credentials(id_token, access_token):
	var body = id_token.split(".")[1] + "==" # add padding to base64 so godot can parse it
	var jwt = Marshalls.base64_to_utf8(body)
	var payload = JSON.parse_string(jwt)
	assert(payload != null, "unable to parse id token")
	
	var newCredentials = TwitchCredentials.new()
	newCredentials.user_id = payload.sub
	newCredentials.user_login = payload.get("preferred_username" ,"").to_lower()
	newCredentials.profile = {
		"display_name": payload.get("preferred_username" ,""),
		"image": payload.get("picture", ""),
	}
	if credentials.channel:
		newCredentials.channel = credentials.channel
		newCredentials.broadcaster_user_id = await _lookup_channel(access_token, newCredentials.channel)
	else:
		newCredentials.channel = payload.preferred_username
		newCredentials.broadcaster_user_id = payload.sub
	newCredentials.client_id = credentials.client_id
	newCredentials.token = access_token
	
	await tmi.set_credentials(newCredentials)

## Calls twitch API to validate if a token is still usable
## Typically call this on startup after loading credentials from persistent storage
func validate_token(credentials: TwitchCredentials):
	var result = await utils.fetch(
		self,
		"https://id.twitch.tv/oauth2/validate",
		HTTPClient.METHOD_GET,
		{
			"Content-Type": "application/x-www-form-urlencoded",
			"Authorization": "OAuth %s" % [credentials.token]
		},
		{},
		true,
	)
	
	if result.code != 200:
		push_warning("[tmi/oauth] Invalid token provided, reauthentication is advised")
	return result.code == 200
	
## Refreshes credentials to have a new access token if possible
## This should be called when Twitch API requests fail with 401
func refresh_token():
	if tmi.credentials == null:
		return
	if not tmi.credentials.refresh_token:
		await login(tmi.credentials)
		return
	
	var result = await utils.fetch(
		self,
		"https://id.twitch.tv/oauth2/token",
		HTTPClient.METHOD_POST,
		{
			"Content-Type": "application/x-www-form-urlencoded"
		},
		{
			"grant_type": "refresh_token",
			"client_id": tmi.credentials.client_id,
			"client_secret": tmi.credentials.client_secret,
			"refresh_token": tmi.credentials.refresh_token
		},
		true,
	)
	
	if result.code != 200:
		return
	
	var body = result.data
	
	var newCredentials = TwitchCredentials.new()
	newCredentials.user_id = tmi.credentials.user_id
	newCredentials.user_login = tmi.credentials.user_login
	newCredentials.channel = tmi.credentials.channel
	newCredentials.broadcaster_user_id = tmi.credentials.broadcaster_user_id
	newCredentials.client_id = tmi.credentials.client_id
	newCredentials.client_secret = tmi.credentials.client_secret
	newCredentials.token = body.access_token
	newCredentials.refresh_token = body.refresh_token
	
	await tmi.set_credentials(newCredentials)
