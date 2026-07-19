extends Control

signal feed_open_level(level: Dictionary)
signal feed_back_requested

const FeedController := preload("res://scripts/controllers/feed_controller.gd")
const FeedDefs := preload("res://scripts/views/feed_defs.gd")

var _ctrl: FeedController


func _ready() -> void:
	_ctrl = FeedController.new(self)
	_ctrl.load_json()
	call_deferred("_build_and_enter")


func _build_and_enter() -> void:
	_build_ui()
	_ctrl.set_active_tab(FeedDefs.TAB_ARTIST)


func _build_ui() -> void:
	_ctrl.build_ui()
	set_process(true)


func _process(_delta: float) -> void:
	_ctrl.process_banner_tick()


func set_active_tab(tab: String) -> void:
	_ctrl.set_active_tab(tab)


func apply_opening_post_lock(locked: bool) -> void:
	_ctrl.apply_opening_post_lock(locked)


func get_active_tab() -> String:
	return _ctrl.get_active_tab()


func get_artist_visible_count() -> int:
	return _ctrl.count_artist_posts() if _ctrl != null else 0


func refresh_feed(play_reveal: bool = false) -> void:
	_ctrl.refresh_feed(play_reveal)


func _feed_deferred_refresh(play_reveal: bool = false) -> void:
	_ctrl.refresh_feed(play_reveal)


func _feed_relayout_list() -> void:
	_ctrl.relayout_list()


func _feed_play_reveals(tabtype: int, run_id: int) -> void:
	_ctrl.play_pending_reveals(tabtype, run_id)
