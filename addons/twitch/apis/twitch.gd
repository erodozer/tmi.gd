extends Node
class_name TwitchApi

const utils = preload("../utils.gd")

var credentials: TwitchCredentials

var _emotes = []
var _profiles = []

signal user_cached(profile)

func _ready():
	var tmi = get_parent()
	user_cached.connect(
		func (profile):
			if tmi.include_profile_images:
				await fetch_profile_image(profile)
	)

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

func refresh_token(credentials: TwitchCredentials) -> TwitchCredentials:
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
	
	var newCredentials = TwitchCredentials.new()
	newCredentials.bot_id = credentials.bot_id
	newCredentials.client_id = credentials.client_id
	newCredentials.client_secret = credentials.client_secret
	newCredentials.token = body.access_token
	newCredentials.refresh_token = body.refresh_token
	return newCredentials

## prefetch emote images and cache them to local storage
func fetch_twitch_emote(emote: String):
	var data = emote.split(":")
	var emote_id = data[0]
	
	var tex = utils.load_animated("user://emotes/%s.gif" % emote_id)
	if not tex:
		tex = utils.load_static("user://emotes/%s.png" % emote_id)
	
	if tex:
		return tex
		
	print("new emote encountered: %s" % emote_id)
	
	# Create an HTTP request node and connect its completion signal.
	
	# Perform the HTTP request
	# first we try to get an animated version if it exists
	# else we'll fall back to static png
	for type in ["animated", "static"]:
		var url = "https://static-cdn.jtvnw.net/emoticons/v2/%s/%s/dark/3.0" % [emote_id, type]
		
		var body = await utils.fetch(self, url)
		if body == null:
			continue
		
		match type:
			"static":
				return utils.save_static("user://emotes/%s.png" % emote_id, body)
			"animated":
				return utils.save_animated("user://emotes/%s.gif" % emote_id, body)
	
	return null

func fetch_profile_image(profile: TwitchUserState):
	profile.loading["profile_image"] = true
	var profile_image = utils.load_static("user://profile_images/%s.png" % profile.id)
	if not profile_image and profile.extra.profile_image_url:
		var body = await utils.fetch(self, profile.extra.profile_image_url)
		if body:
			DirAccess.make_dir_recursive_absolute("user://profile_images/")
			profile_image = await utils.save_static("user://profile_images/%s.png" % profile.id, body)
			
	profile.extra["profile_image"] = profile_image
	profile.loading.erase("profile_image")

func fetch_user(user_id: String):
	var path = "user://profile/%s.profile" % user_id
	var profile = _profiles.filter(func (p): return p.id == user_id).front()
	if profile:
		if profile.expires_at < Time.get_unix_time_from_system():
			_profiles.remove(profile)
			profile = null
		else:
			return profile
	
	var result = await http("users?id=%s" % user_id)
	if result == null:
		return null
	
	var users = result.get("data", [])
	var found_data = null
	for user in users:
		if user.id == user_id:
			found_data = user
			break
			
	if found_data == null:
		return null
			
	profile = TwitchUserState.new()
	profile.id = user_id
	profile.display_name = found_data.login
	profile.extra["profile_image_url"] = found_data.profile_image_url
	
	# mark profile for cache expiration after a certain amount of time
	profile.expires_at = Time.get_unix_time_from_system() + (15 * 60.0)

	# add to cache so the profile doesn't get removed due to garbage collection
	_profiles.append(profile)
	
	user_cached.emit(profile)
	await get_tree().process_frame

	return profile
	
