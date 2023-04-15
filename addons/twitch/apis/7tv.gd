extends Node
class_name TmiAPI7tv

const twitch_utils = preload("../utils.gd")

func _ready():
	var tmi = get_parent()

	await tmi.ready
	tmi.command.connect(_on_room_state)

func _on_room_state(type: String, evt):
	if type != "roomstate":
		return
		
	await preload_emotes(evt.channel_id)

func preload_emotes(channel_id:String):
	var body = await twitch_utils.fetch(self,
		"https://7tv.io/v3/users/twitch/%s" % channel_id,
		true
	)
	if body == null:
		push_warning("Unable to fetch 7tv emotes for channel %s" % channel_id)
		return
	
	var emotes = []
	if body.emote_set and body.emote_set.emotes:
		emotes = body.emote_set.emotes
		
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
			var tex = await twitch_utils.fetch_animated(
				self,
				"user://emotes/7tv_%s.webp" % id,
				url,
			)
			acc.append({
				"code": name,
				"texture": tex,
				"dimensions": {
					"width": image.width,
					"height": image.height
				}
			})
	
	var tmi = get_parent() as Tmi
	tmi._emotes.append_array(acc)
	tmi._emotes.sort_custom(
		func (a, b):
			return len(a.code) > len(b.code)
	)
