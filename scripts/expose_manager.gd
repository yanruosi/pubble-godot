extends Node
class_name ExposeManager

const MY_POSTS_PATH := "res://data/my_posts.json"
const POST_TAGS_PATH := "res://data/post_tags.json"
const HEAT_ACTIONS_PATH := "res://data/heat_actions.json"
const HOT_RATES_PATH := "res://data/hot_rates.json"
const IDLE_REWARDS_PATH := "res://data/idle_rewards.json"
const POST_TEMPLATES_PATH := "res://data/post_templates.json"
const INTEL_LEVELS_PATH := "res://data/intel_levels.json"
const STATION_LEVELS_PATH := "res://data/station_levels.json"
const FEED_POSTS_PATH := "res://data/feed_posts.json"

const TAB_FANDOM := 0
const TAB_SISTER := 903
const TAB_ACCOUNT := 904

const POSTCLASS_NORMAL := 1
const POSTCLASS_ADVANCED := 2
const POSTCLASS_KEY := 3

const BANNER_EXPOSING := "exposing"
const BANNER_HOT_SUCCESS := "hot_success"
const BANNER_HOT_FAIL := "hot_fail"
const BANNER_NEW_REPLACED := "new_replaced"
const BANNER_DEFAULT_STATIC := "default_static"

const AUTO_SETTLE_TABS: Array[int] = [TAB_FANDOM, TAB_SISTER, TAB_ACCOUNT]

var _save_manager: SaveManager
var _economy_manager: EconomyManager

var _my_posts_by_id: Dictionary = {}
var _my_posts_by_tag: Dictionary = {}
var _post_tags: Array = []
var _templates_by_id: Dictionary = {}
var _heat_actions: Dictionary = {}
var _hot_rates: Array = []
var _idle_rewards_by_id: Dictionary = {}
var _intel_levels: Array = []
var _station_levels: Array = []
var _feed_posts: Array = []

var _active_tabtype: int = -1
var _pending_intel_level_up: bool = false
var _pending_reveal_by_tab: Dictionary = {}
var _banner_override_state: String = ""
var _banner_override_until: float = 0.0
var _banner_focus_queue_id: String = ""
var _fail_banner_queue_id: String = ""
var _queue_id_counter: int = 0
var _tick_accum: float = 0.0
var _preview_cursor: Dictionary = {}

signal banner_state_changed
signal instance_changed
signal lump_granted(tabtype: int, grant_type: int, amount: int)
signal intel_level_up(new_level: int)
signal keypost_favorited(instance_id: String)
signal queue_settled(queue_id: String, hotresult: int)


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_economy_manager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_load_tables()


func _process(delta: float) -> void:
	if _banner_override_until > 0.0 and Time.get_ticks_msec() / 1000.0 >= _banner_override_until:
		_banner_override_state = ""
		_banner_override_until = 0.0
	_tick_accum += delta
	if _tick_accum < 0.25:
		return
	_tick_accum = 0.0
	_tick_exposure_queue()
	_tick_idle_rewards()
	## 规则详述：冷却到期后，玩家停留在饭圈/站姐页时自动刷出帖子（不必等曝光倒计时结束）
	if _active_tabtype == TAB_FANDOM or _active_tabtype == TAB_SISTER:
		var auto_released: Array = refresh_feed_on_tab(_active_tabtype)
		#region agent log
		if not auto_released.is_empty():
			_dbg67_expose("H", "expose_manager.gd:_process", "auto release pending while on tab", {
				"tabtype": _active_tabtype,
				"released": auto_released.size(),
				"pending_left": _save_manager.feed_pending.size() if _save_manager != null else -1,
				"instances": _save_manager.feed_instances.size() if _save_manager != null else -1,
				"exposing": not _get_exposing_item().is_empty(),
				"runId": "post-fix",
			})
		#endregion
	if _save_manager != null and not _save_manager.mypost_queue.is_empty():
		banner_state_changed.emit()


func _load_tables() -> void:
	_my_posts_by_id.clear()
	_my_posts_by_tag.clear()
	for row in _read_json_array(MY_POSTS_PATH):
		if not (row is Dictionary):
			continue
		var mp: Dictionary = row as Dictionary
		var mid: String = str(mp.get("mypostid", ""))
		if mid.is_empty():
			continue
		_my_posts_by_id[mid] = mp
		var tagid: String = str(mp.get("tagid", ""))
		if not _my_posts_by_tag.has(tagid):
			_my_posts_by_tag[tagid] = []
		(_my_posts_by_tag[tagid] as Array).append(mid)

	_post_tags = _read_json_array(POST_TAGS_PATH)

	_templates_by_id.clear()
	for row in _read_json_array(POST_TEMPLATES_PATH):
		if row is Dictionary:
			_templates_by_id[str(row.get("postid", ""))] = row

	_heat_actions.clear()
	for row in _read_json_array(HEAT_ACTIONS_PATH):
		if row is Dictionary:
			_heat_actions[str(row.get("actiontype", ""))] = row

	_hot_rates = _read_json_array(HOT_RATES_PATH)

	_idle_rewards_by_id.clear()
	for row in _read_json_array(IDLE_REWARDS_PATH):
		if row is Dictionary:
			_idle_rewards_by_id[str(row.get("id", ""))] = row

	_intel_levels = _read_json_array(INTEL_LEVELS_PATH)
	_station_levels = _read_json_array(STATION_LEVELS_PATH)
	_feed_posts = _read_json_array(FEED_POSTS_PATH)


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []


func on_game_loaded() -> void:
	if _save_manager == null:
		return
	_save_manager.feed_instances = _save_manager.normalize_feed_instances(_save_manager.feed_instances)
	if _save_manager.banner_last_offline_ts <= 0:
		_save_manager.banner_last_offline_ts = int(Time.get_unix_time_from_system())
	_ensure_head_timer()
	_catch_up_offline()
	_save_manager.save_progress()
	banner_state_changed.emit()


func on_tab_entered(tabtype: int) -> void:
	if not _supports_unified_banner(tabtype):
		return
	_active_tabtype = tabtype
	## 定案：线下结算入队后，首次进入饭圈动态才开始算 refreshcd
	if tabtype == TAB_FANDOM:
		_arm_feed_pending_cooldowns()
	refresh_feed_on_tab(tabtype)
	banner_state_changed.emit()


func on_tab_left(tabtype: int) -> void:
	if tabtype != _active_tabtype:
		return
	_active_tabtype = -1
	## 曝光失败 banner：切离页签后消失
	_fail_banner_queue_id = ""
	if _banner_override_state == BANNER_HOT_FAIL:
		_banner_override_state = ""
		_banner_override_until = 0.0
	banner_state_changed.emit()


func notify_app_closing() -> void:
	if _save_manager == null:
		return
	_save_manager.banner_last_offline_ts = int(Time.get_unix_time_from_system())
	_save_manager.save_progress()


func add_instance(postid: String, tabsource: int = -1) -> Dictionary:
	if _save_manager == null or postid.is_empty():
		return {}
	var tpl: Dictionary = _templates_by_id.get(postid, {})
	if tabsource < 0:
		tabsource = int(tpl.get("tabtype", TAB_SISTER))
	var inst := {
		"instanceid": _save_manager.next_instance_id(),
		"postid": postid,
		"tabsource": tabsource,
		"createdat": int(Time.get_unix_time_from_system()),
		"fpcollected": false,
		"keypostcollected": false,
		"fpearned": 0,
	}
	_save_manager.feed_instances.append(inst)
	_save_manager.save_progress()
	instance_changed.emit()
	banner_state_changed.emit()
	return inst


func mark_instances_for_reveal(instances: Array) -> void:
	for item in instances:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		var iid: String = str(inst.get("instanceid", ""))
		if iid.is_empty():
			continue
		for tabtype in [TAB_FANDOM, TAB_SISTER, TAB_ACCOUNT]:
			if not _is_visible_on_tab(inst, tabtype):
				continue
			if not _pending_reveal_by_tab.has(tabtype):
				_pending_reveal_by_tab[tabtype] = []
			var ids: Array = _pending_reveal_by_tab[tabtype]
			if ids.has(iid):
				continue
			ids.append(iid)


func take_pending_reveal_ids(tabtype: int) -> Array:
	if not _pending_reveal_by_tab.has(tabtype):
		return []
	var ids: Array = (_pending_reveal_by_tab[tabtype] as Array).duplicate()
	_pending_reveal_by_tab.erase(tabtype)
	return ids


func get_instances_for_tab(tabtype: int) -> Array:
	if _save_manager == null:
		return []
	var out: Array = []
	for item in _save_manager.feed_instances:
		if not (item is Dictionary):
			continue
		if _is_visible_on_tab(item as Dictionary, tabtype):
			out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("createdat", 0)) > int(b.get("createdat", 0))
	)
	return out


func get_template(postid: String) -> Dictionary:
	return _templates_by_id.get(postid, {}).duplicate(true)


func get_keypost_display() -> Dictionary:
	if _save_manager == null or _economy_manager == null:
		return {"current": 0, "target": 0}
	return {
		"current": _save_manager.keypost_progress,
		"target": _economy_manager.get_keypost_target(),
	}


func get_mypost_queue() -> Array:
	if _save_manager == null:
		return []
	return _save_manager.mypost_queue.duplicate(true)


func get_expose_queue() -> Array:
	return get_mypost_queue()


func get_expose_queue_size() -> int:
	return get_mypost_queue().size()


func get_post_count(tagid: String) -> int:
	if _save_manager == null:
		return 0
	return _save_manager.get_post_count(tagid)


func get_post_tags() -> Array:
	if _save_manager == null:
		return []
	var out: Array = []
	for row in _post_tags:
		if not (row is Dictionary):
			continue
		var tag: Dictionary = row as Dictionary
		var tagid: String = str(tag.get("tagid", ""))
		if tagid.is_empty():
			continue
		var count: int = _save_manager.get_post_count(tagid)
		if count <= 0:
			continue
		out.append({
			"tagid": tagid,
			"name": str(tag.get("name", tagid)),
			"count": count,
		})
	return out


func preview_tag_post(tagid: String) -> Dictionary:
	var candidates: Array = _my_posts_by_tag.get(tagid, [])
	if candidates.is_empty():
		return {}
	var idx: int = int(_preview_cursor.get(tagid, -1)) + 1
	if idx >= candidates.size():
		idx = 0
	_preview_cursor[tagid] = idx
	var mid: String = str(candidates[idx])
	var def: Dictionary = _my_posts_by_id.get(mid, {})
	return {
		"mypostid": mid,
		"title": str(def.get("title", "")),
		"text": str(def.get("text", "")),
	}


func clear_preview_cursor(tagid: String = "") -> void:
	if tagid.is_empty():
		_preview_cursor.clear()
	elif _preview_cursor.has(tagid):
		_preview_cursor.erase(tagid)


func get_my_post(mypostid: String) -> Dictionary:
	return _my_posts_by_id.get(mypostid, {}).duplicate(true)


func post_with_tag(tagid: String, mypostid: String = "") -> Dictionary:
	if _save_manager == null or tagid.is_empty():
		return {"ok": false, "reason": "无效标签"}
	if not _save_manager.consume_post_count(tagid, 1):
		return {"ok": false, "reason": "发帖次数不足"}
	var candidates: Array = _my_posts_by_tag.get(tagid, [])
	if candidates.is_empty():
		_save_manager.add_post_count(tagid, 1)
		return {"ok": false, "reason": "该标签暂无帖子模板"}
	var pick_id: String = mypostid
	if pick_id.is_empty():
		pick_id = str(candidates[randi() % candidates.size()])
	elif not candidates.has(pick_id):
		_save_manager.add_post_count(tagid, 1)
		return {"ok": false, "reason": "预览帖不属于该标签"}
	var item: Dictionary = _append_queue_item(pick_id)
	if not _save_manager.opening_done:
		_save_manager.opening_done = true
	_save_manager.save_progress()
	#region agent log
	_dbg67_expose("A", "expose_manager.gd:post_with_tag", "queued my post", {
		"tagid": tagid,
		"pick_id": pick_id,
		"queue_size": _save_manager.mypost_queue.size(),
		"feed_instances_size": _save_manager.feed_instances.size(),
		"item_state": str(item.get("state", "")),
	})
	#endregion
	instance_changed.emit()
	banner_state_changed.emit()
	return {"ok": true, "queue_item": item}


func _dbg67_expose(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	#region agent log
	var payload := {
		"sessionId": "67dfb8",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"runId": "pre-fix",
	}
	var paths: PackedStringArray = [
		"D:/GAMES/pubble-v1/debug-67dfb8.log",
		"C:/Users/sameen/.cursor/projects/C-Users-sameen-AppData-Local-Temp-80478286-4eb1-464b-83ec-c5356a96a167/debug-67dfb8.log",
	]
	var line := JSON.stringify(payload)
	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
		if f == null:
			continue
		f.seek_end()
		f.store_line(line)
		f.close()
	#endregion


func _dbg_c195(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	#region agent log
	var payload := {
		"sessionId": "c195b4",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000),
		"runId": str(data.get("runId", "pre-fix")),
	}
	var paths: PackedStringArray = [
		"D:/GAMES/pubble-v1/debug-c195b4.log",
		"C:/Users/sameen/.cursor/projects/C-Users-sameen-AppData-Local-Temp-a9f83106-70af-4714-a6b8-6f5a37772cf3/debug-c195b4.log",
		"user://debug-c195b4.log",
	]
	var line := JSON.stringify(payload)
	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
		if f == null:
			continue
		f.seek_end()
		f.store_line(line)
		f.close()
	#endregion


func post_mainline(mypostid: String) -> Dictionary:
	if _save_manager == null or mypostid.is_empty():
		return {"ok": false, "reason": "无效帖子"}
	if not _my_posts_by_id.has(mypostid):
		return {"ok": false, "reason": "帖子不存在"}
	var item: Dictionary = _create_queue_item(mypostid, true)
	var queue: Array = _save_manager.mypost_queue
	var exposing: Dictionary = _get_exposing_item()
	var shared_end: int = 0
	if not exposing.is_empty():
		shared_end = int(exposing.get("expose_end_ts", 0))
	if shared_end > 0:
		item["expose_start_ts"] = int(Time.get_unix_time_from_system())
		item["expose_end_ts"] = shared_end
	else:
		_start_queue_item_timer(item)
	queue.insert(0, item)
	_set_banner_override(BANNER_NEW_REPLACED)
	_save_manager.save_progress()
	instance_changed.emit()
	banner_state_changed.emit()
	return {"ok": true, "queue_item": item}


func add_heat(actiontype: String) -> bool:
	if _save_manager == null:
		return false
	var head: Dictionary = _get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return false
	var action: Dictionary = _heat_actions.get(actiontype, {})
	if action.is_empty():
		return false
	head["heat"] = int(head.get("heat", 0)) + int(action.get("heatvalue", 0))
	_save_manager.save_progress()
	banner_state_changed.emit()
	return true


func get_post_display_date(_instanceid: String = "") -> String:
	var save: SaveManager = _save_manager
	if save == null:
		return ""
	var chapter: ChapterManager = get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	if chapter == null:
		return ""
	var cc: ConditionChecker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	var chapter_levels: Array = chapter.get_levels_for_chapter(1)
	var best_order := -1
	var best_time := ""
	for level_raw in chapter_levels:
		if not (level_raw is Dictionary):
			continue
		var level: Dictionary = level_raw as Dictionary
		var lid: String = str(level.get("levelid", ""))
		if lid.is_empty():
			continue
		var unlocked := save.is_level_unlocked(lid) or save.is_level_completed(lid)
		if not unlocked:
			var cid: int = int(level.get("unlockconditionid", 0))
			if cid > 0:
				if cc == null or not cc.is_level_condition_met(cid, level, chapter_levels):
					continue
			elif cid != 0:
				continue
		var order: int = int(level.get("order", 0))
		if order < best_order:
			continue
		var time_str := str(level.get("text2", ""))
		for fp in _feed_posts:
			if not (fp is Dictionary):
				continue
			if str((fp as Dictionary).get("level_id", "")) == lid:
				time_str = str((fp as Dictionary).get("time", time_str))
				break
		if time_str.is_empty():
			continue
		best_order = order
		best_time = time_str
	return best_time


func favorite_instance(inst_id: String) -> bool:
	if _save_manager == null or inst_id.is_empty():
		return false
	if _save_manager.favorites.has(inst_id):
		return false
	var inst: Dictionary = _find_feed_instance(inst_id)
	if inst.is_empty():
		return false
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	if _resolve_postclass(tpl) != POSTCLASS_KEY:
		return false
	if bool(inst.get("keypostcollected", false)):
		return false
	inst["keypostcollected"] = true
	_save_manager.favorites.append(inst_id)
	_save_manager.keypost_progress += 1
	_try_auto_upgrade_intel()
	_save_manager.save_progress()
	keypost_favorited.emit(inst_id)
	instance_changed.emit()
	banner_state_changed.emit()
	return true


func try_collect_instance(instance_id: String, tabtype: int) -> bool:
	if _save_manager == null or instance_id.is_empty():
		return false
	for item in _save_manager.feed_instances:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		if str(inst.get("instanceid", "")) != instance_id:
			continue
		if not _is_visible_on_tab(inst, tabtype):
			return false
		return favorite_instance(instance_id)
	return false


func refresh_feed_on_tab(tabtype: int) -> Array:
	if _save_manager == null:
		return []
	var now: int = int(Time.get_unix_time_from_system())
	var released: Array = []
	var keep: Array = []
	var earliest_wait := -1
	var unarmed := 0
	for item in _save_manager.feed_pending:
		if not (item is Dictionary):
			continue
		var pending: Dictionary = item as Dictionary
		## 未武装：绝不可当「已到期」立刻刷出
		if not bool(pending.get("cd_armed", false)) or int(pending.get("release_ts", 0)) <= 0:
			unarmed += 1
			keep.append(pending)
			continue
		var wait: int = int(pending.get("release_ts", 0)) - now
		if wait > 0:
			if earliest_wait < 0 or wait < earliest_wait:
				earliest_wait = wait
			keep.append(pending)
			continue
		var tabsource: int = int(pending.get("tabsource", tabtype))
		if not _is_visible_on_tab_source(tabsource, tabtype):
			keep.append(pending)
			continue
		var inst: Dictionary = add_instance(str(pending.get("postid", "")), tabsource)
		if not inst.is_empty():
			released.append(inst)
	_save_manager.feed_pending = keep
	#region agent log
	if not released.is_empty():
		_dbg67_expose("I", "expose_manager.gd:refresh_feed_on_tab", "pending released", {
			"tabtype": tabtype,
			"released": released.size(),
			"pending_left": keep.size(),
			"unarmed": unarmed,
			"earliest_wait_sec": earliest_wait,
			"exposing": not _get_exposing_item().is_empty(),
			"runId": "post-fix",
		})
	#endregion
	if not released.is_empty():
		mark_instances_for_reveal(released)
		_save_manager.save_progress()
		instance_changed.emit()
		banner_state_changed.emit()
	return released


func _arm_feed_pending_cooldowns() -> void:
	if _save_manager == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var armed_n := 0
	for item in _save_manager.feed_pending:
		if not (item is Dictionary):
			continue
		var pending: Dictionary = item as Dictionary
		if bool(pending.get("cd_armed", false)) and int(pending.get("release_ts", 0)) > 0:
			continue
		var delay: int = int(pending.get("delay_sec", 0))
		if delay <= 0:
			delay = 2
		pending["delay_sec"] = delay
		pending["release_ts"] = now + delay
		pending["cd_armed"] = true
		armed_n += 1
	#region agent log
	_dbg67_expose("I", "expose_manager.gd:_arm_feed_pending_cooldowns", "arm cooldowns on first fandom enter", {
		"armed": armed_n,
		"pending_total": _save_manager.feed_pending.size(),
		"runId": "post-fix",
	})
	#endregion
	if armed_n > 0:
		_save_manager.save_progress()


func get_banner_snapshot() -> Dictionary:
	var exposing: Dictionary = _get_exposing_item()
	var display: Dictionary = _get_display_item()
	var focus: Dictionary = _find_queue_item(_banner_focus_queue_id)
	if focus.is_empty() and _fail_banner_queue_id != "":
		focus = _find_queue_item(_fail_banner_queue_id)
	var banner_state: String = BANNER_DEFAULT_STATIC
	if _banner_override_state != "":
		banner_state = _banner_override_state
	elif _fail_banner_queue_id != "" and not _find_queue_item(_fail_banner_queue_id).is_empty():
		banner_state = BANNER_HOT_FAIL
		if focus.is_empty():
			focus = _find_queue_item(_fail_banner_queue_id)
	elif not exposing.is_empty():
		banner_state = BANNER_EXPOSING
	elif not display.is_empty() and str(display.get("state", "")) == "collected":
		var hr: int = int(display.get("hotresult", -1))
		if hr == 1:
			banner_state = BANNER_HOT_SUCCESS
		elif hr == 0:
			banner_state = BANNER_HOT_FAIL

	var source: Dictionary = {}
	if banner_state == BANNER_EXPOSING and not exposing.is_empty():
		source = exposing
	elif not focus.is_empty():
		source = focus
	elif not display.is_empty():
		source = display

	var remaining := -1.0
	var heat := 0
	var heat_bonus := 0
	var idle_fp := 0
	var idle_fans := 0
	var settle_fp := 0
	var settle_fans := 0
	var title := ""
	var is_pinned := false
	var mypostid := ""
	if not source.is_empty():
		heat = int(source.get("heat", 0))
		heat_bonus = _heat_bonus_rate(heat)
		title = str(source.get("title", ""))
		is_pinned = bool(source.get("is_pinned", false))
		mypostid = str(source.get("mypostid", ""))
		settle_fp = int(source.get("settle_fp", 0))
		settle_fans = int(source.get("settle_fans", 0))
		## 旧档无 settle_*：按我的帖子表回填基础值
		if settle_fp == 0 and settle_fans == 0 and str(source.get("state", "")) == "collected":
			var def_fb: Dictionary = _my_posts_by_id.get(mypostid, {})
			settle_fp = int(def_fb.get("basefp", 0))
			settle_fans = int(def_fb.get("basefans", 0))
			if int(source.get("hotresult", 0)) == 1:
				settle_fp += int(def_fb.get("hotbonusfp", 0))
		if banner_state == BANNER_EXPOSING:
			remaining = _remaining_expose_sec(source)
		elif banner_state == BANNER_HOT_SUCCESS:
			idle_fp = int(source.get("idle_fp_earned", 0))
			idle_fans = int(source.get("idle_fans_earned", 0))
		## 失败：只显示结算基础，不叠加放置

	var display_fp: int = settle_fp + idle_fp
	var display_fans: int = settle_fans + idle_fans

	var kp := get_keypost_display()
	return {
		"banner_state": banner_state,
		"intellevel": _save_manager.intellevel if _save_manager != null else 0,
		"keypost_current": kp.get("current", 0),
		"keypost_target": kp.get("target", 0),
		"heat": heat,
		"heat_bonus_rate": heat_bonus,
		"heat_max": 50,
		"remaining_sec": remaining,
		"idle_fp_earned": idle_fp,
		"idle_fans_earned": idle_fans,
		"settle_fp": settle_fp,
		"settle_fans": settle_fans,
		"display_fp": display_fp,
		"display_fans": display_fans,
		"title": title,
		"is_pinned": is_pinned,
		"mypostid": mypostid,
		"fans": _save_manager.fans if _save_manager != null else 0,
		"hotcount": _save_manager.hotcount if _save_manager != null else 0,
		"fanlevel": _save_manager.fanlevel if _save_manager != null else 0,
		"has_my_post": not display.is_empty() or not exposing.is_empty(),
		"queue_length": _save_manager.mypost_queue.size() if _save_manager != null else 0,
	}


func consume_pending_intel_level_up() -> bool:
	if not _pending_intel_level_up:
		return false
	_pending_intel_level_up = false
	return true


func queue_feed_pending(postid: String, tabsource: int, delay_sec: int) -> void:
	## delay_sec：入队时掷好的冷却秒数；release_ts 在首次进饭圈时才写入
	if _save_manager == null or postid.is_empty():
		return
	var delay: int = maxi(delay_sec, 1)
	_save_manager.feed_pending.append({
		"postid": postid,
		"tabsource": tabsource,
		"delay_sec": delay,
		"release_ts": 0,
		"cd_armed": false,
	})
	_save_manager.save_progress()


func debug_add_keypost() -> void:
	if _save_manager == null:
		return
	_save_manager.keypost_progress += 1
	_try_auto_upgrade_intel()
	_save_manager.save_progress()
	banner_state_changed.emit()
	instance_changed.emit()


func debug_skip_expose() -> void:
	var head: Dictionary = _get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return
	head["expose_end_ts"] = int(Time.get_unix_time_from_system())
	_on_expose_complete(head)


func debug_skip_expose_timer() -> void:
	debug_skip_expose()


func debug_flush_feed_pending() -> void:
	if _save_manager == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	for item in _save_manager.feed_pending:
		if item is Dictionary:
			var pending: Dictionary = item as Dictionary
			pending["cd_armed"] = true
			pending["release_ts"] = now
	_save_manager.save_progress()


func debug_add_post_count(tagid: String, count: int = 1) -> void:
	if _save_manager == null:
		return
	_save_manager.add_post_count(tagid, count)
	_save_manager.save_progress()


func _append_queue_item(mypostid: String) -> Dictionary:
	var item: Dictionary = _create_queue_item(mypostid, true)
	var queue: Array = _save_manager.mypost_queue
	queue.append(item)
	var exposing: Dictionary = _get_exposing_item()
	if str(exposing.get("queue_id", "")) == str(item.get("queue_id", "")):
		_start_queue_item_timer(item)
	return item


func _create_queue_item(mypostid: String, pinned: bool) -> Dictionary:
	_queue_id_counter += 1
	var def: Dictionary = _my_posts_by_id.get(mypostid, {})
	var now: int = int(Time.get_unix_time_from_system())
	return {
		"queue_id": "q_%d" % _queue_id_counter,
		"mypostid": mypostid,
		"state": "exposing",
		"heat": 0,
		"hotresult": -1,
		"posted_ts": now,
		"expose_start_ts": 0,
		"expose_end_ts": 0,
		"idle_fp_earned": 0,
		"idle_fans_earned": 0,
		"idle_next_ts": 0,
		"settle_fp": 0,
		"settle_fans": 0,
		"title": str(def.get("title", "")),
		"is_pinned": pinned,
	}


func _start_queue_item_timer(item: Dictionary) -> void:
	var def: Dictionary = _my_posts_by_id.get(str(item.get("mypostid", "")), {})
	var sec: int = maxi(int(def.get("exposesec", 120)), 1)
	var now: int = int(Time.get_unix_time_from_system())
	item["expose_start_ts"] = now
	item["expose_end_ts"] = now + sec
	## 新曝光开始时收起失败 banner
	_fail_banner_queue_id = ""
	if _banner_override_state == BANNER_HOT_FAIL:
		_banner_override_state = ""
		_banner_override_until = 0.0
	_banner_focus_queue_id = str(item.get("queue_id", ""))


func _ensure_head_timer() -> void:
	var head: Dictionary = _get_exposing_item()
	if head.is_empty():
		return
	if str(head.get("state", "")) != "exposing":
		return
	if int(head.get("expose_end_ts", 0)) <= 0:
		_start_queue_item_timer(head)


func _get_exposing_item() -> Dictionary:
	if _save_manager == null:
		return {}
	for item_raw in _save_manager.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) == "exposing":
			return item
	return {}


func _get_display_item() -> Dictionary:
	if _save_manager == null:
		return {}
	var pinned_hot: Dictionary = {}
	for i in range(_save_manager.mypost_queue.size() - 1, -1, -1):
		var item_raw: Variant = _save_manager.mypost_queue[i]
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) != "collected":
			continue
		if int(item.get("hotresult", -1)) == 1 and bool(item.get("is_pinned", false)):
			pinned_hot = item
			break
	if not pinned_hot.is_empty():
		return pinned_hot
	var exposing: Dictionary = _get_exposing_item()
	if not exposing.is_empty():
		return exposing
	return {}


func _get_head_queue_item() -> Dictionary:
	return _get_exposing_item()


func _remaining_expose_sec(item: Dictionary) -> float:
	var end_ts: int = int(item.get("expose_end_ts", 0))
	if end_ts <= 0:
		return -1.0
	return maxf(float(end_ts - int(Time.get_unix_time_from_system())), 0.0)


func _tick_exposure_queue() -> void:
	var head: Dictionary = _get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return
	if _remaining_expose_sec(head) > 0.0:
		return
	_on_expose_complete(head)


func _on_expose_complete(item: Dictionary) -> void:
	var def: Dictionary = _my_posts_by_id.get(str(item.get("mypostid", "")), {})
	var heat: int = int(item.get("heat", 0))
	var base_chance: int = int(def.get("hotbasechance", 0))
	var bonus: int = _heat_bonus_rate(heat)
	var final_rate: int = mini(95, base_chance + bonus)
	var hot_ok := final_rate >= 100 or (final_rate > 0 and randi_range(1, 100) <= final_rate)
	item["hotresult"] = 1 if hot_ok else 0
	if hot_ok:
		item["is_pinned"] = true
		_set_banner_override(BANNER_HOT_SUCCESS)
	else:
		item["is_pinned"] = false
		_set_banner_override(BANNER_HOT_FAIL)
	#region agent log
	_dbg67_expose("J", "expose_manager.gd:_on_expose_complete", "hot roll after countdown", {
		"mypostid": str(item.get("mypostid", "")),
		"heat": heat,
		"base_chance": base_chance,
		"bonus": bonus,
		"final_rate": final_rate,
		"hot_ok": hot_ok,
		"active_tabtype": _active_tabtype,
		"runId": "post-fix",
	})
	#endregion

	if _active_tabtype in AUTO_SETTLE_TABS:
		_settle_queue_item(item)
	else:
		banner_state_changed.emit()


func _settle_queue_item(item: Dictionary) -> void:
	if _save_manager == null or _economy_manager == null:
		return
	if str(item.get("state", "")) == "collected":
		return
	var def: Dictionary = _my_posts_by_id.get(str(item.get("mypostid", "")), {})
	var hot_ok: bool = int(item.get("hotresult", 0)) == 1
	var fp_grant: int = int(def.get("basefp", 0))
	var fans_grant: int = int(def.get("basefans", 0))
	if hot_ok:
		fp_grant += int(def.get("hotbonusfp", 0))
		_save_manager.hotcount += 1

	_economy_manager.add_currency(SaveManager.CAT_FP, fp_grant, "expose_settle")
	_save_manager.fans += fans_grant
	_check_station_level_up()

	item["state"] = "collected"
	item["settle_fp"] = fp_grant
	item["settle_fans"] = fans_grant
	item["idle_fp_earned"] = 0
	item["idle_fans_earned"] = 0
	_banner_focus_queue_id = str(item.get("queue_id", ""))
	var idle_id: String = ""
	if hot_ok:
		idle_id = str(def.get("idlerewardid", "1001"))
		if idle_id.is_empty():
			idle_id = "1001"
		_fail_banner_queue_id = ""
		_start_idle_timer(item, idle_id)
	else:
		## 定案：曝光失败立即结算，不给放置收益；banner 保持到切页签
		idle_id = ""
		item["idle_next_ts"] = 0
		_fail_banner_queue_id = str(item.get("queue_id", ""))
	#region agent log
	_dbg_c195("C,D", "expose_manager.gd:_settle_queue_item", "settle grants vs idle start", {
		"mypostid": str(item.get("mypostid", "")),
		"hot_ok": hot_ok,
		"fp_grant": fp_grant,
		"fans_grant": fans_grant,
		"basefp": int(def.get("basefp", 0)),
		"hotbonusfp": int(def.get("hotbonusfp", 0)),
		"basefans": int(def.get("basefans", 0)),
		"idle_id": idle_id,
		"idle_fp_earned": int(item.get("idle_fp_earned", 0)),
		"idle_fans_earned": int(item.get("idle_fans_earned", 0)),
		"idle_next_ts": int(item.get("idle_next_ts", 0)),
		"settle_fp": int(item.get("settle_fp", 0)),
		"settle_fans": int(item.get("settle_fans", 0)),
		"runId": "post-fix",
	})
	#endregion

	lump_granted.emit(TAB_ACCOUNT, SaveManager.CAT_FP, fp_grant)
	queue_settled.emit(str(item.get("queue_id", "")), int(item.get("hotresult", 0)))

	_advance_queue_after_settle()
	_save_manager.save_progress()
	instance_changed.emit()
	banner_state_changed.emit()


func settle_pending_head() -> bool:
	var head: Dictionary = _get_exposing_item()
	if head.is_empty():
		return false
	if str(head.get("state", "")) != "exposing":
		return false
	if int(head.get("hotresult", -1)) < 0:
		return false
	_settle_queue_item(head)
	return true


func _advance_queue_after_settle() -> void:
	if _save_manager == null:
		return
	_cleanup_finished_collected()
	var new_head: Dictionary = _get_exposing_item()
	if new_head.is_empty():
		return
	if str(new_head.get("state", "")) == "exposing" and int(new_head.get("expose_end_ts", 0)) <= 0:
		_start_queue_item_timer(new_head)


func _cleanup_finished_collected() -> void:
	## 定案：已领取帖仍留在队列（饭圈/账号列表按发帖时间展示）；仅停掉放置收益，不删帖
	if _save_manager == null:
		return
	for item_raw in _save_manager.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) != "collected":
			continue
		if int(item.get("hotresult", 0)) != 1:
			item["idle_next_ts"] = 0
			continue
		var def: Dictionary = _my_posts_by_id.get(str(item.get("mypostid", "")), {})
		var idle_id: String = str(def.get("idlerewardid", "1001"))
		var idle: Dictionary = _idle_rewards_by_id.get(idle_id, {})
		var fp_cap: int = int(idle.get("fpcap", 0))
		var fans_cap: int = int(idle.get("fanscap", 0))
		var fp_earned: int = int(item.get("idle_fp_earned", 0))
		var fans_earned: int = int(item.get("idle_fans_earned", 0))
		if fp_earned >= fp_cap and fans_earned >= fans_cap:
			item["idle_next_ts"] = 0


func _start_idle_timer(item: Dictionary, idle_id: String) -> void:
	if idle_id.is_empty():
		item["idle_next_ts"] = 0
		return
	var idle: Dictionary = _idle_rewards_by_id.get(idle_id, {})
	if idle.is_empty():
		item["idle_next_ts"] = 0
		return
	var min_sec: int = maxi(int(idle.get("intervalmin", 8)), 1)
	var max_sec: int = maxi(int(idle.get("intervalmax", min_sec)), min_sec)
	var wait_sec: int = randi_range(min_sec, max_sec)
	item["idle_next_ts"] = int(Time.get_unix_time_from_system()) + wait_sec


func _tick_idle_rewards() -> void:
	if _save_manager == null or _economy_manager == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var changed := false
	for item_raw in _save_manager.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) != "collected":
			continue
		## 仅热帖成功走放置收益（idle_rewards 1001）
		if int(item.get("hotresult", 0)) != 1:
			if int(item.get("idle_next_ts", 0)) != 0:
				item["idle_next_ts"] = 0
				changed = true
			continue
		if int(item.get("idle_next_ts", 0)) <= 0 or now < int(item.get("idle_next_ts", 0)):
			continue
		var def: Dictionary = _my_posts_by_id.get(str(item.get("mypostid", "")), {})
		var idle_id: String = str(def.get("idlerewardid", "1001"))
		var idle: Dictionary = _idle_rewards_by_id.get(idle_id, {})
		var fp_cap: int = int(idle.get("fpcap", 0))
		var fans_cap: int = int(idle.get("fanscap", 0))
		var fp_earned: int = int(item.get("idle_fp_earned", 0))
		var fans_earned: int = int(item.get("idle_fans_earned", 0))
		if fp_earned >= fp_cap and fans_earned >= fans_cap:
			item["idle_next_ts"] = 0
			changed = true
			continue
		var fp_tick: int = 1 if fp_earned < fp_cap else 0
		var fans_tick: int = 1 if fans_earned < fans_cap else 0
		if fp_tick > 0:
			_economy_manager.add_currency(SaveManager.CAT_FP, fp_tick, "idle_reward")
			item["idle_fp_earned"] = fp_earned + fp_tick
			lump_granted.emit(TAB_ACCOUNT, SaveManager.CAT_FP, fp_tick)
		if fans_tick > 0:
			_save_manager.fans += fans_tick
			item["idle_fans_earned"] = fans_earned + fans_tick
			_check_station_level_up()
		if int(item.get("idle_fp_earned", 0)) >= fp_cap and int(item.get("idle_fans_earned", 0)) >= fans_cap:
			item["idle_next_ts"] = 0
		else:
			_start_idle_timer(item, idle_id)
		changed = true
	if changed:
		_cleanup_finished_collected()
		_save_manager.save_progress()
		banner_state_changed.emit()


func _catch_up_offline() -> void:
	if _save_manager == null:
		return
	var last: int = _save_manager.banner_last_offline_ts
	var now: int = int(Time.get_unix_time_from_system())
	if last <= 0 or now <= last:
		return
	var guard := 0
	while guard < 500:
		guard += 1
		var head: Dictionary = _get_exposing_item()
		if head.is_empty():
			break
		if str(head.get("state", "")) == "exposing":
			if _remaining_expose_sec(head) > 0.0:
				break
			_on_expose_complete(head)
			if str(head.get("state", "")) == "exposing":
				_settle_queue_item(head)
		else:
			break
	_tick_idle_rewards()
	_save_manager.banner_last_offline_ts = now


func _heat_bonus_rate(heat: int) -> int:
	for row in _hot_rates:
		if not (row is Dictionary):
			continue
		var r: Dictionary = row as Dictionary
		if heat >= int(r.get("heatmin", 0)) and heat <= int(r.get("heatmax", 999)):
			return int(r.get("bonusrate", 0))
	return 0


func _check_station_level_up() -> void:
	if _economy_manager == null:
		return
	while _economy_manager.try_upgrade_station():
		pass


func _try_auto_upgrade_intel() -> void:
	if _economy_manager == null or _save_manager == null:
		return
	while _economy_manager.try_upgrade_intel():
		_pending_intel_level_up = true
		intel_level_up.emit(_save_manager.intellevel)


func _set_banner_override(state: String, duration_sec: float = 3.0) -> void:
	_banner_override_state = state
	## 失败态由切页签清除，不靠短时 override
	if state == BANNER_HOT_FAIL:
		_banner_override_until = 0.0
	else:
		_banner_override_until = Time.get_ticks_msec() / 1000.0 + duration_sec


func _find_queue_item(queue_id: String) -> Dictionary:
	if _save_manager == null or queue_id.is_empty():
		return {}
	for item_raw in _save_manager.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("queue_id", "")) == queue_id:
			return item
	return {}


func _find_feed_instance(inst_id: String) -> Dictionary:
	if _save_manager == null:
		return {}
	for item in _save_manager.feed_instances:
		if item is Dictionary and str((item as Dictionary).get("instanceid", "")) == inst_id:
			return item as Dictionary
	return {}


func _resolve_postclass(tpl: Dictionary) -> int:
	if tpl.has("postclass"):
		return int(tpl.get("postclass", POSTCLASS_NORMAL))
	if int(tpl.get("tabtype", 0)) == TAB_SISTER and int(tpl.get("grantintel", 0)) > 0:
		return POSTCLASS_KEY
	return POSTCLASS_NORMAL


func _supports_unified_banner(tabtype: int) -> bool:
	return tabtype == TAB_FANDOM or tabtype == TAB_SISTER or tabtype == TAB_ACCOUNT


func _is_my_post_template(tpl: Dictionary) -> bool:
	return int(tpl.get("tabtype", 0)) == TAB_ACCOUNT


func _is_sister_or_key_template(tpl: Dictionary) -> bool:
	if _resolve_postclass(tpl) == POSTCLASS_KEY:
		return true
	return int(tpl.get("tabtype", 0)) == TAB_SISTER


func _is_visible_on_tab(inst: Dictionary, tabtype: int) -> bool:
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	if tpl.is_empty():
		return false
	if _is_my_post_template(tpl):
		return tabtype == TAB_ACCOUNT
	if tabtype == TAB_ACCOUNT:
		return false
	if tabtype == TAB_FANDOM:
		if _is_sister_or_key_template(tpl):
			return true
		var postclass: int = _resolve_postclass(tpl)
		return postclass in [POSTCLASS_NORMAL, POSTCLASS_ADVANCED]
	if tabtype == TAB_SISTER:
		return _is_sister_or_key_template(tpl)
	return false


func _is_visible_on_tab_source(tabsource: int, viewing_tab: int) -> bool:
	if tabsource == viewing_tab:
		return true
	if viewing_tab == TAB_FANDOM and tabsource == TAB_SISTER:
		return true
	return false


func is_tab_p1_visible(tabtype: int) -> bool:
	return _supports_unified_banner(tabtype)


func is_tab_p2_visible(tabtype: int) -> bool:
	return tabtype == TAB_FANDOM or tabtype == TAB_SISTER


func is_tab_p3_visible(tabtype: int) -> bool:
	return _supports_unified_banner(tabtype)


func is_tab_p4_visible(tabtype: int) -> bool:
	return tabtype == TAB_SISTER


func is_tab_p5_visible(tabtype: int) -> bool:
	return tabtype == TAB_SISTER
