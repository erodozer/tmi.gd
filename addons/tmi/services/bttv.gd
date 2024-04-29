extends Node
class_name TmiBttvService

const twitch_utils = preload("../utils.gd")
static var logger = preload("../logger.gd").new("bttv")

@onready var tmi: Tmi = get_parent()

func _on_twitch_command(type: String, evt):
	if type != Tmi.EventType.ROOM_STATE:
		return
		
	tmi._load_stack["bttv"] = true
	logger.info("fetching emotes list")
	await preload_global_emotes()
	await preload_emotes(evt.channel_id)
	tmi._load_stack.erase("bttv")
	logger.info("fetching emotes list completed")
	
func fetch_emote_images(emotes):
	if len(emotes) == 0:
		return []
		
	var tmi = get_parent() as Tmi
	var text_processor = tmi.get_node("TextProcessor")
	
	for e in emotes:
		var id = e.id
		var name = e.code
		var image_type = e.imageType
		
		# bttv uses webp for everything, so we'll just convert it regardless since we can't tell
		# if it's static or animated
		text_processor.register_emote(
			e.code,
			e.id,
			"https://cdn.betterttv.net/emote/%s/2x.%s" % [e.id, e.imageType],
			{
				"provider": "bttv",
				"format": image_type,
				"animated": e.animated,
				"dimensions": Vector2i(e.get("width", 32), e.get("height", 32))
			}
		)
	
func preload_global_emotes():
	var body = await twitch_utils.fetch(self,
		"https://api.betterttv.net/3/cached/emotes/global",
		HTTPClient.METHOD_GET,
		{}, {},
		true
	)
	if body.code != 200:
		push_warning("unable to fetch global Bttv emotes")
		return
	
	var emotes = body.data
	
	await fetch_emote_images(emotes)

func preload_emotes(channel_id:String):
	var result = await twitch_utils.fetch(self,
		"https://api.betterttv.net/3/cached/users/twitch/%s" % channel_id,
		HTTPClient.METHOD_GET,
		{}, {},
		true
	)
	if result.code != 200:
		logger.warn("unable to fetch Bttv emotes for channel %s" % channel_id)
		return
	
	var emotes = []
	if result.data.channelEmotes:
		emotes.append_array(result.data.channelEmotes)
	if result.data.sharedEmotes:
		emotes.append_array(result.data.sharedEmotes)
		
	if len(emotes) == 0:
		return
	
	await fetch_emote_images(emotes)
		
