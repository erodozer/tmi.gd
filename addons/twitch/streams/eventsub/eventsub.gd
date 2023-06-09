class_name TwitchEventSub
extends TwitchEventStream

const ENDPOINTS = {
	"LIVE": {
		"WEBSOCKET": "wss://eventsub.wss.twitch.tv/ws",
		"SUBSCRIPTION": "https://api.twitch.tv/helix/eventsub/subscriptions"
	},
	"LOCAL": {
		"WEBSOCKET": "ws://127.0.0.1:8080/ws",
		"SUBSCRIPTION": "http://127.0.0.1:8080/eventsub/subscriptions"
	}
}

const SUBSCRIPTION_TYPES = [
	# Info
	{
		"channel.update": "1",
		"stream.online": "1",
		"stream.offline": "1",
	},
	# Follow/Subscriptions
	{
		"channel.follow": {
			"version": "2",
			"condition": {
				"broadcaster_user_id": "broadcaster_user_id",
				"moderator_user_id": "user_id",
			}
		},
		"channel.subscribe": "1",
		"channel.subscription.gift": "1",
		"channel.subscription.message": "1",
		"channel.cheer": "1",
	},
	# Shoutout
	{
		"channel.shoutout.create": {
			"version": "1",
			"condition": {
				"broadcaster_user_id": "broadcaster_user_id",
				"moderator_user_id": "user_id",
			}
		},
	},
	# Raid
	{
		"channel.raid": {
			"version": "1",
			"condition": {
				"to_broadcaster_user_id": "broadcaster_user_id",
			}
		}
	},
	# Hype
	{	
		"channel.hype_train.begin": "1",
		"channel.hype_train.progress": "1",
		"channel.hype_train.end": "1"
	},
	# Redeems
	{
		"channel.channel_points_custom_reward_redemption.add": "1",
	},
	# Polls/Predictions
	{
		"channel.poll.begin": "1",
		"channel.poll.progress": "1",
		"channel.poll.end": "1",
		"channel.prediction.begin": "1",
		"channel.prediction.progress": "1",
		"channel.prediction.lock": "1",
		"channel.prediction.end": "1",
	},
	# Goals/Charity
	{
		"channel.charity_campaign.donate": "1",
		"channel.charity_campaign.progress": "1",
		"channel.goal.progress": "1",
	}
]

@export_flags("Info", "Follow/Subscriptions", "Shoutout", "Raid", "Hype", "Redeems", "Polls/Predictions", "Goal") var listen_to = 0
@export_enum("LIVE", "LOCAL") var mode = "LIVE"

var socket: WebSocketPeer
var reconnect_socket: WebSocketPeer

var session_id: String
var keep_alive_timer: Timer

signal message_received(command)
signal socket_connected
signal authenticated(success)
signal request
signal channel_set

@onready var commands:  = [
	await preload("./commands/redeem.gd").new(),
	await preload("./commands/follow.gd").new(),
	await preload("./commands/raid.gd").new(),
	await preload("./commands/subscription.gd").new()
]

func _init():
	# twitch IRC command parsing using regex grouops
	message_received.connect(self.handle_message)
	
func _ready():
	keep_alive_timer = Timer.new()
	keep_alive_timer.timeout.connect(
		func():
			# attempt reconnect process for new session
			# if this one has reached its expiration
			connect_to_server(true)
	)
	add_child(keep_alive_timer)
	
func connect_to_server(soft = false):
	# do not start up the socket on soft connects
	if soft and socket == null:
		return
	
	# do not attempt to connect if we're in the middle
	# of reconnecting already
	if reconnect_socket:
		return
		
	if socket:
		socket.close()
		socket = null
	
	if credentials == null:
		return
	if credentials.user_id == "":
		return
	
	connection_state = ConnectionState.NOT_STARTED
	
	socket = WebSocketPeer.new()
	
	# create websocket connection to twitch irc endpoitn
	socket.connect_to_url(ENDPOINTS[mode].WEBSOCKET)
	set_process(true)
	
func _process(_delta):
	for socket in [self.socket, reconnect_socket]:
		if socket == null:
			continue
		
		socket.poll()
		
		var state = socket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			# detect first moment of when we're open
			if connection_state == ConnectionState.NOT_STARTED:
				_setup_connection()
				
			# read current received packets until end of buffer
			while socket.get_available_packet_count():
				_handle_packet(socket.get_packet())
				
		elif state == WebSocketPeer.STATE_CLOSING:
			# Keep polling to achieve proper close.
			pass
		elif state == WebSocketPeer.STATE_CLOSED:
			var code = socket.get_close_code()
			var reason = socket.get_close_reason()
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
			keep_alive_timer.stop()
			set_process(false) # Stop processing.

func request_permission(permission, details):
	var version = ""
	var condition = {
		"broadcaster_user_id": credentials.broadcaster_user_id
	}
	
	if details is String:
		version = details
		
	if details is Dictionary:
		version = details.version
		if details.condition:
			condition = {}
			for i in details.condition:
				condition[i] = credentials.get(details.condition[i])
	
	var req = HTTPRequest.new()
	add_child(req)
	req.request(
		ENDPOINTS[mode].SUBSCRIPTION,
		[
			"Authorization: Bearer %s" % credentials.token,
			"Client-Id: %s" % credentials.client_id,
			"Content-Type: application/json",
		],
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"type": permission,
			"version": version,
			"condition": condition,
			"transport": {
				"method": "websocket",
				"session_id": session_id
			}
		})
	)
	
	var result = await req.request_completed
	
	if result[1] != 202:
		push_error("Request for permission failed: %s" % permission)
		print_debug(JSON.parse_string(result[3].get_string_from_utf8()))
		
	# return success if response is ok
	return result[1] == 202
	
func _setup_connection():
	connection_state = ConnectionState.STARTING
	
	# wait for welcome message
	await socket_connected
	
	# request all permissions necessary
	for i in range(len(SUBSCRIPTION_TYPES)):
		if 1 << i & listen_to:
			for subscription in SUBSCRIPTION_TYPES[i]:
				var version = SUBSCRIPTION_TYPES[i][subscription]
				var success = await request_permission(subscription, version)
				if not success:
					push_error("Authentication failed")
					connection_state = ConnectionState.FAILED
					socket.close()
					return
	
	print("twitch-gd: welcome to subway")
	
	connection_state = ConnectionState.STARTED

func _handle_packet(packet: PackedByteArray):
	# parse packet as list of json messages
	var event = packet.get_string_from_utf8()
	
	for message in event.strip_edges().split("\n", false):
		var data = JSON.parse_string(message)
		if data:
			message_received.emit(data)

func handle_message(command: Dictionary):
	match command.metadata.message_type:
		"session_keepalive":
			if not keep_alive_timer.paused:
				keep_alive_timer.start(keep_alive_timer.wait_time)
		"session_welcome":
			session_id = command.payload.session.id
			keep_alive_timer.start(command.payload.session.keepalive_timeout_seconds + 5.0) # twitch's keep alive is a bit too aggressive
			
			if reconnect_socket:
				socket.close()
				socket = reconnect_socket
				reconnect_socket = null
			else:
				socket_connected.emit()
		"session_reconnect":
			reconnect_socket = WebSocketPeer.new()
			reconnect_socket.connect_to_url(command.metadata.payload.session.reconenct_url)
		"notification":
			if not keep_alive_timer.paused:
				keep_alive_timer.start(keep_alive_timer.wait_time)
			
			var notification = TwitchEventSubNotification.new()
			notification.message_id = command.metadata.message_id
			notification.notification_type = "%s:%s" % [
				command.metadata.subscription_type,
				command.metadata.subscription_version
			]
			notification.event = command.payload.event
			
			var tmi = get_parent()
			for c in commands:
				c.handle_message(notification, tmi)
				
