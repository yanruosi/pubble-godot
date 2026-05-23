extends Control
class_name IdolBottomBar

signal slot_pressed(slot_id: String)

var _bar: PanelContainer
var _slot_buttons: Dictionary = {}
var _slot_base_labels: Dictionary = {}
var _completed_slots: Dictionary = {}
var _progress_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_build_ui()

func setup(vocab_total: int) -> void:
	_completed_slots.clear()
	update_progress(0, vocab_total)
	set_slot_unlocked("slot1", true)
	set_slot_unlocked("slot2", false)
	set_slot_unlocked("slot3", false)
	for slot_id in _slot_buttons.keys():
		_update_slot_text(str(slot_id))

func update_progress(collected_count: int, vocab_total: int) -> void:
	if _progress_label != null:
		_progress_label.text = "%d/%d" % [collected_count, vocab_total]

func set_slot_unlocked(slot_id: String, unlocked: bool) -> void:
	var btn: Button = _slot_buttons.get(slot_id, null)
	if btn == null:
		return
	btn.disabled = not unlocked
	if slot_id == "slot3":
		_slot_base_labels[slot_id] = "票" if unlocked else "?"
	if unlocked:
		btn.modulate = Color(1, 1, 1, 1)
	else:
		btn.modulate = Color(0.55, 0.55, 0.65, 0.82)
	_update_slot_text(slot_id)

func set_slot_completed(slot_id: String, completed: bool) -> void:
	_completed_slots[slot_id] = completed
	_update_slot_text(slot_id)

func set_active_slot(slot_id: String) -> void:
	for key in _slot_buttons.keys():
		var btn: Button = _slot_buttons[key]
		btn.button_pressed = key == slot_id

func _build_ui() -> void:
	_bar = PanelContainer.new()
	_bar.name = "BottomBarPanel"
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_left = 14
	_bar.offset_top = -108
	_bar.offset_right = -14
	_bar.offset_bottom = -20
	_bar.add_theme_stylebox_override("panel", _panel_style())
	add_child(_bar)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 18)
	_bar.add_child(hbox)

	_add_slot_button(hbox, "slot1", "书")
	_add_slot_button(hbox, "slot2", "镜")
	_add_slot_button(hbox, "slot3", "?")

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(14, 1)
	hbox.add_child(spacer)

	var progress_panel := PanelContainer.new()
	progress_panel.custom_minimum_size = Vector2(72, 72)
	progress_panel.add_theme_stylebox_override("panel", _progress_style())
	hbox.add_child(progress_panel)

	var progress_vbox := VBoxContainer.new()
	progress_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_vbox.add_theme_constant_override("separation", 0)
	progress_panel.add_child(progress_vbox)

	var icon_label := Label.new()
	icon_label.text = "词"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_color_override("font_color", Color(0.92, 0.84, 0.42, 1))
	icon_label.add_theme_font_size_override("font_size", 20)
	progress_vbox.add_child(icon_label)

	_progress_label = Label.new()
	_progress_label.text = "0/5"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.66, 1))
	_progress_label.add_theme_font_size_override("font_size", 16)
	progress_vbox.add_child(_progress_label)

func _add_slot_button(parent: Control, slot_id: String, label: String) -> void:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(64, 64)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(0.88, 0.82, 0.64, 1))
	btn.pressed.connect(func() -> void:
		slot_pressed.emit(slot_id)
	)
	_slot_buttons[slot_id] = btn
	_slot_base_labels[slot_id] = label
	parent.add_child(btn)

func _update_slot_text(slot_id: String) -> void:
	var btn: Button = _slot_buttons.get(slot_id, null)
	if btn == null:
		return
	var text: String = str(_slot_base_labels.get(slot_id, btn.text))
	if bool(_completed_slots.get(slot_id, false)):
		text += "✓"
	btn.text = text

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.13, 0.94)
	style.border_color = Color(0.86, 0.75, 0.46, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _progress_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.13, 0.22, 1)
	style.border_color = Color(0.77, 0.66, 0.34, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style
