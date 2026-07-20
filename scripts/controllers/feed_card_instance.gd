extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const FeedCardEffects := preload("res://scripts/views/feed_card_effects.gd")

var _ctrl


func _init(ctrl) -> void:
	_ctrl = ctrl


func bind_instance_card(card: Node, inst: Dictionary, tpl: Dictionary) -> void:
	var inst_bind: Dictionary = inst.duplicate(true)
	var tpl_bind: Dictionary = tpl.duplicate(true)
	if card.has_signal("like_pressed"):
		card.like_pressed.connect(func(anchor_global: Vector2) -> void:
			on_instance_like_pressed(inst_bind, tpl_bind, card, anchor_global)
		)
	if card.has_signal("pin_toggled"):
		card.pin_toggled.connect(func(is_pinned: bool) -> void:
			on_instance_fav_pressed(inst_bind, tpl_bind, card, is_pinned)
		)


func bind_mypost_like(card: Node, expose: ExposeManager) -> void:
	if not card.has_signal("like_pressed"):
		return
	card.like_pressed.connect(func(anchor_global: Vector2) -> void:
		if card.has_method("bump_display_likes"):
			card.call("bump_display_likes")
		_ctrl._list.play_heart_effect(card, anchor_global)
		_ctrl.sync_banner_snapshot()
	)


func on_instance_like_pressed(inst: Dictionary, tpl: Dictionary, card: Node, anchor_global: Vector2) -> void:
	var expose: ExposeManager = _ctrl._expose()
	var iid: String = str(inst.get("instanceid", ""))
	if expose != null and expose.has_method("add_heat") and not iid.is_empty():
		expose.add_heat("like", iid)
	if expose != null and expose.has_method("bump_instance_display_likes") and not iid.is_empty():
		var count: int = int(expose.bump_instance_display_likes(iid))
		inst["display_likes"] = count
		if card != null and card.has_method("setup"):
			var view: Dictionary = _ctrl._vm.instance_card_view_dict(inst, tpl, true)
			card.call("setup", view)
	elif card != null and card.has_method("bump_display_likes"):
		card.call("bump_display_likes")
	var postclass: int = resolve_tpl_postclass(tpl)
	FeedCardEffects.play_like(_ctrl._list, card, anchor_global, postclass)
	_ctrl.sync_banner_snapshot()


func resolve_tpl_postclass(tpl: Dictionary) -> int:
	if tpl.has("postclass"):
		return int(tpl.get("postclass", 1))
	if int(tpl.get("tabtype", 0)) == FeedDefs.TABTYPE_SISTER and int(tpl.get("grantintel", 0)) > 0:
		return 3
	return 1


func on_instance_fav_pressed(inst: Dictionary, tpl: Dictionary, card: Node, favorited: bool = true) -> void:
	var expose: ExposeManager = _ctrl._expose()
	if expose == null:
		return
	var iid: String = str(inst.get("instanceid", ""))
	var postclass: int = resolve_tpl_postclass(tpl)
	if favorited and expose.has_method("apply_wrong_sister_favorite_penalty"):
		if expose.apply_wrong_sister_favorite_penalty(iid):
			_ctrl.show_toast("当前收藏的帖子引起争议 粉丝-10")
	if favorited and expose.has_method("add_heat") and not iid.is_empty():
		expose.add_heat("fav", iid)
	var ok := false
	if expose.has_method("toggle_instance_favorite"):
		ok = bool(expose.toggle_instance_favorite(iid, favorited))
	elif postclass == 3 and favorited:
		ok = bool(expose.favorite_instance(iid))
	if card.has_method("set_pinned"):
		card.call("set_pinned", favorited and ok)
	if postclass == 3 and favorited and ok:
		var msg := "收集关键艺人粉丝投稿+1"
		if expose.has_method("get_keypost_display"):
			var kp: Dictionary = expose.get_keypost_display()
			var cur: int = int(kp.get("current", 0))
			var tgt: int = int(kp.get("target", 0))
			if tgt > 0 and cur >= tgt:
				msg = "收集关键艺人粉丝投稿+1 已收集全部%d个艺人粉丝投稿" % tgt
			elif tgt > 0:
				msg = "收集关键艺人粉丝投稿+1 还需收集%d个" % maxi(tgt - cur, 0)
		_ctrl.show_toast(msg)
	if ok and not favorited:
		_ctrl.refresh_feed()
	_ctrl.sync_banner_snapshot()
	_ctrl.update_currency_hud()
