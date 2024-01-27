extends RefCounted

const twitch_utils = preload("../../../utils.gd")

var PRIVMSG_PARSER: RegEx

func _init():
	PRIVMSG_PARSER = RegEx.new()
	PRIVMSG_PARSER.compile("#(?<channel>[^\\s]*)\\s:/delete (?<messageid>.*)")
	
func handle_message(ircCommand: TwitchIrcCommand, tmi: Tmi):
	if ircCommand.command != "PRIVMSG":
		return
		
	# ignore twitch chat commands
	if ircCommand.message.begins_with("/"):
		return
		
	# convert metadata into dictionary
	var result = PRIVMSG_PARSER.search(ircCommand.message)
	if not result:
		return
			
	tmi.command.emit(
		Tmi.EventType.DELETE_MESSAGE,
		{
			"channel": result.get_string("channel"),
			"message": result.get_string("messageid"),
		},
	)
