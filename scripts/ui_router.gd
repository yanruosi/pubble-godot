extends Control

enum PageId {
	HOME,
	FEED,
	LEVEL_SELECT
}

@onready var top_bar: Control = $SafeArea/RootVBox/TopBar
@onready var bottom_nav: Control = $SafeArea/RootVBox/BottomNav
@onready var home_page: Control = $SafeArea/RootVBox/ContentStack/HomePage
@onready var feed_page: Control = $SafeArea/RootVBox/ContentStack/FeedPage
@onready var level_select_page: Control = $SafeArea/RootVBox/ContentStack/LevelSelectPage
@onready var btn_artist_feed: Button = $SafeArea/RootVBox/ContentStack/HomePage/BtnArtistFeed
@onready var home_margin: MarginContainer = $SafeArea/RootVBox/ContentStack/HomePage/HomeMargin

var current_page: Control = null
var chapter_manager: ChapterManager
var save_manager: SaveManager
var condition_checker: ConditionChecker


func _ready() -> void:
	_init_managers()
	_apply_chrome_hidden()
	_connect_home_entry()
	_connect_feed_signals()
	_connect_level_select_signals()
	_ensure_initial_page_state()
	_apply_boot_entry()


func _apply_chrome_hidden() -> void:
	top_bar.visible = false
	bottom_nav.visible = false
	if home_margin != null:
		home_margin.visible = false


func _ensure_initial_page_state() -> void:
	home_page.visible = true
	feed_page.visible = false
	level_select_page.visible = false
	current_page = home_page


func _init_managers() -> void:
	chapter_manager = get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	condition_checker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker

	if chapter_manager == null:
		push_warning("Autoload ChapterManagerSingleton not found")
	if save_manager == null:
		push_warning("Autoload SaveManagerSingleton not found")
	if condition_checker == null:
		push_warning("Autoload ConditionCheckerSingleton not found")

	if condition_checker != null and chapter_manager != null and save_manager != null:
		condition_checker.setup(chapter_manager, save_manager)


func _connect_home_entry() -> void:
	if btn_artist_feed != null:
		btn_artist_feed.pressed.connect(_on_artist_feed_pressed)


func _connect_feed_signals() -> void:
	if feed_page == null:
		return
	if feed_page.has_signal("feed_open_level"):
		feed_page.feed_open_level.connect(_on_feed_open_level)
	if feed_page.has_signal("feed_back_requested"):
		feed_page.feed_back_requested.connect(_on_feed_back_requested)


func _on_feed_back_requested() -> void:
	show_page(PageId.HOME)


func _connect_level_select_signals() -> void:
	if level_select_page == null:
		return
	if level_select_page.has_signal("level_start_requested"):
		level_select_page.connect("level_start_requested", Callable(self, "_on_level_start_requested"))


func _on_artist_feed_pressed() -> void:
	open_feed_artist_tab()


func open_feed_artist_tab() -> void:
	if feed_page != null and feed_page.has_method("set_active_tab"):
		feed_page.call("set_active_tab", "artist")
	show_page(PageId.FEED)


func show_page(page_id: PageId) -> void:
	var target: Control = _get_page_by_id(page_id)
	if target == null:
		push_warning("Invalid page id")
		return

	if current_page != null:
		current_page.visible = false

	target.visible = true
	current_page = target
	if page_id == PageId.FEED and feed_page.has_method("refresh_feed"):
		feed_page.call_deferred("refresh_feed")
	top_bar.visible = false
	bottom_nav.visible = false


func _get_page_by_id(page_id: PageId) -> Control:
	match page_id:
		PageId.HOME: return home_page
		PageId.FEED: return feed_page
		PageId.LEVEL_SELECT: return level_select_page
		_: return null


func _apply_boot_entry() -> void:
	var target := ""
	if save_manager != null:
		target = save_manager.boot_target
		save_manager.boot_target = ""
		save_manager.mark_game_started()
	if target == "home":
		show_page(PageId.HOME)
		return
	if not _apply_pending_post_level_nav():
		show_page(PageId.HOME)


func _on_feed_open_level(level: Dictionary) -> void:
	var level_id: String = str(level.get("levelid", ""))
	if save_manager != null:
		save_manager.set_recent_opened_level_id(level_id)
		save_manager.set_recent_opened_chapter_id(int(level.get("chapter_id", 0)))
	_on_level_start_requested(level)


func _on_level_start_requested(level: Dictionary) -> void:
	var level_id: String = str(level.get("levelid", ""))
	var scene_path: String = str(level.get("scene_path", ""))
	if scene_path.is_empty():
		push_warning("关卡 %s 没有 scene_path" % level_id)
		return
	if not FileAccess.file_exists(scene_path):
		push_warning("Level scene not found: %s" % scene_path)
		return
	get_tree().set_meta("pending_level_id", level_id)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("Change scene failed (%d): %s" % [err, scene_path])


func _apply_pending_post_level_nav() -> bool:
	if save_manager == null:
		return false
	var pending: Dictionary = save_manager.consume_pending_post_level_nav()
	if pending.is_empty():
		return false
	var page: String = str(pending.get("page", ""))
	if page == "feed":
		var tab: String = str(pending.get("tab", "artist"))
		if feed_page != null and feed_page.has_method("set_active_tab"):
			feed_page.call("set_active_tab", tab)
		show_page(PageId.FEED)
		return true
	if page == "home":
		show_page(PageId.HOME)
		return true
	return false
