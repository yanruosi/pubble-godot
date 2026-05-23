## 槽位拖拽共享控件（词库芯片 / 填空格 / 词库回收区）

class SlotVocabChip extends PanelContainer:
	const DRAG_THRESHOLD := 8.0

	var vocab_id: String = ""
	var display_text: String = ""
	var owner_panel: Node = null
	var _press_pos: Vector2 = Vector2.ZERO
	var _dragging: bool = false

	func setup_chip(p_owner: Node, p_vocab_id: String, p_text: String) -> void:
		owner_panel = p_owner
		vocab_id = p_vocab_id
		display_text = p_text
		custom_minimum_size = Vector2(142, 42)
		add_theme_stylebox_override("panel", owner_panel.call("_drag_chip_style"))
		var label := Label.new()
		label.text = p_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08, 1))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_dragging = false
			elif not _dragging and owner_panel != null:
				owner_panel.call("_drag_select_vocab", vocab_id)
		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if _dragging or not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
				return
			if motion.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
				var preview := Label.new()
				preview.text = display_text
				preview.add_theme_font_size_override("font_size", 18)
				force_drag({"vocab_id": vocab_id, "from_row_id": ""}, preview)


class SlotBlankSlot extends PanelContainer:
	const DRAG_THRESHOLD := 8.0

	var row_id: String = ""
	var owner_panel: Node = null
	var _label: Label
	var _press_pos: Vector2 = Vector2.ZERO
	var _dragging: bool = false

	func setup_blank(p_owner: Node, p_row_id: String, min_size: Vector2 = Vector2(96, 36)) -> void:
		owner_panel = p_owner
		row_id = p_row_id
		custom_minimum_size = min_size
		add_theme_stylebox_override("panel", owner_panel.call("_drag_blank_style"))
		_label = Label.new()
		_label.name = "BlankLabel"
		_label.text = "______"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.add_theme_font_size_override("font_size", 18)
		_label.add_theme_color_override("font_color", Color(0.13, 0.11, 0.08, 1))
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)
		refresh_display()

	func refresh_display() -> void:
		if owner_panel == null or _label == null:
			return
		var vocab_id: String = owner_panel.call("_drag_get_row_vocab", row_id)
		if vocab_id.is_empty():
			_label.text = "______"
		else:
			_label.text = owner_panel.call("_drag_vocab_text", vocab_id)

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_dragging = false
			elif not _dragging and owner_panel != null:
				var filled: String = owner_panel.call("_drag_get_row_vocab", row_id)
				if filled.is_empty():
					owner_panel.call("_drag_fill_row_click", row_id)
				else:
					owner_panel.call("_drag_select_vocab", filled)
		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if _dragging or not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
				return
			var filled_id: String = owner_panel.call("_drag_get_row_vocab", row_id)
			if filled_id.is_empty():
				return
			if motion.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
				var preview := Label.new()
				preview.text = owner_panel.call("_drag_vocab_text", filled_id)
				preview.add_theme_font_size_override("font_size", 18)
				force_drag({"vocab_id": filled_id, "from_row_id": row_id}, preview)

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		if owner_panel == null:
			return false
		return owner_panel.call("_drag_can_drop_row", row_id, at_position, data)

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if owner_panel != null:
			owner_panel.call("_drag_drop_row", row_id, at_position, data)


class SlotVocabPoolZone extends PanelContainer:
	var owner_panel: Node = null

	func setup_pool(p_owner: Node) -> void:
		owner_panel = p_owner
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if owner_panel == null or not (data is Dictionary):
			return false
		var from_row: String = str((data as Dictionary).get("from_row_id", ""))
		return not from_row.is_empty()

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if owner_panel == null or not (data is Dictionary):
			return
		var from_row: String = str((data as Dictionary).get("from_row_id", ""))
		if from_row.is_empty():
			return
		owner_panel.call("_drag_clear_row", from_row)
