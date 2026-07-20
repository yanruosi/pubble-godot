extends RefCounted

## 饭圈实例 CRUD / 收藏 / 可见性

const _Tpl = preload("res://scripts/expose/feed_instance_tpl.gd")
var _ctx
var _templates_by_id: Dictionary = {}
var _pending_reveal_by_tab: Dictionary = {}


func _init(ctx) -> void:
	_ctx = ctx


func load_tables() -> void:
	_templates_by_id.clear()
	for row in TableRepo.get_table("post_templates"):
		if row is Dictionary:
			_templates_by_id[str(row.get("postid", ""))] = row


func get_templates_by_id() -> Dictionary:
	return _templates_by_id


func add_instance(postid: String, tabsource: int = -1) -> Dictionary:
	if _ctx.save == null or postid.is_empty():
		return {}
	var tpl: Dictionary = _templates_by_id.get(postid, {})
	if tabsource < 0:
		tabsource = int(tpl.get("tabtype", ExposeManager.TAB_SISTER))
	var inst := {
		"instanceid": _ctx.save.next_instance_id(),
		"postid": postid,
		"tabsource": tabsource,
		"createdat": int(Time.get_unix_time_from_system()),
		"fpcollected": false,
		"keypostcollected": false,
		"fpearned": 0,
	}
	_ctx.save.feed_instances.append(inst)
	_ctx.save.save_progress()
	_ctx.host.instance_changed.emit()
	_ctx.banner.notify_changed()
	return inst


func mark_instances_for_reveal(instances: Array) -> void:
	for item in instances:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		var iid: String = str(inst.get("instanceid", ""))
		if iid.is_empty():
			continue
		for tabtype in [ExposeManager.TAB_FANDOM, ExposeManager.TAB_SISTER, ExposeManager.TAB_ACCOUNT]:
			if not is_visible_on_tab(inst, tabtype):
				continue
			if not _pending_reveal_by_tab.has(tabtype):
				_pending_reveal_by_tab[tabtype] = []
			var ids: Array = _pending_reveal_by_tab[tabtype]
			if not ids.has(iid):
				ids.append(iid)


func take_pending_reveal_ids(tabtype: int) -> Array:
	if not _pending_reveal_by_tab.has(tabtype):
		return []
	var ids: Array = (_pending_reveal_by_tab[tabtype] as Array).duplicate()
	_pending_reveal_by_tab.erase(tabtype)
	return ids


func get_instances_for_tab(tabtype: int) -> Array:
	if _ctx.save == null:
		return []
	var out: Array = []
	for item in _ctx.save.feed_instances:
		if not (item is Dictionary):
			continue
		if is_visible_on_tab(item as Dictionary, tabtype):
			out.append(item)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("createdat", 0)) > int(b.get("createdat", 0))
	)
	return out


func get_template(postid: String) -> Dictionary:
	return _templates_by_id.get(postid, {}).duplicate(true)


func find_feed_instance(inst_id: String) -> Dictionary:
	if _ctx.save == null:
		return {}
	for item in _ctx.save.feed_instances:
		if item is Dictionary and str((item as Dictionary).get("instanceid", "")) == inst_id:
			return item as Dictionary
	return {}


func resolve_postclass(tpl: Dictionary) -> int:
	if tpl.has("postclass"):
		return int(tpl.get("postclass", ExposeManager.POSTCLASS_NORMAL))
	if int(tpl.get("tabtype", 0)) == ExposeManager.TAB_SISTER and int(tpl.get("grantintel", 0)) > 0:
		return ExposeManager.POSTCLASS_KEY
	return ExposeManager.POSTCLASS_NORMAL


func is_visible_on_tab(inst: Dictionary, tabtype: int) -> bool:
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	if tpl.is_empty():
		return false
	if _Tpl.is_my_post_template(tpl):
		return tabtype == ExposeManager.TAB_ACCOUNT
	if tabtype == ExposeManager.TAB_ACCOUNT:
		return false
	if tabtype == ExposeManager.TAB_FANDOM:
		if _Tpl.is_sister_or_key_template(tpl, resolve_postclass(tpl)):
			return true
		return resolve_postclass(tpl) in [ExposeManager.POSTCLASS_NORMAL, ExposeManager.POSTCLASS_ADVANCED]
	if tabtype == ExposeManager.TAB_SISTER:
		return _Tpl.is_sister_or_key_template(tpl, resolve_postclass(tpl))
	return false


func favorite_instance(inst_id: String) -> bool:
	if _ctx.save == null or inst_id.is_empty() or _ctx.save.favorites.has(inst_id):
		return false
	var inst: Dictionary = find_feed_instance(inst_id)
	if inst.is_empty():
		return false
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	if resolve_postclass(tpl) != ExposeManager.POSTCLASS_KEY:
		return false
	if bool(inst.get("keypostcollected", false)):
		return false
	inst["keypostcollected"] = true
	_ctx.save.favorites.append(inst_id)
	_ctx.save.keypost_progress += 1
	_ctx.try_auto_upgrade_intel()
	_ctx.save.save_progress()
	_ctx.host.keypost_favorited.emit(inst_id)
	_ctx.host.instance_changed.emit()
	_ctx.banner.notify_changed()
	return true


func toggle_instance_favorite(inst_id: String, favorited: bool) -> bool:
	if _ctx.save == null or inst_id.is_empty():
		return false
	var inst: Dictionary = find_feed_instance(inst_id)
	if inst.is_empty():
		return false
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	var postclass: int = resolve_postclass(tpl)
	if postclass == ExposeManager.POSTCLASS_KEY:
		return favorited and favorite_instance(inst_id)
	if postclass not in [ExposeManager.POSTCLASS_NORMAL, ExposeManager.POSTCLASS_ADVANCED, ExposeManager.POSTCLASS_MAINLINE]:
		return false
	if favorited:
		if _ctx.save.favorites.has(inst_id):
			return false
		_ctx.save.favorites.append(inst_id)
	else:
		if not _ctx.save.favorites.has(inst_id):
			return false
		_ctx.save.favorites.erase(inst_id)
	_ctx.save.save_progress()
	_ctx.host.instance_changed.emit()
	return true


func is_instance_favorited(inst_id: String) -> bool:
	if _ctx.save == null or inst_id.is_empty():
		return false
	return _ctx.save.favorites.has(inst_id)


func bump_instance_display_likes(inst_id: String) -> int:
	if _ctx.save == null or inst_id.is_empty():
		return 0
	var inst: Dictionary = find_feed_instance(inst_id)
	if inst.is_empty():
		return 0
	var count: int = int(inst.get("display_likes", 0)) + 1
	inst["display_likes"] = count
	_ctx.save.save_progress()
	return count


func apply_wrong_sister_favorite_penalty(inst_id: String) -> bool:
	if _ctx.save == null or inst_id.is_empty() or _ctx.save.favorites.has(inst_id):
		return false
	var inst: Dictionary = find_feed_instance(inst_id)
	if inst.is_empty():
		return false
	var tpl: Dictionary = _templates_by_id.get(str(inst.get("postid", "")), {})
	if int(tpl.get("tabtype", 0)) != ExposeManager.TAB_SISTER:
		return false
	if resolve_postclass(tpl) == ExposeManager.POSTCLASS_KEY:
		return false
	_ctx.save.fans = maxi(0, _ctx.save.fans - 10)
	_ctx.save.save_progress()
	if _ctx.economy != null and _ctx.economy.has_method("notify_balance_updated"):
		_ctx.economy.notify_balance_updated(-1)
	_ctx.host.instance_changed.emit()
	return true


func try_collect_instance(instance_id: String, tabtype: int) -> bool:
	if _ctx.save == null or instance_id.is_empty():
		return false
	for item in _ctx.save.feed_instances:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		if str(inst.get("instanceid", "")) != instance_id:
			continue
		if not is_visible_on_tab(inst, tabtype):
			return false
		return favorite_instance(instance_id)
	return false
