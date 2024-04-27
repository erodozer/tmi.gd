extends TmiService
class_name TmiHeatService
# Scott Garner's Heatmap extension
# This must also be enabled on your channel via https://dashboard.twitch.tv/extensions/cr20njfkgll4okyrhag7xxph270sqk-2.1.1
# See https://github.com/scottgarner/Heat/ for documentation, though this module handles the connection aspects.

# May not be necessary given the kind of system this is
const utils = preload("../utils.gd")

var socket = WebSocketPeer.new()

# Channel to watch
var target_channel_id

signal view_click_registered(id, position)

func _ready():
	tmi.credentials_updated.connect(credentials_updated)

func credentials_updated(c: TwitchCredentials):
	target_channel_id = c.broadcaster_user_id
	connect_to_websocket()

func connect_to_websocket():
	socket.connect_to_url("wss://heat-api.j38.net/channel/%s" % target_channel_id)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var response = socket.get_packet().get_string_from_ascii()
			var json = JSON.parse_string(response)
			if json.type == "click":
				var profile = {}
				profile.id = json.id
				# Anonymous - No idea how this works
				if (json.id.begins_with("A")):
					profile.display_name = "Anonymous"
					profile.color = Color.WHITE
					profile.extra = {}
					pass
				# Unverified - User is logged in but has not given this extension access
				elif (json.id.begins_with("U")):
					profile.display_name = "Unverified"
					profile.color = Color.ORANGE
					profile.extra = {}
					pass
				# User is logged in and has given the extension access, so we have their user ID
				else:
					profile = await tmi.get_user(json.id, {})
				
				var screen_pos = Vector2(float(json.x), float(json.y)) * Vector2(get_viewport().size)
				
				view_click_registered.emit(
					{
						"user": {
							"id": profile.id,
							"display_name": profile.display_name,
							"color": profile.color,
							"profile_image": profile.extra["profile_image"] if profile.extra.has("profile_image") else null
						},
						"position": screen_pos
					}
				)
	elif state == WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
		pass
	elif state == WebSocketPeer.STATE_CLOSED:
		# Attempt to reconnect
		connect_to_websocket()
