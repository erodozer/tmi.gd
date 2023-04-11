@tool
extends EditorImportPlugin

enum Presets { DEFAULT }

func _get_importer_name():
	return "erodozer.gt2.car"

func _get_visible_name():
	return "GT2 Car"

func _get_recognized_extensions():
	return ["cdo", "cno"]

func _get_save_extension():
	return "tscn"

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
				"default_value": false
			}]
		_:
			return []

func _get_import_order():
	return 0

func _get_option_visibility(path, option, options):
	return true
	
func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	var model = preload("./gdo.gd").new().parse_model(
		source_file
	)
	model.name = source_file.get_file().replace(".", "_")
	
	var out = PackedScene.new()
	out.pack(model)
	
	if model:
		return ResourceSaver.save(
			out,
			"%s.%s" % [save_path, _get_save_extension()],
			ResourceSaver.FLAG_CHANGE_PATH|ResourceSaver.FLAG_REPLACE_SUBRESOURCE_PATHS
		)
	push_error("failed to import %s" % source_file)
	
