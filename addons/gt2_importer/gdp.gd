extends RefCounted

# File layout
const HeaderData = 0
const ColorCountIndex = 0
const PaletteStartIndex = 0x20
const PaletteSize = 0x240
const BitmapStartIndex = 0x43A0
const BitmapEmptyFillSize = 0
const SingleInstanceOfFlagsStartIndex = 0

# Dimensions
const BitmapHeight = 224
const BitmapWidth = 256

func load_color(buffer: FileAccess, index: int):
	buffer.seek(ColorCountIndex + 2 + index)
	var id = buffer.get_8()
	
	buffer.seek(PaletteStartIndex + (PaletteSize * index))
	
	var palettes = []
	for i in range(16):
		var palette = []
		for x in range(16):
			var c = buffer.get_16()
			
			var r = c & 0x1F
			var g = (c >> 5) & 0x1F
			var b = (c >> 10) & 0x1f
			var a = 0xFF if c > 0 else 0
			palette.append(
				Color8(
					r * 8,
					g * 8,
					b * 8,
					a
				)
			)
		palettes.append(palette)
	
	var illumination_masks = []
	for i in range(16):
		var flags = buffer.get_16()
		var mask = []
		for x in range(16):
			mask.append(flags & 1 == 1)
			flags = flags >> 1
		illumination_masks.append(mask)
		
	var paint_masks = []
	for i in range(16):
		var flags = buffer.get_16()
		var mask = []
		for x in range(16):
			mask.append(flags & 1 == 1)
			flags = flags >> 1
		paint_masks.append(mask)
		
	return {
		"id": id,
		"palettes": palettes,
		"illumination": illumination_masks,
		"paint": paint_masks
	}
	
func create_bitmap(bitmap_lut, palette):
	var image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var x = 0
	var y = 0
	
	image.fill(Color.TRANSPARENT)
	for _i in bitmap_lut:
		# convert byte to Color
		image.set_pixel(x, y, palette[_i])
		
		x += 1
		if x >= BitmapWidth:
			y += 1
			x = 0
		
	return image

func parse_palette(source_file: String, dump_files = false):
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		var code = FileAccess.get_open_error()
		push_error("could not open palette file %s, error_code: %d" % [source_file, code])
		return code
	
	# read colors
	file.seek(ColorCountIndex)
	var color_count = file.get_16()
	var colors = []
	for i in range(color_count):
		colors.append(load_color(file, i))
	
	file.seek(BitmapStartIndex + BitmapEmptyFillSize)
	
	# get the texture bitmap
	var bitmap = []
	for y in range(BitmapHeight):
		for x in range(0, BitmapWidth, 2):
			var px_pair = file.get_8()
			bitmap.append(px_pair & 0xF)
			bitmap.append(px_pair >> 4)
	
	# build images from the bitmap mapped with each palette
	var textures = {}
	for color_set in colors:
		var images: Array[Image] = []
		var materials: Array[Material] = []
		var merged = Image.create(256, 256, false, Image.FORMAT_RGBA8)
		merged.fill(Color.TRANSPARENT)
		
		var i = 0
		for palette in range(16):
			var image = create_bitmap(bitmap, color_set.palettes[i])
			images.append(image)
			
			var mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			mat.albedo_texture = ImageTexture.create_from_image(image)
			
			materials.append(mat)
			
			if dump_files:
				var path = "user://cars/%s/Color%s/palette%02d.png" % [
					source_file.get_file().rsplit(".", false, 1)[0],
					color_set.id,
					i,
				]
				DirAccess.make_dir_recursive_absolute(path.get_base_dir())
				
				image.save_png(path)
			
			i += 1
		
		# copy tire from first texture
		merged.blit_rect(
			images[0],
			Rect2i(0, 0, 48, 48),
			Vector2i(0, 0)
		)
		
		textures[color_set.id] = {
			"id": color_set.id,
			"palettes": images,
			"materials": materials,
			"merged": merged
		}
		
	return textures
	
