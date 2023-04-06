extends VBoxContainer

@onready var timer = %Time

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var current_time = Time.get_time_dict_from_system()
	
	timer.text = "%d:%02d:%02d %s" % [
		12 if current_time.hour % 12 == 0 else current_time.hour % 12,
		current_time.minute,
		current_time.second,
		"AM" if current_time.hour < 12 else "PM"
	]
