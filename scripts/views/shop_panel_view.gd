extends RefCounted
class_name ShopPanelView

const Defs := preload("res://scripts/views/home_overlay_defs.gd")
const Ui := preload("res://scripts/views/home_overlay_ui.gd")
const CurrencyBarView := preload("res://scripts/views/currency_bar_view.gd")

var panel: Control

var _economy: EconomyManager
var _shop: ShopManager
var _upgrade_btn: Button
var _close_btn: Button
var _lv_current: Label
var _lv_next: Label
var _lv_name: Label
var _slot_buy: Array[Button] = []
var _slot_price: Array[Label] = []
var _slot_desc: Array[Label] = []
var _slot_icon: Array[TextureRect] = []
var _slot_offer_ids: Array[int] = [-1, -1]
var _currency_bar: CurrencyBarView


func bind_services(economy: EconomyManager, shop: ShopManager) -> void:
	_economy = economy
	_shop = shop


func build(layer: CanvasLayer) -> void:
	panel = Control.new()
	panel.name = "ShopPanel"
	panel.visible = false
	panel.custom_minimum_size = Defs.SHOP_SIZE
	panel.size = Defs.SHOP_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)
	if ResourceLoader.exists(Defs.SHOP_BG_PATH):
		var bg := TextureRect.new()
		bg.name = "ShopBg"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = load(Defs.SHOP_BG_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bg)
	else:
		push_warning("商店底图缺失: %s" % Defs.SHOP_BG_PATH)
	_currency_bar = CurrencyBarView.new()
	_currency_bar.build(panel, CurrencyBarView.MODE_PANEL)
	_upgrade_btn = Ui.make_hit_button(Defs.SHOP_P1_UPGRADE, "升级")
	_upgrade_btn.pressed.connect(_on_upgrade_fan_pressed)
	panel.add_child(_upgrade_btn)
	_close_btn = Ui.make_hit_button(Defs.SHOP_P7_CLOSE, "")
	_close_btn.pressed.connect(func() -> void: panel.visible = false)
	panel.add_child(_close_btn)
	_lv_current = Ui.make_label(Defs.SHOP_P8_CURRENT, 14, HORIZONTAL_ALIGNMENT_LEFT)
	_lv_current.name = "LvCurrent"
	panel.add_child(_lv_current)
	_lv_name = Ui.make_label(Defs.SHOP_P10_NAME, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_lv_name.name = "LvName"
	panel.add_child(_lv_name)
	_lv_next = Ui.make_label(Defs.SHOP_P9_NEXT, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_lv_next.name = "LvNext"
	panel.add_child(_lv_next)
	_slot_buy.clear()
	_slot_price.clear()
	_slot_desc.clear()
	_slot_icon.clear()
	for i in range(2):
		var icon := TextureRect.new()
		icon.name = "SlotIcon%d" % i
		Ui.place_control(icon, Defs.SHOP_SLOT_ICON_RECTS[i])
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(icon)
		_slot_icon.append(icon)
		var desc := Ui.make_label(Defs.SHOP_SLOT_DESC_RECTS[i], 12)
		desc.name = "SlotDesc%d" % i
		panel.add_child(desc)
		_slot_desc.append(desc)
		var price := Ui.make_label(Defs.SHOP_SLOT_PRICE_RECTS[i], 14)
		price.name = "SlotPrice%d" % i
		panel.add_child(price)
		_slot_price.append(price)
		var buy := Ui.make_hit_button(Defs.SHOP_SLOT_BUY_RECTS[i], "购买")
		buy.name = "SlotBuy%d" % i
		var slot_idx := i
		buy.pressed.connect(func() -> void: _on_slot_buy_pressed(slot_idx))
		panel.add_child(buy)
		_slot_buy.append(buy)


func open() -> void:
	refresh()
	panel.visible = true


func refresh() -> void:
	if _shop == null or panel == null:
		return
	var sm: SaveManager = panel.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if _currency_bar != null:
		_currency_bar.apply(sm)
	_refresh_member_labels()
	_refresh_offer_slots()


func _refresh_member_labels() -> void:
	var sm: SaveManager = panel.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null or _shop == null:
		return
	var cur_level: int = sm.fanlevel
	var cur_row: Dictionary = _shop.get_fan_level_row(cur_level)
	var next_row: Dictionary = _shop.get_next_fan_level_row()
	var cur_name: String = str(cur_row.get("name", ""))
	if _lv_current != null:
		_lv_current.text = "Lv.%d" % cur_level
	if _lv_name != null:
		_lv_name.text = "Lv.%d %s" % [cur_level, cur_name]
	if _lv_next != null:
		if next_row.is_empty():
			_lv_next.text = "已满级"
		else:
			var next_level: int = int(next_row.get("level", cur_level + 1))
			var next_name: String = str(next_row.get("name", ""))
			_lv_next.text = "下一级 Lv.%d %s" % [next_level, next_name]


func _refresh_offer_slots() -> void:
	for i in range(2):
		_slot_offer_ids[i] = -1
		_clear_slot(i)
	var offers: Array = _shop.get_visible_offers(1)
	var count: int = mini(offers.size(), 2)
	for i in range(count):
		if not (offers[i] is Dictionary):
			continue
		_bind_slot(i, offers[i] as Dictionary)


func _clear_slot(index: int) -> void:
	if index < 0 or index >= 2:
		return
	if index < _slot_price.size():
		_slot_price[index].text = ""
	if index < _slot_desc.size():
		_slot_desc[index].text = ""
	if index < _slot_icon.size():
		_slot_icon[index].texture = null
	if index < _slot_buy.size():
		_slot_buy[index].disabled = true


func _bind_slot(index: int, offer: Dictionary) -> void:
	if index < 0 or index >= 2:
		return
	var offerid: int = int(offer.get("offerid", 0))
	_slot_offer_ids[index] = offerid
	if index < _slot_price.size():
		_slot_price[index].text = "%d 积分" % int(offer.get("price", 0))
	if index < _slot_desc.size():
		var name_text: String = str(offer.get("name", ""))
		var desc_text: String = str(offer.get("shopdesc", ""))
		if desc_text.is_empty():
			_slot_desc[index].text = name_text
		else:
			_slot_desc[index].text = "%s\n%s" % [name_text, desc_text]
	if index < _slot_icon.size():
		var icon_path: String = str(offer.get("shopicon", "")).strip_edges()
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			_slot_icon[index].texture = load(icon_path) as Texture2D
		else:
			_slot_icon[index].texture = null
	if index < _slot_buy.size():
		_slot_buy[index].disabled = false


func _on_slot_buy_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_offer_ids.size():
		return
	var offerid: int = _slot_offer_ids[slot_index]
	if offerid <= 0:
		return
	if _shop != null and _shop.purchase(offerid):
		refresh()


func _on_upgrade_fan_pressed() -> void:
	if _economy != null and _economy.try_upgrade_fan():
		refresh()
	else:
		push_warning("升级失败：专辑数量不足或未达下一级")
