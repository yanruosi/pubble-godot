extends RefCounted
class_name FeedController

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const FeedTabBarView := preload("res://scripts/views/feed_tab_bar.gd")
const FeedBannerView := preload("res://scripts/views/feed_banner_view.gd")
const FeedListView := preload("res://scripts/views/feed_list_view.gd")
const PostComposerView := preload("res://scripts/views/post_composer_view.gd")
const FeedUiBuild := preload("res://scripts/controllers/feed_ui_build.gd")
const FeedListVm := preload("res://scripts/controllers/feed_list_vm.gd")
const FeedTabRefresh := preload("res://scripts/controllers/feed_tab_refresh.gd")
const FeedCardActions := preload("res://scripts/controllers/feed_card_actions.gd")
const CurrencyBarView := preload("res://scripts/views/currency_bar_view.gd")
const _Nodes = preload("res://scripts/controllers/feed_controller_nodes.gd")

var _page: Control
var _active_tab: String = FeedDefs.TAB_ARTIST
var _posts_raw: Array = []
var _content_root: Control
var _scroll_started: bool = false
var _love_effect_tex: Texture2D
var _opening_post_lock: bool = false
var _reveal_run_id: int = 0
var _tab_bar: FeedTabBarView
var _banner: FeedBannerView
var _list: FeedListView
var _composer: PostComposerView
var _currency_bar: CurrencyBarView
var _toast_label: Label
var _bag_panel: PanelContainer
var _bag_grid: GridContainer
var _hot_list: VBoxContainer
var _ui: FeedUiBuild
var _vm: FeedListVm
var _tabs: FeedTabRefresh
var _actions: FeedCardActions

func _init(page: Control) -> void:
	_page = page
	_tab_bar = FeedTabBarView.new()
	_banner = FeedBannerView.new()
	_list = FeedListView.new()
	_composer = PostComposerView.new()
	_love_effect_tex = FeedDefs.load_tex(FeedDefs.PATH_LOVE)
	_ui = FeedUiBuild.new(self)
	_vm = FeedListVm.new(self)
	_tabs = FeedTabRefresh.new(self)
	_actions = FeedCardActions.new(self)

func load_json() -> void:
	var parsed: Variant = TableRepo.get_table("feed_posts")
	if parsed is Array:
		_posts_raw = parsed as Array
	else:
		_posts_raw.clear()
		push_warning("feed_page: feed_posts.json 非数组")

func build_ui() -> void:
	_ui.build_ui()
	_wire_signals()
	_ui.update_layout_visibility()
	_tab_bar.apply_visual(_active_tab, _opening_post_lock)
	refresh_banner_area()
	update_currency_hud()
	refresh_compose_area()

func set_active_tab(tab: String) -> void:
	var normalized := FeedDefs.normalize_tab_name(tab)
	if _opening_post_lock and normalized != FeedDefs.TAB_ACCOUNT:
		show_toast("请先完成首次发帖")
		return
	var old_exposure := FeedDefs.exposure_tabtype_for_name(_active_tab)
	var new_exposure := FeedDefs.exposure_tabtype_for_name(normalized)
	var expose: ExposeManager = _expose()
	if expose != null and old_exposure >= 0:
		expose.on_tab_left(old_exposure)
	_active_tab = normalized
	_scroll_started = false
	if expose != null and new_exposure >= 0:
		expose.on_tab_entered(new_exposure)
	if _page.is_inside_tree():
		_ui.update_layout_visibility()
		_tab_bar.apply_visual(_active_tab, _opening_post_lock)
		refresh_banner_area()
		update_currency_hud()
		refresh_compose_area()
		refresh_feed(true)

func apply_opening_post_lock(locked: bool) -> void:
	_opening_post_lock = locked
	_tab_bar.apply_visual(_active_tab, _opening_post_lock)
	if locked and _active_tab != FeedDefs.TAB_ACCOUNT:
		set_active_tab(FeedDefs.TAB_ACCOUNT)
	else:
		refresh_compose_area()

func get_active_tab() -> String:
	return _active_tab


func count_artist_posts() -> int:
	return _vm.collect_artist_enriched().size()


func build_favorites_vm() -> Array:
	return _vm.build_favorites_vm()


func process_banner_tick() -> void:
	if _banner.shows_dynamic_overlay(_active_tab):
		sync_banner_snapshot()

func relayout_list() -> void:
	_list.relayout(_ui.get_active_list_rect())

func refresh_feed(play_reveal: bool = false) -> void:
	load_json()
	update_currency_hud()
	if _list.list_box == null:
		return
	_reveal_run_id += 1
	var run_id := _reveal_run_id
	_list.clear_list()
	match _active_tab:
		FeedDefs.TAB_ARTIST:
			_tabs.refresh_artist_tab()
		FeedDefs.TAB_FAVORITES:
			_tabs.refresh_favorites_tab()
		FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ACCOUNT:
			var tabtype: int = FeedDefs.exposure_tabtype_for_name(_active_tab)
			_tabs.refresh_instance_tab(tabtype)
			_page.call_deferred("_feed_relayout_list")
			if play_reveal:
				_page.call_deferred("_feed_play_reveals", tabtype, run_id)
		FeedDefs.TAB_MARKET:
			_tabs.add_empty_tip("敬请期待")

func play_pending_reveals(tabtype: int, run_id: int = -1) -> void:
	await _tabs.play_pending_reveals(tabtype, run_id)

func refresh_banner_area() -> void:
	var expose: ExposeManager = _expose()
	_banner.relayout(_active_tab, _ui.get_active_banner_rect())
	if _active_tab in [FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ACCOUNT, FeedDefs.TAB_FAVORITES]:
		sync_banner_snapshot()
	_banner.refresh_tab(_active_tab, func() -> bool:
		return expose != null and expose.consume_pending_intel_level_up()
	)

func sync_banner_snapshot() -> void:
	var expose: ExposeManager = _expose()
	if expose == null:
		return
	var snap: Dictionary = expose.get_banner_snapshot()
	_banner.apply_snapshot(snap)

func refresh_compose_area() -> void:
	if _active_tab != FeedDefs.TAB_ACCOUNT:
		return
	var expose: ExposeManager = _expose()
	var sm: SaveManager = _save()
	if expose == null or sm == null:
		return
	var tags: Array = []
	for row in TableRepo.get_table("post_tags"):
		if not (row is Dictionary):
			continue
		var tag: Dictionary = row as Dictionary
		var tagid: String = str(tag.get("tagid", ""))
		if tagid.is_empty():
			continue
		tags.append({
			"tagid": tagid,
			"name": str(tag.get("name", tagid)),
			"count": sm.get_post_count(tagid),
		})
	_composer.refresh_tags(tags, expose)

func update_currency_hud(pulse_fp: bool = false) -> void:
	if not is_instance_valid(_page) or _currency_bar == null:
		return
	var sm: SaveManager = _save()
	if sm == null:
		return
	_currency_bar.apply(sm)
	if pulse_fp and is_instance_valid(_page):
		_currency_bar.pulse_fp(_page)

func show_toast(msg: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = msg
	_toast_label.position = Vector2(400, 340)
	_toast_label.visible = true
	var tw := _page.create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(func() -> void:
		if _toast_label != null:
			_toast_label.visible = false
	)

func _wire_signals() -> void:
	_tab_bar.tab_selected.connect(set_active_tab)
	_composer.publish_requested.connect(_actions.on_publish_requested)
	_composer.tag_blocked.connect(func(_tagid: String) -> void:
		show_toast("去参加线下活动获得次数")
	)
	_banner.market_bag_pressed.connect(_actions.on_market_bag_pressed)
	_list.scrolled_down.connect(_tabs.on_list_scrolled_down)
	var expose: ExposeManager = _expose()
	if expose == null:
		return
	if not expose.lump_granted.is_connected(_tabs.on_lump_granted):
		expose.lump_granted.connect(_tabs.on_lump_granted)
	if not expose.banner_state_changed.is_connected(_tabs.on_banner_state_changed):
		expose.banner_state_changed.connect(_tabs.on_banner_state_changed)
	if not expose.intel_level_up.is_connected(_tabs.on_intel_level_up):
		expose.intel_level_up.connect(_tabs.on_intel_level_up)
	if not expose.instance_changed.is_connected(_on_instance_changed):
		expose.instance_changed.connect(_on_instance_changed)
	if not expose.lump_granted.is_connected(_on_hud_lump_granted):
		expose.lump_granted.connect(_on_hud_lump_granted)
	if not expose.intel_level_up.is_connected(_on_hud_intel_level_up):
		expose.intel_level_up.connect(_on_hud_intel_level_up)
	if not expose.keypost_favorited.is_connected(_on_hud_keypost_favorited):
		expose.keypost_favorited.connect(_on_hud_keypost_favorited)
	var economy: EconomyManager = _page.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if economy != null and not economy.balance_updated.is_connected(_on_economy_balance_updated):
		economy.balance_updated.connect(_on_economy_balance_updated)


func _on_economy_balance_updated(grant_type: int) -> void:
	update_currency_hud(grant_type == SaveManager.CAT_FP)

func _on_hud_lump_granted(_tabtype: int, grant_type: int, _amount: int) -> void:
	update_currency_hud(grant_type == SaveManager.CAT_FP)

func _on_hud_intel_level_up(_new_level: int) -> void:
	update_currency_hud()

func _on_hud_keypost_favorited(_instance_id: String) -> void:
	update_currency_hud()

func _on_instance_changed() -> void:
	if not is_instance_valid(_page):
		return
	_page.call_deferred("_feed_deferred_refresh", true)

func _expose() -> ExposeManager:
	return _Nodes.expose(_page)

func _save() -> SaveManager:
	return _Nodes.save(_page)

func _chapter() -> ChapterManager:
	return _Nodes.chapter(_page)

func _conditions() -> ConditionChecker:
	return _Nodes.conditions(_page)
