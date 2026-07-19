extends RefCounted
class_name FeedListVmArtist

const FeedDefs := preload("res://scripts/views/feed_defs.gd")

var _ctrl: FeedController


func _init(ctrl: FeedController) -> void:
	_ctrl = ctrl


func collect_enriched() -> Array:
	var save_manager: SaveManager = _ctrl._save()
	var chapter_manager: ChapterManager = _ctrl._chapter()
	if save_manager == null or chapter_manager == null or _ctrl._conditions() == null:
		return []
	var chapter_levels: Array = chapter_manager.get_levels_for_chapter(1)
	var levels_sorted: Array = chapter_levels.duplicate()
	levels_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	var unlocked_ids: Dictionary = {}
	var next_locked_id := ""
	for level_raw in levels_sorted:
		if not (level_raw is Dictionary):
			continue
		var level: Dictionary = level_raw as Dictionary
		var lid: String = str(level.get("levelid", ""))
		if lid.is_empty():
			continue
		if is_level_playable(level, 1, chapter_levels, save_manager, chapter_manager):
			unlocked_ids[lid] = true
		elif next_locked_id.is_empty():
			next_locked_id = lid
	var enriched: Array = []
	for item in _ctrl._posts_raw:
		if not (item is Dictionary):
			continue
		var post: Dictionary = (item as Dictionary).duplicate(true)
		if int(post.get("type", 0)) != FeedDefs.TYPE_ARTIST:
			continue
		var level_id: String = str(post.get("level_id", ""))
		var is_unlocked := unlocked_ids.has(level_id)
		var is_next_locked := level_id == next_locked_id and not next_locked_id.is_empty()
		if not is_unlocked and not is_next_locked:
			continue
		var e: Dictionary = enrich_post(post, chapter_manager)
		if e.is_empty():
			continue
		e["_locked"] = is_next_locked and not is_unlocked
		enriched.append(e)
	sort_artist_list(enriched, save_manager, chapter_manager)
	return enriched


func enrich_post(post: Dictionary, chapter_manager: ChapterManager) -> Dictionary:
	var level_id: String = str(post.get("level_id", ""))
	var level_row: Dictionary = {}
	var chapter_id: int = 1
	var chapter_levels: Array = chapter_manager.get_levels_for_chapter(chapter_id)
	if not level_id.is_empty():
		level_row = chapter_manager.get_level_by_id(level_id)
		if level_row.is_empty():
			push_warning("feed_page: 未知 level_id %s" % level_id)
			return {}
		chapter_id = int(level_row.get("chapter_id", 1))
		chapter_levels = chapter_manager.get_levels_for_chapter(chapter_id)
	var out: Dictionary = post.duplicate(true)
	out["artist_name"] = str(post.get("name", ""))
	out["time_display"] = str(post.get("time", ""))
	out["_level_row"] = level_row.duplicate(true)
	out["_chapter_id"] = chapter_id
	out["_chapter_levels"] = chapter_levels.duplicate(true)
	return out


func card_view_dict(e: Dictionary) -> Dictionary:
	return {
		"layout": "artist",
		"artist_name": e.get("artist_name", ""),
		"time_display": e.get("time_display", ""),
		"text": e.get("text", ""),
		"image_path": e.get("image_path", ""),
		"image_path2": e.get("image_path2", ""),
		"avatar_path": e.get("avatar_path", ""),
		"is_pinned": bool(e.get("_is_pinned", false)),
		"locked": bool(e.get("_locked", false)),
	}


func sort_artist_list(items: Array, save_manager: SaveManager, chapter_manager: ChapterManager) -> void:
	var pinned_post_id: String = save_manager.get_feed_pinned_post_id()
	var current_level_id: String = current_level_id_for(save_manager, chapter_manager)
	for item in items:
		if item is Dictionary:
			(item as Dictionary)["_is_pinned"] = str((item as Dictionary).get("post_id", "")) == pinned_post_id
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: Array = artist_rank(a, current_level_id, pinned_post_id, chapter_manager)
		var rb: Array = artist_rank(b, current_level_id, pinned_post_id, chapter_manager)
		for i in range(mini(ra.size(), rb.size())):
			if ra[i] != rb[i]:
				return ra[i] < rb[i]
		return false
	)


func artist_rank(e: Dictionary, current_level_id: String, pinned_post_id: String, chapter_manager: ChapterManager) -> Array:
	var post_id: String = str(e.get("post_id", ""))
	var level_id: String = str(e.get("level_id", ""))
	var tier: int = 2
	if not pinned_post_id.is_empty() and post_id == pinned_post_id:
		tier = 0
	elif not level_id.is_empty() and level_id == current_level_id:
		tier = 1
	var level_order: int = -1 if level_id.is_empty() else level_order_for(chapter_manager, level_id)
	return [tier, -level_order, post_id]


func current_level_id_for(save_manager: SaveManager, chapter_manager: ChapterManager) -> String:
	var best_order: int = -1
	var best_id: String = ""
	for item in chapter_manager.get_levels_for_chapter(1):
		if not (item is Dictionary):
			continue
		var level: Dictionary = item as Dictionary
		var level_id: String = str(level.get("levelid", ""))
		if not is_level_playable(level, 1, chapter_manager.get_levels_for_chapter(1), save_manager, chapter_manager):
			continue
		var order: int = int(level.get("order", 0))
		if order > best_order:
			best_order = order
			best_id = level_id
	return best_id


func level_order_for(chapter_manager: ChapterManager, level_id: String) -> int:
	return int(chapter_manager.get_level_by_id(level_id).get("order", 999))


func is_level_playable(level: Dictionary, chapter_id: int, chapter_levels: Array, save_manager: SaveManager, chapter_manager: ChapterManager) -> bool:
	if level.is_empty():
		return false
	var level_id: String = str(level.get("levelid", ""))
	if save_manager.is_level_unlocked(level_id) or save_manager.is_level_completed(level_id):
		return true
	var condition_id: int = int(level.get("unlockconditionid", 0))
	if condition_id <= 0:
		return true
	var condition_checker: ConditionChecker = _ctrl._conditions()
	if condition_checker == null:
		return false
	return condition_checker.is_level_condition_met(condition_id, level, chapter_levels)
