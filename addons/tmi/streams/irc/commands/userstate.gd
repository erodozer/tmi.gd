extends RefCounted

func handle_message(command: TwitchIrcCommand, tmi: Tmi):
	if command.command != "USERSTATE":
		return
