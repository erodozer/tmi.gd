class_name TwitchIrc
extends TmiEventStream

const ENDPOINT = "ws://irc-ws.chat.twitch.tv:80"

static var logger = preload("../../logger.gd").new("irc")

var socket: WebSocketPeer

signal message_received(command: TwitchIrcCommand)
signal socket_connected(channel)
signal authenticated(success)
signal request(acknowledge)

var COMMAND_REGEX: RegEx

@onready var commands = [
	await preload("./commands/privmsg.gd").new(),
	await preload("./commands/deletemsg.gd").new(),
	await preload("./commands/deleteuser.gd").new(),
	await preload("./commands/roomstate.gd").new(),
	await preload("./commands/userstate.gd").new(),
]

var _holding_messages = []

func _init():
	# twitch IRC command parsing using regex grouops
	COMMAND_REGEX = RegEx.new()
	COMMAND_REGEX.compile("(@(?<metadata>.*)\\s)?(:(.*!.*@)?((?<username>.*)\\.)?tmi\\.twitch\\.tv\\s)(?<command>(\\S*))\\s*(?<message>.*)")
	
	message_received.connect(handle_message)
	
func connect_to_server():
	logger.info("attempting to connect to IRC")
	close_stream()

	connection_state = ConnectionState.NOT_STARTED
	socket = WebSocketPeer.new()
	# create websocket connection to twitch irc endpoitn
	socket.connect_to_url(ENDPOINT)
	
func close_stream():
	if socket:
		logger.info("closing stream")
		socket.close()
		socket = null
	
	if connection_state != ConnectionState.FAILED:
		connection_state = ConnectionState.NOT_STARTED
	
func poll():
	if socket == null:
		return
		
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
		set_process(false) # Stop processing.
		socket = null
	
func _setup_connection():
	logger.info("connection established")
	connection_state = ConnectionState.STARTING
	
	# this requests for this client to receive additional twitch IRC specific commands
	# in its command stream.
	var err = socket.send_text("CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership")
	if err:
		logger.error("failed to request additional capabiltilies")
		connection_state = ConnectionState.FAILED
		socket.close()
		return
		
	var kill_timer = get_tree().create_timer(10.0)
	kill_timer.timeout.connect(
		func ():
			if socket == null:
				return

			if connection_state != ConnectionState.STARTED:
				logger.error("could not connect to IRC within time limit")
				connection_state = ConnectionState.FAILED
				socket.close()
			, CONNECT_ONE_SHOT
	)
		
	_wait_for_acknowledgement()
		
func _wait_for_acknowledgement():
	if not socket:
		return
	
	# wait for cap req acknowledgement before proceeding
	var acknowledged = await request
	if not acknowledged:
		logger.error("capability request denied")
		connection_state = ConnectionState.FAILED
		socket.close()
		return
	
	# set authentication of the integration so that the bot
	# may assume an identity within chat
	_login_with_credentials(tmi.credentials)

func _login_with_credentials(credentials: TwitchCredentials):
	if socket == null:
		return

	socket.send_text("PASS %s" % credentials.get_password.call())
	socket.send_text("NICK %s" % credentials.user_login)
	
	var authed = await authenticated
	if not authed:
		logger.error("Authentication failed")
		connection_state = ConnectionState.FAILED
		socket.close()
		return
		
	_join_channel()
	
func _join_channel():
	if socket == null:
		return

	# join channels to listen to
	socket.send_text("JOIN #%s" % tmi.credentials.channel)
	
	# begin a ping-pong with the server to keep the bot alive
	var ping_interval = Timer.new()
	ping_interval.wait_time = 1.0
	ping_interval.timeout.connect(self._send_ping)
	add_child(ping_interval)
	ping_interval.start()
	logger.info("we're in hampwnDance")
	
	connection_state = ConnectionState.STARTED

func _handle_packet(packet: PackedByteArray):
	# converts a websocket message from the IRC stream into an object
	var event = packet.get_string_from_utf8()
	
	for message in event.strip_edges().split("\n"):
		var command = _parse_twitch_message(message)
		if command:
			handle_websocket_message(command)
	
## Keeps the connection alive by sending PING requests to the server
func _send_ping():
	if socket == null:
		return
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
		
	socket.send_text("PING")

## Responds to server ping requests to keep alive
func _send_pong():
	socket.send_text("PONG")
	
## Sends a PRIVMSG to a specified channel.
## If the channel is not specified, we default to using the first channel that 
## we are connected to
func send_message(text, channel = tmi.channels[0]):
	socket.send_text("PRIVMSG #%s :%s" % [
		channel,
		text
	])

## parses out an IRC message and converts it into a rich 
## [IrcCommand] if possible
func _parse_twitch_message(rawMessage: String):
	var result = COMMAND_REGEX.search(rawMessage)
	if not result:
		return null

	var command = TwitchIrcCommand.new()
		
	if result.get_string("metadata"):
		# convert metadata into a dictionary
		var metadata = {}
		for group in result.get_string("metadata").split(";"):
			var data = group.split("=")
			
			metadata[data[0]] = data[1]
		
		metadata['display-name'] = result.get_string("username")
			
		command.metadata = metadata
		
	command.who = result.get_string("username")
	command.command = result.get_string("command")
	command.message = result.get_string("message")
	
	return command
	
func handle_websocket_message(ircCommand: TwitchIrcCommand):
	match ircCommand.command:
		"CAP":
			request.emit(ircCommand.message.begins_with("* ACK"))
		"NOTICE":
			authenticated.emit(false)
		"001":
			authenticated.emit(true)
		"PING":
			_send_pong()
		_:
			message_queue.append(ircCommand)
		
func handle_message(message):
	for c in commands:
		c.handle_message(message, tmi)
