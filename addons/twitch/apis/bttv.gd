extends Node
class_name BttvAPI

const twitch_utils = preload("../utils.gd")

@onready var tmi: Tmi = get_parent()

func _ready():
	await tmi.ready
	tmi.command.connect(_on_room_state)

func _on_room_state(type: String, evt):
	if type != "roomstate":
		return
		
	tmi._load_stack["bttv"] = true
	await preload_emotes(evt.channel_id)
	tmi._load_stack.erase("bttv")

func preload_emotes(channel_id:String):
	var body = await twitch_utils.fetch(self,
		"https://api.betterttv.net/3/cached/users/twitch/%s" % channel_id,
		true
	)
	if body == null:
		push_warning("Unable to fetch Bttv emotes for channel %s" % channel_id)
		return
	
	var emotes = []
	if body.channelEmotes:
		emotes.append_array(body.channelEmotes)
	if body.sharedEmotes:
		emotes.append_array(body.sharedEmotes)
		
	var acc = []
	
	if len(emotes) == 0:
		return
		
	print("downloading bttv emotes")
	for e in emotes:
		var id = e.id
		var name = e.code
		var image_type = e.imageType
		
		var url = "https://cdn.betterttv.net/emote/%s/2x" % id
		
		# bttv uses webp for everything, so we'll just convert it regardless since we can't tell
		# if it's static or animated
		var tex
		var path = "user://emotes/bttv_%s.%s" % [id, image_type]
		if e.animated:
			tex = await twitch_utils.fetch_animated(self, path, url)
		else:
			tex = await twitch_utils.fetch_static(self, path, url)
		assert(tex != null, "failed to load image")
		if tex:
			acc.append({
				"code": name,
				"texture": tex,
				"dimensions": {
					"width": tex.get_width(),
					"height": tex.get_height()
				}
			})
	
	var tmi = get_parent() as Tmi
	tmi._emotes.append_array(acc)
	tmi._emotes.sort_custom(
		func (a, b):
			return len(a.code) > len(b.code)
	)
