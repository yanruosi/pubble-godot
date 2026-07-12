extends CanvasLayer

var _panel: PanelContainer
var _visible := false


func _ready() -> void:
	layer = 500
	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_F12:
			_toggle()


func _toggle() -> void:
	_visible = not _visible
	visible = _visible
	if _visible:
		_refresh()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(40, 40)
	_panel.custom_minimum_size = Vector2(420, 520)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 500)
	_panel.add_child(scroll)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	box.add_child(_label("调试面板 (F12)"))
	box.add_child(_btn("+10 饭圈积分", func() -> void: _add_currency(22, 10)))
	box.add_child(_btn("+10 情报点", func() -> void: _add_currency(24, 10)))
	box.add_child(_btn("+3 星星", func() -> void: _add_currency(23, 3)))
	box.add_child(_btn("升级情报等级", func() -> void: _upgrade_intel()))
	box.add_child(_btn("升级会员等级", func() -> void: _upgrade_fan()))
	box.add_child(_btn("购买教程专辑", func() -> void: _buy_offer(1)))
	box.add_child(_btn("活动·机场1", func() -> void: _act("1")))
	box.add_child(_btn("活动·签售7", func() -> void: _act("7")))
	box.add_child(_btn("收取全部放置帖", func() -> void: _collect_all()))
	box.add_child(_btn("重置存档", func() -> void: _reset()))
	box.add_child(_btn("关闭", func() -> void: _toggle()))

	_panel.set_meta("status_label", _label("状态"))
	box.add_child(_panel.get_meta("status_label"))


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _refresh() -> void:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var lbl: Label = _panel.get_meta("status_label") as Label
	if sm == null or lbl == null:
		return
	var lines: PackedStringArray = [
		"饭圈积分=%d  情报点=%d  星星=%d" % [sm.fp, sm.intel, sm.stars],
		"情报等级=%d  会员等级=%d  站子经验=%d" % [sm.intellevel, sm.fanlevel, sm.stationexp],
		"放置帖=%d  背包=%s" % [sm.feed_instances.size(), str(sm.inventory)],
	]
	lbl.text = "\n".join(lines)


func _add_currency(cat: int, amt: int) -> void:
	var eco: EconomyManager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if eco != null:
		eco.add_currency(cat, amt, "debug")
	_refresh()


func _upgrade_intel() -> void:
	var eco: EconomyManager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if eco != null:
		eco.try_upgrade_intel()
	_refresh()


func _upgrade_fan() -> void:
	var eco: EconomyManager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if eco != null:
		eco.try_upgrade_fan()
	_refresh()


func _buy_offer(offerid: int) -> void:
	var shop: ShopManager = get_node_or_null("/root/ShopManagerSingleton") as ShopManager
	if shop != null:
		shop.purchase(offerid)
	_refresh()


func _act(activityid: String) -> void:
	var act: ActivityManager = get_node_or_null("/root/ActivityManagerSingleton") as ActivityManager
	if act == null:
		return
	var row: Dictionary = act.get_activity(activityid)
	if row.is_empty():
		return
	var cat: int = int(row.get("category", 0))
	if cat == 2 or cat == 3:
		var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
		var state := sm.get_activity_state(activityid) if sm != null else ""
		if state == ActivityManager.STATE_DEPARTED:
			return
		if state == ActivityManager.STATE_WON:
			act.depart(activityid)
		else:
			var draw_res: Dictionary = act.draw_lottery(activityid)
			if bool(draw_res.get("ok", false)) and bool(draw_res.get("won", false)):
				act.depart(activityid)
	else:
		act.participate(activityid)
	_refresh()


func _collect_all() -> void:
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose == null:
		return
	expose.on_tab_entered(903)
	expose.on_tab_entered(0)
	_refresh()


func _reset() -> void:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if sm != null:
		sm.reset_progress()
	if expose != null:
		expose.seed_tutorial_instance()
	_refresh()
