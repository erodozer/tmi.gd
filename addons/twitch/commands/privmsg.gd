extends RefCounted

const twitch_utils = preload("../utils.gd")

var PRIVMSG_PARSER: RegEx
var irc: TwitchIrc

func _init(irc: TwitchIrc):
	PRIVMSG_PARSER = RegEx.new()
	PRIVMSG_PARSER.compile("#(?<channel>[^\\s]*)\\s:(?<message>.*)")
	
	irc.IrcMessageReceived.connect(handle_message)
	
## prefetch emote images and cache them to local storage
func load_twitch_emote(emote: String):
	var data = emote.split(":")
	var emote_id = data[0]
	
	var filepath = "user://emotes/%s" % emote_id
	if FileAccess.file_exists(filepath + ".png"):
		filepath += ".png"
		var image = Image.new()
		var error = image.load(filepath)
		if error != OK:
			return null
		var tex = ImageTexture.create_from_image(image)
		tex.take_over_path(filepath)
		return tex
	#elif FileAccess.file_exists(filepath + ".gif"):
	#	filepath += ".gif"
	#	var tex = gif.read_from_file(filepath)
	#	return tex
		
	print("new emote encountered: %s" % emote_id)
	
	# Create an HTTP request node and connect its completion signal.
	var http_request = HTTPRequest.new()
	irc.add_child(http_request)
	
	if not DirAccess.dir_exists_absolute("user://emotes"):
		DirAccess.make_dir_recursive_absolute("user://emotes")
		
	# Perform the HTTP request
	# first we try to get an animated version if it exists
	# else we'll fall back to static png
	for type in ["static"]: #["animated", "static"]:
		var url = "https://static-cdn.jtvnw.net/emoticons/v2/%s/%s/dark/3.0" % [emote_id, type]
		var error = http_request.request(url)
		if error != OK:
			push_error("An error occurred in the HTTP request.")
			return null
		
		var result = await http_request.request_completed
		http_request.queue_free()
		
		error = result[0]
		var status = result[1]
		if status == 404:
			continue
		
		var headers = twitch_utils.http_headers(result[2])
		var body = result[3]
		
		match type:
			"static":
				var image = Image.new()
				error = image.load_png_from_buffer(body)
				if error != OK:
					push_error("Couldn't load the image.")
					return null
				image.save_png(filepath + ".png")
				var tex = ImageTexture.create_from_image(image)
				tex.take_over_path(filepath + ".png")
				print("emote saved: %s" % emote_id)
				return tex
			"animated":
				# TODO load gifs
				var f = FileAccess.open(filepath + ".gif", FileAccess.WRITE)
				f.store_buffer(body)
				f.close()
				
				# var tex = gif.read_from_buffer(body)
				# tex.take_over_path(filepath + ".png")
				
				print("emote saved: %s" % emote_id)
				
				return null
	
	return null
	
func _render_message(message: String, emotes: Dictionary = {}):
	var stringReplacements = []
	
	# iterate of emotes to access ids and positions
	for id in emotes:
		# use only the first position to find out the emote key word
		var emote = emotes[id]
		var position = emote.positions[0]
		var stringToReplace = message.substr(
			position[0],
			position[1] - position[0] + 1
		)
		
		stringReplacements.append({
			"stringToReplace": stringToReplace,
			"replacement": "[img=%d]%s[/img]" % [32, emote.texture.resource_path],
		})
	
	# convert the text into bbcode
	for r in stringReplacements:
		message = message.replace(r.stringToReplace, r.replacement)
		
	return message
	
func handle_message(ircCommand: TwitchIrcCommand):
	if ircCommand.command != "PRIVMSG":
		return
		
	# convert metadata into dictionary
	var result = PRIVMSG_PARSER.search(ircCommand.message)
	if not result:
		return
	
	var emotes = ircCommand.metadata.emotes.split("/")
	var e = {}
	var parse_emote = func (emote):
		var data = emote.split(":")
		var emote_id = data[0]
		var tex = await load_twitch_emote(emote)
		
		if not tex:
			return
		
		var positions = e.get(emote_id, [])
		for position in data[1].split(","):
			var s_e = position.split("-")
			positions.append([s_e[0].to_int(), s_e[1].to_int()])
		
		e[emote_id] = {
			"id": emote_id,
			"positions": positions,
			"texture": tex
		}
			
	for emote in emotes:
		await parse_emote.call(emote)
		
	ircCommand.metadata.emotes = e
	
	irc.Command.emit(
		"message",
		preload("../models/chat_message.gd").new(
			result.get_string("channel"),
			_render_message(result.get_string("message"), e),
			result.get_string("message"),
			ircCommand.metadata	
		)
	)
