extends Window

const LOREM_IPSUM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

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
