extends RefCounted

var channel:String
var text: String
var raw_message: String
var tags: Dictionary
var sender: TwitchUserState

func _init(
	channel,
	text,
	raw_message,
	tags,
	sender
):
	self.channel = channel
	self.text = text
	self.raw_message = text
	self.tags = tags
	self.sender = sender
