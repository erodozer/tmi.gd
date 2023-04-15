extends RefCounted

class SubscriptionMessage:
	var user_id
	var user_name
	var is_gift
	var text

func handle_message(message, tmi: Tmi):
	match message.notification_type:
		"channel.subscribe:1":
			tmi.command.emit(
				Tmi.EventType.SUBSCRIPTION,
				{
					"user": {
						"id": message.event.user_id,
						"display_name": message.event.user_name
					},
					"is_gift": false,
					"text": message.event.get("user_input", ""),
				}
			)	
		"channel.subscription.gift:1":
			pass
		"channel.subscription.message:1":
			pass
