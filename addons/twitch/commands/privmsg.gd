extends Object

const twitch_utils = preload("../utils.gd")

var PRIVMSG_PARSER: RegEx

## prefetch emote images and cache them to local storage
func load_emote(emote: String, irc: TwitchIrc):
	var data = emote.split(":")
	var emote_id = data[0]
	
	var filepath = "user://emotes/%s.png" % emote_id
	if FileAccess.file_exists(filepath):
		var image = Image.new()
		var error = image.load(filepath)
		if error != OK:
			return null
		var tex = ImageTexture.create_from_image(image)
		tex.take_over_path(filepath)
		return tex
		
	print("new emote encountered: %s" % emote_id)
	
	# Create an HTTP request node and connect its completion signal.
	var http_request = HTTPRequest.new()
	irc.add_child(http_request)
	
	# Perform the HTTP request. The URL below returns a PNG image as of writing,
	# though worst case it might be a gif which we don't know how to parse :(
	var url = "https://static-cdn.jtvnw.net/emoticons/v2/%s/static/dark/3.0" % emote_id
	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		return null
	
	var result = await http_request.request_completed
	http_request.queue_free()
	
	error = result[0]
	var status = result[1]
	var headers = twitch_utils.http_headers(result[2])
	var body = result[3]
	
	if headers["Content-Type"] != "image/png":
		push_error("Incompatible file type returned for image")
		return null
	
	var image = Image.new()
	error = image.load_png_from_buffer(body)
	if error != OK:
		push_error("Couldn't load the image.")
		return null
	if not DirAccess.dir_exists_absolute("user://emotes"):
		DirAccess.make_dir_absolute("user://emotes")
	image.save_png(filepath)
	print("emote saved: %s" % emote_id)
	
	var tex = ImageTexture.create_from_image(image)
	tex.take_over_path(filepath)
	
	return tex
	
func handle_message(ircCommand: TwitchIrcCommand, irc: TwitchIrc):
	if ircCommand.command != "PRIVMSG":
		return
		
	# convert metadata into dictionary
	if not PRIVMSG_PARSER:
		PRIVMSG_PARSER = RegEx.new()
		PRIVMSG_PARSER.compile("#(?<channel>.*)\\s:(?<message>.*)")
	
	var result = PRIVMSG_PARSER.search(ircCommand.message)
	if not result:
		return
	
	var emotes = ircCommand.metadata.emotes.split("/")
	var e = {}
	var parse_emote = func (emote):
		var data = emote.split(":")
		var emote_id = data[0]
		var tex = await load_emote(emote, irc)
		
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
	
	irc.Message.emit(
		result.get_string("channel"),
		result.get_string("message"),
		ircCommand.metadata
	)
