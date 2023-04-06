class_name TwitchIrc
extends Node

const TWITCH_IRC_ENDPOINT = "ws://irc-ws.chat.twitch.tv:80"

var channel: String
var credentials: TwitchCredentials
var socket: WebSocketPeer

signal IrcMessageReceived(command: TwitchIrcCommand)
signal Connected(channel)
signal Authenticated(success)
signal Request(acknowledge)

# specific command types
signal Command(type, event)

enum ConnectionState {
	NOT_STARTED,
	STARTING,
	STARTED,
	FAILED
}
	
var connection_state = ConnectionState.NOT_STARTED
var COMMAND_REGEX: RegEx

@onready var commands = [
	await preload("./commands/privmsg.gd").new(get_parent()),
	await preload("./commands/deletemsg.gd").new(get_parent()),
	await preload("./commands/deleteuser.gd").new(get_parent()),
	await preload("./commands/roomstate.gd").new(get_parent()),
	await preload("./commands/userstate.gd").new(get_parent()),
]

func _init():
	# twitch IRC command parsing using regex grouops
	COMMAND_REGEX = RegEx.new()
	COMMAND_REGEX.compile("(@(?<metadata>.*)\\s)?(:(.*!.*@)?((?<username>.*)\\.)?tmi\\.twitch\\.tv\\s)(?<command>(\\S*))\\s*(?<message>.*)")
	
	IrcMessageReceived.connect(self.handle_command)
	
func connect_to_server():
	if socket:
		socket.close()
		socket = null
	
	connection_state = ConnectionState.NOT_STARTED
	socket = WebSocketPeer.new()
	# create websocket connection to twitch irc endpoitn
	socket.connect_to_url(TWITCH_IRC_ENDPOINT)
	
func _process(_delta):
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
		print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false) # Stop processing.
	
func _login_with_credentials(credentials: TwitchCredentials):
	socket.send_text("PASS %s" % credentials.get_password.call())
	socket.send_text("NICK %s" % credentials.bot_id)
	
func _setup_connection():
	connection_state = ConnectionState.STARTING
	
	# this requests for this client to receive additional twitch IRC specific commands
	# in its command stream.
	var err = socket.send_text("CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership")
	if err:
		push_error("failed to request additional capabiltilies")
		connection_state = ConnectionState.FAILED
		socket.close()
		return
		
	# wait for cap req acknowledgement before proceeding
	var acknowledged = await Request
	if not acknowledged:
		push_error("capability request denied")
		connection_state = ConnectionState.FAILED
		socket.close()
		return
		
	# set authentication of the integration so that the bot
	# may assume an identity within chat
	
	_login_with_credentials(credentials if credentials else TwitchCredentials.get_fallback_credentials())
	var authed = await Authenticated
	if not authed:
		push_error("Authentication failed")
		connection_state = ConnectionState.FAILED
		socket.close()
		return

	# join channels to listen to
	socket.send_text("JOIN #%s" % channel)
	
	# begin a ping-pong with the server to keep the bot alive
	var ping_interval = Timer.new()
	ping_interval.wait_time = 1.0
	ping_interval.timeout.connect(self._send_ping)
	add_child(ping_interval)
	ping_interval.start()
	print("twitch-gd: we're in hampwnDance")
	
	connection_state = ConnectionState.STARTED

func _handle_packet(packet: PackedByteArray):
	# converts a websocket message from the IRC stream into an object
	var event = packet.get_string_from_utf8()
	#print("from twitch:\n%s" % event)
	
	for message in event.strip_edges().split("\n"):
		var command = _parse_twitch_message(message)
		if command:
			IrcMessageReceived.emit(command)
	
## Keeps the connection alive by sending PING requests to the server
func _send_ping():
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
		
	socket.send_text("PING")

## Responds to server ping requests to keep alive
func _send_pong():
	socket.send_text("PONG")
	
## Sends a PRIVMSG to a specified channel.
## If the channel is not specified, we default to using the first channel that 
## we are connected to
func send_message(text, channel = null):
	socket.send_text("PRIVMSG #%s :%s" % [
		self.channel if channel == null else channel,
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
	
func handle_command(ircCommand: TwitchIrcCommand):
	match ircCommand.command:
		"CAP":
			Request.emit(ircCommand.message.begins_with("* ACK"))
		"NOTICE":
			Authenticated.emit(false)
		"001":
			Authenticated.emit(true)
		"PING":
			_send_pong()
		_:
			pass
