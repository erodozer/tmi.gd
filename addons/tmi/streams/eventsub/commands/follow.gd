extends RefCounted

func handle_message(message, tmi: Tmi):
	if message.notification_type != "channel.follow:1":
		return
	
	tmi.command.emit(
		Tmi.EventType.FOLLOW,
		{
			"channel": message.event.broadcaster_user_login,
			"user": {
				"id": message.event.user_id,
				"display_name": message.event.user_name,
			},
			"timestamp": message.event.followed_at,
		},
	)
