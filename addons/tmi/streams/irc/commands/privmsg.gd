extends RefCounted

var PRIVMSG_PARSER: RegEx

func _init():
	PRIVMSG_PARSER = RegEx.new()
	PRIVMSG_PARSER.compile("#(?<channel>[^\\s]*)\\s:(?<message>.*)")
	
func _to_fragments(message: String, emotes: Dictionary):
	var stringReplacements = []
	var fragments = []
	
	var parts = []
	for w in message.split(" "):
		parts.append({
			"type": "text",
			"text": w
		})
	
	# iterate of emotes to access ids and positions
	for id in emotes:
		# use only the first position to find out the emote key word
		var emote = emotes[id]
		var position = emote.positions[0]
		var stringToReplace = message.substr(
			position[0],
			position[1] - position[0] + 1
		)
		
		for i in range(len(parts)):
			var f = parts[i]
			if f.type == "text" and f.text == stringToReplace:
				parts[i] = {
					"type": "emote",
					"text": stringToReplace,
					"emote": {
						"provider": "twitch",
						"id": id,
						"animated": true,
						"format": "gif",
						"url": TmiTwitchService.EMOTE_URL % [id, "animated"],
						"fallback": [{
							"animated": false,
							"format": "png",
							"url": TmiTwitchService.EMOTE_URL % [id, "static"],
						}],
						"dimensions": Vector2i(32, 32)
					}
				}
				
	# flatten text fragments
	var builder = []
	for p in parts:
		match p.type:
			"text":
				builder.append(p.text)
			"emote":
				fragments.append({
					"type": "text",
					"text": " ".join(builder)
				})
				fragments.append(p)
				builder = []
	if !builder.is_empty():
		fragments.append({
			"type": "text",
			"text": " ".join(builder)
		})
	return fragments
	
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
		
		var positions = e.get(emote_id, [])
		for position in data[1].split(","):
			var s_e = position.split("-")
			positions.append([s_e[0].to_int(), s_e[1].to_int()])
		
		e[emote_id] = {
			"id": emote_id,
			"positions": positions,
		}
			
	for emote in emotes:
		await parse_emote.call(emote)
		
	ircCommand.metadata.emotes = e
	
	var profile = TmiUserState.new()
	profile.id =  ircCommand.metadata["user-id"]
	profile.display_name = ircCommand.metadata['display-name']
	profile = await tmi.enrich(profile)
	
	var chat = TmiChatMessage.new()
	chat.id = ircCommand.metadata['id']
	chat.channel = result.get_string("channel")
	chat.raw_message = message
	chat.tags = ircCommand.metadata
	chat.sender = profile
	chat.timestamp = ircCommand.metadata["tmi-sent-ts"].to_int()
	chat.fragments = _to_fragments(message, e)
	chat = await tmi.enrich(chat)
		
	tmi.command.emit(
		Tmi.EventType.CHAT_MESSAGE,
		chat
	)
