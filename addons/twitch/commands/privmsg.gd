extends RefCounted

const twitch_utils = preload("../utils.gd")

var PRIVMSG_PARSER: RegEx
var tmi: Tmi

func _init(tmi: Tmi):
	await tmi.ready
	PRIVMSG_PARSER = RegEx.new()
	PRIVMSG_PARSER.compile("#(?<channel>[^\\s]*)\\s:(?<message>.*)")
	
	tmi.irc.IrcMessageReceived.connect(handle_message)
	self.tmi = tmi
	
	if not DirAccess.dir_exists_absolute("user://emotes"):
		DirAccess.make_dir_recursive_absolute("user://emotes")
	
func _render_message(message: String, emotes: Dictionary = {}):
	var stringReplacements = []
	
	# iterate of emotes to access ids and positions
	for id in emotes:
		# use only the first position to find out the emote key word
		var emote = emotes[id]
		var position = emote.positions[0]
		var stringToReplace = message.substr(
			position[0],
			position[1] - position[0] + 1
		)
		
		stringReplacements.append({
			"stringToReplace": stringToReplace,
			"replacement": "[img=%d]%s[/img]" % [32, emote.texture.resource_path],
		})
	
	# convert the text into bbcode
	for r in stringReplacements:
		message = message.replace(r.stringToReplace, r.replacement)
		
	return tmi._emotes.reduce(
		func (acc, e):
			return acc.replace(
				e.code,
				"[img=%d]%s[/img]" % [
					(e.dimensions.width / e.dimensions.height) * 32,
					e.texture.resource_path
				]
			),
		message
	);
	
func fetch_user(user_id: String):
	var path = "user://profile/%s.profile" % user_id
	var profile = tmi._profiles.filter(func (p): return p.id == user_id).front()
	if profile:
		if profile.expires_at < Time.get_unix_time_from_system():
			tmi._profiles.remove_at(tmi._profiles.find(profile))
			profile = null
		else:
			return profile
	
	var result = await tmi.twitch_api.http("users?id=%s" % user_id)
	if result == null:
		return null
	
	var users = result.get("data", [])
	var found_data = null
	for user in users:
		if user.id == user_id:
			found_data = user
			break
			
	if found_data == null:
		return null
			
	profile = TwitchUserState.new()
	profile.id = user_id
	profile.display_name = found_data.login
	
	if tmi.include_profile_images:
		var profile_image = twitch_utils.load_static("user://profile_images/%s.png" % user_id)
		if not profile_image and found_data.profile_image_url:
			var body = await twitch_utils.fetch(tmi, found_data.profile_image_url)
			if body:
				DirAccess.make_dir_recursive_absolute("user://profile_images/")
				twitch_utils.save_static("user://profile_images/%s.png" % user_id, body)
	
	if tmi.include_pronouns:
		pass
	# mark profile for cache expiration after a certain amount of time
	profile.expires_at = Time.get_unix_time_from_system() + (15 * 60.0)

	# add to cache so the profile doesn't get removed due to garbage collection
	tmi._profiles.append(profile)
	
	return profile
	
func handle_message(ircCommand: TwitchIrcCommand):
	if ircCommand.command != "PRIVMSG":
		return
		
	# convert metadata into dictionary
	var result = PRIVMSG_PARSER.search(ircCommand.message)
	if not result:
		return
	
	var emotes = ircCommand.metadata.emotes.split("/", false)
	var e = {}
	var parse_emote = func (emote):
		var data = emote.split(":")
		var emote_id = data[0]
		var tex = await tmi.twitch_api.load_twitch_emote(emote)
		
		if not tex:
			return
		
		var positions = e.get(emote_id, [])
		for position in data[1].split(","):
			var s_e = position.split("-")
			positions.append([s_e[0].to_int(), s_e[1].to_int()])
		
		e[emote_id] = {
			"id": emote_id,
			"positions": positions,
			"texture": tex
		}
			
	for emote in emotes:
		await parse_emote.call(emote)
		
	ircCommand.metadata.emotes = e
	
	var profile = await fetch_user(ircCommand.metadata["user-id"])
		
	tmi.irc.Command.emit(
		"message",
		preload("../models/chat_message.gd").new(
			result.get_string("channel"),
			_render_message(result.get_string("message"), e),
			result.get_string("message"),
			ircCommand.metadata,
			profile,
		)
	)
