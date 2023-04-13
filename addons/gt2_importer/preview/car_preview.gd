extends Node

func _ready():
	var car = get_node("Car")
	var colors = car.get_meta("colors")

	var control = %ActivePalette
	control.max_value = len(colors) - 1
	control.min_value = 0
	control.value_changed.connect(
		func(value):
			preload("res://addons/gt2_importer/gdo.gd").apply_palette(
				car,
				car.get_meta("colors"),
				value
			)
	)
	
	var t = create_tween()
	t.tween_property(car, "rotation", Vector3(0, PI * 2, 0), 3.0)\
		.from(Vector3(0,0,0))
	t.set_loops()
