extends Button
class_name HotspotNode

signal triggered(row: Dictionary)

var hotspot_row: Dictionary = {}
var _question_badge: Label

static func is_hidden_visual(row: Dictionary) -> bool:
	return str(row.get("visual_mode", "")).strip_edges() == "hidden"

static func uses_question_badge(row: Dictionary) -> bool:
	if str(row.get("hotspot_type", "")) == "close":
		return false
	if is_hidden_visual(row):
		return false
	if int(row.get("hide_question_only", 0)) == 1:
		return true
	if int(row.get("highlight", 0)) == 1:
		return false
	if not str(row.get("hotspot_label", "")).strip_edges().is_empty():
		return false
	return true

func setup(row: Dictionary, rect: Rect2) -> void:
	hotspot_row = row.duplicate(true)
	position = rect.position
	size = rect.size
	custom_minimum_size = rect.size
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = clampi(int(row.get("z_order", 0)), 0, 5)
	z_as_relative = true
	flat = false
	if is_hidden_visual(row) or str(row.get("hotspot_type", "")) == "close":
		text = ""
		_apply_hidden_style()
	elif str(row.get("hotspot_type", "")) == "collect" and _resolve_label_text(row).is_empty():
		text = ""
		_apply_hidden_style()
	elif not _resolve_label_text(row).is_empty():
		text = _resolve_label_text(row)
		_apply_text_label_style(int(row.get("highlight", 0)) == 1)
	else:
		var placeholder_text: String = str(row.get("display_name", "")).strip_edges()
		if not placeholder_text.is_empty():
			text = placeholder_text
			_apply_text_label_style(false)
		else:
			text = ""
			_apply_placeholder_style()
	if uses_question_badge(row):
		_show_question_badge()
	else:
		_hide_question_badge()
	tooltip_text = str(row.get("display_name", ""))
	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

func set_used() -> void:
	_hide_question_badge()
	disabled = false
	modulate = Color(1, 1, 1, 1)

func hide_question_badge() -> void:
	_hide_question_badge()

func set_viewed() -> void:
	disabled = false
	_hide_question_badge()
	modulate = Color(1, 1, 1, 1)

func _resolve_label_text(row: Dictionary) -> String:
	if is_hidden_visual(row):
		return ""
	var label: String = str(row.get("hotspot_label", "")).strip_edges()
	if not label.is_empty():
		return label
	if int(row.get("highlight", 0)) == 1:
		return str(row.get("display_name", "")).strip_edges()
	return ""

func _apply_hidden_style() -> void:
	flat = true
	var style := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("disabled", style)
	modulate = Color(1, 1, 1, 1)

func _apply_text_label_style(is_collect: bool) -> void:
	flat = true
	var style := StyleBoxFlat.new()
	if is_collect:
		style.bg_color = Color(0.95, 0.25, 0.2, 0.18)
		style.border_color = Color(1.0, 0.62, 0.52, 0.85)
	else:
		style.bg_color = Color(0.12, 0.1, 0.2, 0.12)
		style.border_color = Color(0.92, 0.82, 0.45, 0.75)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("disabled", style)
	add_theme_color_override("font_color", Color(1.0, 0.94, 0.72, 1.0) if is_collect else Color(0.95, 0.9, 0.78, 1.0))
	add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.86, 1.0))
	add_theme_font_size_override("font_size", 20)

func _on_pressed() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	if IdolBottomBar.blocks_hotspot_at(mouse_pos):
		#region agent log
		DebugSessionLog.write_debug("H3", "hotspot_node.gd:_on_pressed", "blocked_by_bottom_ui", {
			"hotspot_id": str(hotspot_row.get("hotspot_id", "")),
			"mouse_pos": [mouse_pos.x, mouse_pos.y]
		})
		#endregion
		return
	#region agent log
	var gr := get_global_rect()
	DebugSessionLog.write_debug("H3", "hotspot_node.gd:_on_pressed", "hotspot_pressed", {
		"hotspot_id": str(hotspot_row.get("hotspot_id", "")),
		"hotspot_type": str(hotspot_row.get("hotspot_type", "")),
		"open_modal": str(hotspot_row.get("open_modal", "")),
		"global_rect": [gr.position.x, gr.position.y, gr.size.x, gr.size.y]
	})
	#endregion
	triggered.emit(hotspot_row.duplicate(true))

func _apply_placeholder_style() -> void:
	flat = true
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.2, 0.08)
	style.border_color = Color(0.92, 0.82, 0.45, 0.45)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_stylebox_override("focus", style)
	add_theme_stylebox_override("disabled", style)

func _show_question_badge() -> void:
	if _question_badge == null:
		_question_badge = Label.new()
		_question_badge.name = "QuestionBadge"
		_question_badge.text = "?"
		_question_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_question_badge.set_anchors_preset(Control.PRESET_CENTER)
		_question_badge.offset_left = -15.0
		_question_badge.offset_top = -15.0
		_question_badge.offset_right = 15.0
		_question_badge.offset_bottom = 15.0
		_question_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_question_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_question_badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45, 1.0))
		_question_badge.add_theme_font_size_override("font_size", 20)
		add_child(_question_badge)
	_question_badge.visible = true

func _hide_question_badge() -> void:
	if _question_badge != null:
		_question_badge.visible = false
