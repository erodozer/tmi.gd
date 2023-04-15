extends Control

const YIPPEE_ID = "6518c704-4ba6-43b2-85fa-5b69d4fe9c06"

func _on_twitch_command(type, event):
	if type != "subscription":
		return
		
	var id = event.reward.id
	
	if id != YIPPEE_ID:
		return
		
	%Label.text = "%s YIPPEE" % event.user.display_name
	%AnimationPlayer.play("show")
	
