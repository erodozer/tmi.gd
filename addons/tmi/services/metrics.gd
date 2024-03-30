extends TmiEventQueue

var id: String
var broadcaster_user_id: String

var followers: int
var latest_follower: TmiUserState

var subscribers: int
var latest_subscriber: TmiUserState

signal updated

func _ready():
	super._ready()
	
	tmi.credentials_updated.connect(fetch_from_api)

func fetch_from_api(c: TwitchCredentials):
	id = c.channel
	broadcaster_user_id = c.broadcaster_user_id
	
	var api = tmi.get_node("TwitchAPI")
	var result = await api.http("channels/followers", { "broadcaster_id": broadcaster_user_id, "first": 1 })
	if result != null:
		followers = int(result.total)
		if len(result.data) > 0:
			var user =  result.data.front()
			var profile = await tmi.get_user(
				user.user_id,
				{
					"display_name": user.user_name,
				}
			)
			
			latest_follower = profile
	else:
		followers = 0
		latest_follower = null

	result = await api.http("subscriptions", { "broadcaster_id": broadcaster_user_id, "first": 1 })
	subscribers = int(result.total)
	if len(result.data) > 0:
		var user =  result.data.front()
		var profile = await tmi.get_user(
			user.user_id,
			{
				"display_name": user.user_name
			}
		)
		
		latest_subscriber = profile
		
	updated.emit()

func accept_command(type, event):
	return type in [Tmi.EventType.FOLLOW, Tmi.EventType.SUBSCRIPTION]
	
func process_event(type, event):
	# handle a subset of commands to update stateful data managed by the API
	if type == Tmi.EventType.FOLLOW:
		followers += 1
		var profile = await tmi.get_user(
			event.user.id,
			{
				"display_name": event.user.display_name
			}
		)
		latest_follower = profile

	if type == Tmi.EventType.SUBSCRIPTION:
		subscribers += 1
		var profile = await tmi.get_user(
			event.user.id,
			{
				"display_name": event.user.display_name
			}
		)
		latest_subscriber = profile
	
	updated.emit()
