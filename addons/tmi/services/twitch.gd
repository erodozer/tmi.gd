extends TmiService
class_name TmiTwitchService

const EMOTE_URL = "https://static-cdn.jtvnw.net/emoticons/v2/%s/%s/dark/3.0"

const PROFILE_IMAGE_CACHE_KEY = "twitch_profile_image"
const PROFILE_CACHE_KEY = "twitch_api"

const utils = preload("../utils.gd")

static var logger = preload("../logger.gd").new("api")

## enables enriching profiles by fetching their profile image resource and saving it to disk
@export var include_profile_images = true
@export var image_cache_duration = 24 * 3600 # 24 hr
## enables enriching profiles by getting their chat color (only required for EventSub sessions)
@export var include_profile_color = true
## set the duration in which extra twitch API details are cached for 
@export var cache_duration = 3600 # 1 hr

var credentials: TwitchCredentials

signal user_cached(profile)

func http(command: String, params = {}, credentials = tmi.credentials, method = HTTPClient.METHOD_GET):
	if credentials == null:
		return null
	if credentials.token == null or credentials.token == "":
		return null
	
	var res = await utils.fetch(
		self,
		"https://api.twitch.tv/helix/%s" % command,
		method,
		{
			"Authorization": "Bearer %s" % credentials.token,
			"Client-Id": credentials.client_id,
			"Content-Type": "application/json",
		},
		params,
		true
	)
	if res.code < 300:
		return res.data
	logger.warn("twitch returned invalid response: %s" % res.code)
	
	# refresh token on authorization failed
	if res.code == 401 and tmi.has_node("OAuth") and credentials == tmi.credentials:
		return await tmi.get_node("OAuth").refresh_token()
	
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

func fetch_user(profile: TmiUserState):
	var img_dirty = profile.extra.get("profile_image", null) == null
	if not profile.is_cached(PROFILE_CACHE_KEY):
		var result = await http("users", {"id": profile.id})
		if result == null:
			return
		
		var found_data = result.get("data", []).front()
		
		if found_data == null or found_data.id != profile.id:
			return
				
		profile.display_name = found_data.login
		if profile.extra.get("profile_image_url") != found_data.profile_image_url:
			profile.extra["profile_image_url"] = found_data.profile_image_url
			img_dirty = true
			
		if include_profile_color:
			result = await http("chat/color", { "user_id": profile.id })
			profile.color = Color.from_string(result.data.front().color, Color.DARK_GRAY)
			
		profile.cache(PROFILE_CACHE_KEY, cache_duration)
		
	if include_profile_images and (img_dirty or not profile.is_cached(PROFILE_IMAGE_CACHE_KEY)):
		profile.extra["profile_image"] = await fetch_profile_image(profile)
		profile.cache(PROFILE_IMAGE_CACHE_KEY, image_cache_duration)
