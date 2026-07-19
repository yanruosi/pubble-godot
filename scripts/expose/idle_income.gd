extends RefCounted

## 热帖成功后的放置收益（idle_rewards 1001）

signal idle_gain(tabtype: int, grant_type: int, amount: int)

var _ctx
var _idle_rewards_by_id: Dictionary = {}


func _init(ctx) -> void:
	_ctx = ctx


func load_tables() -> void:
	_idle_rewards_by_id.clear()
	for row in TableRepo.get_table("idle_rewards"):
		if row is Dictionary:
			_idle_rewards_by_id[str(row.get("id", ""))] = row


func start(item: Dictionary, idle_id: String) -> void:
	if idle_id.is_empty():
		item["idle_next_ts"] = 0
		return
	var idle: Dictionary = _idle_rewards_by_id.get(idle_id, {})
	if idle.is_empty():
		item["idle_next_ts"] = 0
		return
	var min_sec: int = maxi(int(idle.get("intervalmin", 8)), 1)
	var max_sec: int = maxi(int(idle.get("intervalmax", min_sec)), min_sec)
	var wait_sec: int = randi_range(min_sec, max_sec)
	item["idle_next_ts"] = int(Time.get_unix_time_from_system()) + wait_sec


func tick() -> void:
	if _ctx.save == null or _ctx.economy == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var changed := false
	for item_raw in _ctx.save.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) != "collected":
			continue
		if int(item.get("hotresult", 0)) != 1:
			if int(item.get("idle_next_ts", 0)) != 0:
				item["idle_next_ts"] = 0
				changed = true
			continue
		if int(item.get("idle_next_ts", 0)) <= 0 or now < int(item.get("idle_next_ts", 0)):
			continue
		var def: Dictionary = _ctx.my_posts_by_id.get(str(item.get("mypostid", "")), {})
		var idle_id: String = str(def.get("idlerewardid", "1001"))
		var idle: Dictionary = _idle_rewards_by_id.get(idle_id, {})
		var fp_cap: int = int(idle.get("fpcap", 0))
		var fans_cap: int = int(idle.get("fanscap", 0))
		var fp_earned: int = int(item.get("idle_fp_earned", 0))
		var fans_earned: int = int(item.get("idle_fans_earned", 0))
		if fp_earned >= fp_cap and fans_earned >= fans_cap:
			item["idle_next_ts"] = 0
			changed = true
			continue
		var fp_tick: int = 1 if fp_earned < fp_cap else 0
		var fans_tick: int = 1 if fans_earned < fans_cap else 0
		if fp_tick > 0:
			_ctx.economy.add_currency(SaveManager.CAT_FP, fp_tick, "idle_reward")
			item["idle_fp_earned"] = fp_earned + fp_tick
			idle_gain.emit(ExposeManager.TAB_ACCOUNT, SaveManager.CAT_FP, fp_tick)
		if fans_tick > 0:
			_ctx.save.fans += fans_tick
			item["idle_fans_earned"] = fans_earned + fans_tick
			_ctx.check_station_level_up()
		if int(item.get("idle_fp_earned", 0)) >= fp_cap and int(item.get("idle_fans_earned", 0)) >= fans_cap:
			item["idle_next_ts"] = 0
		else:
			start(item, idle_id)
		changed = true
	if changed:
		_ctx.queue.cleanup_finished_collected()
		_ctx.save.save_progress()
		_ctx.banner.notify_changed()


func cleanup_caps_for_item(item: Dictionary) -> void:
	if str(item.get("state", "")) != "collected":
		return
	if int(item.get("hotresult", 0)) != 1:
		item["idle_next_ts"] = 0
		return
	var def: Dictionary = _ctx.my_posts_by_id.get(str(item.get("mypostid", "")), {})
	var idle_id: String = str(def.get("idlerewardid", "1001"))
	var idle: Dictionary = _idle_rewards_by_id.get(idle_id, {})
	var fp_cap: int = int(idle.get("fpcap", 0))
	var fans_cap: int = int(idle.get("fanscap", 0))
	var fp_earned: int = int(item.get("idle_fp_earned", 0))
	var fans_earned: int = int(item.get("idle_fans_earned", 0))
	if fp_earned >= fp_cap and fans_earned >= fans_cap:
		item["idle_next_ts"] = 0
