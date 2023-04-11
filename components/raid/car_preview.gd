extends Node

func _ready():
	var cdo_loader = preload("res://addons/gt2_importer/gdo.gd").new()
	var model = cdo_loader.parse_model(
		"res://assets/cars/hpnvn.cdo",
	)
		
	model.name = "Car"
	add_child(model)
	
	var t = create_tween()
	t.tween_property(model, "rotation", Vector3(0, PI * 2, 0), 3.0)\
		.from(Vector3(0,0,0))
	t.set_loops()


#	var car = $Car
#	var wheel = $Wheel
#
#	for i in car.get_children():
#		if i.name.begins_with("wheelpos"):
#			var pos = (i.mesh as Mesh).get_faces()[0]
#			var w = wheel.duplicate() as Node3D
#			car.add_child(w)
#			var scale = i.name.rsplit("=", false, 1)[1].to_int() / 10000.0
#			w.scale = Vector3(scale, scale, scale)
#			if "-" in i.name:
#				w.scale *= Vector3(1.0, -1.0, 1.0)
#				# w.translate(Vector3(scale, 0, 0))
#				w.position = Vector3(pos[0] - 0.01,pos[1],pos[2])
#			else:
#				w.position = Vector3(pos[0] + 0.01,pos[1],pos[2])
#		if i.name.begins_with("shadowscale"):
#			i.queue_free()
#
#	wheel.queue_free()
