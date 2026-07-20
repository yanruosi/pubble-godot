extends RefCounted

## 曝光结算与离线追赶

var _ctx


func _init(ctx) -> void:
	_ctx = ctx


func settle_item(item: Dictionary) -> void:
	var save: SaveManager = _ctx.save
	var econ: EconomyManager = _ctx.economy
	if save == null or econ == null:
		return
	if str(item.get("state", "")) == "collected":
		return
	var def: Dictionary = _ctx.my_posts_by_id.get(str(item.get("mypostid", "")), {})
	var hot_ok: bool = int(item.get("hotresult", 0)) == 1
	var fp_grant: int = int(def.get("basefp", 0))
	var fans_grant: int = int(def.get("basefans", 0))
	if hot_ok:
		fp_grant += int(def.get("hotbonusfp", 0))
		save.hotcount += 1
	econ.add_currency(SaveManager.CAT_FP, fp_grant, "expose_settle")
	save.fans += fans_grant
	_ctx.check_station_level_up()
	if econ.has_method("notify_balance_updated"):
		econ.notify_balance_updated(SaveManager.CAT_FP)
	item["state"] = "collected"
	item["settle_fp"] = fp_grant
	item["settle_fans"] = fans_grant
	item["idle_fp_earned"] = 0
	item["idle_fans_earned"] = 0
	_ctx.banner.set_focus_queue_id(str(item.get("queue_id", "")))
	if hot_ok:
		var idle_id: String = str(def.get("idlerewardid", "1001"))
		if idle_id.is_empty():
			idle_id = "1001"
		_ctx.banner.clear_fail_queue_id()
		_ctx.idle.start(item, idle_id)
	else:
		item["idle_next_ts"] = 0
		_ctx.banner.set_fail_queue_id(str(item.get("queue_id", "")))
	_ctx.host.lump_granted.emit(ExposeManager.TAB_ACCOUNT, SaveManager.CAT_FP, fp_grant)
	_ctx.host.queue_settled.emit(str(item.get("queue_id", "")), int(item.get("hotresult", 0)))
	advance_after_settle()
	save.save_progress()
	_ctx.host.instance_changed.emit()
	_ctx.banner.notify_changed()


func advance_after_settle() -> void:
	_ctx.queue.cleanup_finished_collected()
	var new_head: Dictionary = _ctx.queue.get_exposing_item()
	if new_head.is_empty():
		return
	if str(new_head.get("state", "")) == "exposing" and int(new_head.get("expose_end_ts", 0)) <= 0:
		_ctx.queue.start_timer(new_head)


func catch_up_offline_loop(max_iter: int, on_head_matured: Callable) -> void:
	var save: SaveManager = _ctx.save
	if save == null:
		return
	var guard := 0
	while guard < max_iter:
		guard += 1
		var head: Dictionary = _ctx.queue.get_exposing_item()
		if head.is_empty():
			break
		if str(head.get("state", "")) == "exposing":
			if _ctx.queue.remaining_expose_sec(head) > 0.0:
				break
			on_head_matured.call(head)
			if str(head.get("state", "")) == "exposing":
				settle_item(head)
		else:
			break
