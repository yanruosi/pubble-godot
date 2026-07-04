## 槽位拖拽共享控件（词库芯片 / 填空格 / 词库回收区）

class SlotVocabChip extends PanelContainer:
	const DRAG_THRESHOLD := 8.0
	const LEGACY_CHIP_SIZE := Vector2(142, 42)
	const PSD_CHIP_SIZE := Vector2(133, 61)

	var vocab_id: String = ""
	var display_text: String = ""
	var tex_path: String = ""
	var owner_panel: Node = null
	var _press_pos: Vector2 = Vector2.ZERO
	var _press_active: bool = false
	var _dragging: bool = false
	var _font_size: int = 18

	static func _owner_has(owner: Node, method: String) -> bool:
		return owner != null and owner.has_method(method)

	static func _owner_call(owner: Node, method: String, args: Array = []):
		if _owner_has(owner, method):
			return owner.callv(method, args)
		return null

	static func _owner_call_bool(owner: Node, method: String, default: bool = false) -> bool:
		if _owner_has(owner, method):
			return owner.call(method)
		return default

	static func _owner_call_bool_args(owner: Node, method: String, args: Array, default: bool = false) -> bool:
		if _owner_has(owner, method):
			return owner.callv(method, args)
		return default

	func setup_chip(p_owner: Node, p_vocab_id: String, p_text: String, p_tex_path: String = "") -> void:
		owner_panel = p_owner
		vocab_id = p_vocab_id
		display_text = p_text
		tex_path = p_tex_path
		if p_tex_path.is_empty():
			custom_minimum_size = LEGACY_CHIP_SIZE
			_font_size = 18
			add_theme_stylebox_override("panel", owner_panel.call("_drag_chip_style"))
		else:
			custom_minimum_size = PSD_CHIP_SIZE
			size = PSD_CHIP_SIZE
			_font_size = _owner_call(owner_panel, "_chip_font_size_for_text", [p_text])
			if _font_size == null:
				_font_size = 28
			add_theme_stylebox_override("panel", _texture_style(p_tex_path))
		var label := Label.new()
		label.text = p_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_theme_font_size_override("font_size", _font_size)
		label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08, 1))
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)

	func _texture_style(p_tex_path: String) -> StyleBoxTexture:
		var style := StyleBoxTexture.new()
		style.texture = load(p_tex_path) as Texture2D
		style.set_content_margin_all(0)
		return style

	static func _invisible_drag_preview() -> Control:
		var preview := Control.new()
		preview.custom_minimum_size = Vector2(1, 1)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.modulate = Color(1, 1, 1, 0)
		return preview

	func _make_drag_preview() -> Control:
		return _invisible_drag_preview()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			_restore_drag_visual()
			_dragging = false
			_press_active = false
			_owner_call(owner_panel, "_end_vocab_drag")

	func _restore_drag_visual() -> void:
		modulate = Color.WHITE
		visible = true

	func _apply_drag_pickup_visual() -> void:
		modulate = Color(1, 1, 1, 0.2)
		visible = false

	func _can_start_drag_now() -> bool:
		if not _press_active or _dragging:
			return false
		if _owner_has(owner_panel, "_is_vocab_drag_active") and _owner_call_bool(owner_panel, "_is_vocab_drag_active"):
			return false
		if _owner_has(owner_panel, "_can_start_vocab_drag"):
			return _owner_call_bool_args(owner_panel, "_can_start_vocab_drag", [vocab_id])
		return true

	func _try_begin_owner_drag() -> bool:
		if _owner_has(owner_panel, "_begin_vocab_drag"):
			return _owner_call_bool_args(owner_panel, "_begin_vocab_drag", [vocab_id])
		return true

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_press_active = true
				_dragging = false
			elif owner_panel != null:
				_press_active = false
				if _dragging or _owner_call_bool(owner_panel, "_consume_vocab_drag_release"):
					return
				owner_panel.call("_drag_select_vocab", vocab_id)
		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if not _press_active or _dragging or not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
				return
			if not _can_start_drag_now():
				return
			if motion.position.distance_to(_press_pos) <= DRAG_THRESHOLD:
				return
			_dragging = true
			if not _try_begin_owner_drag():
				_dragging = false
				return
			_apply_drag_pickup_visual()
			_owner_call(owner_panel, "_show_drag_ghost", [vocab_id, _press_pos, PSD_CHIP_SIZE, tex_path])
			#region agent log
			_owner_call(owner_panel, "_debug_chip_drag_start", [vocab_id, "pool"])
			#endregion
			force_drag({"vocab_id": vocab_id, "from_row_id": ""}, _make_drag_preview())


class SlotBlankSlot extends PanelContainer:
	const DRAG_THRESHOLD := 8.0

	var row_id: String = ""
	var filter_tag: String = ""
	var owner_panel: Node = null
	var _label: Label
	var _press_pos: Vector2 = Vector2.ZERO
	var _press_active: bool = false
	var _dragging: bool = false
	var _font_size: int = 18
	var _use_texture_bg: bool = false
	var _min_size: Vector2 = Vector2(96, 36)

	func setup_blank(
		p_owner: Node,
		p_row_id: String,
		p_filter_tag_or_size,
		min_size: Vector2 = Vector2(96, 36),
		blank_font_size: int = 28
	) -> void:
		owner_panel = p_owner
		row_id = p_row_id
		if p_filter_tag_or_size is Vector2:
			custom_minimum_size = p_filter_tag_or_size as Vector2
			size = custom_minimum_size
			filter_tag = ""
			_use_texture_bg = false
			_font_size = 18
			add_theme_stylebox_override("panel", owner_panel.call("_drag_blank_style"))
		else:
			filter_tag = str(p_filter_tag_or_size)
			_min_size = min_size
			custom_minimum_size = min_size
			size = min_size
			_use_texture_bg = true
			_font_size = blank_font_size
			_apply_blank_texture()
		_label = Label.new()
		_label.name = "BlankLabel"
		_label.text = "" if _use_texture_bg else "______"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.add_theme_font_size_override("font_size", _font_size)
		_label.add_theme_color_override("font_color", Color(0.13, 0.11, 0.08, 1))
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gui_input.connect(_on_gui_input)
		refresh_display()

	func _apply_blank_texture() -> void:
		if owner_panel == null:
			return
		if not SlotVocabChip._owner_has(owner_panel, "_chip_texture_for_filter_tag"):
			return
		var tex_path: String = owner_panel.call("_chip_texture_for_filter_tag", filter_tag)
		var style := StyleBoxTexture.new()
		style.texture = load(tex_path) as Texture2D
		style.set_content_margin_all(0)
		add_theme_stylebox_override("panel", style)

	func refresh_display() -> void:
		if owner_panel == null or _label == null:
			return
		var vocab_id: String = owner_panel.call("_drag_get_row_vocab", row_id)
		if vocab_id.is_empty():
			_label.text = "" if _use_texture_bg else "______"
			_label.add_theme_font_size_override("font_size", _font_size)
			if _use_texture_bg:
				custom_minimum_size = _min_size
				size = _min_size
		else:
			var text: String = owner_panel.call("_drag_vocab_text", vocab_id)
			_label.text = text
			if _use_texture_bg:
				if SlotVocabChip._owner_has(owner_panel, "_chip_font_size_for_text"):
					_label.add_theme_font_size_override("font_size", owner_panel.call("_chip_font_size_for_text", text))
				var target_w: float = owner_panel.call("_mystery_blank_width_for_text", text)
				custom_minimum_size = Vector2(target_w, _min_size.y)
				size = custom_minimum_size

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			modulate = Color.WHITE
			visible = true
			_dragging = false
			_press_active = false
			SlotVocabChip._owner_call(owner_panel, "_end_vocab_drag")

	func _on_gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_press_active = true
				_dragging = false
			elif owner_panel != null:
				_press_active = false
				if _dragging or SlotVocabChip._owner_call_bool(owner_panel, "_consume_vocab_drag_release"):
					return
				var filled: String = owner_panel.call("_drag_get_row_vocab", row_id)
				if filled.is_empty():
					owner_panel.call("_drag_fill_row_click", row_id)
				else:
					owner_panel.call("_drag_select_vocab", filled)
		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if not _press_active or _dragging or not (motion.button_mask & MOUSE_BUTTON_MASK_LEFT):
				return
			var filled_id: String = owner_panel.call("_drag_get_row_vocab", row_id)
			if filled_id.is_empty():
				return
			if SlotVocabChip._owner_has(owner_panel, "_is_vocab_drag_active") and SlotVocabChip._owner_call_bool(owner_panel, "_is_vocab_drag_active"):
				return
			if SlotVocabChip._owner_has(owner_panel, "_can_start_vocab_drag") and not SlotVocabChip._owner_call_bool_args(owner_panel, "_can_start_vocab_drag", [filled_id]):
				return
			if motion.position.distance_to(_press_pos) <= DRAG_THRESHOLD:
				return
			_dragging = true
			var accepted := true
			if SlotVocabChip._owner_has(owner_panel, "_begin_vocab_drag"):
				accepted = SlotVocabChip._owner_call_bool_args(owner_panel, "_begin_vocab_drag", [filled_id])
			if not accepted:
				_dragging = false
				return
			modulate = Color(1, 1, 1, 0.2)
			visible = false
			var tex_path: String = ""
			if SlotVocabChip._owner_has(owner_panel, "_chip_texture_for_vocab"):
				tex_path = str(owner_panel.call("_chip_texture_for_vocab", filled_id))
			SlotVocabChip._owner_call(owner_panel, "_show_drag_ghost", [filled_id, _press_pos, size, tex_path])
			#region agent log
			SlotVocabChip._owner_call(owner_panel, "_debug_chip_drag_start", [filled_id, row_id])
			#endregion
			force_drag({"vocab_id": filled_id, "from_row_id": row_id}, SlotVocabChip._invisible_drag_preview())

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		if owner_panel == null:
			return false
		return owner_panel.call("_drag_can_drop_row", row_id, at_position, data)

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		if owner_panel != null:
			owner_panel.call("_drag_drop_row", row_id, at_position, data)


class SlotVocabPoolZone extends Control:
	var owner_panel: Node = null

	func setup_pool(p_owner: Node) -> void:
		owner_panel = p_owner
		mouse_filter = Control.MOUSE_FILTER_STOP

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
