extends Window

const LOREM_IPSUM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

@export var tmi: Tmi

signal send_bubble(text)
signal clear_bubbles()
signal update_ignore_users_list(users: Array)
signal update_ignore_commands_list(command_prefixes: Array)

func _load_config_from_disk():
	if not FileAccess.file_exists("user://tmi.json"):
		push_error("Tmi configuration has not yet been persisted")
		return null
	
	var file = FileAccess.open("user://tmi.json", FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	
	if "credentials" in data:
		var credentials = TwitchCredentials.new()
		credentials.channel = data.credentials.get("channel", "")
		credentials.broadcaster_user_id = data.credentials.get("broadcaster_id", "")
		credentials.user_id = data.credentials.get("user_id", "")
		credentials.bot_id = data.credentials.get("bot_id", "")
		credentials.client_id = data.credentials.get("client_id", "")
		credentials.client_secret = data.credentials.get("client_secret", "")
		credentials.token = data.credentials.get("token", "")
		credentials.refresh_token = data.credentials.get("refresh_token", "")
		
		_show_credentials(credentials)
		tmi._set_credentials(await tmi.twitch_api.refresh_token(credentials))
		
	if "chat" in data:
		var exclude_users = data.chat.get("exclude_users", [])
		%ExcludeUsers.text = " ".join(data.chat.get("exclude_users", []))
		update_ignore_users_list.emit(exclude_users)
		
		var exclude_commands = data.chat.get("exclude_commands", [])
		%ExcludeCommands.text = " ".join(exclude_commands)
		update_ignore_commands_list.emit(exclude_commands)
	
	%Autoconnect.set_pressed_no_signal(data.get("autoconnect", false))
	
func _save_config_to_disk():
	var file = FileAccess.open("user://tmi.json", FileAccess.WRITE)
	
	var exclude_users = %ExcludeUsers.text.split("\\s", false)
	var exclude_commands = %ExcludeCommands.text.split("\\s", false)
	
	file.store_string(JSON.stringify({
		"credentials": {
			"channel": %ChannelName.text,
			"bot_id": %BotId.text,
			"broadcaster_id": %BroadcasterId.text,
			"user_id": %UserId.text,
			"client_id": %ClientId.text,
			"client_secret": %ClientSecret.text,
			"token": %AccessToken.text,
			"refresh_token": %RefreshToken.text
		},
		"autoconnect": %Autoconnect.is_pressed(),
		"chat": {
			"exclude_users": exclude_users,
			"exclude_commands": exclude_commands,
		},
	}, "\t"))
	file.close()
	
func _build_credentials():
	var credentials = TwitchCredentials.new()
	credentials.channel = %ChannelName.text
	credentials.broadcaster_user_id = %BroadcasterId.text
	credentials.bot_id = %BotId.text
	credentials.user_id = %UserId.text
	credentials.client_id = %ClientId.text
	credentials.client_secret = %ClientSecret.text
	credentials.token = %AccessToken.text
	credentials.refresh_token = %RefreshToken.text
	
	if credentials.token == "":
		return null
	return credentials
	
func _show_credentials(credentials: TwitchCredentials):
	%ChannelName.text = credentials.channel
	%BotId.text = credentials.bot_id
	%UserId.text = credentials.user_id
	%BroadcasterId.text = credentials.broadcaster_user_id
	%ClientId.text = credentials.client_id
	%ClientSecret.text = credentials.client_secret
	%AccessToken.text = credentials.token
	%RefreshToken.text = credentials.refresh_token

func _ready():
	await _load_config_from_disk()
	
	tmi.credentials = _build_credentials()
	
	(get_node("%SendBubbleChat") as Button).pressed.connect(func():
		var input = get_node("%BubbleMessage")
		var message = input.text
		input.text = ""
		
		if message:
			send_bubble.emit(message)
	)
	(get_node("%ClearBubbleChat") as Button).pressed.connect(func():
		clear_bubbles.emit()
	)
	
	(get_node("%DebugBubbleChat") as Button).pressed.connect(func():
		send_bubble.emit(LOREM_IPSUM.substr(0, (randi() % len(LOREM_IPSUM)) + 1))
	)

	(get_node("%ForceRefreshToken") as Button).pressed.connect(func ():
		var credentials = await tmi.twitch_api.refresh_token(_build_credentials())
		
		tmi._set_credentials(credentials)
		
		
		_save_config_to_disk()
	)
	
	(get_node("%GenerateCLICommand") as Button).pressed.connect(func ():
		# get the initial token command required in case refresh token is waaaay too old
		# guarantees the system will have all the permissions necessary
		DisplayServer.clipboard_set(
			"twitch token -u -s \"%s\"" % " ".join([
				"chat:read", "chat:edit",
				"moderator:read:chatters",
				"moderator:read:followers", "channel:read:subscriptions",
				"bits:read",
				"channel:read:redemptions",
				"channel:read:polls", "channel:read:predictions",
				"channel:read:hype_train",
				"channel:read:charity", "channel:read:goals",
				"moderator:read:shoutouts",
			])
		)
	)
	
	(get_node("%ExcludeUsers") as TextEdit).text_changed.connect(func ():
		var input = (get_node("%ExcludeUsers") as TextEdit).text
		
		update_ignore_users_list.emit(
			input.split("\\s", false)
		)
		
		_save_config_to_disk()
	)
	
	(get_node("%ExcludeCommands") as LineEdit).text_changed.connect(func (input: String):
		update_ignore_commands_list.emit(
			input.split("\\s", false)
		)
		
		_save_config_to_disk()
	)
	
	(get_node("%Reconnect") as Button).pressed.connect(func ():
		_save_config_to_disk()
		tmi.start(false)
	)
	
	(get_node("%FileButton") as Button).pressed.connect(func ():
		var file_dialog = get_node("%FileDialog")
		file_dialog.visible = true
		var path = await file_dialog.file_selected
		
		var buffer = FileAccess.get_file_as_bytes(path)
		preload("res://addons/twitch/utils.gd").save_animated(
			path,
			buffer
		)
	)
	
	tmi.credentials_updated.connect(self._on_twitch_credentials_updated)
	
	if %Autoconnect.is_pressed():
		tmi.start(false)

func _on_twitch_credentials_updated(credentials: TwitchCredentials):
	if credentials == null:
		%TokenStatus.text = "Invalid"
		return
	
	%TokenStatus.text = "Valid"
	_show_credentials(credentials)

func _on_twitch_connection_status_changed(status):
	match status:
		Tmi.ConnectionStatus.CONNECTED:
			%ConnectionStatus.text = "Connected"
		Tmi.ConnectionStatus.NOT_CONNECTED:
			%ConnectionStatus.text = "Not Connected"
		Tmi.ConnectionStatus.PARTIAL:
			%ConnectionStatus.text = "Partially Connected"
