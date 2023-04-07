extends RefCounted

## Converts a packed byte array to an AnimatedTexture and writes it out to the destination path
##
## The byte array must represent an animated gif, webp, or any imagemagick supported format
## Idumps it into a binary resource consisting of PNG frames.
##
## The resource is automatically added to the ResourceLoader cache as the input path value
static func dump_and_convert(path: String, buffer: PackedByteArray = []) -> AnimatedTexture:
	var folder_path = "user://.tmp_%d/" % Time.get_unix_time_from_system()
	
	# dump the buffer
	if FileAccess.file_exists(path):
		push_warning("File found at %s, loading it instead of using the buffer." % path)
		buffer = FileAccess.get_file_as_bytes(path)
	else:
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
		ProjectSettings.globalize_path(folder_path + "%02d.png"),
	], out, true)
	assert(code == 0, "unable to convert: %s" % "\n".join(out))
	
	# rename files to include their delays
	var tex = AnimatedTexture.new()
	var frames = DirAccess.get_files_at(folder_path)
	if len(frames) == 0:
		return null
	
	tex.frames = len(frames)
	for filepath in frames:
		var idx = filepath.substr(0, filepath.rfind(".")).to_int()
		var delay = frame_delays[idx] / 1000.0
	
		var image = Image.new()
		var error = image.load(folder_path + filepath)
		if error != OK:
			return null
		
		var frame = ImageTexture.create_from_image(image)
		# frame.take_over_path(filepath)
		tex.set_frame_duration(idx, delay) # ffmpeg defaults to 25fps
		tex.set_frame_texture(idx, frame)
	
	# delete the temp directory
	OS.move_to_trash(ProjectSettings.globalize_path(folder_path))
	
	ResourceSaver.save(
		tex,
		path + ".res",
		ResourceSaver.SaverFlags.FLAG_COMPRESS
	)
	tex.take_over_path(path + ".res")
	
	print("animated image saved: %s" % path)
	
	return tex
