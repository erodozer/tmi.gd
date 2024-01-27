func handle_message(message, tmi: Tmi):
	match message.notification_type:
		"channel.chat.notification:1":
