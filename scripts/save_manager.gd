extends Node
class_name SaveManager

const SAVE_PATH := "user://progress.cfg"
const SAVE_VERSION := 2

const CAT_FP := 22
const CAT_STARS := 23
const CAT_INTEL := 24

var chapter_completed: Dictionary = {}
var chapter_unlocked: Dictionary = {}
var chapter_new_badge: Dictionary = {}
var level_unlocked: Dictionary = {}
var level_completed: Dictionary = {}
var level_progress: Dictionary = {}
var level_hotspot_clicked: Dictionary = {}
var recent_opened_chapter_id: int = 0
var recent_opened_level_id: String = ""

var fp: int = 0
var intel: int = 0
var stars: int = 0
var intellevel: int = 0
var fanlevel: int = 0
var stationexp: int = 0
var tutorialstep: int = 0
var tutorialdone: bool = false

var inventory: Dictionary = {}
var feed_instances: Array = []
var banner_last_offline_ts: int = 0
var _instance_id_counter: int = 0

## 关卡结算后 change_scene 回主界面时消费；不写盘。
var pending_post_level_nav: Dictionary = {}

var feed_seen: Dictionary = {}
var feed_pinned_post_id: String = ""

## 标题页 → 主界面接力；瞬态，不写盘。"home" / "continue" / ""
var boot_target: String = ""

var save_version_invalid: bool = false


func _init() -> void:
	load_progress()


func load_progress() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		_apply_defaults_after_fresh_save()
		save_progress()
		return

	var version: int = int(config.get_value("meta", "save_version", 0))
	if version < SAVE_VERSION:
		push_warning("Save version %d < %d; reset required" % [version, SAVE_VERSION])
		save_version_invalid = true
		_apply_defaults_after_fresh_save()
		save_progress()
		return

	save_version_invalid = false
	fp = int(config.get_value("player", "fp", 0))
	intel = int(config.get_value("player", "intel", 0))
	stars = int(config.get_value("player", "stars", 0))
	intellevel = int(config.get_value("player", "intellevel", 0))
	fanlevel = int(config.get_value("player", "fanlevel", 0))
	stationexp = int(config.get_value("player", "stationexp", 0))
	tutorialstep = int(config.get_value("player", "tutorialstep", 0))
	tutorialdone = bool(config.get_value("player", "tutorialdone", false))
	recent_opened_chapter_id = int(config.get_value("player", "recent_opened_chapter_id", 0))
	recent_opened_level_id = str(config.get_value("player", "recent_opened_level_id", ""))

	chapter_completed = _as_dict(config.get_value("chapter", "completed", {}))
	chapter_unlocked = _as_dict(config.get_value("chapter", "unlocked", {}))
	chapter_new_badge = _as_dict(config.get_value("chapter", "new_badge", {}))
	level_unlocked = _as_dict(config.get_value("level", "unlocked", {}))
	level_completed = _as_dict(config.get_value("level", "completed", {}))
	level_progress = _as_dict(config.get_value("level", "progress", {}))
	level_hotspot_clicked = _as_dict(config.get_value("level_hotspot", "clicked", {}))
	inventory = _as_dict(config.get_value("inventory", "items", {}))
	feed_instances = _as_array(config.get_value("instances", "feed", []))
	banner_last_offline_ts = int(config.get_value("banner", "last_offline_ts", 0))
	_instance_id_counter = int(config.get_value("instances", "id_counter", 0))
	feed_seen = _as_dict(config.get_value("feed", "seen", {}))
	feed_pinned_post_id = str(config.get_value("feed", "pinned_post_id", ""))


func _apply_defaults_after_fresh_save() -> void:
	fp = 0
	intel = 0
	stars = 0
	intellevel = 0
	fanlevel = 0
	stationexp = 0
	tutorialstep = 0
	tutorialdone = false
	inventory = {}
	feed_instances = []
	banner_last_offline_ts = int(Time.get_unix_time_from_system())
	_instance_id_counter = 0


func _as_dict(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v
	return {}


func _as_array(v: Variant) -> Array:
	if v is Array:
		return v
	return []


func is_game_started() -> bool:
	return _get_game_started()


func mark_game_started() -> void:
	_set_game_started(true)


func can_continue() -> bool:
	return _get_game_started() and not save_version_invalid


func reset_progress() -> void:
	chapter_completed.clear()
	chapter_unlocked.clear()
	chapter_new_badge.clear()
	level_unlocked.clear()
	level_completed.clear()
	level_progress.clear()
	level_hotspot_clicked.clear()
	feed_seen.clear()
	feed_pinned_post_id = ""
	recent_opened_chapter_id = 0
	recent_opened_level_id = ""
	pending_post_level_nav.clear()
	_apply_defaults_after_fresh_save()
	mark_chapter_unlocked(1, true)
	chapter_new_badge["1"] = false
	mark_level_unlocked("ch1_l01", true)
	save_progress()
	_set_game_started(true)


func _get_game_started() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	return bool(config.get_value("player", "game_started", false))


func _set_game_started(started: bool) -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("player", "game_started", started)
	config.save(SAVE_PATH)


func is_chapter_available(chapter_id: int, chapter_manager: ChapterManager, condition_checker: ConditionChecker) -> bool:
	if chapter_id <= 0:
		return false
	if is_chapter_unlocked(chapter_id):
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


func save_progress() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("meta", "save_version", SAVE_VERSION)
	config.set_value("player", "fp", fp)
	config.set_value("player", "intel", intel)
	config.set_value("player", "stars", stars)
	config.set_value("player", "intellevel", intellevel)
	config.set_value("player", "fanlevel", fanlevel)
	config.set_value("player", "stationexp", stationexp)
	config.set_value("player", "tutorialstep", tutorialstep)
	config.set_value("player", "tutorialdone", tutorialdone)
	config.set_value("player", "recent_opened_chapter_id", recent_opened_chapter_id)
	config.set_value("player", "recent_opened_level_id", recent_opened_level_id)
	config.set_value("chapter", "completed", chapter_completed)
	config.set_value("chapter", "unlocked", chapter_unlocked)
	config.set_value("chapter", "new_badge", chapter_new_badge)
	config.set_value("level", "unlocked", level_unlocked)
	config.set_value("level", "completed", level_completed)
	config.set_value("level", "progress", level_progress)
	config.set_value("level_hotspot", "clicked", level_hotspot_clicked)
	config.set_value("inventory", "items", inventory)
	config.set_value("instances", "feed", feed_instances)
	config.set_value("instances", "id_counter", _instance_id_counter)
	config.set_value("banner", "last_offline_ts", banner_last_offline_ts)
	config.set_value("feed", "seen", feed_seen)
	config.set_value("feed", "pinned_post_id", feed_pinned_post_id)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Save progress failed: %d" % err)


func get_currency(category: int) -> int:
	match category:
		CAT_FP:
			return fp
		CAT_STARS:
			return stars
		CAT_INTEL:
			return intel
		_:
			return 0


func set_currency(category: int, value: int) -> void:
	var v: int = max(value, 0)
	match category:
		CAT_FP:
			fp = v
		CAT_STARS:
			stars = v
		CAT_INTEL:
			intel = v


func add_currency(category: int, amount: int) -> void:
	if amount <= 0:
		return
	set_currency(category, get_currency(category) + amount)


func consume_currency(category: int, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_currency(category) < amount:
		return false
	set_currency(category, get_currency(category) - amount)
	return true


func get_inventory_count(itemid: int) -> int:
	return int(inventory.get(str(itemid), 0))


func set_inventory_count(itemid: int, count: int) -> void:
	var key := str(itemid)
	if count <= 0:
		inventory.erase(key)
	else:
		inventory[key] = count


func add_inventory_item(itemid: int, count: int = 1) -> void:
	if count <= 0:
		return
	set_inventory_count(itemid, get_inventory_count(itemid) + count)


func remove_inventory_item(itemid: int, count: int = 1) -> bool:
	if count <= 0:
		return true
	if get_inventory_count(itemid) < count:
		return false
	set_inventory_count(itemid, get_inventory_count(itemid) - count)
	return true


func next_instance_id() -> String:
	_instance_id_counter += 1
	return "inst_%d" % _instance_id_counter


func is_chapter_completed(chapter_id: int) -> bool:
	return bool(chapter_completed.get(str(chapter_id), false))


func mark_chapter_completed(chapter_id: int, completed: bool = true) -> void:
	chapter_completed[str(chapter_id)] = completed
	if completed:
		chapter_unlocked[str(chapter_id)] = true
		chapter_new_badge[str(chapter_id)] = false
	save_progress()


func is_chapter_unlocked(chapter_id: int) -> bool:
	return bool(chapter_unlocked.get(str(chapter_id), false))


func mark_chapter_unlocked(chapter_id: int, unlocked: bool = true) -> void:
	chapter_unlocked[str(chapter_id)] = unlocked
	if unlocked:
		chapter_new_badge[str(chapter_id)] = true
	save_progress()


func has_chapter_new_badge(chapter_id: int) -> bool:
	return bool(chapter_new_badge.get(str(chapter_id), false))


func mark_chapter_entered(chapter_id: int) -> void:
	chapter_new_badge[str(chapter_id)] = false
	recent_opened_chapter_id = chapter_id
	save_progress()


func get_recent_opened_chapter_id() -> int:
	return recent_opened_chapter_id


func set_recent_opened_chapter_id(chapter_id: int) -> void:
	recent_opened_chapter_id = chapter_id
	save_progress()


func get_recent_opened_level_id() -> String:
	return recent_opened_level_id


func set_recent_opened_level_id(level_id: String) -> void:
	recent_opened_level_id = level_id
	save_progress()


func is_level_unlocked(level_id: String) -> bool:
	return bool(level_unlocked.get(level_id, false))


func mark_level_unlocked(level_id: String, unlocked: bool = true) -> void:
	if level_id.is_empty():
		return
	level_unlocked[level_id] = unlocked
	save_progress()


func is_level_completed(level_id: String) -> bool:
	return bool(level_completed.get(level_id, false))


func is_hotspot_clicked(level_id: String, hotspot_id: String) -> bool:
	if level_id.is_empty() or hotspot_id.is_empty():
		return false
	var clicked_raw: Variant = level_hotspot_clicked.get(level_id, {})
	if not (clicked_raw is Dictionary):
		return false
	var clicked: Dictionary = clicked_raw
	return bool(clicked.get(hotspot_id, false))


func mark_hotspot_clicked(level_id: String, hotspot_id: String) -> void:
	if level_id.is_empty() or hotspot_id.is_empty():
		return
	var clicked_raw: Variant = level_hotspot_clicked.get(level_id, {})
	var clicked: Dictionary = {}
	if clicked_raw is Dictionary:
		clicked = clicked_raw
	else:
		clicked = {}
	clicked[hotspot_id] = true
	level_hotspot_clicked[level_id] = clicked
	save_progress()


func set_pending_post_level_nav(data: Dictionary) -> void:
	pending_post_level_nav = data.duplicate(true)


func is_feed_post_seen(post_id: String) -> bool:
	return bool(feed_seen.get(post_id, false))


func mark_feed_post_seen(post_id: String) -> void:
	if post_id.is_empty():
		return
	feed_seen[post_id] = true
	save_progress()


func get_feed_pinned_post_id() -> String:
	return feed_pinned_post_id


func set_feed_pinned_post_id(post_id: String) -> void:
	feed_pinned_post_id = post_id
	save_progress()


func consume_pending_post_level_nav() -> Dictionary:
	var copy: Dictionary = pending_post_level_nav.duplicate(true)
	pending_post_level_nav.clear()
	return copy


func mark_level_completed(level_id: String, completed: bool = true) -> void:
	if level_id.is_empty():
		return
	level_completed[level_id] = completed
	if completed:
		level_unlocked[level_id] = true
	save_progress()


func get_level_progress(level_id: String) -> Dictionary:
	if level_id.is_empty():
		return {}
	var raw: Variant = level_progress.get(level_id, {})
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	return {}


func set_level_progress(level_id: String, patch: Dictionary) -> void:
	if level_id.is_empty() or patch.is_empty():
		return
	var current: Dictionary = get_level_progress(level_id)
	for key in patch.keys():
		current[key] = patch[key]
	level_progress[level_id] = current


func clear_level_progress(level_id: String) -> void:
	if level_id.is_empty():
		return
	if is_level_completed(level_id):
		var existing: Dictionary = get_level_progress(level_id)
		level_progress[level_id] = {
			"scroll_fills": existing.get("scroll_fills", {}),
			"identity_fills": existing.get("identity_fills", {}),
			"slots_completed": existing.get("slots_completed", {}),
		}
	else:
		level_progress.erase(level_id)
	save_progress()


func mark_hotspot_used(level_id: String, hotspot_id: String) -> void:
	if level_id.is_empty() or hotspot_id.is_empty():
		return
	var current: Dictionary = get_level_progress(level_id)
	var used_raw: Variant = current.get("hotspot_used", [])
	var used: Array = []
	if used_raw is Array:
		used = (used_raw as Array).duplicate()
	if not used.has(hotspot_id):
		used.append(hotspot_id)
	current["hotspot_used"] = used
	level_progress[level_id] = current
