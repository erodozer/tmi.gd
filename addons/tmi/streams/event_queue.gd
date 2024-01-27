extends Node
class_name EventQueue

@export var tmi: Tmi
var _evt_queue = []

func _ready():
	if tmi:
		tmi.command.connect(self._on_twitch_command)

func accept_command(type, event) -> bool:
	return false

func _on_twitch_command(type, event):
	if accept_command(type, event):
		_evt_queue.append([type, event])
	
func process_event(type, event):
	pass
	
func _process(delta):
	if not _evt_queue.is_empty():
		set_process(false)
		var event = _evt_queue.pop_front()
		await process_event(event[0], event[1])
		set_process(true)
