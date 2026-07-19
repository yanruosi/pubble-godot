extends RefCounted
class_name FeedTabFavorites

var _ctrl: FeedController
var _cards


func _init(ctrl: FeedController, cards) -> void:
	_ctrl = ctrl
	_cards = cards


func refresh() -> void:
	var sm: SaveManager = _ctrl._save()
	var expose: ExposeManager = _ctrl._expose()
	if sm == null or expose == null or _ctrl._list.list_box == null:
		return
	var rendered := 0
	var list_width := _ctrl._ui.get_active_list_rect().size.x
	for fav_raw in sm.favorites:
		var fav_id: String = str(fav_raw)
		if fav_id.begins_with("mypost:"):
			rendered += _render_mypost_fav(fav_id, expose, list_width)
			continue
		rendered += _render_instance_fav(fav_id, sm, expose, list_width)
	if rendered == 0:
		_cards.add_empty_tip("暂无收藏，在饭圈动态收藏帖子后会显示在这里")


func _render_mypost_fav(fav_id: String, expose: ExposeManager, list_width: float) -> int:
	var queue_id: String = fav_id.substr(7)
	var item: Dictionary = expose.get_queue_item(queue_id)
	if item.is_empty():
		return 0
	var mypostid: String = str(item.get("mypostid", ""))
	var def: Dictionary = expose.get_my_post(mypostid)
	var card: Node = _cards.mount_card(_ctrl._vm.mypost_queue_card_view_dict(item, def, expose), list_width)
	_ctrl._actions.connect_mypost_card_signals(card, item, expose)
	return 1


func _render_instance_fav(fav_id: String, sm: SaveManager, expose: ExposeManager, list_width: float) -> int:
	var inst: Dictionary = {}
	for item_raw in sm.feed_instances:
		if not (item_raw is Dictionary):
			continue
		var inst_dict: Dictionary = item_raw as Dictionary
		if str(inst_dict.get("instanceid", "")) == fav_id:
			inst = inst_dict
			break
	if inst.is_empty():
		return 0
	var tpl: Dictionary = expose.get_template(str(inst.get("postid", "")))
	var feed_card: Node = _cards.mount_card(_ctrl._vm.instance_card_view_dict(inst, tpl, true), list_width)
	_ctrl._actions.bind_instance_card(feed_card, inst, tpl)
	return 1
