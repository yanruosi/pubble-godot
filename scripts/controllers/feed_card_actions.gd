extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const _BagMod = preload("res://scripts/controllers/feed_card_bag.gd")
const _InstMod = preload("res://scripts/controllers/feed_card_instance.gd")

var _ctrl: FeedController
var _bag
var _instance


func _init(ctrl: FeedController) -> void:
	_ctrl = ctrl
	_bag = _BagMod.new(ctrl)
	_instance = _InstMod.new(ctrl)


func on_media_pressed(e: Dictionary, save_manager: SaveManager, chapter_manager: ChapterManager) -> void:
	if bool(e.get("_locked", false)):
		var cc: ConditionChecker = _ctrl._conditions()
		var msg := "关卡尚未解锁"
		if cc != null:
			var level_row: Dictionary = e.get("_level_row", {})
			var cid: int = int(level_row.get("unlockconditionid", 0))
			msg = cc.get_fail_text(cid) if cid > 0 else msg
		_ctrl.show_toast(msg)
		return
	var pid: String = str(e.get("post_id", ""))
	if not pid.is_empty():
		save_manager.mark_feed_post_seen(pid)
	var level_row: Dictionary = e.get("_level_row", {}).duplicate(true)
	if level_row.is_empty():
		return
	var chapter_id: int = int(e.get("_chapter_id", 1))
	var chapter_levels: Array = e.get("_chapter_levels", [])
	if _ctrl._vm.is_level_playable(level_row, chapter_id, chapter_levels, save_manager, chapter_manager):
		_ctrl._page.feed_open_level.emit(level_row.duplicate(true))


func on_like_pressed(card: Node, anchor_global: Vector2 = Vector2.ZERO) -> void:
	var anchor_pos := anchor_global
	if anchor_pos == Vector2.ZERO and card is Control:
		anchor_pos = (card as Control).global_position
	_ctrl._list.play_heart_effect(card, anchor_pos)


func on_pin_toggled(post_id: String, is_pinned: bool, save_manager: SaveManager) -> void:
	if save_manager == null:
		return
	if is_pinned:
		save_manager.set_feed_pinned_post_id(post_id)
	else:
		save_manager.set_feed_pinned_post_id("")
	_ctrl.refresh_feed()


func on_mypost_pin_toggled(queue_id: String, is_pinned: bool, expose: ExposeManager) -> void:
	if expose == null or queue_id.is_empty():
		return
	if expose.has_method("toggle_mypost_pin"):
		expose.toggle_mypost_pin(queue_id, is_pinned)
	_ctrl.refresh_feed()


func on_publish_requested(tagid: String, mypostid: String) -> void:
	if tagid.is_empty() or mypostid.is_empty():
		_ctrl.show_toast("请先选择标签并预览帖子")
		return
	var expose: ExposeManager = _ctrl._expose()
	var sm: SaveManager = _ctrl._save()
	if expose == null:
		_ctrl.show_toast("发帖功能未就绪")
		return
	var was_opening := sm != null and not bool(sm.opening_done)
	var res: Dictionary = expose.post_with_tag(tagid, mypostid)
	if not bool(res.get("ok", false)):
		_ctrl.show_toast(str(res.get("reason", "发帖失败")))
		return
	var queue_item: Dictionary = res.get("queue_item", {})
	var queue_id: String = str(queue_item.get("queue_id", ""))
	_ctrl._composer.reset_after_publish()
	if expose.has_method("clear_preview_cursor"):
		expose.clear_preview_cursor()
	_ctrl.refresh_compose_area()
	_ctrl.refresh_banner_area()
	_ctrl.sync_banner_snapshot()
	_ctrl.update_currency_hud()
	_ctrl.show_toast("发布成功")
	_ctrl.refresh_feed(false)
	if _ctrl._active_tab == FeedDefs.TAB_ACCOUNT and not queue_id.is_empty():
		_ctrl._list.play_mypost_slide_in(queue_id)
	if was_opening and sm != null and bool(sm.opening_done):
		notify_opening_post_done()


func notify_opening_post_done() -> void:
	var node: Node = _ctrl._page
	while node != null:
		if node.has_method("clear_pending_first_post"):
			node.call("clear_pending_first_post")
			return
		node = node.get_parent()


func connect_mypost_card_signals(card: Node, item: Dictionary, expose: ExposeManager) -> void:
	if card == null or expose == null:
		return
	var queue_id: String = str(item.get("queue_id", ""))
	if card.has_signal("pin_toggled"):
		card.pin_toggled.connect(func(is_pinned: bool) -> void:
			on_mypost_pin_toggled(queue_id, is_pinned, expose)
		)


func bind_instance_card(card: Node, inst: Dictionary, tpl: Dictionary) -> void:
	_instance.bind_instance_card(card, inst, tpl)


func bind_mypost_like(card: Node, expose: ExposeManager) -> void:
	_instance.bind_mypost_like(card, expose)


func on_market_bag_pressed() -> void:
	_bag.on_market_bag_pressed()


func refresh_bag_panel() -> void:
	_bag.refresh_bag_panel()


func resolve_tpl_postclass(tpl: Dictionary) -> int:
	return _instance.resolve_tpl_postclass(tpl)


func on_instance_like_pressed(inst: Dictionary, tpl: Dictionary, card: Node, anchor_global: Vector2) -> void:
	_instance.on_instance_like_pressed(inst, tpl, card, anchor_global)


func on_instance_fav_pressed(inst: Dictionary, tpl: Dictionary, card: Node, favorited: bool = true) -> void:
	_instance.on_instance_fav_pressed(inst, tpl, card, favorited)
