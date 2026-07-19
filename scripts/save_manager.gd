extends "res://scripts/data/save_manager_delegates.gd"
class_name SaveManager

const _Store = preload("res://scripts/data/save_store.gd")
const _Migrations = preload("res://scripts/data/save_migrations.gd")

const SAVE_PATH := "user://progress.cfg"
const SAVE_VERSION := 5

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
var keypost_progress: int = 0
var keypost_pity: Dictionary = {}
var _instance_id_counter: int = 0

var opening_done: bool = false
var post_counts: Dictionary = {}
var mypost_queue: Array = []
var favorites: Array = []
var fans: int = 0
var hotcount: int = 0
var activity_first_clear: Dictionary = {}
var feed_pending: Array = []

var pending_post_level_nav: Dictionary = {}
var feed_seen: Dictionary = {}
var feed_pinned_post_id: String = ""
var activity_state: Dictionary = {}
var boot_target: String = ""
var save_version_invalid: bool = false


func _init() -> void:
	load_progress()


func load_progress() -> void:
	var config: ConfigFile = _Store.load_config()
	if config == null:
		_Migrations.apply_defaults(self)
		save_progress()
		return
	save_version_invalid = not _Migrations.load_into(self, config)
	if save_version_invalid:
		save_progress()


func save_progress() -> void:
	var config: ConfigFile = _Store.ensure_config()
	_Migrations.save_from(self, config)
	var err: int = _Store.save_config(config)
	if err != OK:
		push_warning("Save progress failed: %d" % err)


func normalize_feed_instances(raw: Array) -> Array:
	return _Migrations.normalize_feed_instances(raw)


func is_game_started() -> bool:
	return _Store.read_game_started()


func mark_game_started() -> void:
	_Store.write_game_started(true)


func can_continue() -> bool:
	return is_game_started() and not save_version_invalid


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
	activity_state = {}
	recent_opened_chapter_id = 0
	recent_opened_level_id = ""
	pending_post_level_nav.clear()
	_Migrations.apply_defaults(self)
	mark_chapter_unlocked(1, true)
	chapter_new_badge["1"] = false
	mark_level_unlocked("ch1_l01", true)
	save_progress()
	mark_game_started()
