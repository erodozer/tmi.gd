extends RefCounted
class_name TwitchUserState

var id: String
var display_name: String
var badges: Array
var expires_at: int

var extra: Dictionary = {}

# flags to indicate that the profile isn't done loading
# used by any async APIs that extend the profile
var loading: Dictionary = {}

var is_loading:
	get = _is_loading

func _is_loading():
	return len(loading) > 0
