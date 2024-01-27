extends RefCounted

const twitch_utils = preload("../../../utils.gd")

var PRIVMSG_PARSER: RegEx
var tmi: Tmi

func _init():
	PRIVMSG_PARSER = RegEx.new()
	PRIVMSG_PARSER.compile("#(?<channel>[^\\s]*)\\s:/(timeout|ban) (?<userid>[^\\s]*)(?<extra>.*)")
	
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
		Tmi.EventType.USER_DELETED,
		{
			"channel": result.get_string("channel"),
			"user": result.get_string("userid"),
		},
	)
