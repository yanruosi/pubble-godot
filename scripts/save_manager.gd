extends Node
class_name SaveManager

const SAVE_PATH := "user://progress.cfg"
const INITIAL_CHEER_COUNT := 30

var cheer_count: int = 0
var chapter_completed: Dictionary = {}
var chapter_unlocked: Dictionary = {}
var chapter_new_badge: Dictionary = {}
var level_unlocked: Dictionary = {}
var level_completed: Dictionary = {}
var level_hotspot_clicked: Dictionary = {}
var recent_opened_chapter_id: int = 0
var recent_opened_level_id: String = ""

## 关卡结算后 change_scene 回主界面时消费；不写盘。
var pending_post_level_nav: Dictionary = {}

## 动态帖已读（post_id -> true），写入 progress.cfg [feed]seen
var feed_seen: Dictionary = {}
var feed_pinned_post_id: String = ""

## 标题页 → 主界面接力；瞬态，不写盘。"home" / "continue" / ""
var boot_target: String = ""

func _init() -> void:
	load_progress()

func load_progress() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		cheer_count = INITIAL_CHEER_COUNT
		save_progress()
		return

	cheer_count = int(config.get_value("player", "cheer_count", 0))
	recent_opened_chapter_id = int(config.get_value("player", "recent_opened_chapter_id", 0))
	recent_opened_level_id = str(config.get_value("player", "recent_opened_level_id", ""))
	chapter_completed = config.get_value("chapter", "completed", {})
	chapter_unlocked = config.get_value("chapter", "unlocked", {})
	chapter_new_badge = config.get_value("chapter", "new_badge", {})
	level_unlocked = config.get_value("level", "unlocked", {})
	level_completed = config.get_value("level", "completed", {})
	level_hotspot_clicked = config.get_value("level_hotspot", "clicked", {})
	if not (chapter_completed is Dictionary):
		chapter_completed = {}
	if not (chapter_unlocked is Dictionary):
		chapter_unlocked = {}
	if not (chapter_new_badge is Dictionary):
		chapter_new_badge = {}
	if not (level_unlocked is Dictionary):
		level_unlocked = {}
	if not (level_completed is Dictionary):
		level_completed = {}
	if not (level_hotspot_clicked is Dictionary):
		level_hotspot_clicked = {}
	feed_seen = config.get_value("feed", "seen", {})
	if not (feed_seen is Dictionary):
		feed_seen = {}
	feed_pinned_post_id = str(config.get_value("feed", "pinned_post_id", ""))

func is_game_started() -> bool:
	return _get_game_started()

func mark_game_started() -> void:
	_set_game_started(true)

func can_continue() -> bool:
	return _get_game_started()

func reset_progress() -> void:
	chapter_completed.clear()
	chapter_unlocked.clear()
	chapter_new_badge.clear()
	level_unlocked.clear()
	level_completed.clear()
	level_hotspot_clicked.clear()
	feed_seen.clear()
	feed_pinned_post_id = ""
	recent_opened_chapter_id = 0
	recent_opened_level_id = ""
	pending_post_level_nav.clear()
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
	config.set_value("player", "cheer_count", cheer_count)
	config.set_value("player", "recent_opened_chapter_id", recent_opened_chapter_id)
	config.set_value("player", "recent_opened_level_id", recent_opened_level_id)
	config.set_value("chapter", "completed", chapter_completed)
	config.set_value("chapter", "unlocked", chapter_unlocked)
	config.set_value("chapter", "new_badge", chapter_new_badge)
	config.set_value("level", "unlocked", level_unlocked)
	config.set_value("level", "completed", level_completed)
	config.set_value("level_hotspot", "clicked", level_hotspot_clicked)
	config.set_value("feed", "seen", feed_seen)
	config.set_value("feed", "pinned_post_id", feed_pinned_post_id)
	var err := config.save(SAVE_PATH)
	if err != OK:
		push_warning("Save progress failed: %d" % err)

func get_cheer_count() -> int:
	return cheer_count

func set_cheer_count(value: int) -> void:
	cheer_count = max(value, 0)
	save_progress()

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
