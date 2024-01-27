extends RefCounted

class SubscriptionMessage:
	var user_id
	var user_name
	var is_gift
	var gifted
	var total
	var text

func handle_message(message, tmi: Tmi):
	match message.notification_type:
		"channel.subscribe:1":
			if message.event.is_gift:
				return
			tmi.command.emit(
				Tmi.EventType.SUBSCRIPTION,
				{
					"channel": message.event.broadcaster_user_login,
					"user": {
						"id": message.event.user_id,
						"display_name": message.event.user_name
					},
					"is_gift": message.event.get("is_gift", false),
					"text": message.event.get("user_input", ""),
				}
			)	
		"channel.subscription.gift:1":
			tmi.command.emit(
				Tmi.EventType.SUBSCRIPTION,
				{
					"channel": message.event.broadcaster_user_login,
					"user": {
						"id": message.event.user_id,
						"display_name": message.event.user_name if not message.event.is_anonymous else "Anonymous"
					},
					"is_gift": true,
					"gifted": message.event.total,
					"text": message.event.get("user_input", ""),
				}
			)	
		"channel.subscription.message:1":
			tmi.command.emit(
				Tmi.EventType.SUBSCRIPTION,
				{
					"channel": message.event.broadcaster_user_login,
					"user": {
						"id": message.event.user_id,
						"display_name": message.event.user_name
					},
					"is_gift": false,
					"total": message.event.cumulative_months,
					"text": message.event.get("user_input", ""),
				}
			)
