extends Control
class_name ScrollSlotPanel

const SlotDrag := preload("res://scripts/idol_level/slot_drag_widgets.gd")

## PSD 1280×720 槽位1卷轴面板布局
const TEX_SCROLL_BG := "res://art/mainui/level/caowei1bg.png"
const TEX_WORD_BG := "res://art/mainui/level/wordbg.png"
const TEX_CHIP_1 := "res://art/mainui/level/citiaobg1.png"
const TEX_CHIP_2 := "res://art/mainui/level/citiaobg2.png"
const TEX_CHIP_3 := "res://art/mainui/level/citiaobg3.png"

const SCROLL_BG_RECT := Rect2(118, 14, 1044, 586)
const TEXT_AREA_RECT := Rect2(182.56, 107.08, 490, 162.08)
const WORD_BG_RECT := Rect2(705, 33, 427, 524)
const CHIP_SIZE := Vector2(133, 61)
const MYSTERY_BLANK_SIZE := Vector2(88, 40)
const CHIP_GRID_ORIGIN := Vector2(716, 122)
const CHIP_COLS := 3
const CHIP_H_SEP := 5
const CHIP_V_SEP := 25

const MYSTERY_FONT_SIZE := 28
const CHIP_FONT_SIZE := 28
const CHIP_LONG_FONT_SIZE := 21
const CHIP_LONG_TEXT_LEN := 5
const DRAG_OVERLAY_LAYER := 350

signal completed
signal closed

var _dim: ColorRect
var _vocab_drag_vocab_id: String = ""
var _vocab_drag_release_block: bool = false
var _rows: Array = []
var _vocab_bank: VocabBank
var _fills: Dictionary = {}
var _blank_slots: Dictionary = {}
var _text_flow: HFlowContainer
var _vocab_chip_layer: Control
var _vocab_pool_zone: SlotDrag.SlotVocabPoolZone
var _status_label: Label
var _selected_vocab_id: String = ""
var _default_status := "拖动词条填入卷轴，全部填满后自动揭晓。"
var _drag_overlay: CanvasLayer
var _drag_ghost: Control
var _drag_grab_offset := Vector2.ZERO
var _drag_ghost_log_timer := 0.0
var _pool_vocab_order: Array[String] = []

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
		if str(row.get("slot_type", "")) != "scroll":
			continue
		_rows.append(row)
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	if _vocab_bank != null and not _vocab_bank.changed.is_connected(_on_vocab_bank_changed):
		_vocab_bank.changed.connect(_on_vocab_bank_changed)
	_render_scroll_rows()
	_refresh_vocab_chips()

func open_panel() -> void:
	_set_panel_active(true)
	_status_label.text = _default_status
	_refresh_vocab_chips()
	_refresh_all_blanks()
	call_deferred("_log_layout_metrics")
	#region agent log
	DebugSessionLog.write_debug("H10", "scroll_slot_panel.gd:open_panel", "slot_panel_open", {
		"visible": visible,
		"z_index": z_index,
		"mouse_filter": mouse_filter
	})
	#endregion

func close_panel(emit_signal := true) -> void:
	_set_panel_active(false)
	#region agent log
	DebugSessionLog.write_debug("H12", "scroll_slot_panel.gd:close_panel", "slot_panel_close", {
		"emit_signal": emit_signal,
		"visible": visible,
		"z_index": z_index,
		"mouse_filter": mouse_filter
	})
	#endregion
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

func _set_panel_active(active: bool) -> void:
	visible = active
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	set_process_input(active)

func _build_ui() -> void:
	_dim = SlotPanelLayout.make_scene_mask()
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	var scroll_bg := TextureRect.new()
	scroll_bg.name = "ScrollBg"
	scroll_bg.texture = load(TEX_SCROLL_BG) as Texture2D
	scroll_bg.position = SCROLL_BG_RECT.position
	scroll_bg.size = SCROLL_BG_RECT.size
	scroll_bg.stretch_mode = TextureRect.STRETCH_SCALE
	scroll_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scroll_bg)

	var text_area := Control.new()
	text_area.name = "TextArea"
	text_area.position = TEXT_AREA_RECT.position
	text_area.size = TEXT_AREA_RECT.size
	text_area.clip_contents = true
	text_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_area)

	_text_flow = HFlowContainer.new()
	_text_flow.name = "TextFlow"
	_text_flow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_flow.add_theme_constant_override("h_separation", 4)
	_text_flow.add_theme_constant_override("v_separation", 6)
	_text_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_area.add_child(_text_flow)

	var word_bg := TextureRect.new()
	word_bg.name = "WordBg"
	word_bg.texture = load(TEX_WORD_BG) as Texture2D
	word_bg.position = WORD_BG_RECT.position
	word_bg.size = WORD_BG_RECT.size
	word_bg.stretch_mode = TextureRect.STRETCH_SCALE
	word_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(word_bg)

	_vocab_pool_zone = SlotDrag.SlotVocabPoolZone.new()
	_vocab_pool_zone.name = "PoolZone"
	_vocab_pool_zone.setup_pool(self)
	_vocab_pool_zone.position = CHIP_GRID_ORIGIN
	var pool_w: float = CHIP_COLS * CHIP_SIZE.x + (CHIP_COLS - 1) * CHIP_H_SEP
	var pool_h: float = WORD_BG_RECT.position.y + WORD_BG_RECT.size.y - CHIP_GRID_ORIGIN.y
	_vocab_pool_zone.size = Vector2(pool_w, pool_h)
	add_child(_vocab_pool_zone)

	_vocab_chip_layer = Control.new()
	_vocab_chip_layer.name = "VocabChipLayer"
	_vocab_chip_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vocab_chip_layer)

	_status_label = Label.new()
	_status_label.text = _default_status
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.22, 0.18, 0.12, 1))
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.position = Vector2(705, 560)
	_status_label.size = Vector2(427, 28)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)

	_drag_overlay = CanvasLayer.new()
	_drag_overlay.name = "DragOverlay"
	_drag_overlay.layer = DRAG_OVERLAY_LAYER
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
	#region agent log
	_debug_write("drag_ghost_pos", {
		"runId": "drag-ghost-v1",
		"hypothesisId": "H1-H2",
		"mouse": [mouse_global.x, mouse_global.y],
		"ghost_global": [_drag_ghost.global_position.x, _drag_ghost.global_position.y],
		"grab_offset": [_drag_grab_offset.x, _drag_grab_offset.y],
		"overlay_layer": DRAG_OVERLAY_LAYER,
		"vocab_id": _vocab_drag_vocab_id
	})
	#endregion

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
	var keep_open := _should_keep_open_on_click(local_pos)
	#region agent log
	_debug_write("outside_click", {
		"runId": "dismiss-fix",
		"source": source,
		"local_pos": [local_pos.x, local_pos.y],
		"keep_open": keep_open
	})
	#endregion
	if keep_open:
		return
	close_panel()
	if source == "dim":
		_dim.accept_event()
	else:
		get_viewport().set_input_as_handled()

func _should_keep_open_on_click(local_pos: Vector2) -> bool:
	return SlotPanelLayout.should_keep_open_on_click(local_pos, SCROLL_BG_RECT)

func _mystery_half_char_width() -> float:
	var font := ThemeDB.fallback_font
	return font.get_string_size("字", HORIZONTAL_ALIGNMENT_LEFT, -1, MYSTERY_FONT_SIZE).x * 0.5

func _chip_slot_position(slot_index: int) -> Vector2:
	var col: int = slot_index % CHIP_COLS
	var row: int = int(slot_index / CHIP_COLS)
	return Vector2(
		CHIP_GRID_ORIGIN.x + col * (CHIP_SIZE.x + CHIP_H_SEP),
		CHIP_GRID_ORIGIN.y + row * (CHIP_SIZE.y + CHIP_V_SEP)
	)

func _chip_padding_x() -> float:
	return 0.0

func _chip_font_size_for_text(text: String) -> int:
	if text.length() >= CHIP_LONG_TEXT_LEN:
		return CHIP_LONG_FONT_SIZE
	return CHIP_FONT_SIZE

func _mystery_blank_width_for_text(text: String) -> float:
	if text.is_empty():
		return MYSTERY_BLANK_SIZE.x
	var font := ThemeDB.fallback_font
	var font_size: int = _chip_font_size_for_text(text)
	var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pad: float = _mystery_half_char_width()
	return maxf(MYSTERY_BLANK_SIZE.x, text_w + pad * 2.0)

func _render_scroll_rows() -> void:
	if _text_flow == null:
		return
	for child in _text_flow.get_children():
		child.queue_free()
	_blank_slots.clear()
	for row in _rows:
		var prefix: String = str(row.get("prefix_text", ""))
		if not prefix.is_empty():
			_text_flow.add_child(_fixed_label(prefix))
		var row_id: String = str(row.get("row_id", ""))
		var filter_tag: String = str(row.get("filter_tag", ""))
		var blank := SlotDrag.SlotBlankSlot.new()
		blank.setup_blank(self, row_id, filter_tag, MYSTERY_BLANK_SIZE, MYSTERY_FONT_SIZE)
		_blank_slots[row_id] = blank
		_text_flow.add_child(blank)
		var suffix: String = str(row.get("suffix_text", ""))
		if not suffix.is_empty():
			_text_flow.add_child(_fixed_label(suffix))

func _fixed_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.13, 0.11, 0.08, 1))
	label.add_theme_font_size_override("font_size", MYSTERY_FONT_SIZE)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, MYSTERY_BLANK_SIZE.y)
	return label

func _sync_pool_vocab_order() -> void:
	if _vocab_bank == null:
		return
	var kept: Array[String] = []
	for vocab_id in _pool_vocab_order:
		if _vocab_bank.has_vocab(vocab_id):
			kept.append(vocab_id)
	_pool_vocab_order = kept
	for vocab in _vocab_bank.get_collected_vocab():
		var vocab_id: String = str(vocab.get("vocab_id", ""))
		if vocab_id.is_empty() or _pool_vocab_order.has(vocab_id):
			continue
		_pool_vocab_order.append(vocab_id)

func _append_pool_vocab(vocab_id: String, reason: String = "") -> void:
	if vocab_id.is_empty():
		return
	var before: Array = _pool_vocab_order.duplicate()
	_pool_vocab_order.erase(vocab_id)
	_pool_vocab_order.append(vocab_id)
	#region agent log
	_debug_write("pool_order_append", {
		"runId": "pool-order-v1",
		"hypothesisId": "H1",
		"vocab_id": vocab_id,
		"reason": reason,
		"before": before,
		"after": _pool_vocab_order.duplicate()
	})
	#endregion

func _refresh_vocab_chips() -> void:
	if _vocab_chip_layer == null:
		return
	for child in _vocab_chip_layer.get_children():
		child.queue_free()
	if _vocab_bank == null:
		return
	_sync_pool_vocab_order()
	var slot_index := 0
	var chip_layout: Array = []
	for vocab_id in _pool_vocab_order:
		if _is_vocab_placed(vocab_id):
			continue
		var vocab: Dictionary = _vocab_bank.get_vocab(vocab_id)
		if vocab.is_empty():
			continue
		var tex_path: String = _chip_texture_for_vocab(vocab_id)
		var chip := SlotDrag.SlotVocabChip.new()
		chip.setup_chip(self, vocab_id, str(vocab.get("text", vocab_id)), tex_path)
		var slot_pos: Vector2 = _chip_slot_position(slot_index)
		chip.position = slot_pos
		chip.size = CHIP_SIZE
		if vocab_id == _selected_vocab_id:
			chip.modulate = Color(0.82, 0.95, 1.0, 1)
		_vocab_chip_layer.add_child(chip)
		chip_layout.append({
			"vocab_id": vocab_id,
			"slot": slot_index,
			"pos": [slot_pos.x, slot_pos.y],
			"size": [CHIP_SIZE.x, CHIP_SIZE.y]
		})
		slot_index += 1
	call_deferred("_log_chip_layout", chip_layout)

func _visible_pool_order() -> Array:
	var order: Array = []
	for vocab_id in _pool_vocab_order:
		if not _is_vocab_placed(vocab_id):
			order.append(vocab_id)
	return order

func _refresh_all_blanks() -> void:
	for row_id in _blank_slots.keys():
		var blank: SlotDrag.SlotBlankSlot = _blank_slots[row_id]
		if blank != null:
			blank.refresh_display()
	call_deferred("_log_blank_widths")

func _chip_texture_for_vocab(vocab_id: String) -> String:
	if _vocab_bank == null:
		return TEX_CHIP_1
	var tag: String = str(_vocab_bank.get_vocab(vocab_id).get("tag", ""))
	return _chip_texture_for_tag(tag)

func _chip_texture_for_filter_tag(filter_tag: String) -> String:
	return _chip_texture_for_tag(filter_tag)

func _chip_texture_for_tag(tag: String) -> String:
	match tag:
		"name":
			return TEX_CHIP_2
		"drink":
			return TEX_CHIP_3
		_:
			return TEX_CHIP_1

# --- SlotDrag 回调 ---

func _begin_vocab_drag(vocab_id: String) -> bool:
	if not _vocab_drag_vocab_id.is_empty() and _vocab_drag_vocab_id != vocab_id:
		#region agent log
		_debug_write("vocab_drag_rejected", {
			"runId": "drag-fix-v2",
			"requested": vocab_id,
			"active": _vocab_drag_vocab_id
		})
		#endregion
		return false
	_vocab_drag_vocab_id = vocab_id
	_vocab_drag_release_block = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	#region agent log
	_debug_write("vocab_drag_begin", {
		"runId": "drag-fix-v2",
		"vocab_id": vocab_id
	})
	#endregion
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
	#region agent log
	_debug_write("drag_ghost_show", {
		"runId": "drag-ghost-v1",
		"hypothesisId": "H1",
		"vocab_id": vocab_id,
		"text": text,
		"size": [chip_size.x, chip_size.y],
		"overlay_layer": DRAG_OVERLAY_LAYER
	})
	#endregion

func _hide_drag_ghost() -> void:
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	set_process(false)

func _build_drag_ghost_control(text: String, tex_path: String, chip_size: Vector2) -> PanelContainer:
	var ghost := PanelContainer.new()
	ghost.name = "DragGhost"
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

func _debug_chip_drag_start(vocab_id: String, source: String) -> void:
	#region agent log
	_debug_write("chip_drag_start", {
		"runId": "drag-fix-v2",
		"vocab_id": vocab_id,
		"source": source
	})
	#endregion

func _end_vocab_drag() -> void:
	if _vocab_drag_vocab_id.is_empty():
		return
	var ended_id := _vocab_drag_vocab_id
	_vocab_drag_vocab_id = ""
	_hide_drag_ghost()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	#region agent log
	_debug_write("vocab_drag_end", {
		"runId": "drag-fix-v2",
		"vocab_id": ended_id
	})
	#endregion
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
		_status_label.text = "请先点选或拖入一个词条。"
		return
	_drag_apply_fill(row_id, _selected_vocab_id, "")

func _drag_can_drop_row(row_id: String, _at: Vector2, data: Variant) -> bool:
	if not visible or not (data is Dictionary):
		return false
	var vocab_id: String = str((data as Dictionary).get("vocab_id", ""))
	return not vocab_id.is_empty()

func _drag_drop_row(row_id: String, _at: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var payload: Dictionary = data
	_drag_apply_fill(row_id, str(payload.get("vocab_id", "")), str(payload.get("from_row_id", "")))

func _drag_clear_row(row_id: String) -> void:
	if not _fills.has(row_id):
		return
	var returned_id: String = str(_fills.get(row_id, ""))
	_fills.erase(row_id)
	if not returned_id.is_empty():
		_append_pool_vocab(returned_id, "return_to_pool")
	_selected_vocab_id = ""
	_end_vocab_drag()
	_refresh_all_blanks()
	_refresh_vocab_chips()
	_status_label.text = _default_status

func _drag_get_row_vocab(row_id: String) -> String:
	return str(_fills.get(row_id, ""))

func _drag_vocab_text(vocab_id: String) -> String:
	if _vocab_bank == null:
		return vocab_id
	return _vocab_bank.get_vocab_text(vocab_id)

func _drag_apply_fill(row_id: String, vocab_id: String, from_row_id: String) -> void:
	if vocab_id.is_empty():
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
	var empty_count := 0
	var wrong_count := 0
	for row in _rows:
		var row_id: String = str(row.get("row_id", ""))
		var answer: String = str(row.get("answer_vocab", ""))
		var filled: String = str(_fills.get(row_id, ""))
		if filled.is_empty():
			empty_count += 1
		elif filled != answer:
			wrong_count += 1
	if empty_count > 0:
		_status_label.text = "已填 %d/%d，继续拖动词条。" % [_rows.size() - empty_count, _rows.size()]
		return
	if wrong_count > 0:
		_status_label.text = "全部填满，但有 %d 处不正确，可拖动调整。" % wrong_count
		return
	_status_label.text = "所有部位填写正确。"
	completed.emit()

func _is_vocab_placed(vocab_id: String) -> bool:
	for filled in _fills.values():
		if str(filled) == vocab_id:
			return true
	return false

func _on_vocab_bank_changed(_collected_count: int, _total_count: int) -> void:
	_refresh_vocab_chips()

func _log_layout_metrics() -> void:
	if not visible or _text_flow == null:
		return
	var text_area: Control = _text_flow.get_parent() as Control
	var flow_size: Vector2 = _text_flow.get_combined_minimum_size()
	var child_sizes: Array = []
	for child in _text_flow.get_children():
		if child is Control:
			var c := child as Control
			child_sizes.append({
				"name": c.name,
				"size": [c.size.x, c.size.y],
				"min": [c.custom_minimum_size.x, c.custom_minimum_size.y]
			})
	var chip_sample: Dictionary = {}
	if _vocab_chip_layer != null and _vocab_chip_layer.get_child_count() > 0:
		var chip := _vocab_chip_layer.get_child(0) as Control
		if chip != null:
			chip_sample = {
				"size": [chip.size.x, chip.size.y],
				"pos": [chip.position.x, chip.position.y]
			}
	#region agent log
	_debug_write("layout_metrics", {
		"runId": "post-fix",
		"hypothesisId": "H1-H5",
		"mystery_font_pt": MYSTERY_FONT_SIZE,
		"mystery_blank_size": [MYSTERY_BLANK_SIZE.x, MYSTERY_BLANK_SIZE.y],
		"chip_size_const": [CHIP_SIZE.x, CHIP_SIZE.y],
		"text_area_rect": [TEXT_AREA_RECT.size.x, TEXT_AREA_RECT.size.y],
		"text_area_clip": text_area.clip_contents if text_area != null else null,
		"flow_combined_min": [flow_size.x, flow_size.y],
		"flow_child_count": _text_flow.get_child_count(),
		"flow_children": child_sizes,
		"pool_chip_sample": chip_sample,
		"overflow_y": flow_size.y - TEXT_AREA_RECT.size.y
	})
	#endregion

func _debug_write(message: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "45c98c",
		"location": "scroll_slot_panel.gd:_log_layout_metrics",
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

func _log_blank_widths() -> void:
	if not visible:
		return
	var samples: Array = []
	for row_id in _blank_slots.keys():
		var blank: SlotDrag.SlotBlankSlot = _blank_slots[row_id] as SlotDrag.SlotBlankSlot
		if blank == null:
			continue
		var vocab_id: String = str(_fills.get(row_id, ""))
		var text: String = _drag_vocab_text(vocab_id) if not vocab_id.is_empty() else ""
		samples.append({
			"row_id": row_id,
			"text": text,
			"width": blank.size.x,
			"target_w": _mystery_blank_width_for_text(text) if not text.is_empty() else MYSTERY_BLANK_SIZE.x,
			"half_char_pad": _mystery_half_char_width()
		})
	#region agent log
	_debug_write("blank_widths", {
		"runId": "padding-dismiss",
		"samples": samples
	})
	#endregion

func _log_chip_layout(chip_layout: Array) -> void:
	if not visible:
		return
	#region agent log
	_debug_write("chip_layout", {
		"runId": "psd-grid",
		"slots": chip_layout,
		"pool_order": _visible_pool_order(),
		"psd_origin": [CHIP_GRID_ORIGIN.x, CHIP_GRID_ORIGIN.y],
		"chip_size": [CHIP_SIZE.x, CHIP_SIZE.y]
	})
	#endregion
