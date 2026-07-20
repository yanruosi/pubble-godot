extends RefCounted
class_name SaveMigrations

## L1：存档版本校验 · 反序列化 · 归一化 · 默认值

const SAVE_VERSION := 5
const _Io = preload("res://scripts/data/save_migrations_io.gd")


static func is_version_supported(config: ConfigFile) -> bool:
	var version: int = int(config.get_value("meta", "save_version", 0))
	return version >= SAVE_VERSION


static func load_into(sm, config: ConfigFile) -> bool:
	if not is_version_supported(config):
		push_warning("Save version %d < %d; reset required" % [
			int(config.get_value("meta", "save_version", 0)), SAVE_VERSION
		])
		apply_defaults(sm)
		return false
	_read_fields(sm, config)
	return true


static func save_from(sm, config: ConfigFile) -> void:
	_Io.save_from(sm, config)


static func apply_defaults(sm) -> void:
	sm.fp = 0
	sm.intel = 0
	sm.stars = 0
	sm.intellevel = 0
	sm.fanlevel = 0
	sm.stationexp = 0
	sm.tutorialstep = 0
	sm.tutorialdone = true
	sm.inventory = {}
	sm.feed_instances = []
	sm.banner_last_offline_ts = int(Time.get_unix_time_from_system())
	sm.keypost_progress = 0
	sm.keypost_pity = {}
	sm._instance_id_counter = 0
	sm.activity_state = {}
	sm.opening_done = false
	sm.post_counts = {}
	sm.mypost_queue = []
	sm.favorites = []
	sm.fans = 0
	sm.hotcount = 0
	sm.activity_first_clear = {}
	sm.feed_pending = []


static func normalize_feed_instances(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = (item as Dictionary).duplicate(true)
		if inst.has("tabsource"):
			inst["fpcollected"] = bool(inst.get("fpcollected", false))
			inst["keypostcollected"] = bool(inst.get("keypostcollected", inst.get("intelcollected", false)))
			inst["fpearned"] = int(inst.get("fpearned", 0))
			out.append(inst)
			continue
		var postid: String = str(inst.get("postid", ""))
		var tabsource: int = int(inst.get("tabsource", inst.get("tabtype", 903)))
		out.append({
			"instanceid": str(inst.get("instanceid", "")),
			"postid": postid,
			"tabsource": tabsource,
			"createdat": int(inst.get("createdat", int(Time.get_unix_time_from_system()))),
			"fpcollected": bool(inst.get("fpcollected", false)),
			"keypostcollected": bool(inst.get("keypostcollected", inst.get("intelcollected", false))),
			"fpearned": int(inst.get("fpearned", 0)),
		})
	return out


static func normalize_mypost_queue(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		if not (item is Dictionary):
			continue
		var q: Dictionary = item as Dictionary
		out.append({
			"queue_id": str(q.get("queue_id", "")),
			"mypostid": str(q.get("mypostid", "")),
			"state": str(q.get("state", "exposing")),
			"heat": int(q.get("heat", 0)),
			"heat_sources": _as_string_array(q.get("heat_sources", [])),
			"hotresult": int(q.get("hotresult", -1)),
			"expose_start_ts": int(q.get("expose_start_ts", 0)),
			"expose_end_ts": int(q.get("expose_end_ts", 0)),
			"idle_fp_earned": int(q.get("idle_fp_earned", 0)),
			"idle_fans_earned": int(q.get("idle_fans_earned", 0)),
			"idle_next_ts": int(q.get("idle_next_ts", 0)),
			"title": str(q.get("title", "")),
			"is_pinned": bool(q.get("is_pinned", false)),
		})
	return out


static func normalize_feed_pending(raw: Array) -> Array:
	var out: Array = []
	var now: int = int(Time.get_unix_time_from_system())
	for item in raw:
		if not (item is Dictionary):
			continue
		var p: Dictionary = item as Dictionary
		var delay_sec: int = int(p.get("delay_sec", 0))
		var release_ts: int = int(p.get("release_ts", 0))
		var cd_armed: bool = bool(p.get("cd_armed", false))
		if not p.has("cd_armed") and not p.has("delay_sec") and release_ts > 0:
			delay_sec = maxi(release_ts - now, 1)
			release_ts = 0
			cd_armed = false
		elif p.has("cd_armed"):
			cd_armed = bool(p.get("cd_armed", false))
		elif release_ts > 0:
			cd_armed = true
		if delay_sec <= 0 and not cd_armed:
			delay_sec = 2
		out.append({
			"postid": str(p.get("postid", "")),
			"tabsource": int(p.get("tabsource", 903)),
			"delay_sec": delay_sec,
			"release_ts": release_ts if cd_armed else 0,
			"cd_armed": cd_armed,
		})
	return out


static func _read_fields(sm, config: ConfigFile) -> void:
	sm.fp = int(config.get_value("player", "fp", 0))
	sm.intel = int(config.get_value("player", "intel", 0))
	sm.stars = int(config.get_value("player", "stars", 0))
	sm.intellevel = int(config.get_value("player", "intellevel", 0))
	sm.fanlevel = int(config.get_value("player", "fanlevel", 0))
	sm.stationexp = int(config.get_value("player", "stationexp", 0))
	sm.tutorialstep = int(config.get_value("player", "tutorialstep", 0))
	sm.tutorialdone = bool(config.get_value("player", "tutorialdone", false))
	sm.recent_opened_chapter_id = int(config.get_value("player", "recent_opened_chapter_id", 0))
	sm.recent_opened_level_id = str(config.get_value("player", "recent_opened_level_id", ""))
	sm.chapter_completed = _as_dict(config.get_value("chapter", "completed", {}))
	sm.chapter_unlocked = _as_dict(config.get_value("chapter", "unlocked", {}))
	sm.chapter_new_badge = _as_dict(config.get_value("chapter", "new_badge", {}))
	sm.level_unlocked = _as_dict(config.get_value("level", "unlocked", {}))
	sm.level_completed = _as_dict(config.get_value("level", "completed", {}))
	sm.level_progress = _as_dict(config.get_value("level", "progress", {}))
	sm.level_hotspot_clicked = _as_dict(config.get_value("level_hotspot", "clicked", {}))
	sm.inventory = _as_dict(config.get_value("inventory", "items", {}))
	sm.feed_instances = normalize_feed_instances(_as_array(config.get_value("instances", "feed", [])))
	sm.banner_last_offline_ts = int(config.get_value("banner", "last_offline_ts", 0))
	sm.keypost_progress = int(config.get_value("player", "keypost_progress", 0))
	sm.keypost_pity = _as_dict(config.get_value("player", "keypost_pity", {}))
	sm._instance_id_counter = int(config.get_value("instances", "id_counter", 0))
	sm.feed_seen = _as_dict(config.get_value("feed", "seen", {}))
	sm.feed_pinned_post_id = str(config.get_value("feed", "pinned_post_id", ""))
	sm.activity_state = _as_dict(config.get_value("activity", "state", {}))
	sm.opening_done = bool(config.get_value("player", "opening_done", false))
	sm.post_counts = _as_dict(config.get_value("player", "post_counts", {}))
	sm.mypost_queue = normalize_mypost_queue(_as_array(config.get_value("player", "mypost_queue", [])))
	sm.favorites = _as_string_array(config.get_value("player", "favorites", []))
	sm.fans = int(config.get_value("player", "fans", 0))
	sm.hotcount = int(config.get_value("player", "hotcount", 0))
	sm.activity_first_clear = _as_dict(config.get_value("player", "activity_first_clear", {}))
	sm.feed_pending = normalize_feed_pending(_as_array(config.get_value("player", "feed_pending", [])))


static func _as_dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _as_array(v: Variant) -> Array:
	return v if v is Array else []


static func _as_string_array(v: Variant) -> Array:
	if not (v is Array):
		return []
	var out: Array = []
	for item in v:
		out.append(str(item))
	return out
