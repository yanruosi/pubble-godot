extends CanvasLayer
class_name HomeOverlays

const Defs := preload("res://scripts/views/home_overlay_defs.gd")
const ActivityPanelView := preload("res://scripts/views/activity_panel_view.gd")
const ShopPanelView := preload("res://scripts/views/shop_panel_view.gd")
const SignPanelView := preload("res://scripts/views/sign_panel_view.gd")

var _activity_view
var _shop_view
var _sign_view

var _economy: EconomyManager
var _shop: ShopManager
var _activity: ActivityManager
var _expose: ExposeManager
var _inventory: InventoryManager


func setup(home_page: Control) -> void:
	layer = 320
	_economy = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_shop = get_node_or_null("/root/ShopManagerSingleton") as ShopManager
	_activity = get_node_or_null("/root/ActivityManagerSingleton") as ActivityManager
	_expose = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	_inventory = get_node_or_null("/root/InventoryManagerSingleton") as InventoryManager
	_activity_view = ActivityPanelView.new()
	_shop_view = ShopPanelView.new()
	_sign_view = SignPanelView.new()
	_activity_view.bind_services(
		_activity,
		_inventory,
		_sign_view,
		Callable(self, "_is_opening_flow"),
		Callable(self, "_get_fp"),
		Callable(self, "_get_activity_state")
	)
	_shop_view.bind_services(_economy, _shop)
	_sign_view.bind_services(
		_activity,
		_expose,
		Callable(self, "_is_opening_flow"),
		Callable(self, "_get_router"),
		Callable(_activity_view, "refresh")
	)
	_activity_view.build(self)
	_sign_view.build(self, _activity_view.panel)
	_shop_view.build(self)
	_add_home_buttons(home_page)


func on_home_entered() -> void:
	if _is_opening_flow():
		call_deferred("_open_activity_panel")


func _open_activity_panel() -> void:
	_activity_view.open()


func _open_shop_panel() -> void:
	_shop_view.open()


func _is_opening_flow() -> bool:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return false
	if sm.get("opening_done") == null:
		return false
	return not bool(sm.opening_done)


func _get_fp() -> int:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	return sm.fp if sm != null else -1


func _get_activity_state(activityid: String) -> String:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return ""
	return sm.get_activity_state(activityid)


func _get_router() -> Node:
	return get_parent()


func _add_home_buttons(home_page: Control) -> void:
	if home_page == null:
		return
	var btn_act := _make_home_hit_button(Defs.HOME_BTN_ACTIVITY_POS, Defs.HOME_BTN_ACTIVITY_SIZE, home_page)
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
