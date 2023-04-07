extends Control

@export var listen_to_twitch = true
@export var broadcaster_id = "erodozer"

@export var message_limit = 3

func _on_window_send_bubble(text):
	_push_to_stack(text)

func _push_to_stack(text):
	var bubble = preload("./chat_bubble.tscn").instantiate()
	add_child(bubble)
	bubble.update_text(text)
	
	for i in range(0, get_child_count() - 1):
		var prev_message = get_child(i) as Control
		if prev_message.is_queued_for_deletion():
			continue
		
		var tween = get_tree().create_tween()
		tween.parallel().tween_property(
			prev_message, "position", Vector2(0, -40), .2
		).as_relative()
		tween.parallel().tween_property(
			prev_message, "scale", Vector2(-0.1, -0.1), .2
		).as_relative()
		if get_child_count() - i > message_limit:
			tween.parallel().tween_property(
				prev_message, "modulate", Color(1.0,1.0,1.0,0.0), .2
			).from_current()
			tween.finished.connect(
				func(): 
					if not prev_message or prev_message.is_queued_for_deletion():
						return
					prev_message.queue_free(),
				CONNECT_ONE_SHOT
			)
		else:
			tween.parallel().tween_property(
				prev_message, "modulate", Color(0.0,0.0,0.0,-0.25), .2
			).as_relative()
		
func _on_debug_window_clear_bubbles():
	for i in get_children():
		i.queue_free()

func _on_twitch_command(type, event):
	if type != "message":
		return
		
	if event.tags['display-name'] != broadcaster_id:
		return

	_push_to_stack(event.text)
