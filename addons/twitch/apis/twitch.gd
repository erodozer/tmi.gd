extends Node
class_name TwitchApi

const twitch_utils = preload("../utils.gd")

var credentials: TwitchCredentials

func http(command: String):
	if credentials == null:
		return null
	
	var req = HTTPRequest.new()
	add_child(req)
	var err = req.request(
		"https://api.twitch.tv/helix/%s" % command,
		PackedStringArray([
			"Authorization: Bearer %s" % [credentials.token],
			"Client-Id: %s" % [credentials.client_id]
		])
	)
	if err != OK:
		push_error("Unable to make twitch api request")
		return
		
	var response = await req.request_completed
	var status = response[1]
	req.queue_free()
	
	if status != 200:
		push_error("twitch api returned code %d" % status)
		return null
	
	var body:PackedByteArray = response[3]
	
	return JSON.parse_string(body.get_string_from_utf8())

func refresh_token():
	if credentials == null:
		return null
	
	var req = HTTPRequest.new()
	add_child(req)
	var err = req.request(
		"https://id.twitch.tv/oauth2/token",
		PackedStringArray([
			"Content-Type: application/x-www-form-urlencoded",
		]),
		HTTPClient.METHOD_POST,
		"grant_type=refresh_token&client_id=%s&client_secret=%s&refresh_token=%s" % [
			credentials.client_id,
			credentials.client_secret,
			credentials.refresh_token,
		],
	)
	if err != OK:
		push_error("Unable to make twitch api request")
		return
		
	var response = await req.request_completed
	var status = response[1]
	req.queue_free()
	
	if status != 200:
		push_error("twitch api returned code %d" % status)
		return null
	
	var body = JSON.parse_string(response[3].get_string_from_utf8())
	
	credentials.token = body.access_token
	credentials.refresh_token = body.refresh_token

## prefetch emote images and cache them to local storage
func load_twitch_emote(emote: String):
	var data = emote.split(":")
	var emote_id = data[0]
	
	var tex = twitch_utils.load_animated("user://emotes/%s.gif" % emote_id)
	if not tex:
		tex = twitch_utils.load_static("user://emotes/%s.png" % emote_id)
	
	if tex:
		return tex
		
	print("new emote encountered: %s" % emote_id)
	
	# Create an HTTP request node and connect its completion signal.
	
	# Perform the HTTP request
	# first we try to get an animated version if it exists
	# else we'll fall back to static png
	for type in ["animated", "static"]:
		var url = "https://static-cdn.jtvnw.net/emoticons/v2/%s/%s/dark/3.0" % [emote_id, type]
		
		var body = await twitch_utils.fetch(self, url)
		if body == null:
			continue
		
		match type:
			"static":
				return twitch_utils.save_static("user://emotes/%s.png" % emote_id, body)
			"animated":
				return twitch_utils.save_animated("user://emotes/%s.gif" % emote_id, body)
	
	return null
