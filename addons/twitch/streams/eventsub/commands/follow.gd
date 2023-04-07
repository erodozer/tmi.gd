extends RefCounted

func handle_message(message, tmi: Tmi):
	if message.notification_type != "channel.follow:1":
		return
	
	tmi.command.emit(
		"follow",
		{
			"user": {
				"id": message.event.user_id,
				"display_name": message.event.user_name,
			},
			"timestamp": message.event.followed_at,
		},
	)
