extends TmiEventQueue

var id: String
var broadcaster_user_id: String

var followers: int = 0
var latest_follower: TmiUserState = null

var subscribers: int = 0
var latest_subscriber: TmiUserState = null

signal updated

func _ready():
	super._ready()
	
	tmi.credentials_updated.connect(fetch_from_api)

func fetch_from_api(c: TwitchCredentials):
	# metrics APIs only work when looking at own data
	if c.broadcaster_user_id != c.user_id:
		return
	
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

	result = await api.http("subscriptions", { "broadcaster_id": broadcaster_user_id, "first": 1 })
	if result != null:
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
	# metrics APIs only work when looking at own data
	if tmi.credentials.broadcaster_user_id != tmi.credentials.user_id:
		return
	
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
