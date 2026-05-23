extends Control

enum PageId {
	HOME,
	FEED,
	LEVEL_SELECT,
	CODEX,
	SETTINGS
}

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const KEY_MUSIC := "music_enabled"
const KEY_SFX := "sfx_enabled"
const DEBUG_LOG_PATH := "D:/GAMES/pubble/debug-fe0741.log"
const DEBUG_TRACE_LOG_PATH := "D:/GAMES/pubble/debug-8f8638.log"
@onready var top_bar: Control = $SafeArea/RootVBox/TopBar
@onready var home_page: Control = $SafeArea/RootVBox/ContentStack/HomePage
@onready var feed_page: Control = $SafeArea/RootVBox/ContentStack/FeedPage ## scenes/feed_page.gd
@onready var level_select_page: Control = $SafeArea/RootVBox/ContentStack/LevelSelectPage
@onready var codex_page: Control = $SafeArea/RootVBox/ContentStack/CodexPage
@onready var settings_page: Control = $SafeArea/RootVBox/ContentStack/SettingsPage
@onready var btn_home: Button = $SafeArea/RootVBox/BottomNav/NavMargin/NavHBox/BtnHome
@onready var btn_feed: Button = $SafeArea/RootVBox/BottomNav/NavMargin/NavHBox/BtnFeed
@onready var btn_codex: Button = $SafeArea/RootVBox/BottomNav/NavMargin/NavHBox/BtnCodex
@onready var btn_settings: Button = $SafeArea/RootVBox/BottomNav/NavMargin/NavHBox/BtnSettings

@onready var cheer_value: Label = $SafeArea/RootVBox/TopBar/CheerGroup/CheerValue
@onready var music_toggle: CheckButton = $SafeArea/RootVBox/ContentStack/SettingsPage/SettingsMargin/SettingsVBox/MusicRow/MusicToggle
@onready var sfx_toggle: CheckButton = $SafeArea/RootVBox/ContentStack/SettingsPage/SettingsMargin/SettingsVBox/SfxRow/SfxToggle
@onready var card_stack_ui: Control = $SafeArea/RootVBox/ContentStack/HomePage/HomeMargin/CardStack

var current_page: Control = null
var cheer_count: int = 0
var chapters_sorted: Array = []
var chapter_manager: ChapterManager
var save_manager: SaveManager
var condition_checker: ConditionChecker

#region agent log
func _dbg(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "run1") -> void:
	var payload := {
		"sessionId": "fe0741",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f: FileAccess = FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

#region agent log
func _dbg8(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "run1") -> void:
	var payload := {
		"sessionId": "8f8638",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f: FileAccess = FileAccess.open(DEBUG_TRACE_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_TRACE_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

func _ready() -> void:
	_init_managers()
	_connect_nav_signals()
	_connect_setting_signals()
	_connect_card_stack_signals()
	_connect_level_select_signals()
	_connect_feed_signals()
	if save_manager != null:
		_set_cheer(save_manager.get_cheer_count())
	else:
		_set_cheer(0)
	load_settings()
	if chapter_manager != null:
		_load_chapter_data()
	_refresh_home_cards()
	_ensure_initial_page_state()
	if not _apply_pending_post_level_nav():
		show_page(PageId.HOME)

func _ensure_initial_page_state() -> void:
	home_page.visible = true
	feed_page.visible = false
	level_select_page.visible = false
	codex_page.visible = false
	settings_page.visible = false
	current_page = home_page
	#region agent log
	_dbg8(
		"H7",
		"ui_router.gd:_ensure_initial_page_state",
		"initialize current_page to home before pending nav",
		{
			"home_visible": home_page.visible,
			"feed_visible": feed_page.visible,
			"level_select_visible": level_select_page.visible
		}
	)
	#endregion

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

func _connect_nav_signals() -> void:
	btn_home.pressed.connect(func() -> void: show_page(PageId.HOME))
	btn_feed.pressed.connect(func() -> void: show_page(PageId.FEED))
	btn_codex.pressed.connect(func() -> void: show_page(PageId.CODEX))
	btn_settings.pressed.connect(func() -> void: show_page(PageId.SETTINGS))

func _connect_setting_signals() -> void:
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)

func _connect_card_stack_signals() -> void:
	if card_stack_ui != null and card_stack_ui.has_signal("chapter_selected"):
		card_stack_ui.connect("chapter_selected", Callable(self, "_on_card_stack_chapter_selected"))

func _connect_feed_signals() -> void:
	if feed_page == null:
		return
	if feed_page.has_signal("feed_open_level"):
		feed_page.feed_open_level.connect(_on_feed_open_level)
	if feed_page.has_signal("feed_open_level_select"):
		feed_page.feed_open_level_select.connect(_on_feed_open_level_select)


func _connect_level_select_signals() -> void:
	if level_select_page == null:
		return
	if level_select_page.has_signal("close_requested"):
		level_select_page.connect("close_requested", Callable(self, "_on_level_select_close_requested"))
	if level_select_page.has_signal("level_start_requested"):
		level_select_page.connect("level_start_requested", Callable(self, "_on_level_start_requested"))
	if level_select_page.has_signal("chapter_state_changed"):
		level_select_page.connect("chapter_state_changed", Callable(self, "_on_chapter_state_changed"))

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
	_update_nav_visual(page_id)
	top_bar.visible = page_id != PageId.LEVEL_SELECT
	if save_manager != null:
		_set_cheer(save_manager.get_cheer_count())

func _get_page_by_id(page_id: PageId) -> Control:
	match page_id:
		PageId.HOME: return home_page
		PageId.FEED: return feed_page
		PageId.LEVEL_SELECT: return level_select_page
		PageId.CODEX: return codex_page
		PageId.SETTINGS: return settings_page
		_: return null

func _update_nav_visual(active_page: PageId) -> void:
	btn_home.disabled = (active_page == PageId.HOME)
	btn_feed.disabled = (active_page == PageId.FEED)
	btn_codex.disabled = (active_page == PageId.CODEX)
	btn_settings.disabled = (active_page == PageId.SETTINGS)

func add_cheer(amount: int) -> void:
	_set_cheer(cheer_count + amount)

func _set_cheer(value: int) -> void:
	cheer_count = max(value, 0)
	cheer_value.text = str(cheer_count)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)

	var music_enabled := true
	var sfx_enabled := true

	if err == OK:
		music_enabled = bool(config.get_value(SECTION_AUDIO, KEY_MUSIC, true))
		sfx_enabled = bool(config.get_value(SECTION_AUDIO, KEY_SFX, true))

	music_toggle.button_pressed = music_enabled
	sfx_toggle.button_pressed = sfx_enabled
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, KEY_MUSIC, music_toggle.button_pressed)
	config.set_value(SECTION_AUDIO, KEY_SFX, sfx_toggle.button_pressed)

	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Save settings failed: %d" % err)

func _on_music_toggled(_pressed: bool) -> void:
	save_settings()

func _on_sfx_toggled(_pressed: bool) -> void:
	save_settings()

func _load_chapter_data() -> void:
	chapters_sorted = chapter_manager.get_all_chapters()

func _refresh_home_cards() -> void:
	if card_stack_ui != null and card_stack_ui.has_method("setup"):
		card_stack_ui.call("setup", chapters_sorted, save_manager)

func _on_feed_open_level(level: Dictionary) -> void:
	var level_id: String = str(level.get("level_id", ""))
	#region agent log
	_dbg8(
		"H2",
		"ui_router.gd:_on_feed_open_level",
		"feed requests direct level start",
		{
			"level_id": level_id,
			"chapter_id": int(level.get("chapter_id", 0)),
			"scene_path": str(level.get("scene_path", ""))
		}
	)
	#endregion
	if save_manager != null:
		save_manager.set_recent_opened_level_id(level_id)
		save_manager.set_recent_opened_chapter_id(int(level.get("chapter_id", 0)))
	_on_level_start_requested(level)


func _on_feed_open_level_select(chapter_id: int, focus_level_id: String) -> void:
	#region agent log
	_dbg8(
		"H2",
		"ui_router.gd:_on_feed_open_level_select",
		"feed requests open level select",
		{
			"chapter_id": chapter_id,
			"focus_level_id": focus_level_id
		}
	)
	#endregion
	#region agent log
	_dbg(
		"H3",
		"ui_router.gd:_on_feed_open_level_select",
		"open level select from feed",
		{
			"chapter_id": chapter_id,
			"focus_level_id": focus_level_id
		}
	)
	#endregion
	_open_level_select(chapter_id)
	if level_select_page != null and level_select_page.has_method("focus_level_by_id"):
		level_select_page.call("focus_level_by_id", focus_level_id)


func _on_level_select_close_requested() -> void:
	#region agent log
	_dbg(
		"H3",
		"ui_router.gd:_on_level_select_close_requested",
		"close level select to home",
		{
			"recent_opened_chapter_id": save_manager.get_recent_opened_chapter_id() if save_manager != null else -1
		}
	)
	#endregion
	show_page(PageId.HOME)
	# 从动态页或其他入口进入选关后，关闭时要按 recent chapter 重新定位主界面卡堆。
	_refresh_home_cards()


func _on_card_stack_chapter_selected(chapter_id: int) -> void:
	# 主界面仅转发 chapter_id，不做条件判断与解锁处理。
	_open_level_select(chapter_id)

func _open_level_select(chapter_id: int) -> void:
	#region agent log
	_dbg8(
		"H3",
		"ui_router.gd:_open_level_select",
		"open level select",
		{
			"chapter_id": chapter_id,
			"recent_opened_level_id": save_manager.get_recent_opened_level_id() if save_manager != null else "",
			"current_page_before": _get_page_name(current_page)
		}
	)
	#endregion
	if save_manager != null:
		save_manager.set_recent_opened_chapter_id(chapter_id)
	if level_select_page != null and level_select_page.has_method("setup"):
		level_select_page.call("setup", chapter_id, chapter_manager, save_manager, condition_checker)
	show_page(PageId.LEVEL_SELECT)

func _on_level_start_requested(level: Dictionary) -> void:
	var level_id: String = str(level.get("level_id", ""))
	var scene_path: String = str(level.get("scene_path", ""))
	if scene_path.is_empty():
		_show_level_select_status("关卡 %s 没有 scene_path" % level_id)
		return
	if not FileAccess.file_exists(scene_path):
		_show_level_select_status("玩法场景待创建：%s" % scene_path)
		push_warning("Level scene not found: %s" % scene_path)
		return
	get_tree().set_meta("pending_level_id", level_id)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		_show_level_select_status("进入关卡失败：%s" % scene_path)
		push_warning("Change scene failed (%d): %s" % [err, scene_path])

func _show_level_select_status(text: String) -> void:
	if level_select_page != null and level_select_page.has_method("show_status"):
		level_select_page.call("show_status", text)

func _on_chapter_state_changed() -> void:
	if save_manager != null:
		_set_cheer(save_manager.get_cheer_count())
	_refresh_home_cards()


func _apply_pending_post_level_nav() -> bool:
	if save_manager == null:
		return false
	var pending: Dictionary = save_manager.consume_pending_post_level_nav()
	#region agent log
	_dbg8(
		"H4",
		"ui_router.gd:_apply_pending_post_level_nav",
		"consume pending nav",
		{
			"pending": pending
		}
	)
	#endregion
	if pending.is_empty():
		return false
	var page: String = str(pending.get("page", ""))
	if page == "level_select":
		var ch_id: int = int(pending.get("chapter_id", 0))
		var focus_level_id: String = str(pending.get("focus_level_id", ""))
		if ch_id > 0:
			_open_level_select(ch_id)
			if level_select_page != null and level_select_page.has_method("focus_level_by_id"):
				level_select_page.call("focus_level_by_id", focus_level_id)
			return true
	elif page == "home":
		show_page(PageId.HOME)
		if save_manager != null:
			_set_cheer(save_manager.get_cheer_count())
		_refresh_home_cards()
		return true
	return false

func _get_page_name(page: Control) -> String:
	if page == null:
		return "null"
	return str(page.name)
