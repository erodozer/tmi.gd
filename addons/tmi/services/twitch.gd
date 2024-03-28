extends TmiService
class_name TmiTwitchService

const EMOTE_URL = "https://static-cdn.jtvnw.net/emoticons/v2/%s/%s/dark/3.0"

const utils = preload("../utils.gd")

@export var include_profile_images = true

var credentials: TwitchCredentials

var _profiles = {}

signal user_cached(profile)

func _ready():
	tmi.command.connect(self._on_tmi_command)

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
	push_warning("[tmi/api] twitch returned invalid response: %s" % res.code)
	return null

func fetch_profile_image(profile: TmiUserState):
	var tex: Texture2D
	var url = profile.extra.profile_image_url as String
	var extension = url.get_extension()
		
	match extension:
		"png":
			tex = await utils.fetch_static(self, "user://profile_images/%s.png" % profile.id, url)
		_:
			tex = await utils.fetch_animated(self, "user://profile_images/%s" % profile.id, url)
	
	return tex
	
func enrich(obj: TmiAsyncState):
	if obj is TmiUserState:
		await fetch_user(obj)
	elif obj is TmiChannelState:
		await fetch_channel(obj)

func fetch_user(profile: TmiUserState):
	var path = "user://profile/%s.profile" % profile.id
	var cached = _profiles.get(profile.id, null)
	if cached:
		if cached.expires_at < Time.get_unix_time_from_system():
			_profiles.erase(profile.id)
		else:
			profile.display_name = cached.display_name
			profile.extra["profile_image_url"] = cached.extra["profile_image_url"]
			if include_profile_images and cached.extra.get("profile_image") == null:
				cached.extra["profile_image"] = await fetch_profile_image(cached)
			profile.extra["profile_image"] = cached.extra.get("profile_image")
			return
	
	var result = await http("users", {"id": profile.id})
	if result == null:
		return
	
	var found_data = result.get("data", []).front()
	
	if found_data == null or found_data.id != profile.id:
		return
			
	profile.display_name = found_data.login
	profile.extra["profile_image_url"] = found_data.profile_image_url
	
	if include_profile_images:
		profile.extra["profile_image"] = await fetch_profile_image(profile)

	# mark profile for cache expiration after a certain amount of time
	profile.expires_at = Time.get_unix_time_from_system() + (15 * 60.0)

	# add to cache so the profile doesn't get removed due to garbage collection
	_profiles[profile.id] = profile
	
	user_cached.emit(profile)
	
func fetch_channel(channel: TmiChannelState):
	var result = await http("channels/followers", { "broadcaster_id": channel.broadcaster_user_id, "first": 1 })
	channel.followers = int(result.total)
	if len(result.data) > 0:
		var user =  result.data.front()
		var profile = TmiUserState.new()
		profile.id = user.user_id
		profile.display_name = user.user_name
		await fetch_user(profile)
		
		channel.latest_follower = profile

	# TODO get subscription list
	result = await http("subscriptions", { "broadcaster_id": channel.broadcaster_user_id, "first": 1 })
	channel.subscribers = int(result.total)
	if len(result.data) > 0:
		var user =  result.data.front()
		var profile = TmiUserState.new()
		profile.id = user.user_id
		profile.display_name = user.user_name
		await fetch_user(profile)
		
		channel.latest_subscriber = profile

func _on_tmi_command(type, event):
	# handle a subset of commands to update stateful data managed by the API
	if type == Tmi.EventType.FOLLOW:
		tmi.channel.followers += 1
		# TODO get profile
		var profile = TmiUserState.new()
		profile.id = event.user.id
		profile.display_name = event.user.display_name
		await fetch_user(profile)
		tmi.channel.latest_follower = profile

	if type == Tmi.EventType.SUBSCRIPTION:
		tmi.channel.subscribers += 1
		var profile = TmiUserState.new()
		profile.id = event.user.id
		profile.display_name = event.user.display_name
		await fetch_user(profile)
		tmi.channel.latest_subscriber = profile
