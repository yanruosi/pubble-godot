extends Node
class_name ExposeManager

const POST_TEMPLATES_PATH := "res://data/post_templates.json"
const BANNER_CONFIG_PATH := "res://data/banner_config.json"

const STATUS_IDLE := "idle"
const STATUS_EXPOSING := "exposing"
const STATUS_READY := "ready"

var _save_manager: SaveManager
var _economy_manager: EconomyManager
var _templates_by_id: Dictionary = {}
var _banner_by_tab: Dictionary = {}

var _active_tabtype: int = -1
var _active_elapsed: float = 0.0
var _banner_progress: float = 0.0

signal banner_progress_changed(tabtype: int, ratio: float)
signal banner_reward_granted(tabtype: int, grant_type: int, amount: int)
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


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []


func on_game_loaded() -> void:
	_apply_offline_banner_rewards()
	_refresh_instance_ready_states()


func seed_tutorial_instance() -> void:
	if _save_manager == null:
		return
	if not _save_manager.feed_instances.is_empty():
		return
	const TUTORIAL_SEED_POSTID := "9001"
	if not _templates_by_id.has(TUTORIAL_SEED_POSTID):
		push_warning("ExposeManager: tutorial template %s missing" % TUTORIAL_SEED_POSTID)
		return
	add_instance(TUTORIAL_SEED_POSTID, 903)


func add_instance(postid: String, tabtype: int) -> Dictionary:
	if _save_manager == null or postid.is_empty():
		return {}
	var inst := {
		"instanceid": _save_manager.next_instance_id(),
		"postid": postid,
		"tabtype": tabtype,
		"exposestatus": STATUS_IDLE,
		"exposeendts": 0,
		"createdat": int(Time.get_unix_time_from_system()),
	}
	_save_manager.feed_instances.append(inst)
	_save_manager.save_progress()
	instance_changed.emit()
	return inst


func get_instances_for_tab(tabtype: int) -> Array:
	if _save_manager == null:
		return []
	var out: Array = []
	for item in _save_manager.feed_instances:
		if item is Dictionary and int(item.get("tabtype", -1)) == tabtype:
			out.append(item)
	return out


func start_expose(instanceid: String) -> bool:
	var inst: Dictionary = _find_instance(instanceid)
	if inst.is_empty():
		return false
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	var duration: int = int(tpl.get("durationsec", 0))
	var now: int = int(Time.get_unix_time_from_system())
	if duration <= 0:
		inst["exposestatus"] = STATUS_READY
		inst["exposeendts"] = now
	else:
		inst["exposestatus"] = STATUS_EXPOSING
		inst["exposeendts"] = now + duration
	_save_manager.save_progress()
	instance_changed.emit()
	return true


func collect_instance(instanceid: String) -> bool:
	var inst: Dictionary = _find_instance(instanceid)
	if inst.is_empty():
		return false
	_refresh_single_instance(inst)
	if str(inst.get("exposestatus", "")) != STATUS_READY:
		return false
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	if _economy_manager != null:
		if int(tpl.get("grantfp", 0)) > 0:
			_economy_manager.add_currency(22, int(tpl.get("grantfp", 0)), "collect")
		if int(tpl.get("grantintel", 0)) > 0:
			_economy_manager.add_currency(24, int(tpl.get("grantintel", 0)), "collect")
		if int(tpl.get("grantstars", 0)) > 0:
			_economy_manager.add_currency(23, int(tpl.get("grantstars", 0)), "collect")
	_remove_instance(instanceid)
	return true


func get_template(postid: String) -> Dictionary:
	return _templates_by_id.get(postid, {}).duplicate(true)


func start_active_timer(tabtype: int) -> void:
	_active_tabtype = tabtype
	_active_elapsed = 0.0
	_banner_progress = 0.0
	banner_progress_changed.emit(tabtype, 0.0)


func on_tab_left() -> void:
	_active_tabtype = -1
	_active_elapsed = 0.0
	_banner_progress = 0.0


func get_banner_progress(tabtype: int) -> float:
	if tabtype != _active_tabtype:
		return 0.0
	return _banner_progress


func _process(delta: float) -> void:
	if _active_tabtype < 0:
		return
	var cfg: Dictionary = _banner_by_tab.get(_active_tabtype, {})
	var duration: float = float(int(cfg.get("activedurationsec", 30)))
	if duration <= 0.0:
		return
	_active_elapsed += delta
	_banner_progress = clampf(_active_elapsed / duration, 0.0, 1.0)
	banner_progress_changed.emit(_active_tabtype, _banner_progress)
	if _banner_progress >= 1.0:
		_grant_active_banner(_active_tabtype)
		_active_elapsed = 0.0
		_banner_progress = 0.0
		banner_progress_changed.emit(_active_tabtype, 0.0)


func _grant_active_banner(tabtype: int) -> void:
	var cfg: Dictionary = _banner_by_tab.get(tabtype, {})
	if cfg.is_empty() or _economy_manager == null:
		return
	var grant_type: int = int(cfg.get("activegranttype", 0))
	var amount: int = int(cfg.get("activegrantamt", 0))
	if grant_type <= 0 or amount <= 0:
		return
	_economy_manager.add_currency(grant_type, amount, "banner_active")
	banner_reward_granted.emit(tabtype, grant_type, amount)


func _apply_offline_banner_rewards() -> void:
	if _save_manager == null or _economy_manager == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var last: int = _save_manager.banner_last_offline_ts
	if last <= 0:
		last = now
	var elapsed: int = now - last
	for tabtype in _banner_by_tab.keys():
		var cfg: Dictionary = _banner_by_tab[tabtype]
		var max_sec: int = int(cfg.get("offlinemaxsec", 28800))
		var offline_sec: int = int(cfg.get("offlinedurationsec", 150))
		if offline_sec <= 0:
			continue
		var capped: int = mini(elapsed, max_sec)
		var times: int = capped / offline_sec
		if times <= 0:
			continue
		var grant_type: int = int(cfg.get("activegranttype", 0))
		var amount: int = int(cfg.get("activegrantamt", 0)) * times
		if grant_type > 0 and amount > 0:
			_economy_manager.add_currency(grant_type, amount, "banner_offline")
	_save_manager.banner_last_offline_ts = now
	_save_manager.save_progress()


func _refresh_instance_ready_states() -> void:
	if _save_manager == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	for item in _save_manager.feed_instances:
		if item is Dictionary:
			_refresh_single_instance(item, now)
	_save_manager.save_progress()


func _refresh_single_instance(inst: Dictionary, now: int = -1) -> void:
	if now < 0:
		now = int(Time.get_unix_time_from_system())
	var status: String = str(inst.get("exposestatus", STATUS_IDLE))
	if status == STATUS_EXPOSING and int(inst.get("exposeendts", 0)) <= now:
		inst["exposestatus"] = STATUS_READY


func _find_instance(instanceid: String) -> Dictionary:
	if _save_manager == null:
		return {}
	for item in _save_manager.feed_instances:
		if item is Dictionary and str(item.get("instanceid", "")) == instanceid:
			return item
	return {}


func _remove_instance(instanceid: String) -> void:
	if _save_manager == null:
		return
	var kept: Array = []
	for item in _save_manager.feed_instances:
		if item is Dictionary and str(item.get("instanceid", "")) != instanceid:
			kept.append(item)
	_save_manager.feed_instances = kept
	_save_manager.save_progress()
	instance_changed.emit()


func notify_app_closing() -> void:
	if _save_manager == null:
		return
	_save_manager.banner_last_offline_ts = int(Time.get_unix_time_from_system())
	_save_manager.save_progress()
