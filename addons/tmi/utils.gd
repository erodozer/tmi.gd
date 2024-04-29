extends Object

static var logger = preload("./logger.gd").new("utils")

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
	if not DirAccess.dir_exists_absolute(path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		
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

	if not DirAccess.dir_exists_absolute(filepath.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(filepath.get_base_dir())

	if filepath.ends_with("png"):
		var error = image.load_png_from_buffer(buffer)
		if error != OK:
			logger.error("Couldn't parse the image from buffer")
			return null
		image.save_png(filepath)
	elif filepath.ends_with("webp"):
		var error = image.load_webp_from_buffer(buffer)
		if error != OK:
			logger.error("Couldn't parse the image from buffer")
			return null
		image.save_webp(filepath)
	else:
		logger.error("unsupported image format")
		return
		
	logger.debug("static image saved: %s" % filepath)
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
		logger.error("An error occurred in the HTTP request.")
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
		logger.warn("request failed, url:%s, status: %d, body: %s, data:%s" % [url, status, body, data])
	
	return {
		"code": status,
		"data": body
	}
	
static func deserialize(a):
	if a == null:
		return null
	if a is String and a.begins_with("#"):
		return Color.from_string(a, Color.WHITE)
	if a is Array:
		var data = []
		for v in a:
			var value = deserialize(v)
			if value != null:
				data.append(value)
		return data
	if a is Dictionary:
		var data = {}
		for v in a.keys():
			var value = deserialize(a[v])
			if value != null:
				data[v] = value
		return data
	return a
	
static func serialize(a, serialize_objects=true):
	if a == null:
		return null
		
	if a is Array:
		var data = []
		for value in a:
			var v = serialize(value, false)
			if v != null:
				data.append(v)
		return data
	elif a is Dictionary:
		var data = {}
		for k in a:
			if k.begins_with("_"):
				continue
			var value = serialize(a[k], false)
			if value == null:
				continue			
			data[k] = value
		return data
	elif a is Color:
		return "#%s" % a.to_html()
	elif a is Object:
		if not serialize_objects:
			return null
		var data = {}
		for p in a.get_property_list():
			if p.name.begins_with("_"):
				continue
			var value = serialize(a.get(p.name), false)
			if value == null:
				continue
			data[p.name] = value
		return data
	return a
