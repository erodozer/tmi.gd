extends Object

static func http_headers(headers: PackedStringArray):
	var out = {}
	for header in headers:
		var data = header.split(":", true, 1)
		out[data[0]] = data[1].strip_edges()
		
	return out
	
static func load_animated(path: String) -> AnimatedTexture:
	if ResourceLoader.has_cached(path + ".res"):
		return load(path)
	
	if not FileAccess.file_exists(path):
		return null
	
	# load frames into AnimatedTexture
	return ResourceLoader.load(path + ".res") as AnimatedTexture
	
static func save_animated(path: String, buffer: PackedByteArray = []) -> AnimatedTexture:
	return preload("res://addons/magick_dumps/magick.gd").dump_and_convert(path, buffer)
	
static func load_static(filepath: String) -> Texture2D:
	if ResourceLoader.has_cached(filepath):
		return load(filepath)
		
	if FileAccess.file_exists(filepath):
		var image = Image.new()
		var error = image.load(filepath)
		if error != OK:
			return null
		var tex = ImageTexture.create_from_image(image)
		tex.take_over_path(filepath)
		return tex
	
	return null
	
static func save_static(filepath: String, buffer: PackedByteArray) -> Texture2D:
	var image = Image.new()
	var error = image.load_png_from_buffer(buffer)
	if error != OK:
		push_error("Couldn't load the image.")
		return null
	image.save_png(filepath)
	
	print("static image saved: %s" % filepath)
	return load_static(filepath)

# helper function for doing simple http requests
static func fetch(n: Node, url: String, json = false):
	var http_request = HTTPRequest.new()
	n.add_child(http_request)
	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		return null
	
	var result = await http_request.request_completed
	http_request.queue_free()
	
	error = result[0]
	var status = result[1]
	if status == 404:
		return null
	
	var body = result[3] as PackedByteArray
	
	return body if not json else JSON.parse_string(body.get_string_from_utf8())
