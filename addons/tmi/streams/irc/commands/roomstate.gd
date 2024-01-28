extends RefCounted

class RoomStateEvent:
	var channel_id

func handle_message(command: TwitchIrcCommand, tmi: Tmi):
	if command.command != "ROOMSTATE":
		return
	
	var evt = RoomStateEvent.new()
	evt.channel_id = command.metadata['room-id']

	tmi.command.emit(
		Tmi.EventType.ROOM_STATE,
		evt
	)
