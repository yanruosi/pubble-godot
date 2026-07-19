extends Node

## SaveManager 公开 API 委托（非 Autoload）

const _LevelApi = preload("res://scripts/data/save_level_api.gd")
const _PlayerApi = preload("res://scripts/data/save_player_api.gd")


func is_chapter_available(chapter_id: int, chapter_manager: ChapterManager, condition_checker: ConditionChecker) -> bool:
	return _LevelApi.is_chapter_available(self, chapter_id, chapter_manager, condition_checker)


func get_currency(category: int) -> int:
	return _PlayerApi.get_currency(self, category)


func set_currency(category: int, value: int) -> void:
	_PlayerApi.set_currency(self, category, value)


func add_currency(category: int, amount: int) -> void:
	_PlayerApi.add_currency(self, category, amount)


func consume_currency(category: int, amount: int) -> bool:
	return _PlayerApi.consume_currency(self, category, amount)


func get_inventory_count(itemid: int) -> int:
	return _PlayerApi.get_inventory_count(self, itemid)


func set_inventory_count(itemid: int, count: int) -> void:
	_PlayerApi.set_inventory_count(self, itemid, count)


func add_inventory_item(itemid: int, count: int = 1) -> void:
	_PlayerApi.add_inventory_item(self, itemid, count)


func remove_inventory_item(itemid: int, count: int = 1) -> bool:
	return _PlayerApi.remove_inventory_item(self, itemid, count)


func next_instance_id() -> String:
	return _PlayerApi.next_instance_id(self)


func next_queue_id() -> String:
	return _PlayerApi.next_queue_id(self)


func is_activity_first_cleared(activityid: String) -> bool:
	return _PlayerApi.is_activity_first_cleared(self, activityid)


func mark_activity_first_cleared(activityid: String) -> void:
	_PlayerApi.mark_activity_first_cleared(self, activityid)


func get_post_count(tagid: String) -> int:
	return _PlayerApi.get_post_count(self, tagid)


func add_post_count(tagid: String, count: int) -> void:
	_PlayerApi.add_post_count(self, tagid, count)


func consume_post_count(tagid: String, count: int = 1) -> bool:
	return _PlayerApi.consume_post_count(self, tagid, count)


func is_chapter_completed(chapter_id: int) -> bool:
	return _LevelApi.is_chapter_completed(self, chapter_id)


func mark_chapter_completed(chapter_id: int, completed: bool = true) -> void:
	_LevelApi.mark_chapter_completed(self, chapter_id, completed)


func is_chapter_unlocked(chapter_id: int) -> bool:
	return _LevelApi.is_chapter_unlocked(self, chapter_id)


func mark_chapter_unlocked(chapter_id: int, unlocked: bool = true) -> void:
	_LevelApi.mark_chapter_unlocked(self, chapter_id, unlocked)


func has_chapter_new_badge(chapter_id: int) -> bool:
	return _LevelApi.has_chapter_new_badge(self, chapter_id)


func mark_chapter_entered(chapter_id: int) -> void:
	_LevelApi.mark_chapter_entered(self, chapter_id)


func get_recent_opened_chapter_id() -> int:
	return _LevelApi.get_recent_opened_chapter_id(self)


func set_recent_opened_chapter_id(chapter_id: int) -> void:
	_LevelApi.set_recent_opened_chapter_id(self, chapter_id)


func get_recent_opened_level_id() -> String:
	return _LevelApi.get_recent_opened_level_id(self)


func set_recent_opened_level_id(level_id: String) -> void:
	_LevelApi.set_recent_opened_level_id(self, level_id)


func is_level_unlocked(level_id: String) -> bool:
	return _LevelApi.is_level_unlocked(self, level_id)


func mark_level_unlocked(level_id: String, unlocked: bool = true) -> void:
	_LevelApi.mark_level_unlocked(self, level_id, unlocked)


func is_level_completed(level_id: String) -> bool:
	return _LevelApi.is_level_completed(self, level_id)


func is_hotspot_clicked(level_id: String, hotspot_id: String) -> bool:
	return _LevelApi.is_hotspot_clicked(self, level_id, hotspot_id)


func mark_hotspot_clicked(level_id: String, hotspot_id: String) -> void:
	_LevelApi.mark_hotspot_clicked(self, level_id, hotspot_id)


func set_pending_post_level_nav(data: Dictionary) -> void:
	_LevelApi.set_pending_post_level_nav(self, data)


func is_feed_post_seen(post_id: String) -> bool:
	return _LevelApi.is_feed_post_seen(self, post_id)


func mark_feed_post_seen(post_id: String) -> void:
	_LevelApi.mark_feed_post_seen(self, post_id)


func get_feed_pinned_post_id() -> String:
	return _LevelApi.get_feed_pinned_post_id(self)


func set_feed_pinned_post_id(post_id: String) -> void:
	_LevelApi.set_feed_pinned_post_id(self, post_id)


func consume_pending_post_level_nav() -> Dictionary:
	return _LevelApi.consume_pending_post_level_nav(self)


func mark_level_completed(level_id: String, completed: bool = true) -> void:
	_LevelApi.mark_level_completed(self, level_id, completed)


func get_level_progress(level_id: String) -> Dictionary:
	return _LevelApi.get_level_progress(self, level_id)


func set_level_progress(level_id: String, patch: Dictionary) -> void:
	_LevelApi.set_level_progress(self, level_id, patch)


func clear_level_progress(level_id: String) -> void:
	_LevelApi.clear_level_progress(self, level_id)


func mark_hotspot_used(level_id: String, hotspot_id: String) -> void:
	_LevelApi.mark_hotspot_used(self, level_id, hotspot_id)


func get_activity_state(activityid: String) -> String:
	return _LevelApi.get_activity_state(self, activityid)


func set_activity_state(activityid: String, state: String) -> void:
	_LevelApi.set_activity_state(self, activityid, state)
