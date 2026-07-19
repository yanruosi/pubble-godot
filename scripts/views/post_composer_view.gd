extends RefCounted
class_name PostComposerView

signal publish_requested(tagid: String, mypostid: String)
signal tag_selected(tagid: String)

var root: PanelContainer
var _input: TextEdit
var _tag_row: HBoxContainer
var _publish_btn: Button
var _tag_buttons: Dictionary = {}
var _selected_tagid: String = ""
var _preview_mypostid: String = ""


func build(parent: Control) -> void:
	root = PanelContainer.new()
	root.name = "PostArea"
	root.position = FeedDefs.P4_COMPOSE_RECT.position
	root.custom_minimum_size = FeedDefs.P4_COMPOSE_RECT.size
	root.size = FeedDefs.P4_COMPOSE_RECT.size
	root.visible = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.92)
	ps.corner_radius_top_left = 6
	ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6
	ps.corner_radius_bottom_right = 6
	root.add_theme_stylebox_override("panel", ps)
	parent.add_child(root)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	_input = TextEdit.new()
	_input.name = "ComposeInput"
	_input.placeholder_text = "选择标签后预览帖子内容..."
	_input.editable = false
	_input.focus_mode = Control.FOCUS_NONE
	_input.custom_minimum_size = Vector2(0, 72)
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(_input)
	_tag_row = HBoxContainer.new()
	_tag_row.add_theme_constant_override("separation", 6)
	vbox.add_child(_tag_row)
	_publish_btn = Button.new()
	_publish_btn.text = "发布"
	_publish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_publish_btn.disabled = true
	_publish_btn.pressed.connect(_on_publish)
	vbox.add_child(_publish_btn)


func set_visible_for_tab(active_tab: String) -> void:
	if root != null:
		root.visible = active_tab == FeedDefs.TAB_ACCOUNT


func refresh_tags(tags: Array, expose: ExposeManager) -> void:
	if _tag_row == null or _publish_btn == null or expose == null:
		return
	for c in _tag_row.get_children():
		c.queue_free()
	_tag_buttons.clear()
	_tag_row.visible = not tags.is_empty()
	var has_selected := false
	for item in tags:
		if not (item is Dictionary):
			continue
		var tag: Dictionary = item
		var tagid: String = str(tag.get("tagid", ""))
		if tagid.is_empty():
			continue
		var btn := Button.new()
		btn.text = "%s(%d)" % [str(tag.get("name", tagid)), int(tag.get("count", 0))]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void: _on_tag(tagid, expose))
		_tag_row.add_child(btn)
		_tag_buttons[tagid] = btn
		if tagid == _selected_tagid:
			has_selected = true
	if tags.is_empty():
		_clear_preview("发帖次数不足，请参加线下活动")
		return
	if not has_selected:
		_clear_preview("选择标签后预览帖子内容...")
	_publish_btn.disabled = _preview_mypostid.is_empty()


func reset_after_publish() -> void:
	_selected_tagid = ""
	_preview_mypostid = ""
	if _input != null:
		_input.text = ""


func _on_tag(tagid: String, expose: ExposeManager) -> void:
	if expose == null or tagid.is_empty():
		return
	_selected_tagid = tagid
	var preview: Dictionary = expose.preview_tag_post(tagid)
	_preview_mypostid = str(preview.get("mypostid", ""))
	if _input != null:
		if _preview_mypostid.is_empty():
			_input.text = ""
		else:
			_input.text = "%s\n\n%s" % [str(preview.get("title", "")), str(preview.get("text", ""))]
	for tid: String in _tag_buttons.keys():
		var btn: Button = _tag_buttons[tid]
		btn.add_theme_color_override("font_color", Color(0.35, 0.18, 0.55, 1) if tid == tagid else Color(0.45, 0.42, 0.52, 1))
	_publish_btn.disabled = _preview_mypostid.is_empty()
	tag_selected.emit(tagid)


func _on_publish() -> void:
	publish_requested.emit(_selected_tagid, _preview_mypostid)


func _clear_preview(placeholder: String) -> void:
	_selected_tagid = ""
	_preview_mypostid = ""
	if _input != null:
		_input.text = ""
		_input.placeholder_text = placeholder
	_publish_btn.disabled = true
