extends RefCounted

var PRIVMSG_PARSER: RegEx

func _init():
	PRIVMSG_PARSER = RegEx.new()
	PRIVMSG_PARSER.compile("#(?<channel>[^\\s]*)\\s:(?<message>.*)")
	
	if not DirAccess.dir_exists_absolute("user://emotes"):
		DirAccess.make_dir_recursive_absolute("user://emotes")
	
func _render_message(message: String, emotes: Dictionary, tmi: Tmi):
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
			"stringToReplace": "%s" % stringToReplace,
			"replacement": "[img=%d]%s[/img]" % [32, emote.texture.resource_path],
		})
	
	# convert the text into bbcode
	for r in stringReplacements:
		message = message.replace(r.stringToReplace, r.replacement)
		
	var words = message.split(" ")
	for e in tmi._emotes:
		for i in range(len(words)):
			var w = words[i]
			if w == e.code:
				words[i] = "[img=%d]%s[/img]" % [
					(e.dimensions.width / e.dimensions.height) * 32,
					e.texture.resource_path
				]
	
	return " ".join(words)
	
func handle_message(ircCommand: TwitchIrcCommand, tmi: Tmi):
	if ircCommand.command != "PRIVMSG":
		return
		
	if "custom-reward-id" in ircCommand.metadata and ircCommand.metadata["custom-reward-id"] != "":
		return
		
	# ignore messages until other resources are loaded
	if not tmi._load_stack.is_empty():
		return
		
	# convert metadata into dictionary
	var result = PRIVMSG_PARSER.search(ircCommand.message)
	if not result:
		return
	
	var message = result.get_string("message")
	
	# ignore twitch chat commands
	if message.begins_with("/"):
		return
	
	var emotes = ircCommand.metadata.emotes.split("/", false)
	var e = {}
	var parse_emote = func (emote):
		var data = emote.split(":")
		var emote_id = data[0]
		var tex = await tmi.get_node("TwitchAPI").fetch_twitch_emote(emote_id)
		
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
	
	var profile = TmiUserState.new()
	profile.id =  ircCommand.metadata["user-id"]
	profile.display_name = ircCommand.metadata['display-name']
	await tmi.enrich(profile)
		
	tmi.command.emit(
		Tmi.EventType.CHAT_MESSAGE,
		{
			"id": ircCommand.metadata['id'],
			"channel": result.get_string("channel"),
			"text": _render_message(message, e, tmi),
			"raw_message": message,
			"tags": ircCommand.metadata,
			"sender": profile,
			"timestamp": ircCommand.metadata["tmi-sent-ts"].to_int(),
		}
	)
