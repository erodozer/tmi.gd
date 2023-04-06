extends Object

static func http_headers(headers: PackedStringArray):
	var out = {}
	for header in headers:
		var data = header.split(":", true, 1)
		out[data[0]] = data[1].strip_edges()
		
	return out
	
## fetches a gif resource
##
## gifs are cached to disk as a sequence of pngs
## because I'm too lazy to add gif decoding to godot, this depends
## on the user having ffmpeg installed to their Path for us to leverage
static func load_animated(path: String):
	var basename = path.rsplit(".")[0]
	var folder_path = "%s/" % basename
	
	if ResourceLoader.has_cached(path):
		return load(path)
	
	if not DirAccess.dir_exists_absolute(basename):
		return null
		
	# load frames into AnimatedTexture
	var tex = AnimatedTexture.new()
	var frames = DirAccess.get_files_at(folder_path)
	if len(frames) == 0:
		return null
		
	tex.frames = len(frames)
	for i in frames:
		var filepath = "%s/%s" % [basename, i]
		var image = Image.new()
		var error = image.load(filepath)
		if error != OK:
			return null
		var frame = ImageTexture.create_from_image(image)
		var data = i.split("_")
		var idx = data[0].to_int()
		var delay = data[1].to_int() / 1000.0
		tex.set_frame_duration(idx, delay) # ffmpeg defaults to 25fps
		tex.set_frame_texture(idx, frame)
		idx += 1
		
	tex.take_over_path(path)
	return tex
	
static func save_animated(path: String, buffer: PackedByteArray):
	var basename = path.rsplit(".")[0]
	var folder_path = "%s/" % basename
	
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(buffer)
	f.close()
	
	DirAccess.make_dir_recursive_absolute(folder_path)
	# get frame times
	var out = []
	OS.execute("magick", [
		ProjectSettings.globalize_path(path),
		"-format", "%T\\n", "info:"
	], out)
	var frame_delays = []
	for delay in out[0].split("\n"):
		frame_delays.append(
			delay.to_int() * 10 # convert x100 to x1000(ms)
		)
	
	out = []
	var code = OS.execute("magick", [
		"convert",
		"-coalesce",
		ProjectSettings.globalize_path(path),
		ProjectSettings.globalize_path(basename + "/%02d.png"),
	], out, true)
	assert(code == 0, "unable to convert: %s" % "\n".join(out))
	
	# rename files to include their delays
	for i in DirAccess.get_files_at(folder_path):
		var frame = i.substr(0, i.rfind(".")).to_int()
		var delay = frame_delays[frame]
		DirAccess.rename_absolute(
			"%s/%s" % [basename, i],
			"%s/%02d_%04d.png" % [basename, frame, delay]
		)
	
	print("animated image saved: %s" % path)
	
	return load_animated(path)
	
static func load_static(filepath: String):
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
	
static func save_static(filepath: String, buffer: PackedByteArray):
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
