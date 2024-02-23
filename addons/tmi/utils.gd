extends Object

static var magick_loader

static func http_headers(headers: Dictionary):
	var out = []
	for header in headers.keys():
		var value = headers[header]
		out.append(
			"%s: %s" % [header, value]
		)
	return out
	
static func fetch_animated(node: Node, path: String, url: String) -> Texture2D:
	var tex = await load_animated(path)
	if tex == null:
		var result = await fetch(node, url)
		tex = await save_animated(path, result.data)
	return tex

static func fetch_static(node: Node, path: String, url: String) -> Texture2D:
	var tex = await load_static(path)
	if tex == null:
		var result = await fetch(node, url)
		tex = await save_static(path, result.data)
	return tex
	
static func load_animated(path: String) -> AnimatedTexture:
	if not FileAccess.file_exists(path + ".res"):
		return null
	
	# load frames into AnimatedTexture
	return load(path + ".res") as AnimatedTexture
	
static func save_animated(path: String, buffer: PackedByteArray = []) -> Texture2D:
	if ResourceLoader.exists("res://addons/magick_dumps/magick.gd"):
		if magick_loader == null:
			magick_loader = load("res://addons/magick_dumps/magick.gd").new()
		var tex = await magick_loader.dump_and_convert(path, buffer, "%s.res" % path, true)
		return tex
	return null
	
static func load_static(filepath: String) -> Texture2D:
	var tex: Texture2D
	if not FileAccess.file_exists(filepath):
		return null
	
	if ResourceLoader.has_cached(filepath):
		tex = load(filepath)
	
	if tex == null:
		var image = Image.new()
		var error = image.load(filepath)
		if error != OK:
			return null
		tex = ImageTexture.create_from_image(image)
		tex.take_over_path(filepath)
	
	return tex
	
static func save_static(filepath: String, buffer: PackedByteArray) -> Texture2D:
	var image = Image.new()
	
	if filepath.ends_with("png"):
		var error = image.load_png_from_buffer(buffer)
		if error != OK:
			push_error("Couldn't load the image.")
			return null
		image.save_png(filepath)
	elif filepath.ends_with("webp"):
		var error = image.load_webp_from_buffer(buffer)
		if error != OK:
			push_error("Couldn't load the image.")
			return null
		image.save_webp(filepath)
	else:
		push_error("unsupported format")
		return
		
	print("[tmi/img]: static image saved: %s" % filepath)
	return load_static(filepath)

static func qs(params: Dictionary = {}) -> String:
	var s = []
	for k in params.keys():
		var v = "%s" % params[k]
		s.append("%s=%s" % [k.uri_encode(), v.uri_encode()])
	
	return "&".join(s)
	
static func qs_split(query: String) -> Dictionary:
	var data : Dictionary = {}
	for entry in query.split("&"):
		var pair = entry.split("=")
		data[pair[0]] = "" if pair.size() < 2 else pair[1]
	return data

# helper function for doing simple http requests
static func fetch(n: Node, url: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, headers = {}, data = {}, json = false):
	var http_request = HTTPRequest.new()
	n.add_child(http_request)
	
	var formatted_headers = http_headers(headers)
	if method == HTTPClient.METHOD_GET:
		url = "%s?%s" % [
			url,
			qs(data)
		]
		data = ""
	elif method == HTTPClient.METHOD_POST:
		match headers.get("Content-Type", "application/json"):
			"application/json":
				data = JSON.stringify(data)
			"application/x-www-form-urlencoded":
				data = qs(data)
			_:
				data = ""
		
	var error = http_request.request(
		url,
		PackedStringArray(formatted_headers),
		method,
		data,
	)
	if error != OK:
		push_error("[tmi/fetch]: An error occurred in the HTTP request.")
		return null
	
	var result = await http_request.request_completed
	http_request.queue_free()
	
	error = result[0]
	var status = result[1]
	
	var body = result[3] as PackedByteArray
	if body != null and json:
		body = body.get_string_from_utf8()
		body = JSON.parse_string(body)
	
	if status >= 400:
		push_error("[tmi/fetch]: request failed, status: %d, body: %s" % [status, body])
	
	return {
		"code": status,
		"data": body
	}
