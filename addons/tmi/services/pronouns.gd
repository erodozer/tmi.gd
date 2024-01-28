extends Node
class_name TmiPronounsService

const utils = preload("../utils.gd")

@onready var tmi: Tmi = get_parent()

var _pronouns = []

# Called when the node enters the scene tree for the first time.
func _ready():
	_pronouns = (await utils.fetch(self, "https://pronouns.alejo.io/api/pronouns", HTTPClient.METHOD_GET, {}, {}, true)).data

func enrich(obj: TmiAsyncState):
	if not (obj is TmiUserState):
		return
		
	var profile = obj as TmiUserState
	if "pronouns" in profile.extra:
		return
	
	var result = await utils.fetch(self, "https://pronouns.alejo.io/api/users/%s" % profile.display_name, HTTPClient.METHOD_GET, {}, {}, true)
	
	if result.code != 200:
		return
	
	if result.data.is_empty():
		return
	
	var user_pronoun = result.data.front()
	if user_pronoun:
		user_pronoun = user_pronoun.pronoun_id
		
	if user_pronoun:
		var pronoun = _pronouns.filter(func (p): return p.name == user_pronoun).front()
		profile.extra["pronouns"] = pronoun.display

