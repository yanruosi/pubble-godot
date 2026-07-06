extends Control

signal close_requested
signal level_start_requested(level: Dictionary)
signal chapter_state_changed

const SWIPE_THRESHOLD := 45.0
const ANIM_DURATION := 0.36
## 侧卡静止缩放（相对中间大卡）；切换时用 Tween 与中间卡平滑互换 scale / modulate
const SIDE_SCALE := 0.88
const SIDE_MODULATE := Color(1, 1, 1, 0.85)
## 侧卡达到该插值后才切到前景层，避免“尺寸还小但已遮挡中心卡”。
const FOREGROUND_SWAP_THRESHOLD := 0.95
const THIRD_LAYER_SCALE := 0.78
const THIRD_LAYER_ALPHA := 0.68
const THIRD_LAYER_OFFSET_X := 92.0
const ENTER_FULL_PROGRESS := 0.78
const LEAVING_EXTRA_SHIFT_X := 30.0
@onready var back_button: Button = $BackButton
@onready var left_card: PanelContainer = $Carousel/LeftCard
@onready var center_card: PanelContainer = $Carousel/CenterCard
@onready var right_card: PanelContainer = $Carousel/RightCard
@onready var carousel_root: Control = $Carousel
@onready var left_title_label: Label = $Carousel/LeftCard/CardMargin/CardVBox/LeftTitle
@onready var left_sub_label: Label = $Carousel/LeftCard/CardMargin/CardVBox/LeftSub
@onready var right_title_label: Label = $Carousel/RightCard/CardMargin/CardVBox/RightTitle
@onready var right_sub_label: Label = $Carousel/RightCard/CardMargin/CardVBox/RightSub
@onready var preview_rect: ColorRect = $Carousel/CenterCard/CardMargin/CardVBox/PreviewRect
@onready var lock_overlay: ColorRect = $Carousel/CenterCard/CardMargin/CardVBox/PreviewRect/LockOverlay
@onready var left_lock_overlay: ColorRect = $Carousel/LeftCard/CardMargin/CardVBox/PreviewRect/LockOverlay
@onready var right_lock_overlay: ColorRect = $Carousel/RightCard/CardMargin/CardVBox/PreviewRect/LockOverlay
@onready var title_label: Label = $Carousel/CenterCard/CardMargin/CardVBox/TitleLabel
@onready var sub_label: Label = $Carousel/CenterCard/CardMargin/CardVBox/SubLabel
@onready var dots_label: Label = $DotsLabel
@onready var action_button: Button = $ActionButton
@onready var progress_panel: PanelContainer = $ProgressPanel
@onready var progress_text: Label = $ProgressPanel/ProgressMargin/ProgressVBox/ProgressText
@onready var progress_fill: ColorRect = $ProgressPanel/ProgressMargin/ProgressVBox/ProgressTrack/ProgressFill
@onready var condition_bubble: PanelContainer = $ConditionBubble
@onready var condition_bubble_label: Label = $ConditionBubble/ConditionBubbleMargin/ConditionBubbleLabel
@onready var message_label: Label = $MessageLabel

var _chapter_id: int = 0
var _chapter: Dictionary = {}
var _levels: Array = []
var _current_index: int = 0
var _chapter_manager: ChapterManager
var _save_manager: SaveManager
var _condition_checker: ConditionChecker
var _required_counts_by_level_id: Dictionary = {}
var _drag_start_x := 0.0
var _dragging := false
var _animating := false
var _left_card_pos := Vector2.ZERO
var _center_card_pos := Vector2.ZERO
var _right_card_pos := Vector2.ZERO
var _slide_range_px: float = 120.0
var _drag_start_global_x: float = 0.0
var _live_drag_offset: float = 0.0
var _active_carousel_tween: Tween
var _side_gesture_side: int = 0
var _side_gesture_start_x: float = 0.0
var _last_foreground_side: int = 0
var _far_left_card: PanelContainer
var _far_right_card: PanelContainer

func _dbg(_hypothesis_id: String, _location: String, _message: String, _data: Dictionary = {}, _run_id: String = "run1") -> void:
	pass

func _dbg8(_hypothesis_id: String, _location: String, _message: String, _data: Dictionary = {}, _run_id: String = "run1") -> void:
	pass

func _dbg_e48(_hypothesis_id: String, _location: String, _message: String, _data: Dictionary = {}, _run_id: String = "pre-fix") -> void:
	pass

func _carousel_layout_snapshot() -> Dictionary:
	return {
		"carousel_size": carousel_root.size if carousel_root != null else Vector2.ZERO,
		"page_size": size,
		"left_pos": left_card.position,
		"center_pos": center_card.position,
		"right_pos": right_card.position,
		"left_base": _left_card_pos,
		"center_base": _center_card_pos,
		"right_base": _right_card_pos,
		"live_drag_offset": _live_drag_offset,
		"animating": _animating,
		"dragging": _dragging,
		"current_index": _current_index,
		"levels_count": _levels.size()
	}


func _reset_carousel_interaction_state() -> void:
	_kill_carousel_tween()
	_live_drag_offset = 0.0
	_animating = false
	_dragging = false
	_last_foreground_side = 0
	_side_gesture_side = 0


func _restore_carousel_default_layout() -> void:
	left_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left_card.offset_left = 8.0
	left_card.offset_top = 140.0
	left_card.offset_right = 169.0
	left_card.offset_bottom = 300.0
	center_card.anchor_left = 0.5
	center_card.anchor_right = 0.5
	center_card.offset_left = -130.0
	center_card.offset_top = 100.0
	center_card.offset_right = 130.0
	center_card.offset_bottom = 340.0
	right_card.anchor_left = 1.0
	right_card.anchor_right = 1.0
	right_card.offset_left = -169.0
	right_card.offset_top = 140.0
	right_card.offset_right = -8.0
	right_card.offset_bottom = 300.0


func _realign_carousel_after_show() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_restore_carousel_default_layout()
	_cache_card_positions_and_pivots()
	_reset_carousel_layout_to_bases()
	_apply_carousel_rest_visual()
func _ready() -> void:
	back_button.pressed.connect(func() -> void: close_requested.emit())
	action_button.pressed.connect(_on_action_pressed)
	center_card.gui_input.connect(_on_center_card_gui_input)
	left_card.gui_input.connect(func(ev: InputEvent) -> void: _on_side_card_gui_input(-1, ev))
	right_card.gui_input.connect(func(ev: InputEvent) -> void: _on_side_card_gui_input(1, ev))
	_apply_panel_style(left_card, Color(1, 1, 1, 1), 20)
	_apply_panel_style(center_card, Color(1, 1, 1, 1), 20)
	_apply_panel_style(right_card, Color(1, 1, 1, 1), 20)
	_create_far_preview_cards()
	_apply_panel_style(progress_panel, Color(0.68, 0.55, 0.92, 1), 8)
	_apply_panel_style(condition_bubble, Color(0.45, 0.45, 0.45, 0.72), 8)
	call_deferred("_deferred_init_carousel_geometry")


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and _chapter_id > 0:
		_reset_carousel_interaction_state()
		call_deferred("_realign_carousel_after_show")


func _deferred_init_carousel_geometry() -> void:
	await get_tree().process_frame
	_cache_card_positions_and_pivots()


func _cache_card_positions_and_pivots() -> void:
	_left_card_pos = left_card.position
	_center_card_pos = center_card.position
	_right_card_pos = right_card.position
	var d_l := absf(_center_card_pos.x - _left_card_pos.x)
	var d_r := absf(_right_card_pos.x - _center_card_pos.x)
	_slide_range_px = maxf(96.0, (d_l + d_r) * 0.45)
	for card in [left_card, center_card, right_card]:
		card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y * 0.5)
	for far in [_far_left_card, _far_right_card]:
		if far != null:
			far.pivot_offset = Vector2(far.size.x * 0.5, far.size.y * 0.5)
	if not _animating and not _dragging:
		_apply_carousel_rest_visual()


func _kill_carousel_tween() -> void:
	if _active_carousel_tween != null and is_instance_valid(_active_carousel_tween):
		_active_carousel_tween.kill()
	_active_carousel_tween = null


func _reset_carousel_layout_to_bases() -> void:
	left_card.position = _left_card_pos
	center_card.position = _center_card_pos
	right_card.position = _right_card_pos


func _apply_carousel_drag_visual() -> void:
	var range_px: float = maxf(60.0, _slide_range_px)
	var raw: float = _live_drag_offset
	var raw_vis: float = clampf(raw, -range_px * 1.18, range_px * 1.18)
	var u: float = clampf(raw / range_px, -1.0, 1.0)
	var abs_u: float = absf(u)
	var center_idx := _current_index
	var left_idx := _current_index - 1
	var right_idx := _current_index + 1

	center_card.position.x = _center_card_pos.x + raw_vis
	left_card.position.x = _left_card_pos.x + raw_vis
	right_card.position.x = _right_card_pos.x + raw_vis
	# 让离场卡在拖拽中额外侧移，避免与新前卡 x 重叠。
	if raw < 0.0:
		center_card.position.x -= LEAVING_EXTRA_SHIFT_X * clampf(-u, 0.0, 1.0)
	elif raw > 0.0:
		center_card.position.x += LEAVING_EXTRA_SHIFT_X * clampf(u, 0.0, 1.0)

	center_card.scale = Vector2.ONE.lerp(Vector2(SIDE_SCALE, SIDE_SCALE), abs_u)
	center_card.modulate = Color.WHITE.lerp(SIDE_MODULATE, abs_u)

	left_card.scale = Vector2(SIDE_SCALE, SIDE_SCALE)
	left_card.modulate = SIDE_MODULATE
	right_card.scale = Vector2(SIDE_SCALE, SIDE_SCALE)
	right_card.modulate = SIDE_MODULATE
	left_card.z_index = 1
	right_card.z_index = 1
	center_card.z_index = 5
	var foreground_side: int = 0

	if raw < 0.0 and right_card.visible:
		var t_right: float = clampf(-u, 0.0, 1.0)
		var enter_full_t: float = clampf(t_right / ENTER_FULL_PROGRESS, 0.0, 1.0)
		right_card.scale = Vector2(SIDE_SCALE, SIDE_SCALE).lerp(Vector2.ONE, enter_full_t)
		right_card.modulate = SIDE_MODULATE.lerp(Color.WHITE, enter_full_t)
		# 关键：切层时机看“原始拖拽进度”，而不是压缩后的放大进度。
		# 这样可以保证新卡已到前层尺寸一段时间后才提到前景，避免过早遮挡。
		if t_right > FOREGROUND_SWAP_THRESHOLD:
			foreground_side = 1
			right_card.scale = Vector2.ONE
			right_card.modulate = Color.WHITE
			right_card.z_index = 8
			center_card.z_index = 4
	elif raw > 0.0 and left_card.visible:
		var tl: float = clampf(u, 0.0, 1.0)
		var enter_full_l: float = clampf(tl / ENTER_FULL_PROGRESS, 0.0, 1.0)
		left_card.scale = Vector2(SIDE_SCALE, SIDE_SCALE).lerp(Vector2.ONE, enter_full_l)
		left_card.modulate = SIDE_MODULATE.lerp(Color.WHITE, enter_full_l)
		if tl > FOREGROUND_SWAP_THRESHOLD:
			foreground_side = -1
			left_card.scale = Vector2.ONE
			left_card.modulate = Color.WHITE
			left_card.z_index = 8
			center_card.z_index = 4
	_apply_third_layer_preview(raw)
	if foreground_side != _last_foreground_side:
		_last_foreground_side = foreground_side

func _apply_third_layer_preview(raw: float) -> void:
	if _far_left_card == null or _far_right_card == null:
		return
	_far_left_card.visible = false
	_far_right_card.visible = false
	if raw < 0.0:
		var far_right_idx := _current_index + 2
		if far_right_idx < _levels.size():
			_bind_level_to_side_card(_far_right_card, _levels[far_right_idx], false)
			_far_right_card.visible = true
			_far_right_card.scale = Vector2(THIRD_LAYER_SCALE, THIRD_LAYER_SCALE)
			_far_right_card.modulate = Color(1, 1, 1, THIRD_LAYER_ALPHA)
			_far_right_card.position = right_card.position + Vector2(THIRD_LAYER_OFFSET_X, 0.0)
			_far_right_card.z_index = 0
	elif raw > 0.0:
		var far_left_idx := _current_index - 2
		if far_left_idx >= 0:
			_bind_level_to_side_card(_far_left_card, _levels[far_left_idx], true)
			_far_left_card.visible = true
			_far_left_card.scale = Vector2(THIRD_LAYER_SCALE, THIRD_LAYER_SCALE)
			_far_left_card.modulate = Color(1, 1, 1, THIRD_LAYER_ALPHA)
			_far_left_card.position = left_card.position - Vector2(THIRD_LAYER_OFFSET_X, 0.0)
			_far_left_card.z_index = 0


func _bind_left_card_with_level(level: Dictionary) -> void:
	left_title_label.text = str(level.get("title", "未命名关卡"))
	left_sub_label.text = _level_text2(level)
	if left_lock_overlay != null:
		left_lock_overlay.visible = not _is_level_unlocked_for_dict(level)


func _bind_right_card_with_level(level: Dictionary) -> void:
	right_title_label.text = str(level.get("title", "未命名关卡"))
	right_sub_label.text = _level_text2(level)
	if right_lock_overlay != null:
		right_lock_overlay.visible = not _is_level_unlocked_for_dict(level)


func _create_far_preview_cards() -> void:
	if carousel_root == null:
		return
	_far_left_card = left_card.duplicate() as PanelContainer
	_far_right_card = right_card.duplicate() as PanelContainer
	if _far_left_card != null:
		_far_left_card.name = "FarLeftCard"
		_far_left_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carousel_root.add_child(_far_left_card)
		_far_left_card.visible = false
	if _far_right_card != null:
		_far_right_card.name = "FarRightCard"
		_far_right_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		carousel_root.add_child(_far_right_card)
		_far_right_card.visible = false


func _bind_level_to_side_card(card: PanelContainer, level: Dictionary, use_left_labels: bool) -> void:
	if card == null:
		return
	var title_path := "CardMargin/CardVBox/LeftTitle" if use_left_labels else "CardMargin/CardVBox/RightTitle"
	var sub_path := "CardMargin/CardVBox/LeftSub" if use_left_labels else "CardMargin/CardVBox/RightSub"
	var lock_path := "CardMargin/CardVBox/PreviewRect/LockOverlay"
	var title := card.get_node_or_null(title_path) as Label
	var sub := card.get_node_or_null(sub_path) as Label
	var lock := card.get_node_or_null(lock_path) as ColorRect
	if title != null:
		title.text = str(level.get("title", "未命名关卡"))
	if sub != null:
		sub.text = _level_text2(level)
	if lock != null:
		lock.visible = not _is_level_unlocked_for_dict(level)


func _apply_carousel_rest_visual() -> void:
	left_card.scale = Vector2(SIDE_SCALE, SIDE_SCALE)
	right_card.scale = Vector2(SIDE_SCALE, SIDE_SCALE)
	center_card.scale = Vector2.ONE
	left_card.modulate = SIDE_MODULATE
	right_card.modulate = SIDE_MODULATE
	center_card.modulate = Color.WHITE
	left_card.z_index = 1
	right_card.z_index = 1
	center_card.z_index = 5
	if _far_left_card != null:
		_far_left_card.visible = false
	if _far_right_card != null:
		_far_right_card.visible = false


func setup(
	chapter_id: int,
	chapter_manager: ChapterManager,
	save_manager: SaveManager,
	condition_checker: ConditionChecker
) -> void:
	_chapter_id = chapter_id
	_chapter_manager = chapter_manager
	_save_manager = save_manager
	_condition_checker = condition_checker
	_chapter = {}
	_levels.clear()
	_required_counts_by_level_id.clear()
	_current_index = 0

	if _chapter_manager != null:
		_chapter = _chapter_manager.get_chapter_by_id(_chapter_id)
		_levels = _chapter_manager.get_levels_for_chapter(_chapter_id)
		_current_index = _pick_default_level_index()

	if _save_manager != null:
		_save_manager.set_recent_opened_chapter_id(_chapter_id)

	_reset_carousel_interaction_state()
	_refresh()
	call_deferred("_realign_carousel_after_show")


func show_status(text: String) -> void:
	message_label.text = text


func focus_level_by_id(level_id: String) -> void:
	if level_id.is_empty() or _levels.is_empty():
		return
	for i in range(_levels.size()):
		if str(_levels[i].get("levelid", "")) == level_id:
			_reset_carousel_interaction_state()
			_current_index = i
			_refresh()
			call_deferred("_realign_carousel_after_show")
			return


func _refresh() -> void:
	_update_side_cards()
	_update_center_card()
	_update_dots()
	_update_action()
	condition_bubble.visible = false
	if not _animating and not _dragging:
		_apply_carousel_rest_visual()


func _update_side_cards() -> void:
	left_card.visible = _current_index > 0
	right_card.visible = _current_index < _levels.size() - 1
	if left_card.visible:
		var left_level: Dictionary = _levels[_current_index - 1]
		left_title_label.text = str(left_level.get("title", "未命名关卡"))
		left_sub_label.text = _level_text2(left_level)
		left_lock_overlay.visible = not _is_level_unlocked_for_dict(left_level)
	elif left_lock_overlay != null:
		left_lock_overlay.visible = false
	if right_card.visible:
		var right_level: Dictionary = _levels[_current_index + 1]
		right_title_label.text = str(right_level.get("title", "未命名关卡"))
		right_sub_label.text = _level_text2(right_level)
		right_lock_overlay.visible = not _is_level_unlocked_for_dict(right_level)
	elif right_lock_overlay != null:
		right_lock_overlay.visible = false


func _update_center_card() -> void:
	if _levels.is_empty():
		title_label.text = "暂无关卡"
		sub_label.text = "请先在 levels 表添加本章关卡"
		preview_rect.color = Color("D2D2D2")
		lock_overlay.visible = false
		message_label.text = "chapter_id=%d 还没有关卡数据" % _chapter_id
		return

	var level: Dictionary = _current_level()
	title_label.text = str(level.get("title", "未命名关卡"))
	sub_label.text = _level_text2(level)
	preview_rect.color = Color("D2D2D2")
	message_label.text = ""
	lock_overlay.visible = not _is_current_level_unlocked()


func _level_text2(level: Dictionary) -> String:
	var text2: String = str(level.get("text2", ""))
	if not text2.is_empty():
		return text2
	var order: int = int(level.get("order", _current_index + 1))
	return "第 %d 关" % order


func _update_dots() -> void:
	if _levels.is_empty():
		dots_label.text = ""
		return

	var dots := PackedStringArray()
	var max_start: int = max(0, _levels.size() - 4)
	var start: int = clampi(_current_index - 1, 0, max_start)
	var end: int = min(start + 4, _levels.size())
	for i in range(start, end):
		if i == _current_index:
			dots.append("●")
		else:
			dots.append("•")
	dots_label.text = " ".join(dots)


func _update_action() -> void:
	if _levels.is_empty():
		action_button.visible = true
		action_button.disabled = true
		action_button.text = "暂无关卡"
		progress_panel.visible = false
		return

	action_button.disabled = false
	progress_panel.visible = false

	if not _is_chapter_unlocked():
		action_button.visible = false
		return

	if _is_current_level_unlocked():
		action_button.visible = true
		action_button.text = "探索"
		return

	action_button.visible = false


func _is_chapter_unlocked() -> bool:
	if _chapter_id <= 0:
		return false
	if _save_manager == null:
		return false
	return _save_manager.is_chapter_available(_chapter_id, _chapter_manager, _condition_checker)


func _on_action_pressed() -> void:
	if _levels.is_empty():
		return
	if not _is_current_level_unlocked():
		_show_current_level_locked_bubble()
		return
	_start_current_level()


func _start_current_level() -> void:
	if not _is_current_level_unlocked():
		_show_current_level_locked_bubble()
		return
	var level: Dictionary = _current_level().duplicate(true)
	if _save_manager != null:
		_save_manager.set_recent_opened_level_id(str(level.get("levelid", "")))
	level_start_requested.emit(level)


func _current_level() -> Dictionary:
	if _levels.is_empty():
		return {}
	_current_index = clampi(_current_index, 0, _levels.size() - 1)
	return _levels[_current_index]


func _pick_default_level_index() -> int:
	if _levels.is_empty() or _save_manager == null:
		return 0
	var recent_level_id: String = _save_manager.get_recent_opened_level_id()
	if recent_level_id.is_empty():
		return 0
	for i in range(_levels.size()):
		if str(_levels[i].get("level_id", "")) == recent_level_id:
			return i
	return 0


func _update_progress_panel() -> void:
	progress_panel.visible = false


func _is_level_unlocked_for_dict(level: Dictionary) -> bool:
	if level.is_empty():
		return false
	if not _is_chapter_unlocked():
		return false
	var level_id: String = str(level.get("levelid", ""))
	if _save_manager != null:
		if _save_manager.is_level_unlocked(level_id) or _save_manager.is_level_completed(level_id):
			return true
	var condition_id: int = int(level.get("unlockconditionid", 0))
	if condition_id <= 0:
		return true
	if _condition_checker == null:
		return false
	var condition_pass: bool = _condition_checker.is_level_condition_met(condition_id, level, _levels)
	return condition_pass


func _is_current_level_unlocked() -> bool:
	if _levels.is_empty():
		return false
	return _is_level_unlocked_for_dict(_current_level())


func _show_level_locked_prompt(level: Dictionary, for_center_card: bool = false) -> void:
	var condition_id: int = int(level.get("unlockconditionid", 0))
	var text: String = ""
	if not _is_chapter_unlocked() and _condition_checker != null:
		text = _condition_checker.get_fail_text(int(_chapter.get("condition_id", 0)))
	elif _condition_checker != null:
		text = _condition_checker.get_fail_text(condition_id)
	if text.is_empty():
		text = "该关卡尚未解锁"
	condition_bubble_label.text = text
	condition_bubble.visible = true


func _show_current_level_locked_bubble() -> void:
	_show_level_locked_prompt(_current_level(), true)


func _on_side_card_gui_input(side: int, event: InputEvent) -> void:
	if _animating:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_side_gesture_side = side
			_side_gesture_start_x = mb.position.x
		else:
			if _side_gesture_side == side and absf(mb.position.x - _side_gesture_start_x) < 14.0:
				_on_side_card_tapped(side)
			_side_gesture_side = 0
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_side_gesture_side = side
			_side_gesture_start_x = touch.position.x
		else:
			if _side_gesture_side == side and absf(touch.position.x - _side_gesture_start_x) < 14.0:
				_on_side_card_tapped(side)
			_side_gesture_side = 0


func _on_side_card_tapped(side: int) -> void:
	var idx: int = _current_index + side
	if idx < 0 or idx >= _levels.size():
		return
	var lvl: Dictionary = _levels[idx]
	var unlocked := _is_level_unlocked_for_dict(lvl)
	if unlocked:
		_go_to_index(idx, side)
	else:
		_show_level_locked_prompt(lvl, false)


func _load_level_required_counts() -> void:
	# 关卡内词条进度已迁移到 idol 底部栏；选关页不再读取旧 level_props。
	_required_counts_by_level_id.clear()


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Array:
		return parsed
	return []


func _on_center_card_gui_input(event: InputEvent) -> void:
	if _animating:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_drag_start_x = mb.position.x
		var is_click: bool = absf(mb.position.x - _drag_start_x) < 12.0
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and is_click:
			if _is_current_level_unlocked():
				_start_current_level()
			else:
				_show_current_level_locked_bubble()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_drag_start_x = touch.position.x
		var is_tap: bool = absf(touch.position.x - _drag_start_x) < 12.0
		if not touch.pressed and is_tap:
			if _is_current_level_unlocked():
				_start_current_level()
			else:
				_show_current_level_locked_bubble()


func _on_carousel_drag_end() -> void:
	if _levels.size() <= 1:
		_kill_carousel_tween()
		_live_drag_offset = 0.0
		_reset_carousel_layout_to_bases()
		_apply_carousel_rest_visual()
		return
	var off: float = _live_drag_offset
	if absf(off) < SWIPE_THRESHOLD:
		_kill_carousel_tween()
		_live_drag_offset = 0.0
		_reset_carousel_layout_to_bases()
		_apply_carousel_rest_visual()
		return
	var index_delta: int = -1 if off > 0.0 else 1
	var target_idx: int = _current_index + index_delta
	if target_idx < 0 or target_idx >= _levels.size():
		_tween_carousel_snap_back_overshoot()
		return
	## 滑动仅用于浏览关卡位；未解锁也可切换索引，进入关卡仍由中心卡/按钮逻辑拦截。
	_tween_carousel_commit(index_delta)


func _tween_carousel_snap_back_overshoot() -> void:
	_kill_carousel_tween()
	if absf(_live_drag_offset) < 0.5:
		_live_drag_offset = 0.0
		_reset_carousel_layout_to_bases()
		_apply_carousel_rest_visual()
		return
	_animating = true
	var start: float = _live_drag_offset
	_active_carousel_tween = create_tween()
	_active_carousel_tween.tween_method(
		func(v: float) -> void:
			_live_drag_offset = v
			_apply_carousel_drag_visual(),
		start,
		0.0,
		ANIM_DURATION * 0.55
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_carousel_tween.finished.connect(func() -> void:
		_live_drag_offset = 0.0
		_reset_carousel_layout_to_bases()
		_apply_carousel_rest_visual()
		_animating = false
	)


func _tween_carousel_commit(index_delta: int) -> void:
	_kill_carousel_tween()
	_animating = true
	var start: float = _live_drag_offset
	var target: float = -_slide_range_px if index_delta > 0 else _slide_range_px
	var new_index: int = clampi(_current_index + index_delta, 0, maxi(_levels.size() - 1, 0))
	_active_carousel_tween = create_tween()
	_active_carousel_tween.tween_method(
		func(v: float) -> void:
			_live_drag_offset = v
			_apply_carousel_drag_visual(),
		start,
		target,
		ANIM_DURATION * 0.42
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_active_carousel_tween.finished.connect(func() -> void:
		_current_index = new_index
		_live_drag_offset = 0.0
		_reset_card_positions_after_slide()
		_animating = false
		_refresh()
	)


func _input(event: InputEvent) -> void:
	if not visible or _animating:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dragging = true
			_drag_start_global_x = touch.position.x
			_live_drag_offset = 0.0
			_kill_carousel_tween()
			_apply_carousel_drag_visual()
		else:
			if _dragging:
				_on_carousel_drag_end()
			_dragging = false
	elif event is InputEventScreenDrag:
		if not _dragging:
			return
		var drag_ev := event as InputEventScreenDrag
		_live_drag_offset = drag_ev.position.x - _drag_start_global_x
		_apply_carousel_drag_visual()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_dragging = true
			_drag_start_global_x = mb.global_position.x
			_live_drag_offset = 0.0
			_kill_carousel_tween()
			_apply_carousel_drag_visual()
		else:
			if _dragging:
				_on_carousel_drag_end()
			_dragging = false
	elif event is InputEventMouseMotion:
		if not _dragging:
			return
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_live_drag_offset = mm.global_position.x - _drag_start_global_x
			_apply_carousel_drag_visual()


func _go_to_index(target_index: int, direction: int) -> void:
	target_index = clampi(target_index, 0, _levels.size() - 1)
	if target_index == _current_index:
		return
	_kill_carousel_tween()
	_live_drag_offset = 0.0
	_reset_carousel_layout_to_bases()
	_apply_carousel_rest_visual()
	_animating = true

	var leaving_card := center_card
	var entering_card := right_card
	var leaving_target := _left_card_pos
	if direction < 0:
		entering_card = left_card
		leaving_target = _right_card_pos

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(leaving_card, "position", leaving_target, ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(leaving_card, "scale", Vector2(SIDE_SCALE, SIDE_SCALE), ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(leaving_card, "modulate", SIDE_MODULATE, ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	if entering_card.visible:
		entering_card.z_index = 8
		tween.tween_property(entering_card, "position", _center_card_pos, ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(entering_card, "scale", Vector2.ONE, ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(entering_card, "modulate", Color.WHITE, ANIM_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	tween.finished.connect(func() -> void:
		_current_index = target_index
		_reset_card_positions_after_slide()
		_animating = false
		_refresh()
	)


func _reset_card_positions_after_slide() -> void:
	left_card.position = _left_card_pos
	center_card.position = _center_card_pos
	right_card.position = _right_card_pos
	_apply_carousel_rest_visual()


func _apply_panel_style(panel: PanelContainer, color: Color, radius: int) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	panel.add_theme_stylebox_override("panel", style)
