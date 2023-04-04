extends RichTextLabel

@export_range(100, 9999) var max_width = 300

var tween: Tween

func update_text(text: String):
	self.modulate = Color.TRANSPARENT
	self.visible_ratio = 1.0
	self.fit_content = true
	self.text = text
	await self.finished
	self.size = Vector2(max_width, 9999)
	await get_tree().process_frame
	self.size = Vector2(min(get_content_width(), max_width), get_content_height())
	await get_tree().process_frame
	self.fit_content = false
	self.modulate = Color.WHITE
	self.pivot_offset = Vector2(self.size.x / 2, 0)
	self.position = Vector2(-self.size.x / 2, -self.size.y)
	
	if tween:
		tween.stop()
		
	self.visible = true
	tween = get_tree().create_tween()
	tween.tween_property(
		self, "visible_ratio", 1.0, min(.11 * len(text), 2.0)
	).from(0.0)
