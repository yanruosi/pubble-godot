extends RefCounted
class_name HomeOverlayUi

static func place_control(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.custom_minimum_size = rect.size
	node.size = rect.size


static func make_hit_button(rect: Rect2, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	place_control(btn, rect)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)
	if not text.is_empty():
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color(0.18, 0.32, 0.22, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.1, 0.45, 0.25, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.38, 0.2, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.6))
	return btn


static func make_label(rect: Rect2, font_size: int, h_align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lbl := Label.new()
	place_control(lbl, rect)
	lbl.horizontal_alignment = h_align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18, 1))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = false
	return lbl


static func make_activity_label(rect: Rect2, font_size: int, h_align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lbl := make_label(rect, font_size, h_align)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


static func make_activity_toast(layer: CanvasLayer) -> Label:
	var toast := Label.new()
	toast.name = "ActivityToast"
	toast.visible = false
	toast.position = Vector2(440, 360)
	toast.custom_minimum_size = Vector2(400, 32)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 16)
	toast.add_theme_color_override("font_color", Color(0.35, 0.12, 0.12, 1))
	toast.z_index = 400
	layer.add_child(toast)
	return toast
