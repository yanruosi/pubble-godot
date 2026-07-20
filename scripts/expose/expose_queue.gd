extends RefCounted

## mypost 曝光队列：入队 / 插队 / tick

signal head_matured(item: Dictionary)

var _ctx
var _queue_id_counter: int = 0


func _init(ctx) -> void:
	_ctx = ctx


func append(mypostid: String) -> Dictionary:
	var item: Dictionary = create_item(mypostid, true)
	_ctx.save.mypost_queue.append(item)
	var exposing: Dictionary = get_exposing_item()
	if str(exposing.get("queue_id", "")) == str(item.get("queue_id", "")):
		start_timer(item)
	return item


func insert_mainline(mypostid: String) -> Dictionary:
	var item: Dictionary = create_item(mypostid, true)
	var exposing: Dictionary = get_exposing_item()
	var shared_end: int = 0
	if not exposing.is_empty():
		shared_end = int(exposing.get("expose_end_ts", 0))
	if shared_end > 0:
		item["expose_start_ts"] = int(Time.get_unix_time_from_system())
		item["expose_end_ts"] = shared_end
	else:
		start_timer(item)
	_ctx.save.mypost_queue.insert(0, item)
	_ctx.banner.set_override(ExposeManager.BANNER_NEW_REPLACED)
	return item


func create_item(mypostid: String, pinned: bool) -> Dictionary:
	_queue_id_counter += 1
	var def: Dictionary = _ctx.my_posts_by_id.get(mypostid, {})
	var now: int = int(Time.get_unix_time_from_system())
	return {
		"queue_id": "q_%d" % _queue_id_counter,
		"mypostid": mypostid,
		"state": "exposing",
		"heat": 0,
		"heat_sources": [],
		"hotresult": -1,
		"posted_ts": now,
		"expose_start_ts": 0,
		"expose_end_ts": 0,
		"idle_fp_earned": 0,
		"idle_fans_earned": 0,
		"idle_next_ts": 0,
		"settle_fp": 0,
		"settle_fans": 0,
		"title": str(def.get("title", "")),
		"is_pinned": pinned,
	}


func start_timer(item: Dictionary) -> void:
	var def: Dictionary = _ctx.my_posts_by_id.get(str(item.get("mypostid", "")), {})
	var sec: int = maxi(int(def.get("exposesec", 120)), 1)
	var now: int = int(Time.get_unix_time_from_system())
	item["expose_start_ts"] = now
	item["expose_end_ts"] = now + sec
	_ctx.banner.on_expose_timer_start(item)


func ensure_head_timer() -> void:
	var head: Dictionary = get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return
	if int(head.get("expose_end_ts", 0)) <= 0:
		start_timer(head)


func get_exposing_item() -> Dictionary:
	if _ctx.save == null:
		return {}
	for item_raw in _ctx.save.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) == "exposing":
			return item
	return {}


func get_display_item() -> Dictionary:
	if _ctx.save == null:
		return {}
	var pinned_hot: Dictionary = {}
	for i in range(_ctx.save.mypost_queue.size() - 1, -1, -1):
		var item_raw: Variant = _ctx.save.mypost_queue[i]
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) != "collected":
			continue
		if int(item.get("hotresult", -1)) == 1 and bool(item.get("is_pinned", false)):
			pinned_hot = item
			break
	if not pinned_hot.is_empty():
		return pinned_hot
	var exposing: Dictionary = get_exposing_item()
	if not exposing.is_empty():
		return exposing
	return {}


func find_item(queue_id: String) -> Dictionary:
	if _ctx.save == null or queue_id.is_empty():
		return {}
	for item_raw in _ctx.save.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("queue_id", "")) == queue_id:
			return item
	return {}


func remaining_expose_sec(item: Dictionary) -> float:
	var end_ts: int = int(item.get("expose_end_ts", 0))
	if end_ts <= 0:
		return -1.0
	return maxf(float(end_ts - int(Time.get_unix_time_from_system())), 0.0)


func tick() -> void:
	var head: Dictionary = get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return
	if remaining_expose_sec(head) > 0.0:
		return
	head_matured.emit(head)


func settle_head_if_ready() -> bool:
	var head: Dictionary = get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return false
	if int(head.get("hotresult", -1)) < 0:
		return false
	_ctx.settle.settle_item(head)
	return true


func cleanup_finished_collected() -> void:
	if _ctx.save == null:
		return
	for item_raw in _ctx.save.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		_ctx.idle.cleanup_caps_for_item(item_raw as Dictionary)


func is_sticky_item(item: Dictionary) -> bool:
	var state: String = str(item.get("state", ""))
	if state == "exposing":
		return true
	return state == "collected" and bool(item.get("is_pinned", false)) and int(item.get("hotresult", -1)) == 1


func toggle_pin(queue_id: String, pinned: bool) -> bool:
	if _ctx.save == null or queue_id.is_empty():
		return false
	var item: Dictionary = find_item(queue_id)
	if item.is_empty():
		return false
	var fav_key: String = ExposeManager.FAVORITE_MYPOST_PREFIX + queue_id
	if pinned:
		if not _ctx.save.favorites.has(fav_key):
			_ctx.save.favorites.append(fav_key)
		if not is_sticky_item(item):
			item["is_pinned"] = true
	else:
		if str(item.get("state", "")) == "exposing":
			return false
		if _ctx.save.favorites.has(fav_key):
			_ctx.save.favorites.erase(fav_key)
		item["is_pinned"] = false
	_ctx.save.save_progress()
	_ctx.host.instance_changed.emit()
	_ctx.banner.notify_changed()
	return true


func is_mypost_favorited(queue_id: String) -> bool:
	if _ctx.save == null or queue_id.is_empty():
		return false
	return _ctx.save.favorites.has(ExposeManager.FAVORITE_MYPOST_PREFIX + queue_id)
