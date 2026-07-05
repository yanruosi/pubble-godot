extends Control
class_name IdentitySlotPanel

const SlotDrag := preload("res://scripts/idol_level/slot_drag_widgets.gd")

## PSD 槽位2 身份面板
const TEX_IDENTITY_BG := "res://art/mainui/level/caowei2bg.png"
const TEX_PORTRAIT_LEO := "res://art/mainui/level/caowei2tx1.png"
const TEX_PORTRAIT_MAY := "res://art/mainui/level/caowei2tx2.png"

const IDENTITY_BG_RECT := Rect2(150, 154, 540, 263)
const PORTRAIT_LEO_RECT := Rect2(270, 205, 91, 92)
const PORTRAIT_MAY_RECT := Rect2(442, 205, 88, 92)
const BLANK_LEO_RECT := Rect2(249, 299, 133, 61)
const BLANK_MAY_RECT := Rect2(419, 299, 133, 61)
const STATUS_RECT := Rect2(479, 378, 162, 45)
const STATUS_FONT_SIZE := 27
const BLANK_FONT_SIZE := 28

const STATUS_INCOMPLETE := "信息尚未填写完整"
const STATUS_CORRECT := "信息填写正确"
const STATUS_INCORRECT := "信息填写不正确"

signal completed
signal closed

var _dim: ColorRect
var _vocab_drag_vocab_id: String = ""
var _vocab_drag_release_block: bool = false
var _rows: Array = []
var _vocab_bank: VocabBank
var _fills: Dictionary = {}
var _blank_slots: Dictionary = {}
var _vocab_chip_layer: Control
var _vocab_pool_zone: SlotDrag.SlotVocabPoolZone
var _status_label: Label
var _status_host: Control
var _selected_vocab_id: String = ""
var _unlock_events: Dictionary = {}
var _active_rows: Array = []
var _drag_overlay: CanvasLayer
var _drag_ghost: Control
var _drag_grab_offset := Vector2.ZERO
var _drag_ghost_log_timer := 0.0
var _pool_vocab_order: Array[String] = []
var _identity_layer: Control

func _ready() -> void:
	z_index = 240
	_build_ui()
	_set_panel_active(false)
	set_process(false)

func setup(slots: Array, vocab_bank: VocabBank) -> void:
	_rows.clear()
	_fills.clear()
	_blank_slots.clear()
	_selected_vocab_id = ""
	_pool_vocab_order.clear()
	_vocab_bank = vocab_bank
	for item in slots:
		if not (item is Dictionary):
			continue
		var row: Dictionary = (item as Dictionary).duplicate(true)
		if str(row.get("slot_type", "")) == "identity":
			_rows.append(row)
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	if _vocab_bank != null and not _vocab_bank.changed.is_connected(_on_vocab_bank_changed):
		_vocab_bank.changed.connect(_on_vocab_bank_changed)
	_render_identity_slots()
	_refresh_vocab_chips()

func open_panel() -> void:
	_set_panel_active(true)
	_render_identity_slots()
	_refresh_vocab_chips()
	_refresh_all_blanks()
	_update_status_text()
	_bring_status_to_front()
	#region agent log
	_log_identity_layout("open_panel")
	#endregion

func close_panel(emit_signal := true) -> void:
	_set_panel_active(false)
	if emit_signal:
		closed.emit()

func get_fills() -> Dictionary:
	return _fills.duplicate(true)

func restore_fills(fills: Dictionary) -> void:
	_fills = fills.duplicate(true)
	for vocab_id in _fills.values():
		var vid: String = str(vocab_id)
		if not vid.is_empty():
			_pool_vocab_order.erase(vid)
	_refresh_all_blanks()
	_refresh_vocab_chips()
	_update_status_text()

func _set_panel_active(active: bool) -> void:
	visible = active
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	set_process_input(active)

func _status_label_rect() -> Rect2:
	return STATUS_RECT

func _status_text_width(text: String) -> float:
	var font := _status_label.get_theme_font("font") if _status_label != null else ThemeDB.fallback_font
	var font_size := _status_label.get_theme_font_size("font_size") if _status_label != null else STATUS_FONT_SIZE
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

func _build_ui() -> void:
	_dim = SlotPanelLayout.make_scene_mask()
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	var identity_bg := TextureRect.new()
	identity_bg.name = "IdentityBg"
	identity_bg.texture = load(TEX_IDENTITY_BG) as Texture2D
	identity_bg.position = IDENTITY_BG_RECT.position
	identity_bg.size = IDENTITY_BG_RECT.size
	identity_bg.stretch_mode = TextureRect.STRETCH_SCALE
	identity_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(identity_bg)

	var word_bg := TextureRect.new()
	word_bg.name = "WordBg"
	word_bg.texture = load(SlotPanelLayout.TEX_WORD_BG) as Texture2D
	word_bg.position = SlotPanelLayout.WORD_BG_RECT.position
	word_bg.size = SlotPanelLayout.WORD_BG_RECT.size
	word_bg.stretch_mode = TextureRect.STRETCH_SCALE
	word_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(word_bg)

	_identity_layer = Control.new()
	_identity_layer.name = "IdentityLayer"
	_identity_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_identity_layer)

	_vocab_pool_zone = SlotDrag.SlotVocabPoolZone.new()
	_vocab_pool_zone.name = "PoolZone"
	_vocab_pool_zone.setup_pool(self)
	_vocab_pool_zone.position = SlotPanelLayout.CHIP_GRID_ORIGIN
	var pool_w: float = SlotPanelLayout.CHIP_COLS * SlotPanelLayout.CHIP_SIZE.x + (SlotPanelLayout.CHIP_COLS - 1) * SlotPanelLayout.CHIP_H_SEP
	var pool_h: float = SlotPanelLayout.WORD_BG_RECT.position.y + SlotPanelLayout.WORD_BG_RECT.size.y - SlotPanelLayout.CHIP_GRID_ORIGIN.y
	_vocab_pool_zone.size = Vector2(pool_w, pool_h)
	add_child(_vocab_pool_zone)

	_vocab_chip_layer = Control.new()
	_vocab_chip_layer.name = "VocabChipLayer"
	_vocab_chip_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vocab_chip_layer)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = STATUS_INCOMPLETE
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.29, 0.35, 0.42, 1))
	_status_label.add_theme_font_size_override("font_size", STATUS_FONT_SIZE)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status_label.clip_text = true
	_status_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_label.offset_right = 0
	_status_label.offset_bottom = 0
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var status_host := Control.new()
	status_host.name = "StatusHost"
	status_host.position = STATUS_RECT.position
	status_host.custom_minimum_size = STATUS_RECT.size
	status_host.size = STATUS_RECT.size
	status_host.clip_contents = true
	status_host.z_index = 30
	status_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_host.add_child(_status_label)
	_status_host = status_host
	add_child(status_host)

	_drag_overlay = CanvasLayer.new()
	_drag_overlay.name = "DragOverlay"
	_drag_overlay.layer = SlotPanelLayout.DRAG_OVERLAY_LAYER
	add_child(_drag_overlay)

func _process(_delta: float) -> void:
	if _drag_ghost == null:
		return
	var mouse_global := get_viewport().get_mouse_position()
	_drag_ghost.global_position = mouse_global - _drag_grab_offset
	_drag_ghost_log_timer += _delta
	if _drag_ghost_log_timer < 0.15:
		return
	_drag_ghost_log_timer = 0.0

func _on_dim_gui_input(event: InputEvent) -> void:
	_try_dismiss_on_outside_click(event, "dim")

func _input(event: InputEvent) -> void:
	_try_dismiss_on_outside_click(event, "input")

func _try_dismiss_on_outside_click(event: InputEvent, source: String) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var local_pos := get_local_mouse_position()
	if SlotPanelLayout.should_keep_open_on_click(local_pos, IDENTITY_BG_RECT):
		return
	close_panel()
	if source == "dim":
		_dim.accept_event()
	else:
		get_viewport().set_input_as_handled()

func _render_identity_slots() -> void:
	if _identity_layer == null:
		return
	for child in _identity_layer.get_children():
		_identity_layer.remove_child(child)
		child.free()
	_blank_slots.clear()
	_active_rows.clear()
	for row in _rows:
		var row_id: String = str(row.get("row_id", ""))
		if row_id.is_empty():
			continue
		var unlocked: bool = _is_row_unlocked(row)
		#region agent log
		_debug_write("row_unlock_state", {
			"runId": "slot2-may-fix",
			"hypothesisId": "H2",
			"row_id": row_id,
			"unlocked": unlocked,
			"unlock_condition": str(row.get("unlock_condition", "")),
			"answer_vocab": str(row.get("answer_vocab", "")),
			"has_answer_vocab": _vocab_bank != null and _vocab_bank.has_vocab(str(row.get("answer_vocab", ""))),
			"event_unlocked": bool(_unlock_events.get(str(row.get("unlock_condition", "")), false))
		})
		#endregion
		if unlocked:
			_active_rows.append(row)
		var portrait_rect: Rect2 = _portrait_rect_for_row(row_id)
		var blank_rect: Rect2 = _blank_rect_for_row(row_id)
		var portrait_tex: String = _portrait_texture_for_row(row_id)
		if portrait_tex.is_empty() or portrait_rect.size == Vector2.ZERO:
			continue
		var portrait_host := Control.new()
		portrait_host.name = "PortraitHost_%s" % row_id
		portrait_host.position = portrait_rect.position
		portrait_host.custom_minimum_size = portrait_rect.size
		portrait_host.size = portrait_rect.size
		portrait_host.clip_contents = true
		portrait_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var portrait := TextureRect.new()
		portrait.name = "PortraitTex"
		portrait.texture = load(portrait_tex) as Texture2D
		portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait.offset_right = 0
		portrait.offset_bottom = 0
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_host.add_child(portrait)
		_identity_layer.add_child(portrait_host)
		var blank_host := Control.new()
		blank_host.name = "BlankHost_%s" % row_id
		blank_host.position = blank_rect.position
		blank_host.size = blank_rect.size
		blank_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_identity_layer.add_child(blank_host)
		var blank := SlotDrag.SlotBlankSlot.new()
		blank.setup_blank(self, row_id, "name", blank_rect.size, BLANK_FONT_SIZE)
		if not unlocked:
			blank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			blank.modulate = Color(1, 1, 1, 0.55)
		blank_host.add_child(blank)
		_blank_slots[row_id] = blank
	_bring_status_to_front()
	_update_status_text()

func _bring_status_to_front() -> void:
	if _status_host == null or _status_host.get_parent() != self:
		return
	move_child(_status_host, get_child_count() - 1)

func _portrait_rect_for_row(row_id: String) -> Rect2:
	match row_id:
		"portrait_left":
			return PORTRAIT_LEO_RECT
		"portrait_right":
			return PORTRAIT_MAY_RECT
		_:
			return Rect2()

func _blank_rect_for_row(row_id: String) -> Rect2:
	match row_id:
		"portrait_left":
			return BLANK_LEO_RECT
		"portrait_right":
			return BLANK_MAY_RECT
		_:
			return Rect2()

func _portrait_texture_for_row(row_id: String) -> String:
	match row_id:
		"portrait_left":
			return TEX_PORTRAIT_LEO
		"portrait_right":
			return TEX_PORTRAIT_MAY
		_:
			return ""

func _sync_pool_vocab_order() -> void:
	if _vocab_bank == null:
		return
	var kept: Array[String] = []
	for vocab_id in _pool_vocab_order:
		if _vocab_bank.has_vocab(vocab_id):
			kept.append(vocab_id)
	_pool_vocab_order = kept
	for vocab in _vocab_bank.get_collected_vocab("name"):
		var vocab_id: String = str(vocab.get("vocab_id", ""))
		if vocab_id.is_empty() or _pool_vocab_order.has(vocab_id):
			continue
		_pool_vocab_order.append(vocab_id)

func _append_pool_vocab(vocab_id: String) -> void:
	if vocab_id.is_empty():
		return
	_pool_vocab_order.erase(vocab_id)
	_pool_vocab_order.append(vocab_id)

func _refresh_vocab_chips() -> void:
	if _vocab_chip_layer == null:
		return
	for child in _vocab_chip_layer.get_children():
		child.queue_free()
	if _vocab_bank == null:
		return
	_sync_pool_vocab_order()
	var slot_index := 0
	for vocab_id in _pool_vocab_order:
		if _is_vocab_placed(vocab_id):
			continue
		var vocab: Dictionary = _vocab_bank.get_vocab(vocab_id)
		if vocab.is_empty():
			continue
		var tex_path: String = _chip_texture_for_vocab(vocab_id)
		var chip := SlotDrag.SlotVocabChip.new()
		chip.setup_chip(self, vocab_id, str(vocab.get("text", vocab_id)), tex_path)
		var slot_pos: Vector2 = SlotPanelLayout.chip_slot_position(slot_index)
		chip.position = slot_pos
		chip.size = SlotPanelLayout.CHIP_SIZE
		if vocab_id == _selected_vocab_id:
			chip.modulate = Color(0.82, 0.95, 1.0, 1)
		_vocab_chip_layer.add_child(chip)
		slot_index += 1

func _refresh_all_blanks() -> void:
	for row_id in _blank_slots.keys():
		var blank: SlotDrag.SlotBlankSlot = _blank_slots[row_id]
		if blank != null:
			blank.refresh_display()

func _update_status_text() -> void:
	if _status_label == null:
		return
	if _active_rows.is_empty():
		_status_label.text = STATUS_INCOMPLETE
		return
	var empty_count := 0
	var wrong_count := 0
	for row in _active_rows:
		var row_id: String = str(row.get("row_id", ""))
		var answer: String = str(row.get("answer_vocab", ""))
		var filled: String = str(_fills.get(row_id, ""))
		if filled.is_empty():
			empty_count += 1
		elif filled != answer:
			wrong_count += 1
	if empty_count > 0:
		_status_label.text = STATUS_INCOMPLETE
	elif wrong_count > 0:
		_status_label.text = STATUS_INCORRECT
	else:
		_status_label.text = STATUS_CORRECT

func _log_identity_layout(source: String) -> void:
	var portraits: Array = []
	if _identity_layer != null:
		for child in _identity_layer.get_children():
			if child.name.begins_with("PortraitHost_"):
				var p := child as Control
				portraits.append({
					"name": p.name,
					"pos": [p.position.x, p.position.y],
					"size": [p.size.x, p.size.y]
				})
	#region agent log
	var status_rect := _status_label_rect()
	var bg_tex := load(TEX_IDENTITY_BG) as Texture2D
	var bg_native := bg_tex.get_size() if bg_tex != null else Vector2.ZERO
	_debug_write("identity_layout", {
		"runId": "status-align-diagnosis",
		"hypothesisId": "H1-H4",
		"source": source,
		"bg_native_size": [bg_native.x, bg_native.y],
		"bg_code_size": [IDENTITY_BG_RECT.size.x, IDENTITY_BG_RECT.size.y],
		"bg_stretch_y_ratio": IDENTITY_BG_RECT.size.y / maxf(bg_native.y, 1.0),
		"portraits": portraits,
		"blank_count": _blank_slots.size(),
		"active_rows": _active_rows.size(),
		"status_text": _status_label.text if _status_label != null else "",
		"status_rect_psd": [STATUS_RECT.position.x, STATUS_RECT.position.y, STATUS_RECT.size.x, STATUS_RECT.size.y],
		"status_rect_runtime": [status_rect.position.x, status_rect.position.y, status_rect.size.x, status_rect.size.y],
		"status_text_width": _status_text_width(_status_label.text if _status_label != null else ""),
		"status_psd_box_height": STATUS_RECT.size.y,
		"identity_bg_bottom": IDENTITY_BG_RECT.position.y + IDENTITY_BG_RECT.size.y,
		"status_box_bottom": status_rect.position.y + status_rect.size.y,
		"status_font_size": _status_label.get_theme_font_size("font_size") if _status_label != null else -1,
		"status_autowrap": _status_label.autowrap_mode if _status_label != null else -1,
		"status_z": _status_label.z_index if _status_label != null else -1
	})
	#endregion

func _chip_texture_for_vocab(vocab_id: String) -> String:
	if _vocab_bank == null:
		return SlotPanelLayout.TEX_CHIP_2
	var tag: String = str(_vocab_bank.get_vocab(vocab_id).get("tag", ""))
	return SlotPanelLayout.chip_texture_for_tag(tag)

func _chip_texture_for_filter_tag(filter_tag: String) -> String:
	return SlotPanelLayout.chip_texture_for_tag(filter_tag)

func _chip_font_size_for_text(text: String) -> int:
	return SlotPanelLayout.chip_font_size_for_text(text)

func _mystery_blank_width_for_text(text: String) -> float:
	return SlotPanelLayout.CHIP_SIZE.x

# --- SlotDrag 回调 ---

func _begin_vocab_drag(vocab_id: String) -> bool:
	if not _vocab_drag_vocab_id.is_empty() and _vocab_drag_vocab_id != vocab_id:
		return false
	_vocab_drag_vocab_id = vocab_id
	_vocab_drag_release_block = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	return true

func _show_drag_ghost(vocab_id: String, grab_offset: Vector2, chip_size: Vector2, tex_path: String = "") -> void:
	_hide_drag_ghost()
	var text: String = _drag_vocab_text(vocab_id)
	var resolved_tex: String = tex_path if not tex_path.is_empty() else _chip_texture_for_vocab(vocab_id)
	_drag_ghost = _build_drag_ghost_control(text, resolved_tex, chip_size)
	_drag_grab_offset = grab_offset
	_drag_overlay.add_child(_drag_ghost)
	_drag_ghost.global_position = get_viewport().get_mouse_position() - _drag_grab_offset
	_drag_ghost_log_timer = 0.0
	set_process(true)

func _hide_drag_ghost() -> void:
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	set_process(false)

func _build_drag_ghost_control(text: String, tex_path: String, chip_size: Vector2) -> PanelContainer:
	var ghost := PanelContainer.new()
	ghost.custom_minimum_size = chip_size
	ghost.size = chip_size
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 4096
	var style := StyleBoxTexture.new()
	style.texture = load(tex_path) as Texture2D
	style.set_content_margin_all(0)
	ghost.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", _chip_font_size_for_text(text))
	label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(label)
	return ghost

func _can_start_vocab_drag(vocab_id: String) -> bool:
	return _vocab_drag_vocab_id.is_empty() or _vocab_drag_vocab_id == vocab_id

func _end_vocab_drag() -> void:
	if _vocab_drag_vocab_id.is_empty():
		return
	_vocab_drag_vocab_id = ""
	_hide_drag_ghost()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	call_deferred("_clear_vocab_drag_release_block")

func _clear_vocab_drag_release_block() -> void:
	_vocab_drag_release_block = false

func _is_vocab_drag_active() -> bool:
	return not _vocab_drag_vocab_id.is_empty()

func _consume_vocab_drag_release() -> bool:
	return _vocab_drag_release_block

func _drag_select_vocab(vocab_id: String) -> void:
	_selected_vocab_id = vocab_id
	_refresh_vocab_chips()

func _drag_fill_row_click(row_id: String) -> void:
	if _selected_vocab_id.is_empty():
		return
	if not _row_accepts_vocab(row_id, _selected_vocab_id):
		return
	_drag_apply_fill(row_id, _selected_vocab_id, "")

func _drag_can_drop_row(row_id: String, _at: Vector2, data: Variant) -> bool:
	if not visible or not (data is Dictionary):
		return false
	var vocab_id: String = str((data as Dictionary).get("vocab_id", ""))
	var accepted := not vocab_id.is_empty() and _row_accepts_vocab(row_id, vocab_id)
	#region agent log
	_debug_write("blank_can_drop", {
		"runId": "slot2-may-fix",
		"hypothesisId": "H2-H3",
		"row_id": row_id,
		"vocab_id": vocab_id,
		"accepted": accepted
	})
	#endregion
	return accepted

func _drag_drop_row(row_id: String, _at: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var payload: Dictionary = data
	var vocab_id: String = str(payload.get("vocab_id", ""))
	if not _row_accepts_vocab(row_id, vocab_id):
		#region agent log
		_debug_write("blank_drop_rejected", {
			"runId": "slot2-may-fix",
			"hypothesisId": "H2",
			"row_id": row_id,
			"vocab_id": vocab_id
		})
		#endregion
		return
	#region agent log
	_debug_write("blank_drop_accepted", {
		"runId": "slot2-may-fix",
		"hypothesisId": "H2",
		"row_id": row_id,
		"vocab_id": vocab_id
	})
	#endregion
	_drag_apply_fill(row_id, vocab_id, str(payload.get("from_row_id", "")))

func _drag_clear_row(row_id: String) -> void:
	if not _fills.has(row_id):
		return
	var returned_id: String = str(_fills.get(row_id, ""))
	_fills.erase(row_id)
	if not returned_id.is_empty():
		_append_pool_vocab(returned_id)
	_selected_vocab_id = ""
	_end_vocab_drag()
	_refresh_all_blanks()
	_refresh_vocab_chips()
	_update_status_text()

func _drag_get_row_vocab(row_id: String) -> String:
	return str(_fills.get(row_id, ""))

func _drag_vocab_text(vocab_id: String) -> String:
	if _vocab_bank == null:
		return vocab_id
	return _vocab_bank.get_vocab_text(vocab_id)

func _drag_apply_fill(row_id: String, vocab_id: String, from_row_id: String) -> void:
	if vocab_id.is_empty() or not _row_accepts_vocab(row_id, vocab_id):
		return
	var displaced: String = str(_fills.get(row_id, ""))
	if not from_row_id.is_empty():
		if from_row_id == row_id:
			return
		_fills.erase(from_row_id)
	_fills[row_id] = vocab_id
	if not from_row_id.is_empty() and not displaced.is_empty():
		_fills[from_row_id] = displaced
	_selected_vocab_id = ""
	_end_vocab_drag()
	_refresh_all_blanks()
	_refresh_vocab_chips()
	_try_auto_complete()

func _try_auto_complete() -> void:
	_update_status_text()
	var empty_count := 0
	var wrong_count := 0
	for row in _active_rows:
		var row_id: String = str(row.get("row_id", ""))
		var answer: String = str(row.get("answer_vocab", ""))
		var filled: String = str(_fills.get(row_id, ""))
		if filled.is_empty():
			empty_count += 1
		elif filled != answer:
			wrong_count += 1
	if empty_count > 0 or wrong_count > 0:
		return
	completed.emit()

func _row_accepts_vocab(row_id: String, vocab_id: String) -> bool:
	if _vocab_bank == null:
		return false
	for row in _rows:
		if str(row.get("row_id", "")) != row_id:
			continue
		if not _is_row_unlocked(row):
			return false
		var filter_tag: String = str(row.get("filter_tag", ""))
		if filter_tag.is_empty():
			return true
		return str(_vocab_bank.get_vocab(vocab_id).get("tag", "")) == filter_tag
	return false

func _is_vocab_placed(vocab_id: String) -> bool:
	for filled in _fills.values():
		if str(filled) == vocab_id:
			return true
	return false

func _on_vocab_bank_changed(_collected_count: int, _total_count: int) -> void:
	_refresh_vocab_chips()

func set_unlock_events(events: Dictionary) -> void:
	_unlock_events = events.duplicate(true)
	_render_identity_slots()
	_refresh_vocab_chips()

func _is_row_unlocked(row: Dictionary) -> bool:
	var cond: String = str(row.get("unlock_condition", "always")).strip_edges()
	if cond.is_empty() or cond == "always":
		return true
	if bool(_unlock_events.get(cond, false)):
		return true
	var answer_vocab: String = str(row.get("answer_vocab", ""))
	if not answer_vocab.is_empty() and _vocab_bank != null and _vocab_bank.has_vocab(answer_vocab):
		return true
	return false

func _debug_write(message: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "45c98c",
		"location": "identity_slot_panel.gd",
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var file := FileAccess.open("res://debug-45c98c.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("res://debug-45c98c.log", FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_string(JSON.stringify(payload) + "\n")
	file.close()
