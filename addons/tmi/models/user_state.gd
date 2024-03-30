extends TmiAsyncState
class_name TmiUserState

var id: String
var display_name: String
var color: Color = Color.WHITE
var badges: Array

var extra: Dictionary = {}

static func from_json(json: String) -> TmiUserState:
	var user = TmiUserState.new()
	var data = JSON.parse_string(json)
	
	user.id = data.get("id")
	user.color = Color.from_string(data.get("color"), Color.WHITE)
	user.display_name = data.get("display_name")
	user.badges = data.get("badges", [])
	user.cache_expirations = data.get("cache_expirations")
	
	var extra = preload("../utils.gd").deserialize(data.get("extra", {}))
	user.extra = extra
	
	return user
	
func to_json() -> String:
	# convert data to a dictionary so that it's save to encode to text
	var dict = preload("../utils.gd").serialize(self)
	return JSON.stringify(dict)
