extends Node

const utils = preload("../utils.gd")

var _pronouns = []

# Called when the node enters the scene tree for the first time.
func _ready():
	_pronouns = await utils.fetch(self, "https://pronouns.alejo.io/api/pronouns", true)
	var tmi = get_parent()
	tmi.twitch_api.user_cached.connect(
		func(profile):
			if tmi.include_pronouns:
				await fetch_pronouns_for_user(profile) # uses login id instead of user id
	)

func fetch_pronouns_for_user(profile: TwitchUserState):
	profile.loading["pronouns"] = true
	var result = await utils.fetch(self, "https://pronouns.alejo.io/api/users/%s" % profile.display_name, true)
	
	var user_pronoun = result[0]
	if user_pronoun:
		user_pronoun = user_pronoun.pronoun_id
		
	if user_pronoun:
		var pronoun = _pronouns.filter(func (p): return p.name == user_pronoun).front()
		profile.extra["pronouns"] = pronoun.display
		
	profile.loading.erase("pronouns")
