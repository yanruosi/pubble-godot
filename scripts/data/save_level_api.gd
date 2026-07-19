extends RefCounted
class_name SaveLevelApi

const _Progress = preload("res://scripts/data/save_level_progress.gd")

## level_progress / chapter / feed_nav API（L1 委托，签名与 SaveManager 一致）


static func is_chapter_available(sm, chapter_id: int, chapter_manager: ChapterManager, condition_checker: ConditionChecker) -> bool:
	if chapter_id <= 0:
		return false
	if is_chapter_unlocked(sm, chapter_id):
		return true
	if chapter_manager == null or condition_checker == null:
		return false
	var chapter: Dictionary = chapter_manager.get_chapter_by_id(chapter_id)
	if chapter.is_empty():
		return false
	var condition_id: int = int(chapter.get("condition_id", 0))
	if condition_id <= 0:
		return true
	return condition_checker.is_condition_met(condition_id)


static func is_chapter_completed(sm, chapter_id: int) -> bool:
	return bool(sm.chapter_completed.get(str(chapter_id), false))


static func mark_chapter_completed(sm, chapter_id: int, completed: bool = true) -> void:
	sm.chapter_completed[str(chapter_id)] = completed
	if completed:
		sm.chapter_unlocked[str(chapter_id)] = true
		sm.chapter_new_badge[str(chapter_id)] = false
	sm.save_progress()


static func is_chapter_unlocked(sm, chapter_id: int) -> bool:
	return bool(sm.chapter_unlocked.get(str(chapter_id), false))


static func mark_chapter_unlocked(sm, chapter_id: int, unlocked: bool = true) -> void:
	sm.chapter_unlocked[str(chapter_id)] = unlocked
	if unlocked:
		sm.chapter_new_badge[str(chapter_id)] = true
	sm.save_progress()


static func has_chapter_new_badge(sm, chapter_id: int) -> bool:
	return bool(sm.chapter_new_badge.get(str(chapter_id), false))


static func mark_chapter_entered(sm, chapter_id: int) -> void:
	sm.chapter_new_badge[str(chapter_id)] = false
	sm.recent_opened_chapter_id = chapter_id
	sm.save_progress()


static func get_recent_opened_chapter_id(sm) -> int:
	return sm.recent_opened_chapter_id


static func set_recent_opened_chapter_id(sm, chapter_id: int) -> void:
	sm.recent_opened_chapter_id = chapter_id
	sm.save_progress()


static func get_recent_opened_level_id(sm) -> String:
	return sm.recent_opened_level_id


static func set_recent_opened_level_id(sm, level_id: String) -> void:
	sm.recent_opened_level_id = level_id
	sm.save_progress()


static func is_level_unlocked(sm, level_id: String) -> bool:
	return bool(sm.level_unlocked.get(level_id, false))


static func mark_level_unlocked(sm, level_id: String, unlocked: bool = true) -> void:
	if level_id.is_empty():
		return
	sm.level_unlocked[level_id] = unlocked
	sm.save_progress()


static func is_level_completed(sm, level_id: String) -> bool:
	return bool(sm.level_completed.get(level_id, false))


static func is_hotspot_clicked(sm, level_id: String, hotspot_id: String) -> bool:
	if level_id.is_empty() or hotspot_id.is_empty():
		return false
	var clicked_raw: Variant = sm.level_hotspot_clicked.get(level_id, {})
	if not (clicked_raw is Dictionary):
		return false
	return bool((clicked_raw as Dictionary).get(hotspot_id, false))


static func mark_hotspot_clicked(sm, level_id: String, hotspot_id: String) -> void:
	if level_id.is_empty() or hotspot_id.is_empty():
		return
	var clicked_raw: Variant = sm.level_hotspot_clicked.get(level_id, {})
	var clicked: Dictionary = clicked_raw if clicked_raw is Dictionary else {}
	clicked[hotspot_id] = true
	sm.level_hotspot_clicked[level_id] = clicked
	sm.save_progress()


static func set_pending_post_level_nav(sm, data: Dictionary) -> void:
	sm.pending_post_level_nav = data.duplicate(true)


static func is_feed_post_seen(sm, post_id: String) -> bool:
	return bool(sm.feed_seen.get(post_id, false))


static func mark_feed_post_seen(sm, post_id: String) -> void:
	if post_id.is_empty():
		return
	sm.feed_seen[post_id] = true
	sm.save_progress()


static func get_feed_pinned_post_id(sm) -> String:
	return sm.feed_pinned_post_id


static func set_feed_pinned_post_id(sm, post_id: String) -> void:
	sm.feed_pinned_post_id = post_id
	sm.save_progress()


static func consume_pending_post_level_nav(sm) -> Dictionary:
	var copy: Dictionary = sm.pending_post_level_nav.duplicate(true)
	sm.pending_post_level_nav.clear()
	return copy


static func mark_level_completed(sm, level_id: String, completed: bool = true) -> void:
	_Progress.mark_level_completed(sm, level_id, completed)


static func get_level_progress(sm, level_id: String) -> Dictionary:
	return _Progress.get_level_progress(sm, level_id)


static func set_level_progress(sm, level_id: String, patch: Dictionary) -> void:
	_Progress.set_level_progress(sm, level_id, patch)


static func clear_level_progress(sm, level_id: String) -> void:
	_Progress.clear_level_progress(sm, level_id)


static func mark_hotspot_used(sm, level_id: String, hotspot_id: String) -> void:
	_Progress.mark_hotspot_used(sm, level_id, hotspot_id)


static func get_activity_state(sm, activityid: String) -> String:
	return _Progress.get_activity_state(sm, activityid)


static func set_activity_state(sm, activityid: String, state: String) -> void:
	_Progress.set_activity_state(sm, activityid, state)
