extends Node

const utils = preload("../utils.gd")

@onready var tmi: Tmi = get_parent()

var _pronouns = []

# Called when the node enters the scene tree for the first time.
func _ready():
	if tmi.include_pronouns:
		_pronouns = await utils.fetch(self, "https://pronouns.alejo.io/api/pronouns", true)

func fetch_pronouns_for_user(profile: TwitchUserState):
	if not tmi.include_pronouns:
		return
		
	profile.loading["pronouns"] = true
	var result = await utils.fetch(self, "https://pronouns.alejo.io/api/users/%s" % profile.display_name, true)
	
	if result == null:
		result = []
	
	var user_pronoun = result.front()
	if user_pronoun:
		user_pronoun = user_pronoun.pronoun_id
		
	if user_pronoun:
		var pronoun = _pronouns.filter(func (p): return p.name == user_pronoun).front()
		profile.extra["pronouns"] = pronoun.display
		
	profile.loading.erase("pronouns")

func _on_twitch_api_user_cached(profile):
	await fetch_pronouns_for_user(profile) # uses login id instead of user id
