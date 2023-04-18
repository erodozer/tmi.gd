extends Node

const GT2_GDO = preload("res://addons/gt_importer/gdo.gd")

@export var tmi: Tmi

func _on_twitch_command(type, event):
	if type != Tmi.EventType.RAID:
		return
	
	# fetch profile image
	var profile = await tmi.twitch_api.fetch_user(event.user.id)
	var profile_image = await tmi.twitch_api.fetch_profile_image(profile)
	
	# fetch car data
	# TODO interface with supabase
	
	var car = preload("res://assets/cars/hcvon.cdo").instantiate()
	
	GT2_GDO.apply_palette(
		car,
		car.get_meta("colors"),
		2
	)
	%World.add_child(car)
	
	# attach particles to the new car
	var box = (car.get_node("lod_0") as MeshInstance3D).get_aabb()
	var tail = box.get_center() + ( box.get_longest_axis() * box.get_longest_axis_size() * .7)	
	var smoke = %World/%Smoke
	smoke.reparent(car)
	smoke.unique_name_in_owner = true
	smoke.owner = %World
	smoke.position = tail

	# swap places with the placeholder	
	var placeholder = %World/Car
	%World.remove_child(placeholder)
	placeholder.queue_free()
	
	car.name = "Car"
	
	var car_anim = %World/AnimationPlayer as AnimationPlayer
	var anim = $AnimationPlayer as AnimationPlayer
	
	car_anim.play("RESET")
	
	var shadow = StandardMaterial3D.new()
	shadow.albedo_color = Color.BLACK
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	for i in car.get_children():
		if i as MeshInstance3D:
			i.material_overlay = shadow
	
	%UserName.text = profile.display_name
	%UserName.label_settings.font_size = 140
	while %UserName.get_line_count() > 1 and %UserName.label_settings.font_size > 32:
		%UserName.label_settings.font_size = clamp(%UserName.label_settings.font_size - 8, 32, 140)
		(%UserName as Label).force_update_transform()
		await get_tree().process_frame

	%ProfileImage.texture = profile_image
	
	anim.play("startup")
	await anim.animation_finished
	car_anim.play("slide")
	await car_anim.animation_finished
	car_anim.play("drift")
	await car_anim.animation_finished
	car_anim.play("show_off")
	anim.play("show_raider")
	await anim.animation_finished
	
