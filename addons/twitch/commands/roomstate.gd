extends RefCounted

class RoomStateEvent:
	var channel_id

const twitch_utils = preload("../utils.gd")

var irc: TwitchIrc
	
func _init(tmi: Tmi):
	await tmi.ready
	irc = tmi.irc
	irc.IrcMessageReceived.connect(self.handle_message)

func handle_message(command: TwitchIrcCommand):
	if command.command != "ROOMSTATE":
		return
	
	var evt = RoomStateEvent.new()
	evt.channel_id = command.metadata['room-id']

	irc.Command.emit(
		"roomstate",
		evt
	)
