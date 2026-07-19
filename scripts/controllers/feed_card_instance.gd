extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")

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
		if expose.has_method("add_heat"):
			expose.add_heat("like")
		_ctrl._list.play_heart_effect(card, anchor_global)
		_ctrl.sync_banner_snapshot()
	)


func on_instance_like_pressed(inst: Dictionary, _tpl: Dictionary, card: Node, anchor_global: Vector2) -> void:
	var expose: ExposeManager = _ctrl._expose()
	if expose != null and expose.has_method("add_heat"):
		expose.add_heat("like")
	_ctrl._list.play_heart_effect(card, anchor_global)
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
	if expose.has_method("add_heat") and favorited:
		expose.add_heat("fav")
	var postclass: int = resolve_tpl_postclass(tpl)
	var ok := false
	if expose.has_method("toggle_instance_favorite"):
		ok = bool(expose.toggle_instance_favorite(iid, favorited))
	elif postclass == 3 and favorited:
		ok = bool(expose.favorite_instance(iid))
	if card.has_method("set_pinned"):
		card.call("set_pinned", favorited and ok)
	if postclass == 3 and favorited and ok:
		var sm: SaveManager = _ctrl._save()
		if sm != null:
			var target: int = 0
			var eco: EconomyManager = _ctrl._page.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
			if eco != null:
				target = eco.get_keypost_target()
			if target > 0:
				_ctrl.show_toast("找到关键线索帖 %d/%d" % [sm.keypost_progress, target])
	if ok and not favorited:
		_ctrl.refresh_feed()
	_ctrl.sync_banner_snapshot()
	_ctrl.update_currency_hud()
