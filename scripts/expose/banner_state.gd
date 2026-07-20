extends RefCounted

## Banner 五态快照与 override 状态

var _ctx
var _override_state: String = ""
var _override_until: float = 0.0
var _focus_queue_id: String = ""
var _fail_queue_id: String = ""


func _init(ctx) -> void:
	_ctx = ctx


func tick_override_expiry(now_sec: float) -> void:
	if _override_until > 0.0 and now_sec >= _override_until:
		_override_state = ""
		_override_until = 0.0


func clear_fail_on_tab_left() -> void:
	_fail_queue_id = ""
	if _override_state == ExposeManager.BANNER_HOT_FAIL:
		_override_state = ""
		_override_until = 0.0


func set_override(state: String, duration_sec: float = 3.0) -> void:
	_override_state = state
	if state == ExposeManager.BANNER_HOT_FAIL:
		_override_until = 0.0
	else:
		_override_until = Time.get_ticks_msec() / 1000.0 + duration_sec


func on_expose_timer_start(item: Dictionary) -> void:
	_fail_queue_id = ""
	if _override_state == ExposeManager.BANNER_HOT_FAIL:
		_override_state = ""
		_override_until = 0.0
	_focus_queue_id = str(item.get("queue_id", ""))


func set_focus_queue_id(queue_id: String) -> void:
	_focus_queue_id = queue_id


func set_fail_queue_id(queue_id: String) -> void:
	_fail_queue_id = queue_id


func clear_fail_queue_id() -> void:
	_fail_queue_id = ""


func get_post_display_date(_instanceid: String = "") -> String:
	return _ctx.posts.get_post_display_date(_instanceid)


func notify_changed() -> void:
	_ctx.host.banner_state_changed.emit()


func get_snapshot() -> Dictionary:
	var queue = _ctx.queue
	var exposing: Dictionary = queue.get_exposing_item()
	var display: Dictionary = queue.get_display_item()
	var focus: Dictionary = queue.find_item(_focus_queue_id)
	if focus.is_empty() and _fail_queue_id != "":
		focus = queue.find_item(_fail_queue_id)
	var banner_state: String = ExposeManager.BANNER_DEFAULT_STATIC
	if _override_state != "":
		banner_state = _override_state
	elif _fail_queue_id != "" and not queue.find_item(_fail_queue_id).is_empty():
		banner_state = ExposeManager.BANNER_HOT_FAIL
		if focus.is_empty():
			focus = queue.find_item(_fail_queue_id)
	elif not exposing.is_empty():
		banner_state = ExposeManager.BANNER_EXPOSING
	elif not display.is_empty() and str(display.get("state", "")) == "collected":
		var hr: int = int(display.get("hotresult", -1))
		if hr == 1:
			banner_state = ExposeManager.BANNER_HOT_SUCCESS
		elif hr == 0:
			banner_state = ExposeManager.BANNER_HOT_FAIL

	var source: Dictionary = {}
	if banner_state == ExposeManager.BANNER_EXPOSING and not exposing.is_empty():
		source = exposing
	elif not focus.is_empty():
		source = focus
	elif not display.is_empty():
		source = display

	var remaining := -1.0
	var expose_total := 150.0
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
		heat_bonus = _ctx.heat.get_tier_bonus(heat)
		title = str(source.get("title", ""))
		is_pinned = bool(source.get("is_pinned", false))
		mypostid = str(source.get("mypostid", ""))
		settle_fp = int(source.get("settle_fp", 0))
		settle_fans = int(source.get("settle_fans", 0))
		if settle_fp == 0 and settle_fans == 0 and str(source.get("state", "")) == "collected":
			var def_fb: Dictionary = _ctx.my_posts_by_id.get(mypostid, {})
			settle_fp = int(def_fb.get("basefp", 0))
			settle_fans = int(def_fb.get("basefans", 0))
			if int(source.get("hotresult", 0)) == 1:
				settle_fp += int(def_fb.get("hotbonusfp", 0))
		if banner_state == ExposeManager.BANNER_EXPOSING:
			remaining = queue.remaining_expose_sec(source)
			var def_ex: Dictionary = _ctx.my_posts_by_id.get(mypostid, {})
			expose_total = maxf(float(def_ex.get("exposesec", 150)), 1.0)
		elif banner_state == ExposeManager.BANNER_HOT_SUCCESS:
			idle_fp = int(source.get("idle_fp_earned", 0))
			idle_fans = int(source.get("idle_fans_earned", 0))

	var display_fp: int = settle_fp + idle_fp
	var display_fans: int = settle_fans + idle_fans
	var save: SaveManager = _ctx.save
	var kp: Dictionary = _ctx.keypost_display()
	var next_artist := ""
	if _ctx.posts != null and _ctx.posts.has_method("get_next_unlock_artist_title"):
		next_artist = str(_ctx.posts.call("get_next_unlock_artist_title"))
	return {
		"banner_state": banner_state,
		"intellevel": save.intellevel if save != null else 0,
		"keypost_current": kp.get("current", 0),
		"keypost_target": kp.get("target", 0),
		"next_artist_title": next_artist,
		"heat": heat,
		"heat_bonus_rate": heat_bonus,
		"heat_max": 50,
		"remaining_sec": remaining,
		"expose_total_sec": expose_total,
		"idle_fp_earned": idle_fp,
		"idle_fans_earned": idle_fans,
		"settle_fp": settle_fp,
		"settle_fans": settle_fans,
		"display_fp": display_fp,
		"display_fans": display_fans,
		"title": title,
		"is_pinned": is_pinned,
		"mypostid": mypostid,
		"fans": save.fans if save != null else 0,
		"fp": save.fp if save != null else 0,
		"hotcount": save.hotcount if save != null else 0,
		"fanlevel": save.fanlevel if save != null else 0,
		"has_my_post": not display.is_empty() or not exposing.is_empty(),
		"queue_length": save.mypost_queue.size() if save != null else 0,
	}
