extends RefCounted

func handle_message(message, tmi: Tmi):
	if message.notification_type != "channel.raid:1":
		return
	
	tmi.command.emit(
		Tmi.EventType.RAID,
		{
			"user": {
				"id": message.event.user_id,
				"display_name": message.event.user_name,
			},
			"viewers": message.event.viewers,
		},
	)
