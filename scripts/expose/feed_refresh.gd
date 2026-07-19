extends RefCounted

## feed_pending 入队 / 首次进饭圈武装 / 到期刷帖

var _ctx


func _init(ctx) -> void:
	_ctx = ctx


func queue_pending(postid: String, tabsource: int, delay_sec: int) -> void:
	if _ctx.save == null or postid.is_empty():
		return
	var delay: int = maxi(delay_sec, 1)
	_ctx.save.feed_pending.append({
		"postid": postid,
		"tabsource": tabsource,
		"delay_sec": delay,
		"release_ts": 0,
		"cd_armed": false,
	})
	_ctx.save.save_progress()


func arm_on_first_fanclub() -> void:
	if _ctx.save == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	var armed_n := 0
	for item in _ctx.save.feed_pending:
		if not (item is Dictionary):
			continue
		var pending: Dictionary = item as Dictionary
		if bool(pending.get("cd_armed", false)) and int(pending.get("release_ts", 0)) > 0:
			continue
		var delay: int = int(pending.get("delay_sec", 0))
		if delay <= 0:
			delay = 2
		pending["delay_sec"] = delay
		pending["release_ts"] = now + delay
		pending["cd_armed"] = true
		armed_n += 1
	if armed_n > 0:
		_ctx.save.save_progress()


func poll_due(tabtype: int) -> Array:
	if _ctx.save == null:
		return []
	var now: int = int(Time.get_unix_time_from_system())
	var released: Array = []
	var keep: Array = []
	for item in _ctx.save.feed_pending:
		if not (item is Dictionary):
			continue
		var pending: Dictionary = item as Dictionary
		if not bool(pending.get("cd_armed", false)) or int(pending.get("release_ts", 0)) <= 0:
			keep.append(pending)
			continue
		if int(pending.get("release_ts", 0)) - now > 0:
			keep.append(pending)
			continue
		var tabsource: int = int(pending.get("tabsource", tabtype))
		if not _is_visible_on_tab_source(tabsource, tabtype):
			keep.append(pending)
			continue
		var inst: Dictionary = _ctx.instances.add_instance(str(pending.get("postid", "")), tabsource)
		if not inst.is_empty():
			released.append(inst)
	_ctx.save.feed_pending = keep
	if not released.is_empty():
		_ctx.instances.mark_instances_for_reveal(released)
		_ctx.save.save_progress()
		_ctx.host.instance_changed.emit()
		_ctx.banner.notify_changed()
	return released


func _is_visible_on_tab_source(tabsource: int, viewing_tab: int) -> bool:
	if tabsource == viewing_tab:
		return true
	if viewing_tab == ExposeManager.TAB_FANDOM and tabsource == ExposeManager.TAB_SISTER:
		return true
	return false
