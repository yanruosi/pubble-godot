extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const _ArtistMod = preload("res://scripts/controllers/feed_list_vm_artist.gd")

var _ctrl: FeedController
var _artist


func _init(ctrl: FeedController) -> void:
	_ctrl = ctrl
	_artist = _ArtistMod.new(ctrl)


func is_sticky_mypost(item: Dictionary) -> bool:
	var state: String = str(item.get("state", ""))
	if state == "exposing":
		return true
	return state == "collected" and bool(item.get("is_pinned", false)) and int(item.get("hotresult", -1)) == 1


func mypost_sort_before(a: Dictionary, b: Dictionary) -> bool:
	var ra: Array = mypost_list_rank(a)
	var rb: Array = mypost_list_rank(b)
	if int(ra[0]) != int(rb[0]):
		return int(ra[0]) < int(rb[0])
	return int(ra[1]) < int(rb[1])


func mypost_list_rank(item: Dictionary) -> Array:
	var state: String = str(item.get("state", ""))
	var hot_pin := state == "collected" and bool(item.get("is_pinned", false)) and int(item.get("hotresult", -1)) == 1
	var tier := 2
	if state == "exposing":
		tier = 0
	elif hot_pin:
		tier = 1
	var ts: int = int(item.get("posted_ts", 0))
	if ts <= 0:
		ts = int(item.get("expose_start_ts", 0))
	return [tier, -ts]


func mypost_feed_timestamp(item: Dictionary) -> int:
	var ts: int = int(item.get("posted_ts", 0))
	if ts <= 0:
		ts = int(item.get("expose_start_ts", 0))
	return ts


func build_fandom_feed_plan(expose: ExposeManager) -> Array:
	var plan: Array = []
	var sticky: Array = []
	var merged: Array = []
	if expose == null:
		return plan
	for item_raw in expose.get_mypost_queue():
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		var state: String = str(item.get("state", ""))
		if state != "exposing" and state != "collected":
			continue
		var entry := {"kind": "mypost", "item": item, "ts": mypost_feed_timestamp(item)}
		if is_sticky_mypost(item):
			sticky.append(entry)
		else:
			merged.append(entry)
	for inst_raw in expose.get_instances_for_tab(FeedDefs.TABTYPE_FANDOM):
		if not (inst_raw is Dictionary):
			continue
		var inst: Dictionary = inst_raw as Dictionary
		merged.append({
			"kind": "instance",
			"inst": inst,
			"ts": int(inst.get("createdat", 0)),
		})
	sticky.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return mypost_sort_before(a.get("item", {}), b.get("item", {}))
	)
	merged.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("ts", 0)) > int(b.get("ts", 0))
	)
	plan.append_array(sticky)
	plan.append_array(merged)
	return plan


func mypost_queue_card_view_dict(item: Dictionary, def: Dictionary, expose: ExposeManager = null) -> Dictionary:
	var badge := mypost_status_badge(item, expose)
	return {
		"layout": "fans",
		"artist_name": FeedDefs.MYPOST_DISPLAY_NAME,
		"time_display": badge,
		"status_badge": badge,
		"text": str(def.get("text", "")),
		"image_path": str(def.get("imagepath", "")),
		"avatar_path": FeedDefs.resolve_mypost_avatar_path(),
		"is_pinned": false,
		"hide_actions": true,
	}


func mypost_status_badge(item: Dictionary, expose: ExposeManager) -> String:
	var state: String = str(item.get("state", ""))
	if state == "exposing":
		var head_id := _mypost_exposing_queue_id(expose)
		if head_id == str(item.get("queue_id", "")):
			return "曝光中"
		return "排队中"
	if state == "collected":
		if int(item.get("hotresult", -1)) == 1 and bool(item.get("is_pinned", false)):
			return "热帖"
		return "已结算"
	return "排队中"


func _mypost_exposing_queue_id(expose: ExposeManager) -> String:
	if expose == null or not expose.has_method("get_mypost_queue"):
		return ""
	for q_raw in expose.get_mypost_queue():
		if q_raw is Dictionary and str((q_raw as Dictionary).get("state", "")) == "exposing":
			return str((q_raw as Dictionary).get("queue_id", ""))
	return ""


func instance_card_view_dict(inst: Dictionary, tpl: Dictionary, _fp_side: bool) -> Dictionary:
	var time_display := ""
	var expose: ExposeManager = _ctrl._expose()
	var iid: String = str(inst.get("instanceid", ""))
	if expose != null and expose.has_method("get_post_display_date"):
		time_display = str(expose.call("get_post_display_date", iid))
	var postclass: int = _ctrl._actions.resolve_tpl_postclass(tpl)
	return {
		"layout": "fans",
		"artist_name": str(tpl.get("title", inst.get("postid", ""))),
		"time_display": time_display,
		"text": str(tpl.get("text", "")),
		"image_path": str(tpl.get("imagepath", "")),
		"avatar_path": FeedDefs.resolve_template_avatar_path(tpl),
		"is_pinned": is_instance_favorited(inst, tpl),
		"display_likes": int(inst.get("display_likes", 0)),
		"postclass": postclass,
		"postclass_badge": FeedDefs.postclass_badge_label(postclass),
		"show_clue_marker": postclass == ExposeManager.POSTCLASS_KEY,
	}


func build_favorites_vm() -> Array:
	var sm: SaveManager = _ctrl._save()
	var expose: ExposeManager = _ctrl._expose()
	if sm == null or expose == null:
		return []
	var rows: Array = []
	for fav_raw in sm.favorites:
		var fav_id: String = str(fav_raw)
		if fav_id.begins_with("mypost:"):
			var row := _favorites_mypost_row(fav_id, expose)
			if not row.is_empty():
				rows.append(row)
			continue
		var row_inst := _favorites_instance_row(fav_id, sm, expose)
		if not row_inst.is_empty():
			rows.append(row_inst)
	return rows


func _favorites_instance_row(fav_id: String, sm: SaveManager, expose: ExposeManager) -> Dictionary:
	var inst: Dictionary = {}
	for item_raw in sm.feed_instances:
		if item_raw is Dictionary and str((item_raw as Dictionary).get("instanceid", "")) == fav_id:
			inst = item_raw as Dictionary
			break
	if inst.is_empty():
		return {}
	var tpl: Dictionary = expose.get_template(str(inst.get("postid", "")))
	return {
		"kind": "instance",
		"card_view": instance_card_view_dict(inst, tpl, true),
		"meta": {"instance_id": fav_id},
		"inst": inst,
		"tpl": tpl,
	}


func _favorites_mypost_row(fav_id: String, expose: ExposeManager) -> Dictionary:
	var queue_id: String = fav_id.substr(7)
	var item: Dictionary = expose.get_queue_item(queue_id)
	if item.is_empty():
		return {}
	var mypostid: String = str(item.get("mypostid", ""))
	var def: Dictionary = expose.get_my_post(mypostid)
	return {
		"kind": "mypost",
		"card_view": mypost_queue_card_view_dict(item, def, expose),
		"meta": {"queue_id": queue_id, "mypostid": mypostid},
		"item": item,
	}


func is_instance_favorited(inst: Dictionary, tpl: Dictionary) -> bool:
	var iid: String = str(inst.get("instanceid", ""))
	var sm: SaveManager = _ctrl._save()
	if sm != null and sm.favorites.has(iid):
		return true
	if _ctrl._actions.resolve_tpl_postclass(tpl) != 3:
		return false
	if bool(inst.get("keypostcollected", false)):
		return true
	return sm != null and sm.favorites.has(iid)


func enrich_post(post: Dictionary, chapter_manager: ChapterManager) -> Dictionary:
	return _artist.enrich_post(post, chapter_manager)


func card_view_dict(e: Dictionary) -> Dictionary:
	return _artist.card_view_dict(e)


func is_level_playable(level: Dictionary, chapter_id: int, chapter_levels: Array, save_manager: SaveManager, chapter_manager: ChapterManager) -> bool:
	return _artist.is_level_playable(level, chapter_id, chapter_levels, save_manager, chapter_manager)


func collect_artist_enriched() -> Array:
	return _artist.collect_enriched()
