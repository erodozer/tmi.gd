extends RefCounted

var channel:String
var text: String
var raw_message: String
var tags: Dictionary

func _init(
	channel,
	text,
	raw_message,
	tags
):
	self.channel = channel
	self.text = text
	self.raw_message = text
	self.tags = tags
