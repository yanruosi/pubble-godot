extends Control
class_name IdentitySlotPanel

const SlotDrag := preload("res://scripts/idol_level/slot_drag_widgets.gd")
const PORTRAIT_SIZE := 88.0

signal completed
signal closed

var _rows: Array = []
var _vocab_bank: VocabBank
var _fills: Dictionary = {}
var _blank_slots: Dictionary = {}
var _vocab_grid: GridContainer
var _rows_box: VBoxContainer
var _status_label: Label
var _selected_vocab_id: String = ""
var _unlock_events: Dictionary = {}
var _active_rows: Array = []
var _default_status := "拖动人名词条到头像下方，全部填满后自动判定。"

func _ready() -> void:
	z_index = 30
	_build_ui()
	_set_panel_active(false)

func setup(slots: Array, vocab_bank: VocabBank) -> void:
	_rows.clear()
	_fills.clear()
	_blank_slots.clear()
	_selected_vocab_id = ""
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
	_render_rows()
	_refresh_vocab_chips()

func open_panel() -> void:
	_set_panel_active(true)
	_status_label.text = _default_status
	_render_rows()
	_refresh_vocab_chips()
	_refresh_all_blanks()

func close_panel(emit_signal := true) -> void:
	_set_panel_active(false)
	if emit_signal:
		closed.emit()

func _set_panel_active(active: bool) -> void:
	visible = active
	mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.68)
	add_child(dim)

	_status_label = Label.new()
	_status_label.text = _default_status
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_color_override("font_color", Color(0.94, 0.9, 0.82, 1))
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_label.offset_left = 80
	_status_label.offset_top = 112
	_status_label.offset_right = -80
	_status_label.offset_bottom = 148
	add_child(_status_label)

	var puzzle_panel := PanelContainer.new()
	puzzle_panel.name = "PuzzlePanel"
	puzzle_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	puzzle_panel.offset_left = 32
	puzzle_panel.offset_top = 128
	puzzle_panel.offset_right = -32
	puzzle_panel.offset_bottom = 392
	puzzle_panel.add_theme_stylebox_override("panel", _paper_style())
	add_child(puzzle_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	puzzle_panel.add_child(margin)

	_rows_box = VBoxContainer.new()
	_rows_box.name = "RowsBox"
	_rows_box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_rows_box)

	var vocab_panel := PanelContainer.new()
	vocab_panel.name = "VocabPanel"
	vocab_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	vocab_panel.offset_left = 32
	vocab_panel.offset_top = 406
	vocab_panel.offset_right = -32
	vocab_panel.offset_bottom = 704
	vocab_panel.add_theme_stylebox_override("panel", _vocab_panel_style())
	add_child(vocab_panel)

	var pool_zone := SlotDrag.SlotVocabPoolZone.new()
	pool_zone.setup_pool(self)
	vocab_panel.add_child(pool_zone)

	var vocab_margin := MarginContainer.new()
	vocab_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	vocab_margin.add_theme_constant_override("margin_left", 16)
	vocab_margin.add_theme_constant_override("margin_top", 16)
	vocab_margin.add_theme_constant_override("margin_right", 16)
	vocab_margin.add_theme_constant_override("margin_bottom", 16)
	vocab_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool_zone.add_child(vocab_margin)

	_vocab_grid = GridContainer.new()
	_vocab_grid.columns = 2
	_vocab_grid.add_theme_constant_override("h_separation", 8)
	_vocab_grid.add_theme_constant_override("v_separation", 8)
	_vocab_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vocab_margin.add_child(_vocab_grid)

	var close_btn := Button.new()
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(96, 44)
	close_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	close_btn.offset_left = 30
	close_btn.offset_top = -136
	close_btn.offset_right = 126
	close_btn.offset_bottom = -92
	close_btn.pressed.connect(func() -> void:
		close_panel()
	)
	add_child(close_btn)

func _render_rows() -> void:
	if _rows_box == null:
		return
	for child in _rows_box.get_children():
		child.queue_free()
	_blank_slots.clear()
	_active_rows.clear()
	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 56)
	_rows_box.add_child(columns)
	for row in _rows:
		if not _is_row_unlocked(row):
			continue
		_active_rows.append(row)
		var row_id: String = str(row.get("row_id", ""))
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 10)
		columns.add_child(col)
		col.add_child(_build_portrait_placeholder(row))
		var blank := SlotDrag.SlotBlankSlot.new()
		blank.setup_blank(self, row_id, Vector2(120, 40))
		_blank_slots[row_id] = blank
		col.add_child(blank)

func _refresh_vocab_chips() -> void:
	if _vocab_grid == null:
		return
	for child in _vocab_grid.get_children():
		child.queue_free()
	if _vocab_bank == null:
		return
	for vocab in _vocab_bank.get_collected_vocab("name"):
		var vocab_id: String = str(vocab.get("vocab_id", ""))
		if _is_vocab_placed(vocab_id):
			continue
		var chip := SlotDrag.SlotVocabChip.new()
		chip.setup_chip(self, vocab_id, str(vocab.get("text", vocab_id)))
		if vocab_id == _selected_vocab_id:
			chip.modulate = Color(0.82, 0.95, 1.0, 1)
		_vocab_grid.add_child(chip)

func _refresh_all_blanks() -> void:
	for row_id in _blank_slots.keys():
		var blank: SlotDrag.SlotBlankSlot = _blank_slots[row_id]
		if blank != null:
			blank.refresh_display()

func _drag_select_vocab(vocab_id: String) -> void:
	_selected_vocab_id = vocab_id
	_refresh_vocab_chips()

func _drag_fill_row_click(row_id: String) -> void:
	if _selected_vocab_id.is_empty():
		_status_label.text = "请先选择一个人名词条。"
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
	_fills.erase(row_id)
	_selected_vocab_id = ""
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
	_refresh_all_blanks()
	_refresh_vocab_chips()
	_try_auto_complete()

func _drag_blank_style() -> StyleBoxFlat:
	return _blank_style()

func _drag_chip_style() -> StyleBoxFlat:
	return _chip_style()

func _try_auto_complete() -> void:
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
		_status_label.text = "已填 %d/%d，继续拖动词条。" % [_active_rows.size() - empty_count, _active_rows.size()]
		return
	if wrong_count > 0:
		_status_label.text = "全部填满，但有 %d 处不正确，可拖动调整。" % wrong_count
		return
	_status_label.text = "身份信息已填写正确。"
	completed.emit()

func _row_accepts_vocab(row_id: String, vocab_id: String) -> bool:
	if _vocab_bank == null:
		return false
	for row in _active_rows:
		if str(row.get("row_id", "")) != row_id:
			continue
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
	_render_rows()
	_refresh_vocab_chips()

func _is_row_unlocked(row: Dictionary) -> bool:
	var cond: String = str(row.get("unlock_condition", "always")).strip_edges()
	if cond.is_empty() or cond == "always":
		return true
	return bool(_unlock_events.get(cond, false))

func _build_portrait_placeholder(row: Dictionary) -> PanelContainer:
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	var color_text: String = str(row.get("placeholder_color", "#3388ff"))
	portrait.add_theme_stylebox_override("panel", _portrait_style(Color.from_string(color_text, Color(0.2, 0.5, 0.95, 1))))
	var label := Label.new()
	label.text = str(row.get("left_content", "身份"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.add_child(label)
	return portrait

func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.86, 0.78, 0.60, 1)
	style.border_color = Color(0.57, 0.43, 0.20, 1)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _vocab_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.72, 0.64, 0.48, 1)
	style.border_color = Color(0.56, 0.42, 0.2, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style

func _portrait_style(fill_color: Color) -> StyleBoxFlat:
	var radius := int(PORTRAIT_SIZE * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = Color(0.52, 0.42, 0.24, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style

func _blank_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.9, 0.78, 1)
	style.border_color = Color(0.45, 0.35, 0.18, 1)
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style

func _chip_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.88, 0.8, 0.62, 1)
	style.border_color = Color(0.5, 0.38, 0.2, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	return style
