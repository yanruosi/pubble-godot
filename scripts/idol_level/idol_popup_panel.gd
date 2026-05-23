extends Control
class_name IdolPopupPanel

signal close_requested
signal popup_closed(modal_id: String)
signal bubble_dismissed(should_restore_layer: bool)

var _dismiss_rect: ColorRect
var _modal_panel: PanelContainer
var _modal_title: Label
var _modal_body: Label
var _modal_image: TextureRect
var _modal_placeholder: ColorRect
var _bubble_panel: PanelContainer
var _bubble_label: Label
var _close_button: Button
var _current_modal_id: String = ""
var _bubble_only: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	_build_ui()
	hide_all()

func show_modal(modal_id: String, title: String, asset_path: String = "", popup_layout: String = "") -> void:
	_current_modal_id = modal_id
	_dismiss_rect.visible = false
	_bubble_panel.visible = false
	_modal_panel.visible = true
	_close_button.visible = true
	_apply_layout(modal_id, popup_layout)
	_apply_asset_display(title, asset_path)
	#region agent log
	DebugSessionLog.write("idol_popup_panel.gd:show_modal", "modal_shown", "D", {
		"modal_id": modal_id,
		"popup_layout": popup_layout,
		"asset_path": asset_path,
		"panel_rect": _modal_panel.get_rect()
	})
	#endregion

func show_bubble(text: String, keep_modal: bool = false) -> void:
	_bubble_label.text = text
	_bubble_panel.visible = true
	_dismiss_rect.visible = true
	_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble_only = keep_modal
	if keep_modal:
		return
	_current_modal_id = ""
	_modal_panel.visible = false
	_close_button.visible = false

func show_message(text: String) -> void:
	show_bubble(text, false)

func get_current_modal_id() -> String:
	return _current_modal_id

func hide_all() -> void:
	_current_modal_id = ""
	_bubble_only = false
	if _dismiss_rect != null:
		_dismiss_rect.visible = false
		_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _modal_panel != null:
		_modal_panel.visible = false
	if _bubble_panel != null:
		_bubble_panel.visible = false
	if _close_button != null:
		_close_button.visible = false

func _apply_asset_display(title: String, asset_path: String) -> void:
	var use_placeholder: bool = asset_path.is_empty() or asset_path.contains("母体")
	_modal_image.visible = false
	if _modal_placeholder != null:
		_modal_placeholder.visible = use_placeholder
	if use_placeholder:
		_modal_title.visible = true
		_modal_body.visible = true
		_modal_title.text = title
		_modal_body.text = "（占位预览区，请点击图上文字热点）"
		if _modal_placeholder != null:
			_modal_placeholder.color = _placeholder_color(title)
		return
	var has_asset: bool = ResourceLoader.exists(asset_path)
	if has_asset:
		var tex := load(asset_path) as Texture2D
		if tex != null:
			_modal_image.texture = tex
			_modal_image.visible = true
			if _modal_placeholder != null:
				_modal_placeholder.visible = false
			_modal_title.visible = false
			_modal_body.visible = false
			return
	_modal_title.visible = true
	_modal_body.visible = true
	_modal_title.text = title
	_modal_body.text = "物件图加载失败：%s" % asset_path

func _placeholder_color(title: String) -> Color:
	var hash_val: int = title.hash()
	return Color(
		0.22 + float(hash_val % 7) * 0.08,
		0.18 + float((hash_val >> 3) % 7) * 0.07,
		0.32 + float((hash_val >> 6) % 7) * 0.06,
		0.88
	)

func _apply_layout(modal_id: String, popup_layout: String) -> void:
	var layout: String = popup_layout
	if layout.is_empty():
		if modal_id.begins_with("panel_"):
			layout = "panel_rect"
		else:
			layout = "modal_full"
	if layout == "panel_rect":
		_modal_panel.offset_left = 36
		_modal_panel.offset_top = 430
		_modal_panel.offset_right = -36
		_modal_panel.offset_bottom = -210
		_modal_image.custom_minimum_size = Vector2(200, 180)
	else:
		_modal_panel.offset_left = 24
		_modal_panel.offset_top = 360
		_modal_panel.offset_right = -24
		_modal_panel.offset_bottom = -150
		_modal_image.custom_minimum_size = Vector2(200, 260)

func _on_dismiss_rect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _bubble_only:
			_bubble_panel.visible = false
			_dismiss_rect.visible = false
			_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bubble_only = false
			bubble_dismissed.emit(false)
		else:
			hide_all()
			bubble_dismissed.emit(true)

func _build_ui() -> void:
	_dismiss_rect = ColorRect.new()
	_dismiss_rect.name = "DismissRect"
	_dismiss_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dismiss_rect.color = Color(0, 0, 0, 0.01)
	_dismiss_rect.visible = false
	_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dismiss_rect.gui_input.connect(_on_dismiss_rect_input)
	add_child(_dismiss_rect)

	_modal_panel = PanelContainer.new()
	_modal_panel.name = "ModalPanel"
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_panel.offset_left = 24
	_modal_panel.offset_top = 360
	_modal_panel.offset_right = -24
	_modal_panel.offset_bottom = -150
	_modal_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.075, 0.16, 0.96), Color(0.86, 0.75, 0.46, 1), 1, 0))
	add_child(_modal_panel)

	var modal_margin := MarginContainer.new()
	modal_margin.add_theme_constant_override("margin_left", 12)
	modal_margin.add_theme_constant_override("margin_top", 12)
	modal_margin.add_theme_constant_override("margin_right", 12)
	modal_margin.add_theme_constant_override("margin_bottom", 12)
	_modal_panel.add_child(modal_margin)

	var modal_vbox := VBoxContainer.new()
	modal_vbox.add_theme_constant_override("separation", 8)
	modal_margin.add_child(modal_vbox)

	_modal_title = Label.new()
	_modal_title.text = "线索"
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1))
	_modal_title.add_theme_font_size_override("font_size", 18)
	modal_vbox.add_child(_modal_title)

	_modal_image = TextureRect.new()
	_modal_image.name = "ModalImage"
	_modal_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_modal_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_modal_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_image.custom_minimum_size = Vector2(200, 260)
	_modal_image.visible = false
	modal_vbox.add_child(_modal_image)

	_modal_placeholder = ColorRect.new()
	_modal_placeholder.name = "ModalPlaceholder"
	_modal_placeholder.custom_minimum_size = Vector2(200, 180)
	_modal_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_placeholder.visible = false
	modal_vbox.add_child(_modal_placeholder)

	_modal_body = Label.new()
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.add_theme_color_override("font_color", Color(0.84, 0.82, 0.9, 1))
	_modal_body.text = ""
	modal_vbox.add_child(_modal_body)

	_bubble_panel = PanelContainer.new()
	_bubble_panel.name = "BubblePanel"
	_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bubble_panel.offset_left = -170
	_bubble_panel.offset_top = -220
	_bubble_panel.offset_right = 170
	_bubble_panel.offset_bottom = -168
	_bubble_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.10, 0.18, 0.96), Color(0.93, 0.86, 0.66, 1), 1, 8))
	add_child(_bubble_panel)

	var bubble_margin := MarginContainer.new()
	bubble_margin.add_theme_constant_override("margin_left", 14)
	bubble_margin.add_theme_constant_override("margin_top", 10)
	bubble_margin.add_theme_constant_override("margin_right", 14)
	bubble_margin.add_theme_constant_override("margin_bottom", 10)
	_bubble_panel.add_child(bubble_margin)

	_bubble_label = Label.new()
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86, 1))
	_bubble_label.add_theme_font_size_override("font_size", 17)
	bubble_margin.add_child(_bubble_label)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "B"
	_close_button.custom_minimum_size = Vector2(34, 34)
	_close_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_close_button.offset_left = -58
	_close_button.offset_top = -214
	_close_button.offset_right = -24
	_close_button.offset_bottom = -180
	_close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_button.pressed.connect(_on_close_pressed)
	add_child(_close_button)
	_ignore_modal_content_mouse()

func _ignore_modal_content_mouse() -> void:
	_set_ignore_recursive(_modal_panel)
	_set_ignore_recursive(_bubble_panel)

func _set_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_ignore_recursive(child)

func _on_close_pressed() -> void:
	var closed_modal_id: String = _current_modal_id
	hide_all()
	popup_closed.emit(closed_modal_id)
	close_requested.emit()

func _panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style
