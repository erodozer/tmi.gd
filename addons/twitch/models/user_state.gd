extends RefCounted
class_name TwitchUserState

const twitch_utils = preload("../utils.gd")

var id: String
var display_name: String
var badges: Array
var profile_image:
	get = _get_profile_image
var pronouns: String
var expires_at: int

func _get_profile_image() -> Texture2D:
	var path = "user://profile_images/%s.png" % id
	return twitch_utils.load_static(path)
