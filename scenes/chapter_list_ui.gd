extends Control

@onready var chapter_scroll: ScrollContainer = $ChapterScroll
@onready var chapter_list: VBoxContainer = $ChapterScroll/ChapterList

var _chapters_sorted: Array = []
var _condition_checker: ConditionChecker

func setup(chapters_sorted: Array, condition_checker: ConditionChecker) -> void:
	_chapters_sorted = chapters_sorted.duplicate(true)
	_condition_checker = condition_checker
	_chapters_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)

func smart_scroll_to_first_locked() -> void:
	# 固定规则：按 order，找第一个 is_condition_met == false，0.3 秒平滑滚动
	if _chapters_sorted.is_empty():
		return

	var target_index := -1
	for i in range(_chapters_sorted.size()):
		var chapter: Dictionary = _chapters_sorted[i]
		var condition_id: int = int(chapter.get("condition_id", 0))
		if _condition_checker == null or not _condition_checker.is_condition_met(condition_id):
			target_index = i
			break

	if target_index == -1:
		_smooth_scroll_to(0)
		return

	_scroll_to_chapter_index(target_index)

func _scroll_to_chapter_index(index: int) -> void:
	if index < 0 or index >= chapter_list.get_child_count():
		return
	var target_card := chapter_list.get_child(index) as Control
	if target_card == null:
		return

	var target_y: int = int(target_card.position.y)
	var max_scroll: int = int(max(0.0, chapter_scroll.get_v_scroll_bar().max_value - chapter_scroll.size.y))
	target_y = clamp(target_y, 0, max_scroll)
	_smooth_scroll_to(target_y)

func _smooth_scroll_to(target_value: int) -> void:
	var tween := create_tween()
	tween.tween_property(chapter_scroll, "scroll_vertical", target_value, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
