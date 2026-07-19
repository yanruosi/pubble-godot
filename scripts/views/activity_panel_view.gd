extends RefCounted
class_name ActivityPanelView

const Defs := preload("res://scripts/views/home_overlay_defs.gd")
const Ui := preload("res://scripts/views/home_overlay_ui.gd")
const ActivityBind := preload("res://scripts/views/home_overlay_activity.gd")
const _Actions = preload("res://scripts/views/activity_panel_actions.gd")
const SignPanelViewScript := preload("res://scripts/views/sign_panel_view.gd")

var panel: Control

var _activity: ActivityManager
var _inventory: InventoryManager
var _sign
var _is_opening_flow: Callable
var _get_fp: Callable
var _get_activity_state: Callable

var _desc: Label
var _cost: Label
var _own: Label
var _action_btn: Button
var _action_lbl: Label
var _prev_btn: Button
var _next_btn: Button
var _tab_btns: Array[Button] = []
var _tab_index: int = Defs.TAB_SHOW
var _item_index: int = 0


func bind_services(
	activity: ActivityManager,
	inventory: InventoryManager,
	sign,
	is_opening_flow: Callable,
	get_fp: Callable,
	get_activity_state: Callable
) -> void:
	_activity = activity
	_inventory = inventory
	_sign = sign
	_is_opening_flow = is_opening_flow
	_get_fp = get_fp
	_get_activity_state = get_activity_state


func build(layer: CanvasLayer) -> void:
	panel = Control.new()
	panel.name = "ActivityPanel"
	panel.visible = false
	panel.custom_minimum_size = Defs.ACTIVITY_SIZE
	panel.size = Defs.ACTIVITY_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)
	if ResourceLoader.exists(Defs.ACTIVITY_BG_PATH):
		var bg := TextureRect.new()
		bg.name = "ActivityBg"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = load(Defs.ACTIVITY_BG_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(bg)
	else:
		push_warning("活动底图缺失: %s" % Defs.ACTIVITY_BG_PATH)
	var close_btn := Ui.make_hit_button(Defs.ACTIVITY_CLOSE, "")
	close_btn.pressed.connect(func() -> void: panel.visible = false)
	panel.add_child(close_btn)
	_desc = Ui.make_activity_label(Defs.ACTIVITY_P1_DESC, 13, HORIZONTAL_ALIGNMENT_LEFT)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc.clip_text = true
	_desc.name = "ActivityDesc"
	panel.add_child(_desc)
	_cost = Ui.make_activity_label(Defs.ACTIVITY_COST_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_cost.name = "ActivityCost"
	panel.add_child(_cost)
	_own = Ui.make_activity_label(Defs.ACTIVITY_OWN_TEXT, 12, HORIZONTAL_ALIGNMENT_LEFT)
	_own.name = "ActivityOwn"
	panel.add_child(_own)
	_action_btn = Ui.make_hit_button(Defs.ACTIVITY_ACTION_HIT, "")
	_action_btn.pressed.connect(_on_action_pressed)
	panel.add_child(_action_btn)
	_action_lbl = Ui.make_activity_label(Defs.ACTIVITY_ACTION_TEXT, 15, HORIZONTAL_ALIGNMENT_CENTER)
	_action_lbl.name = "ActivityActionText"
	_action_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_action_lbl)
	_prev_btn = Ui.make_hit_button(Defs.ACTIVITY_P2_PREV, "")
	_prev_btn.pressed.connect(_on_prev_pressed)
	panel.add_child(_prev_btn)
	_next_btn = Ui.make_hit_button(Defs.ACTIVITY_P3_NEXT, "")
	_next_btn.pressed.connect(_on_next_pressed)
	panel.add_child(_next_btn)
	_tab_btns.clear()
	var tab_rects := [Defs.ACTIVITY_P4_TAB_SHOW, Defs.ACTIVITY_P5_TAB_DAILY, Defs.ACTIVITY_P6_TAB_SPECIAL]
	for i in range(3):
		var tab_btn := Ui.make_hit_button(tab_rects[i], "")
		var tab_idx := i
		tab_btn.pressed.connect(func() -> void: _set_tab(tab_idx))
		panel.add_child(tab_btn)
		_tab_btns.append(tab_btn)


func open() -> void:
	_tab_index = Defs.TAB_SHOW
	_item_index = 0
	refresh()
	panel.visible = true


func refresh() -> void:
	if panel == null:
		return
	if bool(_is_opening_flow.call()):
		_tab_index = Defs.TAB_DAILY
	var list: Array = ActivityBind.activities_for_tab(
		_activity,
		_tab_index,
		bool(_is_opening_flow.call())
	)
	var has_items := not list.is_empty()
	if has_items:
		_item_index = clampi(_item_index, 0, list.size() - 1)
		ActivityBind.bind_display(
			_desc,
			_cost,
			_own,
			_action_lbl,
			_action_btn,
			list[_item_index] as Dictionary,
			_inventory,
			int(_get_fp.call()),
			str(_get_activity_state.call(str((list[_item_index] as Dictionary).get("activityid", ""))))
		)
	else:
		ActivityBind.bind_empty_tab(_desc, _cost, _own, _action_lbl, _tab_index)
	_prev_btn.disabled = not has_items or list.size() <= 1
	_next_btn.disabled = not has_items or list.size() <= 1
	if _action_btn != null and has_items:
		var act: Dictionary = list[_item_index] as Dictionary
		var aid: String = str(act.get("activityid", ""))
		var blocked := str(_get_activity_state.call(aid)) == ActivityManager.STATE_DEPARTED
		if bool(_is_opening_flow.call()) and aid != "1":
			blocked = true
		_action_btn.disabled = blocked
	elif _action_btn != null:
		_action_btn.disabled = true
	for i in range(_tab_btns.size()):
		if _tab_btns[i] != null:
			_tab_btns[i].disabled = bool(_is_opening_flow.call()) and i != Defs.TAB_DAILY


func _current_tab_activities() -> Array:
	return ActivityBind.activities_for_tab(_activity, _tab_index, bool(_is_opening_flow.call()))


func _current_activity() -> Dictionary:
	var list: Array = _current_tab_activities()
	if list.is_empty():
		return {}
	return list[clampi(_item_index, 0, list.size() - 1)] as Dictionary


func _set_tab(tab: int) -> void:
	_tab_index = tab
	_item_index = 0
	refresh()


func _on_prev_pressed() -> void:
	var list: Array = _current_tab_activities()
	if list.size() <= 1:
		return
	_item_index = (_item_index - 1 + list.size()) % list.size()
	refresh()


func _on_next_pressed() -> void:
	var list: Array = _current_tab_activities()
	if list.size() <= 1:
		return
	_item_index = (_item_index + 1) % list.size()
	refresh()


func _on_action_pressed() -> void:
	_Actions.on_action_pressed(self, _activity, _sign, _get_activity_state)
