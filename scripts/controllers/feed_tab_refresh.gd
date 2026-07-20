extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const _CardsMod = preload("res://scripts/controllers/feed_tab_cards.gd")
const _FavMod = preload("res://scripts/controllers/feed_tab_favorites.gd")

var _ctrl: FeedController
var _cards
var _favorites


func _init(ctrl: FeedController) -> void:
	_ctrl = ctrl
	_cards = _CardsMod.new(ctrl)
	_favorites = _FavMod.new(ctrl, _cards)


func refresh_artist_tab() -> void:
	var enriched: Array = _ctrl._vm.collect_artist_enriched()
	if enriched.is_empty():
		_cards.add_empty_tip("暂无艺人动态")
		return
	var save_manager: SaveManager = _ctrl._save()
	var chapter_manager: ChapterManager = _ctrl._chapter()
	var list_width := _ctrl._ui.get_active_list_rect().size.x
	for e in enriched:
		var view: Dictionary = _ctrl._vm.card_view_dict(e)
		if bool(e.get("_locked", false)):
			view["text"] = "（未解锁）" + str(view.get("text", ""))
		var card: Node = _cards.mount_card(view, list_width)
		if card is Control and bool(e.get("_locked", false)):
			(card as Control).modulate = Color(1, 1, 1, 0.55)
		var ebind: Dictionary = e.duplicate(true)
		if card.has_signal("media_pressed"):
			card.media_pressed.connect(func() -> void: _ctrl._actions.on_media_pressed(ebind, save_manager, chapter_manager))
		if card.has_signal("like_pressed"):
			card.like_pressed.connect(func(anchor_global: Vector2) -> void: _ctrl._actions.on_like_pressed(card, anchor_global))
		if card.has_signal("pin_toggled"):
			card.pin_toggled.connect(func(is_pinned: bool) -> void:
				_ctrl._actions.on_pin_toggled(str(ebind.get("post_id", "")), is_pinned, save_manager)
			)


func refresh_instance_tab(tabtype: int) -> void:
	var expose: ExposeManager = _ctrl._expose()
	if expose == null:
		return
	var fp_side := tabtype == FeedDefs.TABTYPE_FANDOM
	if tabtype == FeedDefs.TABTYPE_ACCOUNT:
		refresh_account_mypost_list(expose)
		return
	if tabtype == FeedDefs.TABTYPE_FANDOM:
		refresh_fandom_merged_feed(expose)
		return
	var list_width := _ctrl._ui.get_active_list_rect().size.x
	for inst in expose.get_instances_for_tab(tabtype):
		if not (inst is Dictionary):
			continue
		var inst_dict: Dictionary = inst as Dictionary
		var tpl: Dictionary = expose.get_template(str(inst_dict.get("postid", "")))
		var card: Node = _cards.mount_card(
			_ctrl._vm.instance_card_view_dict(inst_dict, tpl, fp_side),
			list_width,
			{"instance_id": str(inst_dict.get("instanceid", ""))}
		)
		_ctrl._actions.bind_instance_card(card, inst_dict, tpl)
	if _ctrl._list.list_box.get_child_count() == 0:
		_cards.add_empty_tip("暂无帖子，下拉刷新试试" if tabtype == FeedDefs.TABTYPE_FANDOM else "暂无放置帖子")


func refresh_favorites_tab() -> void:
	_favorites.refresh()


func refresh_account_mypost_list(expose: ExposeManager) -> void:
	var queue: Array = expose.get_mypost_queue().duplicate()
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _ctrl._vm.mypost_sort_before(a, b)
	)
	var list_width := _ctrl._ui.get_active_list_rect().size.x
	for item_raw in queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		var mypostid: String = str(item.get("mypostid", ""))
		var def: Dictionary = expose.get_my_post(mypostid) if expose.has_method("get_my_post") else {}
		var card: Node = _cards.mount_card(_ctrl._vm.mypost_queue_card_view_dict(item, def, expose), list_width, {
			"queue_id": str(item.get("queue_id", "")),
			"mypostid": mypostid,
		})
	if _ctrl._list.list_box.get_child_count() == 0:
		_cards.add_empty_tip("暂无我的帖子，选择标签发布")


func refresh_fandom_merged_feed(expose: ExposeManager) -> void:
	var list_width := _ctrl._ui.get_active_list_rect().size.x
	for entry_raw in _ctrl._vm.build_fandom_feed_plan(expose):
		if not (entry_raw is Dictionary):
			continue
		var entry: Dictionary = entry_raw as Dictionary
		if str(entry.get("kind", "")) == "mypost":
			var item: Dictionary = entry.get("item", {})
			add_mypost_card_to_parent(item, expose, _ctrl._vm.is_sticky_mypost(item))
			continue
		var inst: Dictionary = entry.get("inst", {})
		var tpl: Dictionary = expose.get_template(str(inst.get("postid", "")))
		var card: Node = _cards.mount_card(
			_ctrl._vm.instance_card_view_dict(inst, tpl, true),
			list_width,
			{"instance_id": str(inst.get("instanceid", ""))}
		)
		_ctrl._actions.bind_instance_card(card, inst, tpl)
	if _ctrl._list.list_box.get_child_count() == 0:
		_cards.add_empty_tip("暂无帖子，下拉刷新试试")


func add_mypost_card_to_parent(item: Dictionary, expose: ExposeManager, _is_sticky: bool) -> int:
	if _ctrl._list.list_box == null:
		return 0
	var mypostid: String = str(item.get("mypostid", ""))
	var def: Dictionary = expose.get_my_post(mypostid) if expose.has_method("get_my_post") else {}
	var view: Dictionary = _ctrl._vm.mypost_queue_card_view_dict(item, def, expose)
	var card: Node = _cards.mount_card(view, _ctrl._ui.get_active_list_rect().size.x, {
		"queue_id": str(item.get("queue_id", "")),
		"mypostid": mypostid,
	})
	_ctrl._actions.bind_mypost_like(card, expose)
	_ctrl._actions.connect_mypost_card_signals(card, item, expose)
	return 1


func on_list_scrolled_down() -> void:
	if _ctrl._scroll_started or _ctrl._active_tab != FeedDefs.TAB_FANDOM:
		return
	var expose: ExposeManager = _ctrl._expose()
	if expose == null:
		return
	_ctrl._scroll_started = true
	if expose.has_method("refresh_feed_on_tab"):
		expose.refresh_feed_on_tab(FeedDefs.TABTYPE_FANDOM)
	_ctrl.refresh_feed(true)


func on_lump_granted(_tabtype: int, _grant_type: int, _amount: int) -> void:
	_ctrl.update_currency_hud()
	on_banner_state_changed()


func on_banner_state_changed() -> void:
	if _ctrl._banner.shows_dynamic_overlay(_ctrl._active_tab):
		_ctrl.sync_banner_snapshot()


func on_intel_level_up(_new_level: int) -> void:
	_ctrl.update_currency_hud()
	_ctrl.sync_banner_snapshot()
	if _ctrl._active_tab == FeedDefs.TAB_FANDOM:
		_ctrl._banner.play_intel_flash()
	elif _ctrl._expose() != null:
		_ctrl._expose().consume_pending_intel_level_up()
	_ctrl._page.call_deferred("_feed_deferred_refresh", true)


func play_pending_reveals(tabtype: int, run_id: int = -1) -> void:
	if run_id >= 0 and run_id != _ctrl._reveal_run_id:
		return
	var expose: ExposeManager = _ctrl._expose()
	if expose == null or _ctrl._list.list_box == null:
		return
	var ids: Array = expose.take_pending_reveal_ids(tabtype)
	if ids.is_empty():
		return
	await _ctrl._list.play_slide_in_reveal(ids, run_id, func() -> void:
		_ctrl.sync_banner_snapshot()
		_ctrl.update_currency_hud()
	)
