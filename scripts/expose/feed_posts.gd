extends RefCounted

## 我的帖预览 / 发帖 / 日期规则

var _ctx
var _feed_posts: Array = []


func _init(ctx) -> void:
	_ctx = ctx


func load_tables() -> void:
	_feed_posts = TableRepo.get_table("feed_posts")


func get_post_tags() -> Array:
	if _ctx.save == null:
		return []
	var out: Array = []
	for row in _ctx.post_tags:
		if not (row is Dictionary):
			continue
		var tag: Dictionary = row as Dictionary
		var tagid: String = str(tag.get("tagid", ""))
		if tagid.is_empty() or _ctx.save.get_post_count(tagid) <= 0:
			continue
		out.append({"tagid": tagid, "name": str(tag.get("name", tagid)), "count": _ctx.save.get_post_count(tagid)})
	return out


func preview_tag_post(tagid: String) -> Dictionary:
	var candidates: Array = _ctx.my_posts_by_tag.get(tagid, [])
	if candidates.is_empty():
		return {}
	var idx: int = int(_ctx.preview_cursor.get(tagid, -1)) + 1
	if idx >= candidates.size():
		idx = 0
	_ctx.preview_cursor[tagid] = idx
	var mid: String = str(candidates[idx])
	var def: Dictionary = _ctx.my_posts_by_id.get(mid, {})
	return {"mypostid": mid, "title": str(def.get("title", "")), "text": str(def.get("text", ""))}


func clear_preview_cursor(tagid: String = "") -> void:
	if tagid.is_empty():
		_ctx.preview_cursor.clear()
	elif _ctx.preview_cursor.has(tagid):
		_ctx.preview_cursor.erase(tagid)


func get_my_post(mypostid: String) -> Dictionary:
	return _ctx.my_posts_by_id.get(mypostid, {}).duplicate(true)


func post_with_tag(tagid: String, mypostid: String = "") -> Dictionary:
	if _ctx.save == null or tagid.is_empty():
		return {"ok": false, "reason": "无效标签"}
	if not _ctx.save.consume_post_count(tagid, 1):
		return {"ok": false, "reason": "发帖次数不足"}
	var candidates: Array = _ctx.my_posts_by_tag.get(tagid, [])
	if candidates.is_empty():
		_ctx.save.add_post_count(tagid, 1)
		return {"ok": false, "reason": "该标签暂无帖子模板"}
	var pick_id: String = mypostid if not mypostid.is_empty() else str(candidates[randi() % candidates.size()])
	if not candidates.has(pick_id):
		_ctx.save.add_post_count(tagid, 1)
		return {"ok": false, "reason": "预览帖不属于该标签"}
	var item: Dictionary = _ctx.queue.append(pick_id)
	if not _ctx.save.opening_done:
		_ctx.save.opening_done = true
	_ctx.save.save_progress()
	_ctx.host.instance_changed.emit()
	_ctx.banner.notify_changed()
	return {"ok": true, "queue_item": item}


func post_mainline(mypostid: String) -> Dictionary:
	if _ctx.save == null or mypostid.is_empty() or not _ctx.my_posts_by_id.has(mypostid):
		return {"ok": false, "reason": "无效帖子" if mypostid.is_empty() else "帖子不存在"}
	var item: Dictionary = _ctx.queue.insert_mainline(mypostid)
	_ctx.save.save_progress()
	_ctx.host.instance_changed.emit()
	_ctx.banner.notify_changed()
	return {"ok": true, "queue_item": item}


func debug_flush_feed_pending() -> void:
	if _ctx.save == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	for item in _ctx.save.feed_pending:
		if item is Dictionary:
			(item as Dictionary)["cd_armed"] = true
			(item as Dictionary)["release_ts"] = now
	_ctx.save.save_progress()


func get_post_display_date(_instanceid: String = "") -> String:
	if _ctx.save == null:
		return ""
	var chapter: ChapterManager = _ctx.chapter()
	if chapter == null:
		return ""
	var cc: ConditionChecker = _ctx.condition_checker()
	var best_order := -1
	var best_time := ""
	for level_raw in chapter.get_levels_for_chapter(1):
		if not (level_raw is Dictionary):
			continue
		var level: Dictionary = level_raw as Dictionary
		var lid: String = str(level.get("levelid", ""))
		if lid.is_empty():
			continue
		var unlocked: bool = _ctx.save.is_level_unlocked(lid) or _ctx.save.is_level_completed(lid)
		if not unlocked:
			var cid: int = int(level.get("unlockconditionid", 0))
			if cid > 0 and (cc == null or not cc.is_level_condition_met(cid, level, chapter.get_levels_for_chapter(1))):
				continue
			elif cid != 0:
				continue
		var order: int = int(level.get("order", 0))
		if order < best_order:
			continue
		var time_str := str(level.get("text2", ""))
		for fp in _feed_posts:
			if fp is Dictionary and str((fp as Dictionary).get("level_id", "")) == lid:
				time_str = str((fp as Dictionary).get("time", time_str))
				break
		if time_str.is_empty():
			continue
		best_order = order
		best_time = time_str
	return best_time


func supports_unified_banner(tabtype: int) -> bool:
	return tabtype in [ExposeManager.TAB_FANDOM, ExposeManager.TAB_SISTER, ExposeManager.TAB_ACCOUNT]


func is_tab_p2_visible(tabtype: int) -> bool:
	return tabtype == ExposeManager.TAB_FANDOM or tabtype == ExposeManager.TAB_SISTER


func is_tab_p4_visible(tabtype: int) -> bool:
	return tabtype == ExposeManager.TAB_SISTER


func is_tab_p5_visible(tabtype: int) -> bool:
	return tabtype == ExposeManager.TAB_SISTER
