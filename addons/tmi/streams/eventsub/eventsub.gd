class_name TwitchEventSub
extends TmiEventStream

const utils = preload("../../utils.gd")

const ENDPOINTS = {
	"LIVE": {
		"WEBSOCKET": "wss://eventsub.wss.twitch.tv/ws",
		"SUBSCRIPTION": "eventsub/subscriptions"
	},
	"LOCAL": {
		"WEBSOCKET": "ws://127.0.0.1:8080/ws",
		"SUBSCRIPTION": "http://127.0.0.1:8080/eventsub/subscriptions"
	}
}

const SUBSCRIPTION_TYPES = [
	# Chat
	{
		"channel.chat.message": {
			"version": "1",
			"condition": {
				"broadcaster_user_id": "broadcaster_user_id",
				"user_id": "user_id"
			}
		},
		"channel.chat.notification": {
			"version": "1",
			"condition": {
				"broadcaster_user_id": "broadcaster_user_id",
				"user_id": "user_id"
			}
		},
		"channel.chat.message_delete": {
			"version": "1",
			"condition": {
				"broadcaster_user_id": "broadcaster_user_id",
				"user_id": "user_id"
			}
		},
		"channel.chat.clear_user_messages": {
			"version": "1",
			"condition": {
				"broadcaster_user_id": "broadcaster_user_id",
				"user_id": "user_id"
			}
		},
	},
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

var logger = preload("../../logger.gd").new("sub")

var socket: WebSocketPeer
var reconnect_socket: WebSocketPeer

var session_id: String
var keep_alive_timer: Timer

@export_enum("LIVE", "LOCAL") var mode = "LIVE"

signal socket_connected
signal authenticated(success)
signal request
signal channel_set

@onready var commands:  = [
	await preload("./commands/chat.gd").new(),
	await preload("./commands/redeem.gd").new(),
	await preload("./commands/follow.gd").new(),
	await preload("./commands/raid.gd").new(),
	await preload("./commands/subscription.gd").new()
]

func _ready():
	keep_alive_timer = Timer.new()
	keep_alive_timer.name = "KeepAlive"
	keep_alive_timer.timeout.connect(
		func():
			if connection_state == ConnectionState.NOT_STARTED:
				# attempt reconnect process for new session
				# if this one has reached its expiration
				connect_to_server()
	)
	add_child(keep_alive_timer)
	
func connect_to_server():
	# do not start up the socket on soft connects
	if socket != null:
		return false
	
	# do not attempt to connect if we're in the middle
	# of reconnecting already
	if reconnect_socket:
		return false
	
	logger.info("attempting to connect to EventSub")
	
	connection_state = ConnectionState.NOT_STARTED
	
	socket = WebSocketPeer.new()
	
	# create websocket connection to twitch irc endpoitn
	socket.connect_to_url(ENDPOINTS[mode].WEBSOCKET)
	
	while true:
		match connection_state:
			ConnectionState.FAILED:
				return false
			ConnectionState.STARTED:
				return true
			_:
				await get_tree().process_frame
	
func close_stream():
	if socket:
		logger.info("closing stream")
		socket.close()
		socket = null
	
	if connection_state != ConnectionState.FAILED:
		connection_state = ConnectionState.NOT_STARTED
	
func poll():
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
			logger.warn("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
			keep_alive_timer.stop()
			set_process(false) # Stop processing.

func request_permission(permission, details):
	var version = ""
	var condition = {
		"broadcaster_user_id": tmi.credentials.broadcaster_user_id
	}
	
	if details is String:
		version = details
		
	if details is Dictionary:
		version = details.version
		if details.condition:
			condition = {}
			for i in details.condition:
				condition[i] = tmi.credentials.get(details.condition[i])
	
	var result = await tmi.get_node("TwitchAPI").http(
		ENDPOINTS[mode].SUBSCRIPTION,
		{
			"type": permission,
			"version": version,
			"condition": condition,
			"transport": {
				"method": "websocket",
				"session_id": session_id
			}
		},
		tmi.credentials,
		HTTPClient.METHOD_POST,
	)
	
	return result != null
	
func _setup_connection():
	logger.info("connection established, requesting permissions")
	connection_state = ConnectionState.STARTING
	
	# wait for welcome message
	await socket_connected
	
	# request all permissions necessary
	for i in range(len(SUBSCRIPTION_TYPES)):
		for subscription in SUBSCRIPTION_TYPES[i]:
			var version = SUBSCRIPTION_TYPES[i][subscription]
			var success = await request_permission(subscription, version)
			if not success:
				logger.warn("Authentication failed for %s, disabling message type" % subscription)
				connection_state = ConnectionState.FAILED
				close_stream()
				return

	logger.info("we're in 😎")
	
	tmi.command.emit(
		Tmi.EventType.ROOM_STATE,
		{
			"channel_id": tmi.credentials.broadcaster_user_id,
		},
	)
	
	connection_state = ConnectionState.STARTED

func _handle_packet(packet: PackedByteArray):
	# parse packet as list of json messages
	var event = packet.get_string_from_utf8()
	
	for message in event.strip_edges().split("\n", false):
		var data = JSON.parse_string(message)
		if data:
			handle_websocket_message(data)

func handle_message(message):
	for c in commands:
		c.handle_message(message, tmi)

func handle_websocket_message(command: Dictionary):
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
			notification.timestamp = Time.get_unix_time_from_datetime_string(command.metadata.message_timestamp)
			notification.event = command.payload.event
			
			message_queue.append(notification)
		
