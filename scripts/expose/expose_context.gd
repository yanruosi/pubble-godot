extends RefCounted

## 曝光子模块内部依赖包（非 Autoload · 非对外 API）

var host: ExposeManager
var save: SaveManager
var economy: EconomyManager
var my_posts_by_id: Dictionary = {}
var my_posts_by_tag: Dictionary = {}
var post_tags: Array = []
var preview_cursor: Dictionary = {}

var queue
var heat
var hot_roll
var idle
var feed
var instances
var posts
var banner
var settle
var debug

var pending_intel_level_up: bool = false

var _chapter: ChapterManager
var _conditions: ConditionChecker


func _init(expose_host: ExposeManager, save_mgr: SaveManager, econ: EconomyManager) -> void:
	host = expose_host
	save = save_mgr
	economy = econ


func wire_modules(q, h, hr, i, f, inst, p, b, s) -> void:
	queue = q
	heat = h
	hot_roll = hr
	idle = i
	feed = f
	instances = inst
	posts = p
	banner = b
	settle = s


func load_my_post_tables() -> void:
	my_posts_by_id.clear()
	my_posts_by_tag.clear()
	for row in TableRepo.get_table("my_posts"):
		if not (row is Dictionary):
			continue
		var mp: Dictionary = row
		var mid: String = str(mp.get("mypostid", ""))
		if mid.is_empty():
			continue
		my_posts_by_id[mid] = mp
		var tagid: String = str(mp.get("tagid", ""))
		if not my_posts_by_tag.has(tagid):
			my_posts_by_tag[tagid] = []
		(my_posts_by_tag[tagid] as Array).append(mid)
	post_tags = TableRepo.get_table("post_tags")


func chapter() -> ChapterManager:
	if _chapter == null:
		_chapter = host.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	return _chapter


func condition_checker() -> ConditionChecker:
	if _conditions == null:
		_conditions = host.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	return _conditions


func check_station_level_up() -> void:
	if economy == null:
		return
	while economy.try_upgrade_station():
		pass


func try_auto_upgrade_intel() -> void:
	if economy == null or save == null:
		return
	while economy.try_upgrade_intel():
		pending_intel_level_up = true
		host.intel_level_up.emit(save.intellevel)


func keypost_display() -> Dictionary:
	if save == null or economy == null:
		return {"current": 0, "target": 0}
	return {"current": save.keypost_progress, "target": economy.get_keypost_target()}
