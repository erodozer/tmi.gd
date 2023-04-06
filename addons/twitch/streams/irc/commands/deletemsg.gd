extends RefCounted

const twitch_utils = preload("../../../utils.gd")

var PRIVMSG_PARSER: RegEx
var tmi: Tmi

func _init(tmi: Tmi):
	await tmi.ready
	PRIVMSG_PARSER = RegEx.new()
	PRIVMSG_PARSER.compile("#(?<channel>[^\\s]*)\\s:/delete (?<messageid>.*)")
	
func handle_message(ircCommand: TwitchIrcCommand):
	if ircCommand.command != "PRIVMSG":
		return
		
	# ignore twitch chat commands
	if ircCommand.message.begins_with("/"):
		return
		
	# convert metadata into dictionary
	var result = PRIVMSG_PARSER.search(ircCommand.message)
	if not result:
		return
	
	var emotes = ircCommand.metadata.emotes.split("/", false)
	var e = {}
	var parse_emote = func (emote):
		var data = emote.split(":")
		var emote_id = data[0]
		var tex = await tmi.twitch_api.load_twitch_emote(emote)
		
		if not tex:
			return
		
		var positions = e.get(emote_id, [])
		for position in data[1].split(","):
			var s_e = position.split("-")
			positions.append([s_e[0].to_int(), s_e[1].to_int()])
		
		e[emote_id] = {
			"id": emote_id,
			"positions": positions,
			"texture": tex
		}
			
	for emote in emotes:
		await parse_emote.call(emote)
		
	ircCommand.metadata.emotes = e
			
	tmi.irc.Command.emit(
		"delete-message",
		result.get_string("messageid"),
	)
