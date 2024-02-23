extends Node
class_name TmiPronounsService

const utils = preload("../utils.gd")

@onready var tmi: Tmi = get_parent()

var _pronouns = []

# Called when the node enters the scene tree for the first time.
func _ready():
	_pronouns = (await utils.fetch(self, "https://api.pronouns.alejo.io/v1/pronouns", HTTPClient.METHOD_GET, {}, {}, true)).data

func enrich(obj: TmiAsyncState):
	if not (obj is TmiUserState):
		return
		
	var profile = obj as TmiUserState
	if "pronouns" in profile.extra:
		return
	
	var result = await utils.fetch(self, "https://api.pronouns.alejo.io/v1/users/%s" % profile.display_name, HTTPClient.METHOD_GET, {}, {}, true)
	
	if result.code != 200:
		return
	
	if result.data.is_empty():
		return
	
	var user_pronoun = result.data
	var primary = _pronouns.get(user_pronoun.pronoun_id)
	var secondary = _pronouns.get(user_pronoun.alt_pronoun_id, primary)
	profile.extra["pronouns"] = "%s/%s" % [
		primary.subject,
		secondary.subject if secondary != primary else secondary.object
	]