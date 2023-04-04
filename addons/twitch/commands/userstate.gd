extends RefCounted

const twitch_utils = preload("../utils.gd")

var irc: TwitchIrc
	
func _init(irc: TwitchIrc):
	self.irc = irc
	
