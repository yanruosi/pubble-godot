extends CanvasLayer
class_name HomeOverlays

const SHOP_SIZE := Vector2(1280, 720)
const ACTIVITY_SIZE := Vector2(1280, 720)
const ACTIVITY_BG_PATH := "res://art/mainui/storeui/store2.png"
const ACTIVITY_WIN_BG_PATH := "res://art/mainui/storeui/store3.png"
const ACTIVITY_SETTLE_BG_PATH := "res://art/mainui/storeui/store5.png"

# 线下活动 store2 · PSD 1280×720
const ACTIVITY_P1_DESC := Rect2(339, 327, 243, 154)
const ACTIVITY_P2_PREV := Rect2(279, 347, 43, 42)
const ACTIVITY_P3_NEXT := Rect2(1065, 347, 43, 42)
const ACTIVITY_P4_TAB_SHOW := Rect2(1134, 126, 49, 105)
const ACTIVITY_P5_TAB_DAILY := Rect2(1134, 231, 49, 105)
const ACTIVITY_P6_TAB_SPECIAL := Rect2(1134, 336, 49, 105)
const ACTIVITY_CLOSE := Rect2(1069, 138, 46, 39)
const ACTIVITY_ACTION_HIT := Rect2(500, 530, 400, 60)
const ACTIVITY_ACTION_TEXT := Rect2(679, 569, 65, 27)
const ACTIVITY_COST_TEXT := Rect2(651, 523, 123, 26)
const ACTIVITY_OWN_TEXT := Rect2(978, 583, 123, 26)

const TAB_SHOW := 0
const TAB_DAILY := 1
const TAB_SPECIAL := 2

const HOME_BTN_ACTIVITY_POS := Vector2(985, 260)
const HOME_BTN_ACTIVITY_SIZE := Vector2(177, 56)
const SHOP_BG_PATH := "res://art/mainui/storeui/store1.png"

const SHOP_P1_UPGRADE := Rect2(288, 546, 155, 47)
const SHOP_P7_CLOSE := Rect2(1069, 138, 46, 39)
const SHOP_P8_CURRENT := Rect2(342, 197, 67, 22)
const SHOP_P9_NEXT := Rect2(342, 268, 120, 22)
const SHOP_P10_NAME := Rect2(342, 220, 120, 22)

# 道具描述 p1/p2（PSD 516×443 / 712×443）
const SHOP_SLOT_DESC_RECTS := [
	Rect2(516, 443, 157, 68),
	Rect2(712, 443, 157, 68),
]
# 售价与购买按钮：与描述列对齐
const SHOP_SLOT_PRICE_RECTS := [
	Rect2(516, 514, 157, 28),
	Rect2(712, 514, 157, 28),
]
const SHOP_SLOT_BUY_RECTS := [
	Rect2(516, 548, 157, 39),
	Rect2(712, 548, 157, 39),
]
const SHOP_SLOT_ICON_RECTS := [
	Rect2(516, 303, 156, 138),
	Rect2(722, 303, 156, 138),
]

var _activity_panel: Control
var _activity_store3_overlay: Control
var _activity_store5_overlay: Control
var _activity_desc: Label
var _activity_cost: Label
var _activity_own: Label
var _activity_action_btn: Button
var _activity_action_lbl: Label
var _activity_prev_btn: Button
var _activity_next_btn: Button
var _activity_tab_btns: Array[Button] = []
var _activity_tab_index: int = TAB_SHOW
var _activity_item_index: int = 0
var _activity_settle_event: Label
var _activity_settle_rewards: Label
var _activity_settle_close_btn: Button
var _activity_settle_go_btn: Button
var _activity_toast: Label
var _last_settle_reveal_tab: String = "fandom"

var _shop_panel: Control

var _shop_upgrade_btn: Button
var _shop_close_btn: Button
var _shop_lv_current: Label
var _shop_lv_next: Label
var _shop_lv_name: Label
var _shop_slot_buy: Array[Button] = []
var _shop_slot_price: Array[Label] = []
var _shop_slot_desc: Array[Label] = []
var _shop_slot_icon: Array[TextureRect] = []
var _shop_slot_offer_ids: Array[int] = [-1, -1]

var _economy: EconomyManager
var _shop: ShopManager
var _activity: ActivityManager
var _expose: ExposeManager
var _inventory: InventoryManager

const DEBUG_LOG_PATH := "d:/GAMES/pubble-v1/debug-7376c9.log"


func _dbg_log(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	#region agent log
	var payload := {
		"sessionId": "7376c9",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"runId": "post-fix",
	}
	var exists := FileAccess.file_exists(DEBUG_LOG_PATH)
	var mode := FileAccess.READ_WRITE if exists else FileAccess.WRITE
	var f := FileAccess.open(DEBUG_LOG_PATH, mode)
	if f == null:
		return
	if exists:
		f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
	#endregion


func setup(home_page: Control) -> void:
	layer = 320
	_economy = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_shop = get_node_or_null("/root/ShopManagerSingleton") as ShopManager
	_activity = get_node_or_null("/root/ActivityManagerSingleton") as ActivityManager
	_expose = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	_inventory = get_node_or_null("/root/InventoryManagerSingleton") as InventoryManager
	_build_activity_panel()
	_build_shop_panel()
	_add_home_buttons(home_page)


func _add_home_buttons(home_page: Control) -> void:
	if home_page == null:
		return
	var btn_act := _make_home_hit_button(HOME_BTN_ACTIVITY_POS, HOME_BTN_ACTIVITY_SIZE, home_page)
	btn_act.pressed.connect(_open_activity_panel)
	var btn_shop := _make_home_button("购买周边", Vector2(985, 330), home_page)
	btn_shop.pressed.connect(_open_shop_panel)


func _make_home_button(text: String, pos: Vector2, parent: Control) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.custom_minimum_size = Vector2(177, 56)
	btn.size = Vector2(177, 56)
	btn.focus_mode = Control.FOCUS_NONE
	parent.add_child(btn)
	return btn


func _make_home_hit_button(pos: Vector2, size: Vector2, parent: Control) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.position = pos
	btn.custom_minimum_size = size
	btn.size = size
	btn.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)
	parent.add_child(btn)
	return btn


func _build_activity_panel() -> void:
	_activity_panel = Control.new()
	_activity_panel.name = "ActivityPanel"
	_activity_panel.visible = false
	_activity_panel.custom_minimum_size = ACTIVITY_SIZE
	_activity_panel.size = ACTIVITY_SIZE
	_activity_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_activity_panel)

	if ResourceLoader.exists(ACTIVITY_BG_PATH):
		var bg := TextureRect.new()
		bg.name = "ActivityBg"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = load(ACTIVITY_BG_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_activity_panel.add_child(bg)
	else:
		push_warning("活动底图缺失: %s" % ACTIVITY_BG_PATH)

	var close_btn := _make_shop_hit_button(ACTIVITY_CLOSE, "")
	close_btn.pressed.connect(func() -> void: _activity_panel.visible = false)
	_activity_panel.add_child(close_btn)

	_activity_desc = _make_activity_label(ACTIVITY_P1_DESC, 13, HORIZONTAL_ALIGNMENT_LEFT)
	_activity_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_activity_desc.clip_text = true
	_activity_desc.name = "ActivityDesc"
	_activity_panel.add_child(_activity_desc)

	_activity_cost = _make_activity_label(ACTIVITY_COST_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_activity_cost.name = "ActivityCost"
	_activity_panel.add_child(_activity_cost)

	_activity_own = _make_activity_label(ACTIVITY_OWN_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_activity_own.name = "ActivityOwn"
	_activity_panel.add_child(_activity_own)

	_activity_action_btn = _make_shop_hit_button(ACTIVITY_ACTION_HIT, "")
	_activity_action_btn.pressed.connect(_on_activity_action_pressed)
	_activity_panel.add_child(_activity_action_btn)

	_activity_action_lbl = _make_activity_label(ACTIVITY_ACTION_TEXT, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_activity_action_lbl.name = "ActivityActionText"
	_activity_action_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_activity_panel.add_child(_activity_action_lbl)

	_activity_prev_btn = _make_shop_hit_button(ACTIVITY_P2_PREV, "")
	_activity_prev_btn.pressed.connect(_on_activity_prev_pressed)
	_activity_panel.add_child(_activity_prev_btn)

	_activity_next_btn = _make_shop_hit_button(ACTIVITY_P3_NEXT, "")
	_activity_next_btn.pressed.connect(_on_activity_next_pressed)
	_activity_panel.add_child(_activity_next_btn)

	_activity_tab_btns.clear()
	var tab_rects := [ACTIVITY_P4_TAB_SHOW, ACTIVITY_P5_TAB_DAILY, ACTIVITY_P6_TAB_SPECIAL]
	for i in range(3):
		var tab_btn := _make_shop_hit_button(tab_rects[i], "")
		var tab_idx := i
		tab_btn.pressed.connect(func() -> void: _set_activity_tab(tab_idx))
		_activity_panel.add_child(tab_btn)
		_activity_tab_btns.append(tab_btn)

	_build_activity_store3_overlay()
	_build_activity_store5_overlay()
	_build_activity_toast()


func _build_shop_panel() -> void:
	_shop_panel = Control.new()
	_shop_panel.name = "ShopPanel"
	_shop_panel.visible = false
	_shop_panel.custom_minimum_size = SHOP_SIZE
	_shop_panel.size = SHOP_SIZE
	_shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shop_panel)

	if ResourceLoader.exists(SHOP_BG_PATH):
		var bg := TextureRect.new()
		bg.name = "ShopBg"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = load(SHOP_BG_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_panel.add_child(bg)
	else:
		push_warning("商店底图缺失: %s" % SHOP_BG_PATH)

	_shop_upgrade_btn = _make_shop_hit_button(SHOP_P1_UPGRADE, "升级")
	_shop_upgrade_btn.pressed.connect(_on_upgrade_fan_pressed)
	_shop_panel.add_child(_shop_upgrade_btn)

	_shop_close_btn = _make_shop_hit_button(SHOP_P7_CLOSE, "")
	_shop_close_btn.pressed.connect(func() -> void: _shop_panel.visible = false)
	_shop_panel.add_child(_shop_close_btn)

	_shop_lv_current = _make_shop_label(SHOP_P8_CURRENT, 14, HORIZONTAL_ALIGNMENT_LEFT)
	_shop_lv_current.name = "LvCurrent"
	_shop_panel.add_child(_shop_lv_current)

	_shop_lv_name = _make_shop_label(SHOP_P10_NAME, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_shop_lv_name.name = "LvName"
	_shop_panel.add_child(_shop_lv_name)

	_shop_lv_next = _make_shop_label(SHOP_P9_NEXT, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_shop_lv_next.name = "LvNext"
	_shop_panel.add_child(_shop_lv_next)

	_shop_slot_buy.clear()
	_shop_slot_price.clear()
	_shop_slot_desc.clear()
	_shop_slot_icon.clear()
	for i in range(2):
		var icon := TextureRect.new()
		icon.name = "SlotIcon%d" % i
		_place_control(icon, SHOP_SLOT_ICON_RECTS[i])
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_panel.add_child(icon)
		_shop_slot_icon.append(icon)

		var desc := _make_shop_label(SHOP_SLOT_DESC_RECTS[i], 12)
		desc.name = "SlotDesc%d" % i
		_shop_panel.add_child(desc)
		_shop_slot_desc.append(desc)

		var price := _make_shop_label(SHOP_SLOT_PRICE_RECTS[i], 14)
		price.name = "SlotPrice%d" % i
		_shop_panel.add_child(price)
		_shop_slot_price.append(price)

		var buy := _make_shop_hit_button(SHOP_SLOT_BUY_RECTS[i], "购买")
		buy.name = "SlotBuy%d" % i
		var slot_idx := i
		buy.pressed.connect(func() -> void: _on_shop_slot_buy_pressed(slot_idx))
		_shop_panel.add_child(buy)
		_shop_slot_buy.append(buy)


func _build_activity_store3_overlay() -> void:
	_activity_store3_overlay = Control.new()
	_activity_store3_overlay.name = "ActivityWinOverlay"
	_activity_store3_overlay.visible = false
	_activity_store3_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_activity_store3_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_activity_store3_overlay.gui_input.connect(_on_store3_overlay_input)
	_activity_panel.add_child(_activity_store3_overlay)

	if ResourceLoader.exists(ACTIVITY_WIN_BG_PATH):
		var win_bg := TextureRect.new()
		win_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		win_bg.texture = load(ACTIVITY_WIN_BG_PATH) as Texture2D
		win_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		win_bg.stretch_mode = TextureRect.STRETCH_SCALE
		win_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_activity_store3_overlay.add_child(win_bg)
	else:
		push_warning("中签弹层缺失: %s" % ACTIVITY_WIN_BG_PATH)


func _build_activity_store5_overlay() -> void:
	_activity_store5_overlay = Control.new()
	_activity_store5_overlay.name = "ActivitySettleOverlay"
	_activity_store5_overlay.visible = false
	_activity_store5_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_activity_store5_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_activity_store5_overlay)

	if ResourceLoader.exists(ACTIVITY_SETTLE_BG_PATH):
		var bg := TextureRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.texture = load(ACTIVITY_SETTLE_BG_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_activity_store5_overlay.add_child(bg)
	else:
		push_warning("结算底图缺失: %s" % ACTIVITY_SETTLE_BG_PATH)

	_activity_settle_close_btn = _make_shop_hit_button(ACTIVITY_CLOSE, "")
	_activity_settle_close_btn.pressed.connect(_close_activity_settle)
	_activity_store5_overlay.add_child(_activity_settle_close_btn)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_activity_store5_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	_activity_settle_event = Label.new()
	_activity_settle_event.name = "SettleEvent"
	_activity_settle_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity_settle_event.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_activity_settle_event.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_settle_event.custom_minimum_size = Vector2(620, 0)
	_activity_settle_event.add_theme_font_size_override("font_size", 15)
	_activity_settle_event.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18, 1))
	box.add_child(_activity_settle_event)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	_activity_settle_rewards = Label.new()
	_activity_settle_rewards.name = "SettleRewards"
	_activity_settle_rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity_settle_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_activity_settle_rewards.custom_minimum_size = Vector2(520, 0)
	_activity_settle_rewards.add_theme_font_size_override("font_size", 14)
	_activity_settle_rewards.add_theme_color_override("font_color", Color(0.18, 0.32, 0.22, 1))
	box.add_child(_activity_settle_rewards)

	_activity_settle_go_btn = _make_shop_hit_button(Rect2(490, 600, 300, 44), "前往pubble查看")
	_activity_settle_go_btn.add_theme_font_size_override("font_size", 15)
	_activity_settle_go_btn.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18, 1))
	_activity_settle_go_btn.pressed.connect(_on_settle_go_pubble_pressed)
	_activity_store5_overlay.add_child(_activity_settle_go_btn)


func _build_activity_toast() -> void:
	_activity_toast = Label.new()
	_activity_toast.name = "ActivityToast"
	_activity_toast.visible = false
	_activity_toast.position = Vector2(440, 360)
	_activity_toast.custom_minimum_size = Vector2(400, 32)
	_activity_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_activity_toast.add_theme_font_size_override("font_size", 16)
	_activity_toast.add_theme_color_override("font_color", Color(0.35, 0.12, 0.12, 1))
	_activity_toast.z_index = 400
	add_child(_activity_toast)


func _make_activity_label(rect: Rect2, font_size: int, h_align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lbl := _make_shop_label(rect, font_size, h_align)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _place_control(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.custom_minimum_size = rect.size
	node.size = rect.size


func _make_shop_hit_button(rect: Rect2, text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	_place_control(btn, rect)
	var empty := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty)
	btn.add_theme_stylebox_override("hover", empty)
	btn.add_theme_stylebox_override("pressed", empty)
	btn.add_theme_stylebox_override("disabled", empty)
	btn.add_theme_stylebox_override("focus", empty)
	if not text.is_empty():
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color(0.18, 0.32, 0.22, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.1, 0.45, 0.25, 1))
		btn.add_theme_color_override("font_pressed_color", Color(0.08, 0.38, 0.2, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 0.6))
	return btn


func _make_shop_label(rect: Rect2, font_size: int, h_align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var lbl := Label.new()
	_place_control(lbl, rect)
	lbl.horizontal_alignment = h_align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18, 1))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.clip_text = false
	return lbl



func _open_activity_panel() -> void:
	_activity_tab_index = TAB_SHOW
	_activity_item_index = 0
	_refresh_activity_panel()
	_activity_panel.visible = true


func _open_shop_panel() -> void:
	#region agent log
	_dbg_log("A", "home_overlays.gd:_open_shop_panel", "open shop", {
		"shop_null": _shop == null,
		"tutorial_done": _get_tutorial_done(),
		"fp": _get_fp(),
	})
	#endregion
	_refresh_shop_panel()
	_shop_panel.visible = true


func _get_tutorial_done() -> bool:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	return sm.tutorialdone if sm != null else true


func _get_fp() -> int:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	return sm.fp if sm != null else -1


func _activities_for_tab(tab: int) -> Array:
	if _activity == null:
		return []
	var out: Array = []
	for act in _activity.get_visible_activities():
		if not (act is Dictionary):
			continue
		var cat: int = int((act as Dictionary).get("category", 0))
		if tab == TAB_SHOW and (cat == 2 or cat == 3):
			out.append(act)
		elif tab == TAB_DAILY and cat == 1:
			out.append(act)
	return out


func _current_tab_activities() -> Array:
	return _activities_for_tab(_activity_tab_index)


func _current_activity() -> Dictionary:
	var list: Array = _current_tab_activities()
	if list.is_empty():
		return {}
	var idx: int = clampi(_activity_item_index, 0, list.size() - 1)
	return list[idx] as Dictionary


func _set_activity_tab(tab: int) -> void:
	_activity_tab_index = tab
	_activity_item_index = 0
	_refresh_activity_panel()


func _on_activity_prev_pressed() -> void:
	var list: Array = _current_tab_activities()
	if list.size() <= 1:
		return
	_activity_item_index = (_activity_item_index - 1 + list.size()) % list.size()
	_refresh_activity_panel()


func _on_activity_next_pressed() -> void:
	var list: Array = _current_tab_activities()
	if list.size() <= 1:
		return
	_activity_item_index = (_activity_item_index + 1) % list.size()
	_refresh_activity_panel()


func _refresh_activity_panel() -> void:
	if _activity_panel == null:
		return
	var list: Array = _current_tab_activities()
	var has_items := not list.is_empty()
	if has_items:
		_activity_item_index = clampi(_activity_item_index, 0, list.size() - 1)
		var act: Dictionary = list[_activity_item_index] as Dictionary
		_bind_activity_display(act)
	else:
		_bind_activity_empty_tab()

	_activity_prev_btn.disabled = not has_items or list.size() <= 1
	_activity_next_btn.disabled = not has_items or list.size() <= 1
	if _activity_action_btn != null and has_items:
		var act: Dictionary = list[_activity_item_index] as Dictionary
		var aid: String = str(act.get("activityid", ""))
		_activity_action_btn.disabled = _get_activity_state(aid) == ActivityManager.STATE_DEPARTED
	elif _activity_action_btn != null:
		_activity_action_btn.disabled = true


func _bind_activity_empty_tab() -> void:
	if _activity_desc != null:
		if _activity_tab_index == TAB_SPECIAL:
			_activity_desc.text = "暂无特殊活动"
		else:
			_activity_desc.text = "暂无可用活动"
	if _activity_cost != null:
		_activity_cost.text = ""
		_activity_cost.visible = false
	if _activity_own != null:
		_activity_own.text = ""
		_activity_own.visible = false
	if _activity_action_lbl != null:
		_activity_action_lbl.text = ""


func _bind_activity_display(act: Dictionary) -> void:
	if _activity_desc != null:
		_activity_desc.text = str(act.get("name", ""))

	var cost_fp: int = int(act.get("costfp", 0))
	var cost_item: int = int(act.get("costitemid", 0))
	var cost_count: int = int(act.get("costitemcount", 0))
	var show_cost := cost_fp > 0 or (cost_item > 0 and cost_count > 0)

	if _activity_cost != null:
		_activity_cost.visible = show_cost
		if show_cost:
			if cost_item > 0 and cost_count > 0:
				_activity_cost.text = "消耗签售专%d张" % cost_count
			elif cost_fp > 0:
				_activity_cost.text = "消耗饭圈积分%d" % cost_fp
			else:
				_activity_cost.text = ""

	if _activity_own != null:
		_activity_own.visible = show_cost
		if show_cost:
			if cost_item > 0 and cost_count > 0:
				var owned: int = _inventory.get_count(cost_item) if _inventory != null else 0
				_activity_own.text = "拥有签售专：%d 张" % owned
			elif cost_fp > 0:
				_activity_own.text = "拥有饭圈积分：%d" % _get_fp()
			else:
				_activity_own.text = ""

	var aid: String = str(act.get("activityid", ""))
	var cat: int = int(act.get("category", 0))
	var state := _get_activity_state(aid)
	var needs_lottery := cat == 2 or cat == 3
	if _activity_action_lbl != null:
		if state == ActivityManager.STATE_DEPARTED:
			_activity_action_lbl.text = "已出发"
		elif state == ActivityManager.STATE_WON:
			_activity_action_lbl.text = "出发"
		elif needs_lottery:
			_activity_action_lbl.text = "抽选"
		else:
			_activity_action_lbl.text = "参与"
	if _activity_action_btn != null:
		_activity_action_btn.disabled = state == ActivityManager.STATE_DEPARTED


func _get_activity_state(activityid: String) -> String:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return ""
	return sm.get_activity_state(activityid)


func _on_activity_action_pressed() -> void:
	var act: Dictionary = _current_activity()
	if act.is_empty() or _activity == null:
		return
	var aid: String = str(act.get("activityid", ""))
	var cat: int = int(act.get("category", 0))
	var state := _get_activity_state(aid)
	if cat == 1:
		if state == ActivityManager.STATE_DEPARTED:
			return
		var result: Dictionary = _activity.participate(aid)
		if not bool(result.get("ok", false)):
			_show_activity_toast(str(result.get("reason", "活动失败")))
		else:
			#region agent log
			var payload := {
				"sessionId": "c0d936",
				"hypothesisId": "E",
				"location": "home_overlays.gd:_on_activity_action_pressed",
				"message": "airport settle",
				"data": {
					"aid": aid,
					"reveal_tab": str(result.get("reveal_tab", "")),
					"sister_count": int(result.get("sister_count", 0)),
				},
				"timestamp": Time.get_unix_time_from_system() * 1000,
				"runId": "reveal-fix",
			}
			var lf := FileAccess.open("debug-c0d936.log", FileAccess.READ_WRITE if FileAccess.file_exists("debug-c0d936.log") else FileAccess.WRITE)
			if lf != null:
				if FileAccess.file_exists("debug-c0d936.log"):
					lf.seek_end()
				lf.store_line(JSON.stringify(payload))
				lf.close()
			#endregion
			_show_activity_settle(result)
		_refresh_activity_panel()
		return
	if state == ActivityManager.STATE_DEPARTED:
		return
	if state == ActivityManager.STATE_WON:
		_do_activity_depart(aid)
		return
	_do_activity_draw(aid)


func _do_activity_draw(activity_id: String) -> void:
	var result: Dictionary = _activity.draw_lottery(activity_id)
	if not bool(result.get("ok", false)):
		_show_activity_toast(str(result.get("reason", "抽选失败")))
		_refresh_activity_panel()
		return
	if bool(result.get("won", false)):
		_activity_store3_overlay.visible = true
	else:
		_show_activity_toast("未中签")
	_refresh_activity_panel()


func _do_activity_depart(activity_id: String) -> void:
	var result: Dictionary = _activity.depart(activity_id)
	if not bool(result.get("ok", false)):
		_show_activity_toast(str(result.get("reason", "出发失败")))
		_refresh_activity_panel()
		return
	_show_activity_settle(result)
	_refresh_activity_panel()


func _show_activity_settle(result: Dictionary) -> void:
	_last_settle_reveal_tab = str(result.get("reveal_tab", "fandom"))
	if _activity_settle_event != null:
		_activity_settle_event.text = str(result.get("event_text", ""))
	if _activity_settle_rewards != null:
		var lines: PackedStringArray = []
		var fh: int = int(result.get("fandom_hq_count", 0))
		var sc: int = int(result.get("sister_count", 0))
		if fh > 0:
			lines.append("饭圈新增高质量帖子 %d 条" % fh)
		if sc > 0:
			lines.append("嫂子相关帖子 %d 条" % sc)
		if lines.is_empty():
			lines.append("本次暂无新帖子产出")
		_activity_settle_rewards.text = "\n".join(lines)
	if _activity_panel != null:
		_activity_panel.visible = false
	if _activity_store5_overlay != null:
		_activity_store5_overlay.visible = true


func _close_activity_settle() -> void:
	if _activity_store5_overlay != null:
		_activity_store5_overlay.visible = false
	if _activity_panel != null:
		_activity_panel.visible = false


func _on_settle_go_pubble_pressed() -> void:
	_close_activity_settle()
	var router: Node = get_parent()
	if router != null and router.has_method("open_feed_tab"):
		router.call("open_feed_tab", _last_settle_reveal_tab)


func _show_activity_toast(msg: String) -> void:
	if _activity_toast == null:
		push_warning(msg)
		return
	_activity_toast.text = msg
	_activity_toast.visible = true
	var timer := get_tree().create_timer(1.8)
	timer.timeout.connect(func() -> void:
		if _activity_toast != null:
			_activity_toast.visible = false
	)


func _on_store3_overlay_input(event: InputEvent) -> void:
	if not _activity_store3_overlay.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_activity_store3_overlay.visible = false
			_refresh_activity_panel()
			_activity_store3_overlay.accept_event()


func _refresh_shop_panel() -> void:
	if _shop == null or _shop_panel == null:
		return
	_refresh_shop_member_labels()
	_refresh_shop_offer_slots()


func _refresh_shop_member_labels() -> void:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null or _shop == null:
		return
	var cur_level: int = sm.fanlevel
	var cur_row: Dictionary = _shop.get_fan_level_row(cur_level)
	var next_row: Dictionary = _shop.get_next_fan_level_row()
	var cur_name: String = str(cur_row.get("name", ""))
	if _shop_lv_current != null:
		_shop_lv_current.text = "Lv.%d" % cur_level
	if _shop_lv_name != null:
		_shop_lv_name.text = "Lv.%d %s" % [cur_level, cur_name]
	if _shop_lv_next != null:
		if next_row.is_empty():
			_shop_lv_next.text = "已满级"
		else:
			var next_level: int = int(next_row.get("level", cur_level + 1))
			var next_name: String = str(next_row.get("name", ""))
			_shop_lv_next.text = "下一级 Lv.%d %s" % [next_level, next_name]


func _refresh_shop_offer_slots() -> void:
	for i in range(2):
		_shop_slot_offer_ids[i] = -1
		_clear_shop_slot(i)
	var offers: Array = _shop.get_visible_offers(1)
	var count: int = mini(offers.size(), 2)
	#region agent log
	_dbg_log("A", "home_overlays.gd:_refresh_shop_offer_slots", "offers loaded", {
		"count": count,
		"offer_ids": offers.map(func(o): return int(o.get("offerid", 0)) if o is Dictionary else -1),
	})
	#endregion
	for i in range(count):
		if not (offers[i] is Dictionary):
			continue
		_bind_shop_slot(i, offers[i] as Dictionary)


func _clear_shop_slot(index: int) -> void:
	if index < 0 or index >= 2:
		return
	if index < _shop_slot_price.size():
		_shop_slot_price[index].text = ""
	if index < _shop_slot_desc.size():
		_shop_slot_desc[index].text = ""
	if index < _shop_slot_icon.size():
		_shop_slot_icon[index].texture = null
	if index < _shop_slot_buy.size():
		_shop_slot_buy[index].disabled = true


func _bind_shop_slot(index: int, offer: Dictionary) -> void:
	if index < 0 or index >= 2:
		return
	var offerid: int = int(offer.get("offerid", 0))
	_shop_slot_offer_ids[index] = offerid
	if index < _shop_slot_price.size():
		_shop_slot_price[index].text = "%d 积分" % int(offer.get("price", 0))
	if index < _shop_slot_desc.size():
		var name_text: String = str(offer.get("name", ""))
		var desc_text: String = str(offer.get("shopdesc", ""))
		if desc_text.is_empty():
			_shop_slot_desc[index].text = name_text
		else:
			_shop_slot_desc[index].text = "%s\n%s" % [name_text, desc_text]
	if index < _shop_slot_icon.size():
		var icon_path: String = str(offer.get("shopicon", "")).strip_edges()
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			_shop_slot_icon[index].texture = load(icon_path) as Texture2D
		else:
			_shop_slot_icon[index].texture = null
	if index < _shop_slot_buy.size():
		_shop_slot_buy[index].disabled = false
	#region agent log
	_dbg_log("BCE", "home_overlays.gd:_bind_shop_slot", "slot bound", {
		"index": index,
		"offerid": offerid,
		"price_text": _shop_slot_price[index].text if index < _shop_slot_price.size() else "",
		"desc_text": _shop_slot_desc[index].text if index < _shop_slot_desc.size() else "",
		"buy_text": _shop_slot_buy[index].text if index < _shop_slot_buy.size() else "",
		"buy_disabled": _shop_slot_buy[index].disabled if index < _shop_slot_buy.size() else true,
		"desc_rect": str(_shop_slot_desc[index].position) if index < _shop_slot_desc.size() else "",
		"price_rect": str(_shop_slot_price[index].position) if index < _shop_slot_price.size() else "",
		"buy_rect": str(_shop_slot_buy[index].position) if index < _shop_slot_buy.size() else "",
	})
	#endregion


func _on_shop_slot_buy_pressed(slot_index: int) -> void:
	#region agent log
	_dbg_log("D", "home_overlays.gd:_on_shop_slot_buy_pressed", "buy pressed", {
		"slot_index": slot_index,
		"offerid": _shop_slot_offer_ids[slot_index] if slot_index < _shop_slot_offer_ids.size() else -1,
	})
	#endregion
	if slot_index < 0 or slot_index >= _shop_slot_offer_ids.size():
		return
	var offerid: int = _shop_slot_offer_ids[slot_index]
	if offerid <= 0:
		return
	_on_buy_offer(offerid)


func _on_buy_offer(offerid: int) -> void:
	var ok := _shop != null and _shop.purchase(offerid)
	#region agent log
	_dbg_log("D", "home_overlays.gd:_on_buy_offer", "purchase result", {"offerid": offerid, "ok": ok})
	#endregion
	if ok:
		_refresh_shop_panel()


func _on_upgrade_fan_pressed() -> void:
	if _economy != null and _economy.try_upgrade_fan():
		_refresh_shop_panel()
	else:
		push_warning("升级失败：专辑数量不足或未达下一级")
