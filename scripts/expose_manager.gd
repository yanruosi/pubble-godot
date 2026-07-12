extends Node
class_name ExposeManager

const POST_TEMPLATES_PATH := "res://data/post_templates.json"
const BANNER_CONFIG_PATH := "res://data/banner_config.json"
const INTEL_LEVELS_PATH := "res://data/intel_levels.json"

const TAB_FANDOM := 0
const TAB_SISTER := 903

const CAT_FP := 22
const CAT_INTEL := 24

var _save_manager: SaveManager
var _economy_manager: EconomyManager
var _templates_by_id: Dictionary = {}
var _banner_by_tab: Dictionary = {}
var _intel_levels: Array = []

var _active_tabtype: int = -1
var _countdown_started: bool = false
var _countdown_elapsed: float = 0.0
var _pending_intel_level_up: bool = false

var _pending_reveal_by_tab: Dictionary = {}

signal banner_progress_changed(tabtype: int, ratio: float)
signal lump_granted(tabtype: int, grant_type: int, amount: int)
signal intel_level_up(new_level: int)
signal instance_changed


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_economy_manager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_load_tables()


func _load_tables() -> void:
	_templates_by_id.clear()
	for row in _read_json_array(POST_TEMPLATES_PATH):
		if row is Dictionary:
			_templates_by_id[str(row.get("postid", ""))] = row
	_banner_by_tab.clear()
	for row in _read_json_array(BANNER_CONFIG_PATH):
		if row is Dictionary:
			_banner_by_tab[int(row.get("tabtype", -1))] = row
	_intel_levels = _read_json_array(INTEL_LEVELS_PATH)


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
		_save_manager.save_progress()


func seed_tutorial_instance() -> void:
	if _save_manager == null:
		return
	if not _save_manager.feed_instances.is_empty():
		return
	const TUTORIAL_SEED_POSTID := "9001"
	if not _templates_by_id.has(TUTORIAL_SEED_POSTID):
		push_warning("ExposeManager: tutorial template %s missing" % TUTORIAL_SEED_POSTID)
		return
	add_instance(TUTORIAL_SEED_POSTID)


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
		"fpcollected": int(tpl.get("grantfp", 0)) <= 0,
		"intelcollected": int(tpl.get("grantintel", 0)) <= 0,
	}
	_save_manager.feed_instances.append(inst)
	_save_manager.save_progress()
	instance_changed.emit()
	return inst


func mark_instances_for_reveal(instances: Array) -> void:
	for item in instances:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		var iid: String = str(inst.get("instanceid", ""))
		if iid.is_empty():
			continue
		for tabtype in [TAB_FANDOM, TAB_SISTER]:
			if not _is_visible_on_tab(inst, tabtype):
				continue
			if not _pending_reveal_by_tab.has(tabtype):
				_pending_reveal_by_tab[tabtype] = []
			var ids: Array = _pending_reveal_by_tab[tabtype]
			if ids.has(iid):
				continue
			ids.append(iid)
			#region agent log
			var payload := {
				"sessionId": "c0d936",
				"hypothesisId": "G",
				"location": "expose_manager.gd:mark_instances_for_reveal",
				"message": "marked reveal",
				"data": {
					"instanceid": iid,
					"tabtype": tabtype,
					"tabsource": int(inst.get("tabsource", TAB_SISTER)),
				},
				"timestamp": Time.get_unix_time_from_system() * 1000,
				"runId": "reveal-fix",
			}
			var lf := FileAccess.open("debug-c0d936.log", FileAccess.READ_WRITE if FileAccess.file_exists("debug-c0d936.log") else FileAccess.WRITE)
			if lf != null:
				if FileAccess.file_exists("debug-c0d936.log"):
					lf.seek_end()
				lf.store_line(JSON.stringify(payload))
				lf.close()
			#endregion


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


func get_next_intel_threshold() -> int:
	if _save_manager == null:
		return 0
	var next_level: int = _save_manager.intellevel + 1
	for row in _intel_levels:
		if row is Dictionary and int(row.get("level", -1)) == next_level:
			return int(row.get("thresholdintel", 0))
	return 0


func consume_pending_intel_level_up() -> bool:
	if not _pending_intel_level_up:
		return false
	_pending_intel_level_up = false
	return true


func on_tab_entered(tabtype: int) -> void:
	if not _supports_exposure_tab(tabtype):
		return
	_active_tabtype = tabtype
	_reset_countdown()
	var lump: int = _grant_lump_on_enter(tabtype)
	if lump > 0:
		var grant_type: int = _grant_type_for_tab(tabtype)
		lump_granted.emit(tabtype, grant_type, lump)
		instance_changed.emit()


func on_tab_left(tabtype: int) -> void:
	if tabtype != _active_tabtype:
		return
	_active_tabtype = -1
	_reset_countdown()
	banner_progress_changed.emit(tabtype, 0.0)


func notify_list_scrolled(tabtype: int) -> void:
	if tabtype != _active_tabtype or not _supports_exposure_tab(tabtype):
		return
	if _countdown_started:
		return
	_countdown_started = true
	_countdown_elapsed = 0.0
	banner_progress_changed.emit(tabtype, 0.0)


func get_banner_progress(tabtype: int) -> float:
	if tabtype != _active_tabtype or not _countdown_started:
		return 0.0
	var duration: float = _countdown_duration(tabtype)
	if duration <= 0.0:
		return 0.0
	return clampf(_countdown_elapsed / duration, 0.0, 1.0)


func _process(delta: float) -> void:
	if not _countdown_started or _active_tabtype < 0:
		return
	var duration: float = _countdown_duration(_active_tabtype)
	if duration <= 0.0:
		return
	_countdown_elapsed += delta
	var ratio: float = clampf(_countdown_elapsed / duration, 0.0, 1.0)
	banner_progress_changed.emit(_active_tabtype, ratio)
	if ratio >= 1.0:
		_on_countdown_complete(_active_tabtype)


func _on_countdown_complete(tabtype: int) -> void:
	var inst: Dictionary = _find_earliest_uncollected(tabtype)
	if not inst.is_empty():
		var amount: int = _grant_instance_side(inst, tabtype)
		if amount > 0:
			lump_granted.emit(tabtype, _grant_type_for_tab(tabtype), amount)
		_save_manager.save_progress()
		instance_changed.emit()
		if _has_uncollected_on_tab(tabtype):
			_restart_countdown()
		else:
			_reset_countdown()
		return
	var cfg: Dictionary = _banner_by_tab.get(tabtype, {})
	var grant_type: int = int(cfg.get("activegranttype", 0))
	var fallback_amount: int = int(cfg.get("activegrantamt", 0))
	if fallback_amount > 0 and grant_type > 0 and _economy_manager != null:
		_economy_manager.add_currency(grant_type, fallback_amount, "banner_active")
		lump_granted.emit(tabtype, grant_type, fallback_amount)
		if grant_type == CAT_INTEL:
			_auto_upgrade_intel()
	_restart_countdown()


func _grant_lump_on_enter(tabtype: int) -> int:
	if _save_manager == null or _economy_manager == null:
		return 0
	var total: int = 0
	var grant_type: int = _grant_type_for_tab(tabtype)

	var now: int = int(Time.get_unix_time_from_system())
	var last: int = _save_manager.banner_last_offline_ts
	if last <= 0:
		last = now
	var elapsed: int = now - last
	var cfg: Dictionary = _banner_by_tab.get(tabtype, {})
	var offline_sec: int = int(cfg.get("offlinedurationsec", 150))
	if offline_sec > 0:
		var max_sec: int = int(cfg.get("offlinemaxsec", 28800))
		var capped: int = mini(elapsed, max_sec)
		var times: int = floori(float(capped) / float(offline_sec))
		if times > 0:
			total += int(cfg.get("activegrantamt", 0)) * times

	for item in _save_manager.feed_instances:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		if _is_side_collected(inst, tabtype):
			continue
		if not _is_visible_on_tab(inst, tabtype):
			continue
		var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
		if int(tpl.get("durationsec", 0)) != 0:
			continue
		var amount: int = _grant_amount_for_side(tpl, tabtype)
		if amount <= 0:
			continue
		total += amount
		_mark_side_collected(inst, tabtype)

	if total > 0:
		_economy_manager.add_currency(grant_type, total, "lump_enter")
		if grant_type == CAT_INTEL:
			_auto_upgrade_intel()
		_save_manager.save_progress()
	return total


func _grant_instance_side(inst: Dictionary, tabtype: int) -> int:
	if _economy_manager == null:
		return 0
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	var amount: int = _grant_amount_for_side(tpl, tabtype)
	if amount <= 0:
		return 0
	var grant_type: int = _grant_type_for_tab(tabtype)
	_economy_manager.add_currency(grant_type, amount, "countdown_collect")
	_mark_side_collected(inst, tabtype)
	if grant_type == CAT_INTEL:
		_auto_upgrade_intel()
	return amount


func _auto_upgrade_intel() -> void:
	if _economy_manager == null or _save_manager == null:
		return
	while _economy_manager.try_upgrade_intel():
		_pending_intel_level_up = true
		intel_level_up.emit(_save_manager.intellevel)


func _find_earliest_uncollected(tabtype: int) -> Dictionary:
	if _save_manager == null:
		return {}
	var best: Dictionary = {}
	var best_ts: int = 2147483647
	for item in _save_manager.feed_instances:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		if _is_side_collected(inst, tabtype):
			continue
		if not _is_visible_on_tab(inst, tabtype):
			continue
		var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
		if _grant_amount_for_side(tpl, tabtype) <= 0:
			continue
		var ts: int = int(inst.get("createdat", 0))
		if ts < best_ts:
			best_ts = ts
			best = inst
	return best


func _has_uncollected_on_tab(tabtype: int) -> bool:
	return not _find_earliest_uncollected(tabtype).is_empty()


func _supports_exposure_tab(tabtype: int) -> bool:
	return tabtype == TAB_FANDOM or tabtype == TAB_SISTER


func _is_visible_on_tab(inst: Dictionary, tabtype: int) -> bool:
	if tabtype == TAB_FANDOM:
		return true
	if tabtype == TAB_SISTER:
		return int(inst.get("tabsource", -1)) == TAB_SISTER
	return false


func _is_side_collected(inst: Dictionary, tabtype: int) -> bool:
	if tabtype == TAB_FANDOM:
		return bool(inst.get("fpcollected", false))
	if tabtype == TAB_SISTER:
		return bool(inst.get("intelcollected", false))
	return true


func _mark_side_collected(inst: Dictionary, tabtype: int) -> void:
	if tabtype == TAB_FANDOM:
		inst["fpcollected"] = true
	elif tabtype == TAB_SISTER:
		inst["intelcollected"] = true


func _grant_type_for_tab(tabtype: int) -> int:
	if tabtype == TAB_SISTER:
		return CAT_INTEL
	return CAT_FP


func _grant_amount_for_side(tpl: Dictionary, tabtype: int) -> int:
	if tabtype == TAB_SISTER:
		return int(tpl.get("grantintel", 0))
	return int(tpl.get("grantfp", 0))


func _countdown_duration(tabtype: int) -> float:
	var cfg: Dictionary = _banner_by_tab.get(tabtype, {})
	return float(int(cfg.get("activedurationsec", 30)))


func _reset_countdown() -> void:
	_countdown_started = false
	_countdown_elapsed = 0.0


func _restart_countdown() -> void:
	_countdown_started = true
	_countdown_elapsed = 0.0
	if _active_tabtype >= 0:
		banner_progress_changed.emit(_active_tabtype, 0.0)


func notify_app_closing() -> void:
	if _save_manager == null:
		return
	_save_manager.banner_last_offline_ts = int(Time.get_unix_time_from_system())
	_save_manager.save_progress()
