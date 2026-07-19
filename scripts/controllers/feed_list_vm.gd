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


func mypost_queue_card_view_dict(item: Dictionary, def: Dictionary, expose: ExposeManager = null) -> Dictionary:
	var state: String = str(item.get("state", ""))
	var state_label := "曝光中"
	if state == "collected":
		state_label = "热帖中" if int(item.get("hotresult", -1)) == 1 else "推流中"
	var queue_id: String = str(item.get("queue_id", ""))
	var favorited := false
	if expose != null and expose.has_method("is_mypost_favorited"):
		favorited = expose.is_mypost_favorited(queue_id)
	return {
		"layout": "fans",
		"artist_name": str(def.get("title", item.get("title", item.get("mypostid", "")))),
		"time_display": state_label,
		"text": str(def.get("text", "")),
		"image_path": str(def.get("imagepath", "")),
		"avatar_path": str(def.get("avatarpath", "")),
		"is_pinned": favorited,
	}


func instance_card_view_dict(inst: Dictionary, tpl: Dictionary, _fp_side: bool) -> Dictionary:
	var time_display := ""
	var expose: ExposeManager = _ctrl._expose()
	var iid: String = str(inst.get("instanceid", ""))
	if expose != null and expose.has_method("get_post_display_date"):
		time_display = str(expose.call("get_post_display_date", iid))
	return {
		"layout": "fans",
		"artist_name": str(tpl.get("title", inst.get("postid", ""))),
		"time_display": time_display,
		"text": str(tpl.get("text", "")),
		"image_path": str(tpl.get("imagepath", "")),
		"avatar_path": str(tpl.get("avatarpath", "")),
		"is_pinned": is_instance_favorited(inst, tpl),
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
