extends Control

signal chapter_selected(chapter_id: int)

# 可调参数（按 540x960 初始）
const BASE_CARD_SIZE := Vector2(520.0, 200.0)
const LAYER_SCALES := [1.0, 0.90, 0.83, 0.775]
const LAYER_OFFSET_Y := [0.0, 18.0, 36.0, 54.0]
const LAYER_TINTS := [
	Color(1.0, 1.0, 1.0, 1.0),      # 当前卡
	Color(0.65, 0.65, 0.65, 1.0),   # 后1层：灰度最重
	Color(0.80, 0.80, 0.80, 1.0),   # 后2层：中灰
	Color(0.92, 0.92, 0.92, 1.0)    # 后3层：轻灰
]
const BASE_TOP_Y := 100.0
const ANIM_DURATION := 0.28
const SWIPE_THRESHOLD := 45.0

const CHAPTER_CARD_SCENE := preload("res://scenes/chapter_card.tscn")
const DEBUG_LOG_PATH := "D:/GAMES/pubble/debug-fe0741.log"

const STATE_LOCKED := 0
const STATE_IN_PROGRESS := 1
const STATE_DONE := 2

var _chapters: Array = []
var _save_manager: SaveManager
var _cards: Array[Button] = []
var _card_states: Dictionary = {}
var _current_index: int = 0
var _drag_start_y: float = 0.0
var _drag_start_pos := Vector2.ZERO
var _dragging: bool = false

#region agent log
func _dbg(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "run1") -> void:
	var payload := {
		"sessionId": "fe0741",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f: FileAccess = FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

func setup(chapters_sorted: Array, save_manager: SaveManager) -> void:
	_chapters = chapters_sorted.duplicate(true)
	_save_manager = save_manager
	_chapters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	_rebuild_cards()

func _rebuild_cards() -> void:
	for child in get_children():
		child.queue_free()
	_cards.clear()
	_card_states.clear()

	if _chapters.is_empty():
		return

	for chapter in _chapters:
		var chapter_id: int = int(chapter.get("id", 0))
		var state: int = _calc_state(chapter_id)
		_card_states[chapter_id] = state

		var card := CHAPTER_CARD_SCENE.instantiate() as Button
		if card == null:
			continue
		card.name = "ChapterCard_%d" % chapter_id
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(card)
		card.position = Vector2(0, 0)
		card.custom_minimum_size.x = max(0.0, size.x)

		if card.has_method("setup"):
			card.call("setup", chapter, state)
		if card.has_method("set_new_badge_visible"):
			card.call("set_new_badge_visible", _is_new_badge_visible(chapter_id))

		_cards.append(card)

	_current_index = _pick_default_index()
	_layout_cards(false)

func _calc_state(chapter_id: int) -> int:
	if _save_manager != null and _save_manager.is_chapter_completed(chapter_id):
		return STATE_DONE
	var chapter_manager := get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	var condition_checker := get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	if _save_manager != null and _save_manager.is_chapter_available(chapter_id, chapter_manager, condition_checker):
		return STATE_IN_PROGRESS
	return STATE_LOCKED

func _is_new_badge_visible(chapter_id: int) -> bool:
	if _save_manager == null:
		return false
	return _save_manager.has_chapter_new_badge(chapter_id)

func _pick_default_index() -> int:
	if _chapters.is_empty():
		return 0

	if _save_manager != null:
		var recent_chapter_id := _save_manager.get_recent_opened_chapter_id()
		if recent_chapter_id > 0:
			var recent_index := _find_index_by_chapter_id(recent_chapter_id)
			if recent_index >= 0:
				#region agent log
				_dbg("H3", "card_stack_ui.gd:_pick_default_index", "pick recent chapter", {"recent_chapter_id": recent_chapter_id, "recent_index": recent_index})
				#endregion
				return recent_index

	if _is_partial_unlock_state() and _save_manager != null:
		var first_in_progress := _find_first_index_by_state(STATE_IN_PROGRESS)
		if first_in_progress >= 0:
			#region agent log
			_dbg("H3", "card_stack_ui.gd:_pick_default_index", "pick first in progress", {"first_in_progress": first_in_progress})
			#endregion
			return first_in_progress

	# 全锁或全解锁/已完成时，固定回到 order 最小的第一章。
	#region agent log
	_dbg(
		"H3",
		"card_stack_ui.gd:_pick_default_index",
		"fallback to 0",
		{
			"chapters_size": _chapters.size(),
			"partial_unlock_state": _is_partial_unlock_state(),
			"recent_chapter_id": _save_manager.get_recent_opened_chapter_id() if _save_manager != null else -1
		}
	)
	#endregion
	return 0

func _is_partial_unlock_state() -> bool:
	var locked_count := 0
	var available_count := 0
	for chapter in _chapters:
		var chapter_id: int = int(chapter.get("id", 0))
		var state: int = int(_card_states.get(chapter_id, STATE_LOCKED))
		if state == STATE_LOCKED:
			locked_count += 1
		else:
			available_count += 1
	return locked_count > 0 and available_count > 0

func _find_index_by_chapter_id(chapter_id: int) -> int:
	for i in range(_chapters.size()):
		if int(_chapters[i].get("id", 0)) == chapter_id:
			return i
	return -1

func _find_first_index_by_state(state: int) -> int:
	for i in range(_chapters.size()):
		var chapter_id: int = int(_chapters[i].get("id", 0))
		if int(_card_states.get(chapter_id, STATE_LOCKED)) == state:
			return i
	return -1

func _layout_cards(animated: bool) -> void:
	if _cards.is_empty():
		return

	for i in range(_cards.size()):
		var card: Button = _cards[i]
		var delta: int = i - _current_index
		var depth: int = absi(delta)
		var sign_dir: float = 1.0
		if delta < 0:
			sign_dir = -1.0

		var target_scale: float = _get_layer_scale(depth)
		var target_size: Vector2 = BASE_CARD_SIZE * target_scale
		var target_offset_y: float = _get_layer_offset(depth)
		var target_x: float = (size.x - target_size.x) * 0.5
		var target_y: float = BASE_TOP_Y + sign_dir * target_offset_y
		var target_pos: Vector2 = Vector2(target_x, target_y)
		var target_tint: Color = _get_layer_tint(depth)

		card.custom_minimum_size = target_size
		card.size = target_size
		card.pivot_offset = target_size * 0.5
		card.z_index = 100 - depth
		if animated:
			var tween := create_tween()
			tween.tween_property(card, "position", target_pos, ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(card, "scale", Vector2(target_scale, target_scale), ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(card, "modulate", target_tint, ANIM_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			card.position = target_pos
			card.scale = Vector2(target_scale, target_scale)
			card.modulate = target_tint

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_dragging = true
			_drag_start_y = touch.position.y
			_drag_start_pos = touch.position
		else:
			if _dragging:
				_handle_pointer_release(touch.position)
			_dragging = false
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start_y = mb.position.y
				_drag_start_pos = mb.position
			else:
				if _dragging:
					_handle_pointer_release(mb.position)
				_dragging = false

func _handle_pointer_release(release_pos: Vector2) -> void:
	var delta := release_pos - _drag_start_pos
	if absf(delta.y) >= SWIPE_THRESHOLD:
		_handle_drag_end(delta.y)
		return
	if delta.length() < 12.0:
		_emit_current_chapter_selected()

func _emit_current_chapter_selected() -> void:
	if _chapters.is_empty():
		return
	_current_index = clampi(_current_index, 0, _chapters.size() - 1)
	var chapter_id: int = int(_chapters[_current_index].get("id", 0))
	if chapter_id > 0:
		chapter_selected.emit(chapter_id)

func _handle_drag_end(delta_y: float) -> void:
	if absf(delta_y) < SWIPE_THRESHOLD:
		return
	if delta_y < 0.0:
		_current_index = min(_current_index + 1, max(0, _cards.size() - 1))
	else:
		_current_index = max(_current_index - 1, 0)
	_layout_cards(true)

func refresh_state() -> void:
	_rebuild_cards()

func clear_new_badge_if_present(chapter_id: int) -> void:
	if _save_manager == null:
		return
	_save_manager.mark_chapter_entered(chapter_id)
	refresh_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cards(false)

func _get_layer_scale(depth: int) -> float:
	if depth < LAYER_SCALES.size():
		return float(LAYER_SCALES[depth])
	return float(LAYER_SCALES[LAYER_SCALES.size() - 1])

func _get_layer_offset(depth: int) -> float:
	if depth < LAYER_OFFSET_Y.size():
		return float(LAYER_OFFSET_Y[depth])
	var step: float = float(LAYER_OFFSET_Y[LAYER_OFFSET_Y.size() - 1] - LAYER_OFFSET_Y[LAYER_OFFSET_Y.size() - 2])
	return float(LAYER_OFFSET_Y[LAYER_OFFSET_Y.size() - 1]) + (depth - (LAYER_OFFSET_Y.size() - 1)) * step

func _get_layer_tint(depth: int) -> Color:
	if depth < LAYER_TINTS.size():
		return Color(LAYER_TINTS[depth])
	return Color(LAYER_TINTS[LAYER_TINTS.size() - 1])
