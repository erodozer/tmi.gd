extends ScrollContainer

const ChatMessage = preload("./chat_message.tscn")
const HISTORY_LIMIT = 100

func _on_twitch_command(type, event):
	if type != Tmi.EventType.CHAT_MESSAGE:
		return
		
	var m: RichTextLabel = ChatMessage.instantiate()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.bbcode_text = "%s[color=#%s]%s[/color]%s [color=#444](%s)[/color]: %s" % [
		"" if event.sender.extra.get("profile_image") == null else "[img=32]%s[/img] " % event.sender.extra.profile_image.resource_path,
		event.sender.color.to_html(),
		event.sender.display_name,
		"" if not ("pronouns" in event.sender.extra) else " (%s)" % event.sender.extra.get("pronouns"),
		"%02d:%02d" % [
			Time.get_datetime_dict_from_unix_time(event.timestamp).hour,
			Time.get_datetime_dict_from_unix_time(event.timestamp).minute,
		],
		event.text,
	]
	m.set_meta("user", event.sender.id)
	m.name = event.id
	%History.add_child(m)
	
	if get_child_count() > HISTORY_LIMIT:
		remove_child(get_child(0))
	
