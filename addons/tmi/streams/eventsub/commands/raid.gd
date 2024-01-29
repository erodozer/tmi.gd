extends RefCounted

func handle_message(message, tmi: Tmi):
	if message.notification_type != "channel.raid:1":
		return
	
	tmi.command.emit(
		Tmi.EventType.RAID,
		{
			"channel": message.event.to_broadcaster_user_login,
			"user": {
				"id": message.event.from_broadcaster_user_id,
				"display_name": message.event.from_broadcaster_user_name,
			},
			"viewers": message.event.viewers,
		},
	)
