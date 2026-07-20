extends RefCounted

const _BLACK := Color(0, 0, 0, 1)
const _BLACK_DISABLED := Color(0.35, 0.35, 0.35, 1)
const _BODY_TEXT := Color(0.16, 0.14, 0.2, 1)
const _PLACEHOLDER := Color(0.45, 0.43, 0.52, 1)
const _INDENT := "\u3000\u3000"
const OUTER_BG := Color(0.93, 0.93, 0.95, 1)
const PREVIEW_BG := Color(1, 1, 1, 1)


static func apply_outer_bg(panel: Panel) -> void:
	var ps := StyleBoxFlat.new()
	ps.bg_color = OUTER_BG
	ps.border_color = Color(0.82, 0.82, 0.86, 1)
	ps.set_border_width_all(1)
	ps.corner_radius_top_left = 2
	ps.corner_radius_top_right = 2
	ps.corner_radius_bottom_right = 2
	ps.corner_radius_bottom_left = 2
	ps.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", ps)


static func apply_preview_bg(panel: Panel) -> void:
	var ps := StyleBoxFlat.new()
	ps.bg_color = PREVIEW_BG
	ps.border_color = Color(0.88, 0.88, 0.9, 1)
	ps.set_border_width_all(1)
	ps.corner_radius_top_left = 2
	ps.corner_radius_top_right = 2
	ps.corner_radius_bottom_right = 2
	ps.corner_radius_bottom_left = 2
	ps.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", ps)


static func heiti_font(_size: int, bold: bool = true) -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["SimHei", "Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC"])
	sf.font_weight = 700 if bold else 400
	return sf


static func style_input(input: TextEdit) -> void:
	var white := StyleBoxFlat.new()
	white.bg_color = PREVIEW_BG
	white.set_content_margin_all(4)
	input.add_theme_stylebox_override("normal", white)
	input.add_theme_stylebox_override("focus", white)
	input.add_theme_stylebox_override("read_only", white)
	input.add_theme_font_override("font", heiti_font(14, false))
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", _BODY_TEXT)
	input.add_theme_color_override("font_readonly_color", _BODY_TEXT)
	input.add_theme_color_override("font_placeholder_color", _PLACEHOLDER)
	input.add_theme_constant_override("line_separation", 6)
	input.modulate = Color(1, 1, 1, 1)


static func format_preview_text(title: String, body: String) -> String:
	var parts: PackedStringArray = []
	if not title.is_empty():
		parts.append(_INDENT + title)
	if not body.is_empty():
		for line in body.split("\n"):
			var trimmed := line.strip_edges()
			if trimmed.is_empty():
				parts.append("")
			else:
				parts.append(_INDENT + trimmed)
	return "\n".join(parts)


static func _paint_btn_black(btn: Button) -> void:
	btn.add_theme_color_override("font_color", _BLACK)
	btn.add_theme_color_override("font_hover_color", _BLACK)
	btn.add_theme_color_override("font_pressed_color", _BLACK)
	btn.add_theme_color_override("font_focus_color", _BLACK)
	btn.add_theme_color_override("font_disabled_color", _BLACK_DISABLED)


static func style_tag_button(btn: Button, selected: bool, enabled: bool) -> void:
	btn.disabled = not enabled
	btn.flat = true
	btn.custom_minimum_size = Vector2(0, 24)
	btn.add_theme_font_override("font", heiti_font(13, selected))
	btn.add_theme_font_size_override("font_size", 13)
	_paint_btn_black(btn)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)


static func style_send_button(btn: Button) -> void:
	btn.flat = true
	btn.add_theme_font_override("font", heiti_font(15))
	btn.add_theme_font_size_override("font_size", 15)
	_paint_btn_black(btn)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)
