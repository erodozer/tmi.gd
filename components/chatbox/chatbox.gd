extends Control

@export var expire_delay: float = 60.0
@export var message_limit: int = 10
@export var ignore_users: Array[String] = []
@export var ignore_commands: Array[String] = []

const CACHE_LIMIT = 500
const cached_emotes = {}

func _process(_delta):
	# continuously cleanup
	if get_child_count() > message_limit:
		get_child(0).queue_free()

func _spawn_chat(event):
	# do not render messages that are bot commands
	for i in ignore_commands:
		if event.text.begins_with(i):
			return
	
	if "sender" in event:
		# do not render messages from ignored users
		# required for filtering out known bot accounts in your channel
		if event.sender.display_name in ignore_users:
			return
		
		while event.sender.is_loading:
			await get_tree().process_frame
	
	var text = preload("./chatmessage.tscn").instantiate()
	text.text = event.text
	text.custom_minimum_size = Vector2(size.x, 16)
	add_child(text)
	text.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	text.custom_minimum_size = Vector2(min(text.get_content_width(), text.size.x), 16)
	text.pivot_offset = Vector2(text.custom_minimum_size.x, text.size.y)
	text.set_meta("messageid", event.id)
	
	# inject user profile information
	if "sender" in event:
		text.set_meta("senderid", event.sender.id)
		text.get_node("%Username").text = event.sender.display_name
		
		if "pronouns" in event.sender.extra:
			text.get_node("%Pronouns").visible = true
			text.get_node("%Pronouns/Label").text = event.sender.extra.pronouns
		else:
			text.get_node("%Pronouns").visible = false
		
		if "profile_image" in event.sender.extra:
			var image = event.sender.extra.profile_image
			if image != null:
				text.get_node("%ProfileImage").texture = image
	
	# spawn in message
	var t = create_tween()
	t.tween_property(text, "scale", Vector2(1.0, 1.0), 0.2)\
		.from(Vector2(0.0, 0.0))
	if expire_delay > 0.0:
		t.tween_property(text, "modulate", Color.TRANSPARENT, 0.2)\
			.set_delay(expire_delay)
		t.tween_property(text, "clip_contents", true, 0.0)
		t.tween_property(text, "size", Vector2(0.0, 0.0), 0.15)
		t.tween_callback(text.queue_free)
			
func _delete_user_messages(user_id: String):
	for i in get_children():
		if i.get_meta("senderid") == user_id:
			i.queue_free()
					
func _delete_message(message_id: String):
	for i in get_children():
		if i.get_meta("messageid") == message_id:
			i.queue_free()

# debug integration	to send chat messages
func _on_window_send_bubble(text):
	_spawn_chat(
		{
			"id": "",
			"text": text
		}
	)

func _on_twitch_command(type, event):
	match type:
		Tmi.EventType.CHAT_MESSAGE:
			_spawn_chat(event)
		Tmi.EventType.DELETE_MESSAGE:
			_delete_message(event)
		Tmi.EventType.USER_DELETED:
			_delete_user_messages(event)

func _on_debug_window_update_ignore_users_list(users: Array):
	ignore_users.clear()
	ignore_users.append_array(users)

func _on_debug_window_update_ignore_commands_list(command_prefixes: Array):
	ignore_commands.clear()
	ignore_commands.append_array(command_prefixes)
