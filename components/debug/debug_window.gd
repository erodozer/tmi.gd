extends Window

const LOREM_IPSUM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

@export var tmi: Tmi

signal send_bubble(text)
signal clear_bubbles()

func _ready():
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
		var credentials = TwitchCredentials.new()
		credentials.bot_id = %BotId.text
		credentials.client_id = %ClientId.text
		credentials.client_secret = %ClientSecret.text
		credentials.token = %AccessToken.text
		credentials.refresh_token = %RefreshToken.text
		
		tmi._set_credentials(await tmi.twitch_api.refresh_token(credentials))
	)
	
	(get_node("%GenerateCLICommand") as Button).pressed.connect(func ():
		# get the initial token command required in case refresh token is waaaay too old
		# guarantees the system will have all the permissions necessary
		DisplayServer.clipboard_set(
			"twitch token -u -s \"chat:read chat:edit moderator:read:chatters moderator:read:followers\""
		)
	)

func _on_twitch_credentials_updated(credentials: TwitchCredentials):
	if credentials == null:
		return
	
	%BotId.text = credentials.bot_id
	%ClientId.text = credentials.client_id
	%ClientSecret.text = credentials.client_secret
	%AccessToken.text = credentials.token
	%RefreshToken.text = credentials.refresh_token
