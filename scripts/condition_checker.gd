extends Node
class_name ConditionChecker

var _chapter_manager: ChapterManager
var _save_manager: SaveManager
var _economy_manager: EconomyManager


func setup(chapter_manager: ChapterManager, save_manager: SaveManager) -> void:
	_chapter_manager = chapter_manager
	_save_manager = save_manager
	_economy_manager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager


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
		2:
			return _save_manager.is_chapter_completed(param)
		5:
			var intel_lv := _get_intel_level()
			var met := intel_lv >= param
			#region agent log
			if condition_id == 4:
				_agent_debug_log("H1", "condition_checker.gd:is_condition_met", "type5_check", {
					"condition_id": condition_id,
					"param": param,
					"intellevel": intel_lv,
					"met": met,
					"save_manager_null": _save_manager == null,
					"chapter_manager_null": _chapter_manager == null,
				})
			#endregion
			return met
		6:
			return _get_fan_level() >= param
		7:
			return _save_manager.get_inventory_count(param) >= 1
		_:
			return false


func is_feed_post_visible(post: Dictionary) -> bool:
	var condition_id := int(post.get("condition_id", 0))
	return is_condition_met(condition_id)


func is_feed_post_enterable(post: Dictionary, chapter_levels: Array) -> bool:
	if not is_feed_post_visible(post):
		return false
	var level_id: String = str(post.get("level_id", ""))
	if level_id.is_empty():
		return false
	var level: Dictionary = _chapter_manager.get_level_by_id(level_id) if _chapter_manager else {}
	if level.is_empty():
		return false
	var unlock_id: int = int(level.get("unlockconditionid", 0))
	return is_level_condition_met(unlock_id, level, chapter_levels)


func is_feed_post_locked_visible(post: Dictionary, chapter_levels: Array) -> bool:
	return is_feed_post_visible(post) and not is_feed_post_enterable(post, chapter_levels)


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
		best_level_id = str(level.get("levelid", ""))
	return best_level_id


func get_fail_text(condition_id: int) -> String:
	if _chapter_manager == null:
		return ""
	var condition := _chapter_manager.get_condition_by_id(condition_id)
	return str(condition.get("txt", ""))


func _get_intel_level() -> int:
	if _economy_manager != null:
		return _economy_manager.get_intel_level()
	if _save_manager != null:
		return _save_manager.intellevel
	return 0


func _get_fan_level() -> int:
	if _economy_manager != null:
		return _economy_manager.get_fan_level()
	if _save_manager != null:
		return _save_manager.fanlevel
	return 0


#region agent log
func _agent_debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "580f3e",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"runId": "pre-fix",
	}
	var file := FileAccess.open("res://debug-580f3e.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("res://debug-580f3e.log", FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_string(JSON.stringify(payload) + "\n")
	file.close()
#endregion
