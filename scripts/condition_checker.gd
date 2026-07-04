extends Node
class_name ConditionChecker

var _chapter_manager: ChapterManager
var _save_manager: SaveManager

func setup(chapter_manager: ChapterManager, save_manager: SaveManager) -> void:
	_chapter_manager = chapter_manager
	_save_manager = save_manager

func is_condition_met(condition_id: int) -> bool:
	if condition_id <= 0:
		return true
	if _chapter_manager == null or _save_manager == null:
		return false

	var condition := _chapter_manager.get_condition_by_id(condition_id)
	if condition.is_empty():
		return false

	var cond_type: int = int(condition.get("type", 0))
	var param: int = int(condition.get("param", 0))

	match cond_type:
		1:
			return _save_manager.get_cheer_count() >= param
		2:
			return _save_manager.is_chapter_completed(param)
		4:
			# type4：param 表示「第 N 关已解锁」（查第 1 章 levels.order）
			return _is_chapter_level_order_unlocked(1, param)
		_:
			return false

# 动态帖是否可见：读帖子的 condition_id，交给 is_condition_met 判定
func is_feed_post_visible(post: Dictionary) -> bool:
	var condition_id := int(post.get("condition_id", 0))
	return is_condition_met(condition_id)

# 指定章节中 order==target_order 的关卡是否已解锁（或已通关）
func _is_chapter_level_order_unlocked(chapter_id: int, target_order: int) -> bool:
	if target_order <= 0:
		return true
	if _chapter_manager == null or _save_manager == null:
		return false
	for item in _chapter_manager.get_levels_for_chapter(chapter_id):
		if not (item is Dictionary):
			continue
		var level: Dictionary = item as Dictionary
		if int(level.get("order", 0)) != target_order:
			continue
		var level_id: String = str(level.get("level_id", ""))
		if level_id.is_empty():
			return false
		return _save_manager.is_level_unlocked(level_id) or _save_manager.is_level_completed(level_id)
	return false

func is_level_condition_met(condition_id: int, current_level: Dictionary, chapter_levels: Array) -> bool:
	if condition_id <= 0:
		return true
	if _chapter_manager == null or _save_manager == null:
		return false

	var condition: Dictionary = _chapter_manager.get_condition_by_id(condition_id)
	if condition.is_empty():
		return false

	var cond_type: int = int(condition.get("type", 0))
	if cond_type != 3:
		return is_condition_met(condition_id)

	var current_order: int = int(current_level.get("order", 0))
	if current_order <= 1:
		return true

	var previous_level_id: String = _find_previous_level_id(current_order, chapter_levels)
	if previous_level_id.is_empty():
		return false
	return _save_manager.is_level_completed(previous_level_id)

func _find_previous_level_id(current_order: int, chapter_levels: Array) -> String:
	var best_order: int = -1
	var best_level_id: String = ""
	for item in chapter_levels:
		if not (item is Dictionary):
			continue
		var level: Dictionary = item as Dictionary
		var order: int = int(level.get("order", 0))
		if order >= current_order or order <= best_order:
			continue
		best_order = order
		best_level_id = str(level.get("level_id", ""))
	return best_level_id

func get_fail_text(condition_id: int) -> String:
	if _chapter_manager == null:
		return ""
	var condition := _chapter_manager.get_condition_by_id(condition_id)
	return str(condition.get("txt", ""))
