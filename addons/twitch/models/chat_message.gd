extends RefCounted

var id:String
var channel:String
var text: String
var raw_message: String
var tags: Dictionary
var sender: TwitchUserState

func _init(
	id,
	channel,
	text,
	raw_message,
	tags,
	sender
):
	self.id = id
	self.channel = channel
	self.text = text
	self.raw_message = text
	self.tags = tags
	self.sender = sender
