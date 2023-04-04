extends Control

@export var expire_messages: float = 60.0
@export var message_limit: int = 10

const CACHE_LIMIT = 500
const cached_emotes = {}

func _on_twitch_command(type, event):
	if type != "message":
		return
	
	var text = preload("./chatmessage.tscn").instantiate()
	add_child(text)
	
	text.get_node("%Username").text = event.tags["display-name"]
	
	text.modulate = Color.TRANSPARENT
	text.visible_ratio = 1.0
	text.fit_content = true
	text.text = event.text
	await text.finished
	await get_tree().process_frame
	text.size = Vector2(text.get_parent().size.x, 9999)
	await get_tree().process_frame
	text.size = Vector2(min(text.get_content_width(), text.get_parent().size.x), text.get_content_height())
	await get_tree().process_frame
	text.fit_content = false
	text.modulate = Color.WHITE
	pivot_offset = Vector2(text.size.x, 0)
	text.position = Vector2(size.x - text.size.x, 0)
	
	# spawn in message
	var t = text.create_tween()
	t.parallel().tween_property(text, "scale", Vector2(1.0, 1.0), 0.2).from(Vector2(0.0, 0.0))
		
	for i in range(get_child_count()-1):
		var prev_message = get_child(i)
		var slide_down = prev_message.create_tween()
		slide_down.tween_property(prev_message, "position", Vector2(0, text.size.y + 100), 0.2).as_relative()
	
	get_tree().create_timer(expire_messages).timeout.connect(
		func():
			if text or text.is_queued_for_deletion():
				return
			text.queue_free(), CONNECT_ONE_SHOT
	)
	
