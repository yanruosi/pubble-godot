extends RefCounted
class_name SaveLevelProgress

## level_progress / hotspot_used / activity_state（自 save_level_api 拆出）


static func mark_level_completed(sm, level_id: String, completed: bool = true) -> void:
	if level_id.is_empty():
		return
	sm.level_completed[level_id] = completed
	if completed:
		sm.level_unlocked[level_id] = true
	sm.save_progress()


static func get_level_progress(sm, level_id: String) -> Dictionary:
	if level_id.is_empty():
		return {}
	var raw: Variant = sm.level_progress.get(level_id, {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


static func set_level_progress(sm, level_id: String, patch: Dictionary) -> void:
	if level_id.is_empty() or patch.is_empty():
		return
	var current: Dictionary = get_level_progress(sm, level_id)
	for key in patch.keys():
		current[key] = patch[key]
	sm.level_progress[level_id] = current


static func clear_level_progress(sm, level_id: String) -> void:
	if level_id.is_empty():
		return
	if is_level_completed(sm, level_id):
		var existing: Dictionary = get_level_progress(sm, level_id)
		sm.level_progress[level_id] = {
			"scroll_fills": existing.get("scroll_fills", {}),
			"identity_fills": existing.get("identity_fills", {}),
			"slots_completed": existing.get("slots_completed", {}),
		}
	else:
		sm.level_progress.erase(level_id)
	sm.save_progress()


static func mark_hotspot_used(sm, level_id: String, hotspot_id: String) -> void:
	if level_id.is_empty() or hotspot_id.is_empty():
		return
	var current: Dictionary = get_level_progress(sm, level_id)
	var used_raw: Variant = current.get("hotspot_used", [])
	var used: Array = (used_raw as Array).duplicate() if used_raw is Array else []
	if not used.has(hotspot_id):
		used.append(hotspot_id)
	current["hotspot_used"] = used
	sm.level_progress[level_id] = current


static func get_activity_state(sm, activityid: String) -> String:
	if activityid.is_empty():
		return ""
	return str(sm.activity_state.get(activityid, ""))


static func set_activity_state(sm, activityid: String, state: String) -> void:
	if activityid.is_empty() or state.is_empty():
		return
	sm.activity_state[activityid] = state
	sm.save_progress()


static func is_level_completed(sm, level_id: String) -> bool:
	return bool(sm.level_completed.get(level_id, false))
