extends Node
class_name Tmi7tvService

const twitch_utils = preload("../utils.gd")
static var logger = preload("../logger.gd").new("7tv")

@onready var tmi: Tmi = get_parent()

func _on_twitch_command(type: String, evt):
	if type != Tmi.EventType.ROOM_STATE:
		return
		
	logger.info("fetching emote list")
	tmi._load_stack["7tv"] = true
	await preload_emotes(evt.channel_id)
	tmi._load_stack.erase("7tv")
	logger.info("fetching emotes list completed")

func preload_emotes(channel_id:String):
	var body = await twitch_utils.fetch(self,
		"https://7tv.io/v3/users/twitch/%s" % channel_id,
		HTTPClient.METHOD_GET,
		{},{},
		true
	)
	if body.code != 200:
		logger.warn("unable to fetch emotes for channel %s" % channel_id)
		return
	
	var tmi = get_parent() as Tmi
	var text_processor = tmi.get_node("TextProcessor")
	
	var emotes = []
	if body.data.emote_set and body.data.emote_set.emotes:
		emotes = body.data.emote_set.emotes
		
	var acc = []
	
	for e in emotes:
		var id = e.id
		var name = e.name
		var url = e.data.host.url
		var files = e.data.host.files as Array
		
		if files.is_empty():
			continue
		
		var image = files.filter(
			func (f):
				return "2x" in f.static_name and f.format == "WEBP"
		).front()
		
		if image:
			text_processor.register_emote(
				name,
				id,
				"https:%s/%s" % [url, image.name],
				{
					"provider": "7tv",
					"animated": image.frame_count > 1,
					"format": image.format.to_lower(),
					"dimensions": Vector2i(image.width, image.height)
				}
			)
	
