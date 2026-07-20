extends RefCounted
class_name PostComposerView

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const ComposerSkin := preload("res://scripts/views/post_composer_skin.gd")

signal publish_requested(tagid: String, mypostid: String)
signal tag_selected(tagid: String)
signal tag_blocked(tagid: String)

var root: Control
var _input: TextEdit
var _tag_row: HBoxContainer
var _publish_btn: Button
var _tag_buttons: Dictionary = {}
var _tag_counts: Dictionary = {}
var _selected_tagid: String = ""
var _preview_mypostid: String = ""
var _locked_preview: String = ""


func build(parent: Control) -> void:
	var rect: Rect2 = FeedDefs.P4_COMPOSE_RECT
	root = Control.new()
	root.name = "PostArea"
	root.position = rect.position
	root.custom_minimum_size = rect.size
	root.size = rect.size
	root.clip_contents = true
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var outer := Panel.new()
	outer.name = "OuterP1"
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ComposerSkin.apply_outer_bg(outer)
	root.add_child(outer)
	var preview_panel := Panel.new()
	preview_panel.name = "PreviewP2"
	preview_panel.position = FeedDefs.P4_COMPOSE_INPUT_LOCAL.position
	preview_panel.size = FeedDefs.P4_COMPOSE_INPUT_LOCAL.size
	preview_panel.custom_minimum_size = FeedDefs.P4_COMPOSE_INPUT_LOCAL.size
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ComposerSkin.apply_preview_bg(preview_panel)
	root.add_child(preview_panel)
	_input = TextEdit.new()
	_input.name = "ComposeInput"
	_input.placeholder_text = "点击输入..."
	_input.editable = true
	_input.focus_mode = Control.FOCUS_NONE
	_input.context_menu_enabled = false
	_input.shortcut_keys_enabled = false
	_input.selecting_enabled = false
	_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_input.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input.offset_left = 4
	_input.offset_top = 2
	_input.offset_right = -4
	_input.offset_bottom = -2
	_input.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ComposerSkin.style_input(_input)
	_input.text_changed.connect(_on_preview_text_changed)
	preview_panel.add_child(_input)
	_tag_row = HBoxContainer.new()
	_tag_row.name = "TagRowP3"
	_tag_row.position = FeedDefs.P4_COMPOSE_TAGS_LOCAL.position
	_tag_row.size = FeedDefs.P4_COMPOSE_TAGS_LOCAL.size
	_tag_row.custom_minimum_size = FeedDefs.P4_COMPOSE_TAGS_LOCAL.size
	_tag_row.add_theme_constant_override("separation", 14)
	_tag_row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(_tag_row)
	_publish_btn = Button.new()
	_publish_btn.name = "SendBtnP4"
	_publish_btn.text = "发送"
	_publish_btn.position = FeedDefs.P4_COMPOSE_SEND_LOCAL.position
	_publish_btn.size = FeedDefs.P4_COMPOSE_SEND_LOCAL.size
	_publish_btn.custom_minimum_size = FeedDefs.P4_COMPOSE_SEND_LOCAL.size
	_publish_btn.disabled = true
	_publish_btn.focus_mode = Control.FOCUS_NONE
	_publish_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ComposerSkin.style_send_button(_publish_btn)
	_publish_btn.pressed.connect(_on_publish)
	root.add_child(_publish_btn)


func set_visible_for_tab(active_tab: String) -> void:
	if root != null:
		root.visible = active_tab == FeedDefs.TAB_ACCOUNT


func refresh_tags(tags: Array, expose: ExposeManager) -> void:
	if _tag_row == null or _publish_btn == null:
		return
	for c in _tag_row.get_children():
		c.queue_free()
	_tag_buttons.clear()
	_tag_counts.clear()
	_tag_row.visible = not tags.is_empty()
	var has_selected := false
	var has_usable := false
	for item in tags:
		if not (item is Dictionary):
			continue
		var tag: Dictionary = item
		var tagid: String = str(tag.get("tagid", ""))
		if tagid.is_empty():
			continue
		var count: int = int(tag.get("count", 0))
		var enabled := count > 0
		if enabled:
			has_usable = true
		var btn := Button.new()
		btn.text = str(tag.get("name", tagid))
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void: _on_tag(tagid, enabled, expose))
		ComposerSkin.style_tag_button(btn, tagid == _selected_tagid, enabled)
		_tag_row.add_child(btn)
		_tag_buttons[tagid] = btn
		_tag_counts[tagid] = count
		if tagid == _selected_tagid and enabled:
			has_selected = true
	if tags.is_empty():
		_clear_preview("暂无可用标签")
		return
	if not has_usable:
		_clear_preview("去参加线下活动获得次数")
	if not has_selected:
		_clear_preview("点击输入...")
	_publish_btn.disabled = _preview_mypostid.is_empty()


func reset_after_publish() -> void:
	_selected_tagid = ""
	_preview_mypostid = ""
	_locked_preview = ""
	if _input != null:
		_input.text = ""


func _on_tag(tagid: String, enabled: bool, expose: ExposeManager) -> void:
	if not enabled:
		tag_blocked.emit(tagid)
		return
	if expose == null or tagid.is_empty():
		return
	_selected_tagid = tagid
	var preview: Dictionary = expose.preview_tag_post(tagid)
	_preview_mypostid = str(preview.get("mypostid", ""))
	if _input != null:
		if _preview_mypostid.is_empty():
			_set_preview_text("")
		else:
			_set_preview_text(ComposerSkin.format_preview_text(
				str(preview.get("title", "")),
				str(preview.get("text", ""))
			))
	ComposerSkin.style_input(_input)
	for tid: String in _tag_buttons.keys():
		var btn: Button = _tag_buttons[tid]
		ComposerSkin.style_tag_button(btn, tid == tagid, int(_tag_counts.get(tid, 0)) > 0)
	_publish_btn.disabled = _preview_mypostid.is_empty()
	tag_selected.emit(tagid)


func _on_publish() -> void:
	publish_requested.emit(_selected_tagid, _preview_mypostid)


func _clear_preview(placeholder: String) -> void:
	_selected_tagid = ""
	_preview_mypostid = ""
	if _input != null:
		_set_preview_text("")
		_input.placeholder_text = placeholder
		ComposerSkin.style_input(_input)
	_publish_btn.disabled = true


func _set_preview_text(text: String) -> void:
	_locked_preview = text
	if _input != null:
		_input.text = text


func _on_preview_text_changed() -> void:
	if _input != null and _input.text != _locked_preview:
		_input.text = _locked_preview
