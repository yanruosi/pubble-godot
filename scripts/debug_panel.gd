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

	box.add_child(_label("Debug Panel (F12)"))
	box.add_child(_btn("+10 FP", func() -> void: _add_currency(22, 10)))
	box.add_child(_btn("+10 Intel", func() -> void: _add_currency(24, 10)))
	box.add_child(_btn("+3 Stars", func() -> void: _add_currency(23, 3)))
	box.add_child(_btn("Upgrade Intel", func() -> void: _upgrade_intel()))
	box.add_child(_btn("Upgrade Fan", func() -> void: _upgrade_fan()))
	box.add_child(_btn("Buy Offer 1", func() -> void: _buy_offer(1)))
	box.add_child(_btn("Activity Airport 1", func() -> void: _act("1")))
	box.add_child(_btn("Activity Sign 7", func() -> void: _act("7")))
	box.add_child(_btn("Collect All Ready", func() -> void: _collect_all()))
	box.add_child(_btn("Reset Progress", func() -> void: _reset()))
	box.add_child(_btn("Close", func() -> void: _toggle()))

	_panel.set_meta("status_label", _label("status"))
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
		"fp=%d intel=%d stars=%d" % [sm.fp, sm.intel, sm.stars],
		"intelLv=%d fanLv=%d stationExp=%d" % [sm.intellevel, sm.fanlevel, sm.stationexp],
		"instances=%d inventory=%s" % [sm.feed_instances.size(), str(sm.inventory)],
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
	if act != null:
		act.participate(activityid)
	_refresh()


func _collect_all() -> void:
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if expose == null or sm == null:
		return
	for item in sm.feed_instances.duplicate():
		if item is Dictionary:
			var id: String = str(item.get("instanceid", ""))
			expose.start_expose(id)
			expose.collect_instance(id)
	_refresh()


func _reset() -> void:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if sm != null:
		sm.reset_progress()
	if expose != null:
		expose.seed_tutorial_instance()
	_refresh()
