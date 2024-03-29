extends Node

const utils = preload("./utils.gd")

@export var line_height = 24

var _emotes = []
var _dirty = false

func register_emote(code: String, id: String, url: String, options: Dictionary = {}):
	_emotes.append({
		"code": code,
		"url": url,
		"id": id,
		"provider": options.get("provider", "twitch"),
		"animated": options.get("animated", false),
		"format": options.get("format", "png"),
		"dimensions": options.get("dimensions", Vector2i(32, 32))
	})
	_dirty = true

func fetch_emote(emote):
	if "texture" in emote:
		return
	
	var tex: Texture2D
	var chain = [emote]
	for i in emote.get("fallback", []):
		chain.append({
			"provider": emote.provider,
			"id": emote.id,
			"format": i.get("format", emote.format),
			"url": i.get("url", emote.url),
			"animated": i.get("animated", emote.animated)
		})
		
	for i in chain:
		if i.animated:
			tex = await utils.fetch_animated(
				self,
				"user://emotes/%s/%s.%s" % [i.provider, i.id, i.format],
				i.url
			)
		else:
			tex = await utils.fetch_static(
				self,
				"user://emotes/%s/%s.%s" % [i.provider, i.id, i.format],
				i.url
			)
		if tex != null:
			emote["texture"] = tex
			return

func enrich_fragments(fragments: Array) -> Array:
	if _dirty:
		_emotes.sort_custom(
			func (a, b):
				return len(a.code) > len(b.code)
		)
		_dirty = false
	
	var m = []
	for f in fragments:
		match f.type:
			"text":
				# inject emotes from other services
				var parts = []
				for i in f.text.split(" ", true):
					parts.append({
						"type": "text",
						"text": i
					})
					
				for e in _emotes:
					for i in range(len(parts)):
						var w = parts[i]
						if w.type == "text" and w.text == e.code:
							parts[i] = {
								"type": "emote",
								"text": e.code,
								"emote": e,
							}
				
				var builder = []
				for p in parts:
					match p.type:
						"text":
							builder.append(p.text)
						"emote":
							await fetch_emote(p.emote)
							m.append({
								"type": "text",
								"text": " ".join(builder)
							})
							m.append(p)
							builder = []
				
				if !builder.is_empty():
					m.append({
						"type": "text",
						"text": " ".join(builder)
					})
			"emote":
				await fetch_emote(f.emote)
				m.append(f)
	return m

func render_message(fragments: Array) -> String:
	var bbcode = []
	for f in fragments:
		match f.type:
			"text":
				bbcode.append(f.text)
			"emote":
				if "texture" in f.emote:
					bbcode.append("[img width=%d]%s[/img]" % [
						f.emote.dimensions.aspect() * line_height,
						f.emote.texture.resource_path
					])
				else:
					bbcode.append(f.text)
	
	return " ".join(bbcode)
	
func enrich(obj: TmiAsyncState):
	if not (obj is TmiChatMessage):
		return obj
		
	var chat = obj as TmiChatMessage
	chat.fragments = await enrich_fragments(chat.fragments)
	chat.text = render_message(chat.fragments)
	return chat
	
