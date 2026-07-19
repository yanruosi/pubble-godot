extends RefCounted
class_name SignPanelView

const Defs := preload("res://scripts/views/home_overlay_defs.gd")
const Ui := preload("res://scripts/views/home_overlay_ui.gd")
const Settle := preload("res://scripts/views/home_overlay_settle.gd")
const Build := preload("res://scripts/views/sign_panel_build.gd")

var win_overlay: Control
var settle_overlay: Control
var toast: Label

var _activity: ActivityManager
var _expose: ExposeManager
var _activity_panel: Control
var _layer: CanvasLayer
var _refresh_activity: Callable
var _is_opening_flow: Callable
var _get_router: Callable

var _settle_event: Label
var _settle_rewards: Label
var _settle_close_btn: Button
var _settle_go_btn: Button
var _last_settle_reveal_tab: String = "fandom"
var _opening_settle_pending: bool = false


func bind_services(
	activity: ActivityManager,
	expose: ExposeManager,
	is_opening_flow: Callable,
	get_router: Callable,
	refresh_activity: Callable
) -> void:
	_activity = activity
	_expose = expose
	_is_opening_flow = is_opening_flow
	_get_router = get_router
	_refresh_activity = refresh_activity


func build(layer: CanvasLayer, activity_panel: Control) -> void:
	_layer = layer
	_activity_panel = activity_panel
	win_overlay = Build.build_win_overlay(_activity_panel, _on_win_overlay_input)
	var settle_parts: Dictionary = Build.build_settle_overlay(_layer, _close_settle, _on_settle_go_pubble_pressed)
	settle_overlay = settle_parts.get("overlay") as Control
	_settle_event = settle_parts.get("event") as Label
	_settle_rewards = settle_parts.get("rewards") as Label
	_settle_go_btn = settle_parts.get("go_btn") as Button
	toast = Ui.make_activity_toast(_layer)


func do_draw(activity_id: String, act: Dictionary) -> void:
	var force_first_win := bool(_is_opening_flow.call()) and int(act.get("winratefirst", 0)) >= 1
	var result: Dictionary = _activity.draw_lottery(activity_id)
	if not bool(result.get("ok", false)):
		show_toast(str(result.get("reason", "抽选失败")))
		_refresh_activity.call()
		return
	if force_first_win and not bool(result.get("won", false)):
		if _save_manager_set_won(activity_id):
			result["won"] = true
	if bool(result.get("won", false)):
		win_overlay.visible = true
	else:
		show_toast("未中签")
	_refresh_activity.call()


func do_depart(activity_id: String) -> void:
	var result: Dictionary = _activity.depart(activity_id)
	if not bool(result.get("ok", false)):
		show_toast(str(result.get("reason", "出发失败")))
		_refresh_activity.call()
		return
	show_settle(result)
	_refresh_activity.call()


func show_settle(result: Dictionary) -> void:
	var act: Dictionary = result.get("activity", {}) as Dictionary
	_opening_settle_pending = bool(_is_opening_flow.call())
	_last_settle_reveal_tab = "account" if _opening_settle_pending else str(result.get("reveal_tab", "fandom"))
	if _settle_event != null:
		_settle_event.text = str(result.get("event_text", ""))
	if _settle_rewards != null:
		_settle_rewards.text = Settle.format_reward_text(result, act, _expose)
	if _settle_go_btn != null:
		_settle_go_btn.text = "前往发帖" if _opening_settle_pending else "前往pubble查看"
	if _activity_panel != null:
		_activity_panel.visible = false
	if settle_overlay != null:
		settle_overlay.visible = true


func show_toast(msg: String) -> void:
	if toast == null:
		push_warning(msg)
		return
	toast.text = msg
	toast.visible = true
	var timer := _layer.get_tree().create_timer(1.8)
	timer.timeout.connect(func() -> void:
		if toast != null:
			toast.visible = false
	)


func _save_manager_set_won(activity_id: String) -> bool:
	var sm: SaveManager = _layer.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return false
	sm.set_activity_state(activity_id, ActivityManager.STATE_WON)
	return true


func _close_settle() -> void:
	if settle_overlay != null:
		settle_overlay.visible = false
	if _activity_panel != null:
		_activity_panel.visible = false


func _on_settle_go_pubble_pressed() -> void:
	_close_settle()
	var router: Node = _get_router.call() as Node
	if router == null:
		return
	if _opening_settle_pending:
		_opening_settle_pending = false
		if router.has_method("set_pending_first_post"):
			router.call("set_pending_first_post", true)
		if router.has_method("open_feed_account_tab"):
			router.call("open_feed_account_tab")
		elif router.has_method("open_feed_tab"):
			router.call("open_feed_tab", "account")
		return
	if router.has_method("open_feed_tab"):
		router.call("open_feed_tab", _last_settle_reveal_tab)


func _on_win_overlay_input(event: InputEvent) -> void:
	if not win_overlay.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			win_overlay.visible = false
			_refresh_activity.call()
			win_overlay.accept_event()
