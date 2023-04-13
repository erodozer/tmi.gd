extends RefCounted

const WheelMesh = preload("./wheel.mesh")

const BitmapHeight = preload("./gdp.gd").BitmapHeight
const BitmapWidth = preload("./gdp.gd").BitmapWidth

const UNITS_TO_METRES = 1.0 / 4096.0

## create a signed short
func short(i: int):
	return wrapi(i, -32768, 32767)
	
func int32(i: int):
	return wrapi(i, -pow(2, 16), pow(2, 16))

func make_wheel(buffer: FileAccess, material: Material):
	var x = short(buffer.get_16())
	var y = short(buffer.get_16())
	var z = short(buffer.get_16())
	var w = short(buffer.get_16())
	
	var wheel = MeshInstance3D.new()
	wheel.mesh = WheelMesh.duplicate()
	wheel.set_surface_override_material(0, null)
	wheel.set_surface_override_material(1, material)
	
	wheel.position = Vector3(x,y,z) * UNITS_TO_METRES
	wheel.scale = Vector3(1.0,1.0,1.0) * (w / 10000.0)
	wheel.add_to_group("gt2:wheel", true)
	return wheel
	
func make_face(buffer: FileAccess, is_quad: bool, vertices: Array, normals: Array):
	var v0 = buffer.get_8()
	var v1 = buffer.get_8()
	var v2 = buffer.get_8()
	var v3 = buffer.get_8()
	
	var order_data = buffer.get_16()
	var flags = buffer.get_16() >> 12
	var normals_data = buffer.get_32()
	var face_type = buffer.get_32() >> 24
	
	var render_order = order_data & 0x1F
	
	var n0 = (order_data >> 5) & 0x1FF
	var n1 = (normals_data >> 1) & 0x1FF
	var n2 = (normals_data >> 10) & 0x1FF
	var n3 = (normals_data >> 19) & 0x1FF
	
	var out_v = [v2, v1, v0] # ABC
	var out_n = [n2, n1, n0]
	var raw_v = [v0, v1, v2]
	var raw_n = [n0, n1, n2]
	if is_quad:
		out_v.append_array([v3, v2, v0]) #ACD
		out_n.append_array([n3, n2, n0])
		raw_v.append(v3)
		raw_n.append(n3)
		
	return {
		"vertices": out_v.map(func (x): return vertices[x]),
		"normals": out_n.map(func (x): return normals[x]),
		"raw_vertices": raw_v,
		"raw_normals": raw_n,
		"flags": flags,
		"face_type": face_type
	}
	
func make_uv(buffer, is_quad, vertices, normals):
	var polygon = make_face(buffer, is_quad, vertices, normals)
	
	var uv0 = Vector2(buffer.get_8() / 255.0, buffer.get_8() / 255.0)
	var raw_palette_index = buffer.get_16()
	var palette_index = (raw_palette_index >> 4) + (raw_palette_index & 0x3F)
	var uv1 = Vector2(buffer.get_8() / 255.0, buffer.get_8() / 255.0)
	var unknown_13 = buffer.get_8()
	var unknown_14 = buffer.get_8()
	
	var uv2 = Vector2(buffer.get_8() / 255.0, buffer.get_8() / 255.0)
	var uv3 = Vector2(buffer.get_8() / 255.0, buffer.get_8() / 255.0)
	
	var uvs = [uv2, uv1, uv0]
	var raw_uvs = [uv0, uv1, uv2]
	if is_quad:
		uvs.append_array([uv3, uv2, uv0])
		raw_uvs.append(uv3)
	
	return {
		"vertices": polygon.vertices,
		"normals": polygon.normals,
		"flags": polygon.flags,
		"face_type": polygon.face_type,
		"uvs": uvs,
		"raw_uvs": raw_uvs,
		"palette": palette_index
	}
	
func uvs_to_pixels(uvs):
	# copy pixels to merged texture
	var copy = []
	
	# create bounding box from uvs
	var min_x = 256
	var min_y = 256
	var max_x = 0
	var max_y = 0
	for uv in uvs:
		var scaled = Vector2(uv * 256)
		min_x = min(min_x, scaled.x)
		min_y = min(min_y, scaled.y)
		max_x = max(max_x, scaled.x)
		max_y = max(max_y, scaled.y)
	
	return Rect2i(
		min_x, min_y,
		max_x - min_x + 1, max_y - min_y + 1
	)

func uvs_to_pixels_brute(uvs: Array):
	var pixels = []
	for i in range(0, len(uvs), 3):
		var a = uvs[i] * 256
		var b = uvs[i+1] * 256
		var c = uvs[i+2] * 256
		
		for x in range(256):
			for y in range(256):
				var point = Vector2(x, y)
				if Geometry2D.point_is_inside_triangle(
					point,
					a, b, c
				):
					pixels.append(Vector2i(point))
		
	return pixels
	
func make_lod(buffer: FileAccess, colors: Dictionary):
	var vertex_count = buffer.get_16()
	var normal_count = buffer.get_16()
	var tri_count = buffer.get_16()
	var quad_count = buffer.get_16()
	buffer.get_32() # skip ahead
	var uv_tri_count = buffer.get_16()
	var uv_quad_count = buffer.get_16()
	var unknown = buffer.get_buffer(44)
	
	var low_bound = Vector4(
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
	)
	var high_bound = Vector4(
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
	)
	
	var scale = buffer.get_16() - 16
	if scale < 0:
		scale = 1.0 / (1 << -scale)
	else:
		scale = 1 << scale
	var unknown2 = buffer.get_8()
	var unknown3 = buffer.get_8()
	
	var vertices = []
	for i in range(vertex_count):
		vertices.append(Vector3(
			short(buffer.get_16()),
			short(buffer.get_16()),
			short(buffer.get_16()),
		) * scale * UNITS_TO_METRES)
		buffer.get_16()
		
	var normals = []
	var n_max = [0,0,0]
	var n_min = [0,0,0]
	var sign_bit = 1 << 9
	for _i in range(normal_count):
		var i = buffer.get_32()
		normals.append(Vector3(
			(((i >> 2) & 0x3FF) ^ sign_bit) - sign_bit,
			(((i >> 12) & 0x3FF) ^ sign_bit) - sign_bit,
			(((i >> 22) & 0x3FF) ^ sign_bit) - sign_bit
		) / 500.0)
	
	# group faces into palettes
	# so we can minimize the number of surfaces and texture binds
	var faces = []
	
	var st = SurfaceTool.new()
	# TODO split into multiple surfaces if there is duplicate faces
	# should fix UV mapping
	
	var mesh = ArrayMesh.new()
	
	for _i in range(tri_count):
		faces.append(make_face(buffer, false, vertices, normals))
	for _i in range(quad_count):
		faces.append(make_face(buffer, true, vertices, normals))
	for _i in range(uv_tri_count):
		faces.append(make_uv(buffer, false, vertices, normals))
	for _i in range(uv_quad_count):
		faces.append(make_uv(buffer, true, vertices, normals))
		
	# chunk faces based on their material
	var groups = {}
	for f in faces:
		var p = -1 if not ("palette" in f) else f.palette
		var l = groups.get(p, [])
		l.append(f)
		groups[p] = l
	
	for p in groups:
		var mat = null if p == -1 else colors.values()[0].materials[p]
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
		for f in groups[p]:
			for i in range(len(f.vertices)):
				st.set_normal(f.normals[i])
				st.set_uv(Vector2.ZERO if p == -1 else f.uvs[i])
				st.add_vertex(f.vertices[i])
				
			if p != -1:
				# copy pixels to merged texture
				var copy = uvs_to_pixels(f.uvs)
				for _c in colors.values():
					_c.merged.blend_rect(
						_c.palettes[p], copy, copy.position
					)
		
		mesh = st.commit(mesh)
		mesh.surface_set_name(
			mesh.get_surface_count() - 1,
			"face=%d/palette=%d" % [
				mesh.get_surface_count() - 1,
				-1
			]
		)
		#mesh.surface_set_material(
		#	mesh.get_surface_count() - 1,
		#	mat
		#)
		
	#var mesh = st.commit()
	#mesh.surface_set_name(0, "body")
	
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	
	return instance

func make_shadow(buffer: FileAccess):
	var vertex_count = buffer.get_16()
	var tri_count = buffer.get_16()
	var quad_count = buffer.get_16()
	buffer.get_16() # skip ahead
	
	var low_bound = Vector4(
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
	)
	var high_bound = Vector4(
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
		short(buffer.get_16()),
	)
	
	var scale = buffer.get_16() - 16
	if scale < 0:
		scale = 1.0 / (1 << -scale)
	else:
		scale = 1 << scale
	var unknown2 = buffer.get_8()
	var unknown3 = buffer.get_8()
	
	var vertices = []
	for i in range(vertex_count):
		vertices.append(Vector3(
			short(buffer.get_16()),
			0.0,
			short(buffer.get_16()),
		) * scale * UNITS_TO_METRES)
		
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for _i in range(tri_count):
		var data = buffer.get_32()
		st.add_vertex(vertices[data & 0x3F])
		st.add_vertex(vertices[data >> 6 & 0x3F])
		st.add_vertex(vertices[data >> 12 & 0x3F])
		
	for _i in range(quad_count):
		var data = buffer.get_32()
		st.add_vertex(vertices[data & 0x3F])
		st.add_vertex(vertices[data >> 6 & 0x3F])
		st.add_vertex(vertices[data >> 12 & 0x3F])
		
		st.add_vertex(vertices[data >> 12 & 0x3F])
		st.add_vertex(vertices[data >> 18 & 0x3F])
		st.add_vertex(vertices[data & 0x3F])
		
	var mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	mesh.surface_set_material(0, mat)
	mesh.surface_set_name(0, "shadow")
	
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	
	return instance

func parse_model(source_file: String, palettes: Dictionary, include_wheels = true):
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	
	var root = Node3D.new()
	
	# read header
	file.seek(0x08)
	var unknown_1 = file.get_16()
	if unknown_1 == 0:
		file.seek(0x18)
		unknown_1 = file.get_16()
	var unknown_2 = file.get_16()
	var unknown_3 = file.get_16()
	var unknown_4 = file.get_16()
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.resource_local_to_scene = true
	
	# read wheel positions
	var wheels = []
	for i in range(4):
		var wheel = make_wheel(file, mat)
		if include_wheels:
			wheel.name = "wheel_%02d" % i
			root.add_child(wheel)
			wheels.append(wheel)
			wheel.owner = root
		
	file.get_buffer(0x828) # skip ahead
	var lodCount = file.get_16()
	
	var unknown_5 = file.get_buffer(26)
	
	var lods = []
	for i in range(lodCount):
		var lod = make_lod(file, palettes)
		lod.name = "lod_%d" % i
		
		for s in range(lod.mesh.get_surface_count()):
			var palette = (lod.mesh as ArrayMesh).surface_get_name(s).split("/")[1].split("=")[1].to_int()
			lod.set_surface_override_material(
				s,
				mat,
			)
	
		if lods.is_empty():
			lods.append(lod)
			lod.add_to_group("gt2:body", true)
			root.add_child(lod)
			lod.owner = root
		
	# var shadow = make_shadow(file)
	# root.add_child(shadow)
		
	file.close()
	
	# convert images to textures
	var textures: Array[ImageTexture] = []
	for c in palettes.values():
		var tex = ImageTexture.create_from_image(c.merged)
		textures.append(tex)
	
	# debug show textures
	var debug = Control.new()
	for i in range(len(palettes)):
		var c = palettes.values()[i]
		var rect = TextureRect.new()
		rect.texture = textures[i]
		rect.name = "Color%s" % c.id
		debug.add_child(rect)
	
	root.add_child(debug)
			
	mat.albedo_texture = textures.front()
	
	root.set_meta("colors", textures)
	
	return root

## Swap the color texture for a car model
static func apply_palette(car: Node, palettes: Array, idx: int):
	var tex = palettes[idx]
	for mesh in car.get_children():
		if mesh.is_in_group("gt2:wheel"):
			var wheel = mesh as MeshInstance3D
			# only override the wheel
			var mat = wheel.get_surface_override_material(
				1
			)
			mat.albedo_texture = tex
		elif mesh.is_in_group("gt2:body"):
			var body = mesh as MeshInstance3D
			# all surfaces share the same resource
			var mat = mesh.get_surface_override_material(
				0
			)
			mat.albedo_texture = tex
