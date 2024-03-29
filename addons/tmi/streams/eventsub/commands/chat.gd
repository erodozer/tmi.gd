extends RefCounted

func handle_message(message, tmi: Tmi):
	if not tmi._load_stack.is_empty():
		return
		
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
			
func _to_fragments(fragments):
	var out = []
	for f in fragments:
		match f.type:
			"text":
				out.append({
					"type": "text",
					"text": f.text
				})
			"emote":
				out.append({
					"type": "emote",
					"text": f.text,
					"emote": {
						"provider": "twitch",
						"id": f.emote.id,
						"format": "gif" if "animated" in f.emote.format else "png",
						"animated": "animated" in f.emote.format,
						"url": TmiTwitchService.EMOTE_URL % [f.emote.id, "animated" if "animated" in f.emote.format else "static"],
						"dimensions": Vector2i(32, 32)
					}
				})
	
	return out
	
func handle_chat_message(message, tmi):
	var event = message.event
	var profile = TmiUserState.new()
	profile.id =  event.chatter_user_id
	profile.display_name = event.chatter_user_name
	profile.color = Color.from_string(event.color, "#ffffff")
	profile = await tmi.enrich(profile)
	
	var text = TmiChatMessage.new()
	text.id = event.message_id
	text.channel = event.broadcaster_user_login
	text.raw_message = event.message.text
	text.fragments = _to_fragments(event.message.fragments)
	text.sender = profile
	text.tags = {
		"badges": event.badges,
		"cheer": event.cheer,
		"reward_id": event.channel_points_custom_reward_id
	}
	text.timestamp = message.timestamp
	text = await tmi.enrich(text)
		
	tmi.command.emit(
		Tmi.EventType.CHAT_MESSAGE,
		text,
	)
