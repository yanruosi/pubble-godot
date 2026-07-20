extends RefCounted
class_name FeedTabBarView

const FeedDefs := preload("res://scripts/views/feed_defs.gd")

signal tab_selected(tab_id: String)

var root: PanelContainer
var _buttons: Dictionary = {}


func build(parent: Control) -> void:
	root = PanelContainer.new()
	root.position = FeedDefs.P1_NAV_RECT.position
	root.custom_minimum_size = FeedDefs.P1_NAV_RECT.size
	root.size = FeedDefs.P1_NAV_RECT.size
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.35)
	root.add_theme_stylebox_override("panel", ps)
	parent.add_child(root)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	root.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var title := Label.new()
	title.text = "pubble"
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)
	_buttons.clear()
	for pair in [
		[FeedDefs.TAB_ARTIST, "艺人动态"],
		[FeedDefs.TAB_FANDOM, "饭圈动态"],
		[FeedDefs.TAB_ACCOUNT, "我的站子"],
		[FeedDefs.TAB_SISTER, "嫂嫂别藏了"],
		[FeedDefs.TAB_FAVORITES, "我的收藏"],
		[FeedDefs.TAB_MARKET, "周边中转站"],
	]:
		var btn := Button.new()
		btn.flat = true
		btn.text = pair[1]
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tab_id: String = pair[0]
		btn.pressed.connect(func() -> void: tab_selected.emit(tab_id))
		col.add_child(btn)
		_buttons[tab_id] = btn


func apply_visual(active_tab: String, opening_lock: bool) -> void:
	var active_color := Color(0.17, 0.14, 0.24, 1)
	var inactive_color := Color(0.55, 0.51, 0.64, 1)
	var locked_color := Color(0.78, 0.76, 0.82, 0.55)
	var active_bg := StyleBoxFlat.new()
	active_bg.bg_color = Color(0.82, 0.72, 0.96, 0.55)
	active_bg.corner_radius_top_left = 8
	active_bg.corner_radius_top_right = 8
	active_bg.corner_radius_bottom_left = 8
	active_bg.corner_radius_bottom_right = 8
	var empty_bg := StyleBoxEmpty.new()
	for tab_id: String in _buttons.keys():
		var btn: Button = _buttons[tab_id]
		var on: bool = active_tab == tab_id
		btn.add_theme_font_size_override("font_size", 18 if on else 16)
		if opening_lock and tab_id != FeedDefs.TAB_ACCOUNT:
			btn.disabled = true
			btn.add_theme_color_override("font_color", locked_color)
			btn.add_theme_stylebox_override("normal", empty_bg)
			btn.add_theme_stylebox_override("hover", empty_bg)
			btn.add_theme_stylebox_override("pressed", empty_bg)
		else:
			btn.disabled = false
			btn.add_theme_color_override("font_color", active_color if on else inactive_color)
			btn.add_theme_stylebox_override("normal", active_bg if on else empty_bg)
			btn.add_theme_stylebox_override("hover", active_bg if on else empty_bg)
			btn.add_theme_stylebox_override("pressed", active_bg if on else empty_bg)
