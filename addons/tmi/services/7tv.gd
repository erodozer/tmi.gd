extends Node
class_name Tmi7tvService

const twitch_utils = preload("../utils.gd")

@onready var tmi: Tmi = get_parent()

func _on_twitch_command(type: String, evt):
	if type != Tmi.EventType.ROOM_STATE:
		return
		
	print("[tmi/bttv]: downloading 7tv emotes")
	tmi._load_stack["7tv"] = true
	await preload_emotes(evt.channel_id)
	tmi._load_stack.erase("7tv")
	print("[tmi/bttv]: preloading 7tv emotes completed")

func preload_emotes(channel_id:String):
	var body = await twitch_utils.fetch(self,
		"https://7tv.io/v3/users/twitch/%s" % channel_id,
		HTTPClient.METHOD_GET,
		{},{},
		true
	)
	if body.code != 200:
		push_warning("unable to fetch emotes for channel %s" % channel_id)
		return
	
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
		
		url = "https:%s/%s" % [url, image.name]
		
		if image:
			var tex
			if image.frame_count > 1:
				tex = await twitch_utils.fetch_animated(
					self,
					"user://emotes/7tv_%s.webp" % id,
					url,
				)
			else:
				tex = await twitch_utils.fetch_static(
					self,
					"user://emotes/7tv_%s.webp" % id,
					url,
				)
			
			if tex != null:
				acc.append({
					"code": name,
					"texture": tex,
					"dimensions": {
						"width": image.width,
						"height": image.height
					}
				})
			else:
				push_error("failed to load image %s" % url)
	
	var tmi = get_parent() as Tmi
	tmi._emotes.append_array(acc)
	tmi._emotes.sort_custom(
		func (a, b):
			return len(a.code) > len(b.code)
	)
