extends RefCounted
class_name FeedBannerAnim


static func play_enter(area: Control, widgets: Array) -> void:
	if area == null:
		return
	for w in widgets:
		if w is CanvasItem:
			(w as CanvasItem).modulate.a = 0.0
	var tw := area.create_tween()
	tw.set_parallel(true)
	for w in widgets:
		if w is CanvasItem:
			tw.tween_property(w, "modulate:a", 1.0, 0.22)


static func pulse_label(label: Label, area: Control) -> void:
	if label == null or area == null:
		return
	var tw := area.create_tween()
	tw.tween_property(label, "scale", Vector2(1.08, 1.08), 0.12)
	tw.tween_property(label, "scale", Vector2.ONE, 0.14)


static func pulse_reward(fans_label: Label, fp_label: Label, area: Control) -> void:
	pulse_label(fans_label, area)
	pulse_label(fp_label, area)
