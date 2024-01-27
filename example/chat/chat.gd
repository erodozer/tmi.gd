extends ScrollContainer

const ChatMessage = preload("./chat_message.tscn")
const HISTORY_LIMIT = 100

func _on_twitch_command(type, event):
	if type != Tmi.EventType.CHAT_MESSAGE:
		return
		
	var m: RichTextLabel = ChatMessage.instantiate()
	m.bbcode_text = "[color=#aaaaaa]%s[/color](%s): %s [%s]" % [
		event.sender.display_name,
		event.sender.pronouns,
		event.text,
		Time.get_datetime_string_from_unix_time(event.timestamp)
	]
	add_child(m)
	
	if get_child_count() > HISTORY_LIMIT:
		remove_child(get_child(0))
	
