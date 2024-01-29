extends RefCounted

func handle_message(message, tmi: Tmi):
	match message.notification_type:
		"channel.chat.notification:1":
			pass
		"channel.chat.message:1":
			handle_chat_message(message, tmi)
		"channel.chat.message_delete:1":
			tmi.command.emit(
				Tmi.EventType.DELETE_MESSAGE,
				{
					"channel": message.event.broadcaster_user_login,
					"message": message.event.message_id,
				}
			)
		"channel.chat.clear_user_messages:1":
			tmi.command.emit(
				Tmi.EventType.USER_DELETED,
				{
					"channel": message.event.broadcaster_user_login,
					"user": message.event.target_user_id,
				}
			)
			
func _render_message(fragments, tmi):
	var bbcode = []
	for f in fragments:
		match f.type:
			"text":
				# inject emotes from other services
				var words = f.text.split(" ")
				for e in tmi._emotes:
					for i in range(len(words)):
						var w = words[i]
						if w == e.code:
							words[i] = "[img=%d]%s[/img]" % [
								e.dimensions.width,
								e.texture.resource_path,
							]
				bbcode.append(" ".join(words))
			"emote":
				var tex = await tmi.get_node("TwitchAPI").fetch_twitch_emote(
					f.emote.id,
					f.emote.format,
				)
				if tex != null:
					bbcode.append("[img=%d]%s[/img]" % [32, tex.resource_path])
				else:
					bbcode.append(f.text)
	
	return " ".join(bbcode)
	
func handle_chat_message(message, tmi):
	var event = message.event
	var profile = TmiUserState.new()
	profile.id =  event.chatter_user_id
	profile.display_name = event.chatter_user_name
	profile.color = Color.from_string(event.color, "#ffffff")
	profile = await tmi.enrich(profile)
		
	var text = await _render_message(event.message.fragments, tmi)
	tmi.command.emit(
		Tmi.EventType.CHAT_MESSAGE,
		{
			"id": event.message_id,
			"channel": event.broadcaster_user_login,
			"text": text,
			"raw_message": event.message.text,
			"tags": {
				"badges": event.badges,
			},
			"sender": profile,
			"timestamp": message.timestamp
		}
	)
