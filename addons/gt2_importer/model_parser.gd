@tool
extends EditorImportPlugin

enum Presets { DEFAULT }

func _get_importer_name():
	return "erodozer.gt2.car_mesh"

func _get_visible_name():
	return "GT2 Car"

func _get_recognized_extensions():
	return ["cdo", "cno"]

func _get_save_extension():
	return "scn"

func _get_resource_type():
	return "PackedScene"

func _get_priority():
	return 1

func _get_preset_count():
	return Presets.size()
	
func _get_preset_name(preset):
	match preset:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"
	
func _get_import_options(path, preset):
	match preset:
		Presets.DEFAULT:
			return [{
				"name": "include_materials",
				"default_value": true
			}, {
				"name": "include_wheels",
				"default_value": true
			}]
		_:
			return []

func _get_import_order():
	return 0

func _get_option_visibility(path, option, options):
	return true
	
func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	var color_parser = preload("./gdp.gd").new()
	var shape_parser = preload("./gdo.gd").new()
	
	var extension = source_file.get_extension()
	var is_night = extension == "cno"
	var palette_ext = ".cnp" if is_night else ".cdp"
	var colors = color_parser.parse_palette(
		source_file.get_basename() + palette_ext
	)
	var model = shape_parser.parse_model(
		source_file, colors, options.include_wheels
	)
	model.name = source_file.get_file().replace(".", "_")
	
	var out = PackedScene.new()
	out.pack(model)
	
	if model:
		return ResourceSaver.save(
			out,
			"%s.%s" % [save_path, _get_save_extension()],
			ResourceSaver.FLAG_BUNDLE_RESOURCES|ResourceSaver.FLAG_CHANGE_PATH|ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS|ResourceSaver.FLAG_COMPRESS
		)
	push_error("failed to import %s" % source_file)
	
