extends TmiService
class_name TmiTwitchService

const utils = preload("../utils.gd")

@export var include_profile_images = true

var credentials: TwitchCredentials

var _emotes = []
var _profiles = {}

signal user_cached(profile)

func _ready():
	var tmi = get_parent()
	
func http(command: String, params = {}, credentials = tmi.credentials):
	if credentials == null:
		return null
	if credentials.token == null or credentials.token == "":
		return null
	
	var res = await utils.fetch(
		self,
		"https://api.twitch.tv/helix/%s" % command,
		HTTPClient.METHOD_GET,
		{
			"Authorization": "Bearer %s" % credentials.token,
			"Client-Id": credentials.client_id,
		},
		params,
		true
	)
	if res.code < 300:
		return res.data
	return null

## prefetch emote images and cache them to local storage
func fetch_twitch_emote(emote_id: String, format = ["animated", "static"]):
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
	for type in format:
		var url = "https://static-cdn.jtvnw.net/emoticons/v2/%s/%s/dark/3.0" % [emote_id, type]
		
		var result = await utils.fetch(self, url)
		if result.code != 200:
			continue
		var body = result.data
		
		match type:
			"static":
				return await utils.save_static("user://emotes/%s.png" % emote_id, body)
			"animated":
				return await utils.save_animated("user://emotes/%s.gif" % emote_id, body)
	
	return null

func fetch_profile_image(profile: TmiUserState):
	var profile_image = utils.load_animated("user://profile_images/%s" % profile.id)
	if not profile_image:
		profile_image = utils.load_static("user://profile_images/%s.png" % profile.id)
		
	var url = profile.extra.profile_image_url as String
	if not profile_image and url:
		var result = await utils.fetch(self, url)
		var extension = url.get_extension()
		if result.code != 200:
			return
	
		var body = result.data
		DirAccess.make_dir_recursive_absolute("user://profile_images/")
		match extension:
			"png":
				profile_image = await utils.save_static("user://profile_images/%s.png" % profile.id, body)
			_:
				profile_image = await utils.save_animated("user://profile_images/%s" % profile.id, body)
		
	profile.extra["profile_image"] = profile_image
	
func enrich(obj: TmiAsyncState):
	if obj is TmiUserState:
		await fetch_user(obj)

func fetch_user(baseProfile: TmiUserState):
	var path = "user://profile/%s.profile" % baseProfile.id
	var cached = _profiles.get(baseProfile.id, null)
	if cached:
		if cached.expires_at < Time.get_unix_time_from_system():
			_profiles.erase(baseProfile.id)
		else:
			baseProfile.display_name = cached.display_name
			baseProfile.extra["profile_image_url"] = cached.extra["profile_image_url"]
			if include_profile_images and cached.extra["profile_image"] == null:
				await fetch_profile_image(cached)
			baseProfile.extra["profile_image"] = cached.extra.get("profile_image", null)
			return
	
	var result = await http("users", {"id": baseProfile.id})
	if result == null:
		return
	
	var users = result.get("data", [])
	var found_data = null
	for user in users:
		if user.id == baseProfile.id:
			found_data = user
			break
			
	if found_data == null:
		return
			
	var profile = TmiUserState.new()
	profile.id = baseProfile.id
	profile.display_name = found_data.login
	profile.extra["profile_image_url"] = found_data.profile_image_url
	
	if include_profile_images:
		await fetch_profile_image(profile)

	# mark profile for cache expiration after a certain amount of time
	profile.expires_at = Time.get_unix_time_from_system() + (15 * 60.0)

	# add to cache so the profile doesn't get removed due to garbage collection
	_profiles[baseProfile.id] = profile
	
	user_cached.emit(profile)
	
