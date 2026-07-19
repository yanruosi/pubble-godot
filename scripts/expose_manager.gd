extends "res://scripts/expose/expose_facade_api.gd"
class_name ExposeManager

const TAB_FANDOM := 0
const TAB_SISTER := 903
const TAB_ACCOUNT := 904
const POSTCLASS_NORMAL := 1
const POSTCLASS_ADVANCED := 2
const POSTCLASS_KEY := 3
const FAVORITE_MYPOST_PREFIX := "mypost:"
const BANNER_EXPOSING := "exposing"
const BANNER_HOT_SUCCESS := "hot_success"
const BANNER_HOT_FAIL := "hot_fail"
const BANNER_NEW_REPLACED := "new_replaced"
const BANNER_DEFAULT_STATIC := "default_static"
const AUTO_SETTLE_TABS: Array[int] = [TAB_FANDOM, TAB_SISTER, TAB_ACCOUNT]

const _CtxMod = preload("res://scripts/expose/expose_context.gd")
const _QueueMod = preload("res://scripts/expose/expose_queue.gd")
const _SettleMod = preload("res://scripts/expose/expose_settle.gd")
const _HeatMod = preload("res://scripts/expose/heat_system.gd")
const _HotRollMod = preload("res://scripts/expose/hot_roll.gd")
const _IdleMod = preload("res://scripts/expose/idle_income.gd")
const _FeedMod = preload("res://scripts/expose/feed_refresh.gd")
const _InstMod = preload("res://scripts/expose/feed_instances.gd")
const _PostsMod = preload("res://scripts/expose/feed_posts.gd")
const _BannerMod = preload("res://scripts/expose/banner_state.gd")
const _DebugMod = preload("res://scripts/expose/expose_debug.gd")

var _active_tabtype: int = -1
var _tick_accum: float = 0.0

signal banner_state_changed
signal instance_changed
signal lump_granted(tabtype: int, grant_type: int, amount: int)
signal intel_level_up(new_level: int)
signal keypost_favorited(instance_id: String)
signal queue_settled(queue_id: String, hotresult: int)


func _ready() -> void:
	var save_mgr := get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var econ := get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_ctx = _CtxMod.new(self, save_mgr, econ)
	var queue = _QueueMod.new(_ctx)
	var heat = _HeatMod.new(_ctx)
	var hot_roll = _HotRollMod.new(_ctx)
	var idle = _IdleMod.new(_ctx)
	var feed = _FeedMod.new(_ctx)
	var instances = _InstMod.new(_ctx)
	var posts = _PostsMod.new(_ctx)
	var banner = _BannerMod.new(_ctx)
	var settle = _SettleMod.new(_ctx)
	var debug = _DebugMod.new(_ctx)
	_ctx.wire_modules(queue, heat, hot_roll, idle, feed, instances, posts, banner, settle)
	_ctx.debug = debug
	queue.head_matured.connect(_on_head_matured)
	idle.idle_gain.connect(func(t, g, a): lump_granted.emit(t, g, a))
	_load_tables()


func _process(delta: float) -> void:
	_ctx.banner.tick_override_expiry(Time.get_ticks_msec() / 1000.0)
	_tick_accum += delta
	if _tick_accum < 0.25:
		return
	_tick_accum = 0.0
	_ctx.queue.tick()
	_ctx.idle.tick()
	if _active_tabtype == TAB_FANDOM or _active_tabtype == TAB_SISTER:
		_ctx.feed.poll_due(_active_tabtype)
	if _ctx.save != null and not _ctx.save.mypost_queue.is_empty():
		banner_state_changed.emit()


func _load_tables() -> void:
	_ctx.load_my_post_tables()
	_ctx.heat.load_tables()
	_ctx.idle.load_tables()
	_ctx.instances.load_tables()
	_ctx.posts.load_tables()


func _on_head_matured(item: Dictionary) -> void:
	_ctx.hot_roll.roll_hot(item)
	if _active_tabtype in AUTO_SETTLE_TABS:
		_ctx.settle.settle_item(item)
	else:
		banner_state_changed.emit()


func _catch_up_offline() -> void:
	if _ctx.save == null:
		return
	var last: int = _ctx.save.banner_last_offline_ts
	var now: int = int(Time.get_unix_time_from_system())
	if last <= 0 or now <= last:
		return
	_ctx.settle.catch_up_offline_loop(500, Callable(self, "_on_head_matured"))
	_ctx.idle.tick()
	_ctx.save.banner_last_offline_ts = now


func on_game_loaded() -> void:
	if _ctx.save == null:
		return
	_ctx.save.feed_instances = _ctx.save.normalize_feed_instances(_ctx.save.feed_instances)
	if _ctx.save.banner_last_offline_ts <= 0:
		_ctx.save.banner_last_offline_ts = int(Time.get_unix_time_from_system())
	_ctx.queue.ensure_head_timer()
	_catch_up_offline()
	_ctx.save.save_progress()
	banner_state_changed.emit()


func on_tab_entered(tabtype: int) -> void:
	if not _ctx.posts.supports_unified_banner(tabtype):
		return
	_active_tabtype = tabtype
	if tabtype == TAB_FANDOM:
		_ctx.feed.arm_on_first_fanclub()
	refresh_feed_on_tab(tabtype)
	banner_state_changed.emit()


func on_tab_left(tabtype: int) -> void:
	if tabtype != _active_tabtype:
		return
	_active_tabtype = -1
	_ctx.banner.clear_fail_on_tab_left()
	banner_state_changed.emit()


func notify_app_closing() -> void:
	if _ctx.save == null:
		return
	_ctx.save.banner_last_offline_ts = int(Time.get_unix_time_from_system())
	_ctx.save.save_progress()
