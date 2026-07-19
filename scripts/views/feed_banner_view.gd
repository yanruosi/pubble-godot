extends RefCounted
class_name FeedBannerView

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const FeedBannerText := preload("res://scripts/views/feed_banner_text.gd")

signal market_bag_pressed

var area: Control
var _bg: TextureRect
var _status: Label
var _rate: Label
var _lv: Label
var _key: Label
var _bar: ProgressBar
var _flash: Label
var _active_tab: String = FeedDefs.TAB_ARTIST
var _banner_rect: Rect2 = FeedDefs.P1_BANNER_RECT


func build(parent: Control) -> void:
	area = Control.new()
	area.name = "BannerArea"
	area.position = FeedDefs.P1_BANNER_RECT.position
	area.custom_minimum_size = FeedDefs.P1_BANNER_RECT.size
	area.size = FeedDefs.P1_BANNER_RECT.size
	parent.add_child(area)
	_bg = TextureRect.new()
	_bg.name = "BannerBg"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_bg)
	_lv = FeedBannerText.make_label(FeedDefs.BANNER_LV_LOCAL, 13, HORIZONTAL_ALIGNMENT_CENTER, _banner_rect)
	_lv.name = "BannerP3Lv"
	area.add_child(_lv)
	_key = FeedBannerText.make_label(FeedDefs.BANNER_KEY_LOCAL, 18, HORIZONTAL_ALIGNMENT_CENTER, _banner_rect)
	_key.name = "BannerP4Key"
	area.add_child(_key)
	_rate = FeedBannerText.make_label(FeedDefs.BANNER_RATE_LOCAL, 16, HORIZONTAL_ALIGNMENT_LEFT, _banner_rect)
	_rate.name = "BannerP2Rate"
	area.add_child(_rate)
	_status = FeedBannerText.make_label(FeedDefs.BANNER_STATUS_LOCAL, 11, HORIZONTAL_ALIGNMENT_LEFT, _banner_rect)
	_status.name = "BannerStatusText"
	area.add_child(_status)
	var bar_rect := FeedBannerText.local_rect_scaled(FeedDefs.BANNER_BAR_LOCAL, _banner_rect)
	_bar = ProgressBar.new()
	_bar.name = "BannerP1Bar"
	_bar.position = bar_rect.position
	_bar.custom_minimum_size = bar_rect.size
	_bar.size = bar_rect.size
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.visible = false
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.55, 0.28, 0.82, 0.55)
	bar_style.corner_radius_top_left = 8
	bar_style.corner_radius_top_right = 8
	bar_style.corner_radius_bottom_left = 8
	bar_style.corner_radius_bottom_right = 8
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.45, 0.18, 0.72, 0.85)
	fill_style.corner_radius_top_left = 8
	fill_style.corner_radius_top_right = 8
	fill_style.corner_radius_bottom_left = 8
	fill_style.corner_radius_bottom_right = 8
	_bar.add_theme_stylebox_override("background", bar_style)
	_bar.add_theme_stylebox_override("fill", fill_style)
	area.add_child(_bar)
	_flash = Label.new()
	_flash.text = "情报等级提升！"
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash.add_theme_font_size_override("font_size", 18)
	_flash.add_theme_color_override("font_color", Color(0.55, 0.25, 0.85, 1))
	_flash.visible = false
	area.add_child(_flash)
	_set_bg_texture()


func relayout(active_tab: String, banner_rect: Rect2) -> void:
	_active_tab = active_tab
	_banner_rect = banner_rect
	if area == null:
		return
	area.position = banner_rect.position
	area.size = banner_rect.size
	area.custom_minimum_size = banner_rect.size
	for entry in [[_bar, FeedDefs.BANNER_BAR_LOCAL], [_rate, FeedDefs.BANNER_RATE_LOCAL], [_lv, FeedDefs.BANNER_LV_LOCAL], [_key, FeedDefs.BANNER_KEY_LOCAL], [_status, FeedDefs.BANNER_STATUS_LOCAL]]:
		var ctrl: Control = entry[0]
		var local: Rect2 = entry[1]
		if ctrl == null:
			continue
		var rect := FeedBannerText.local_rect_scaled(local, _banner_rect)
		ctrl.position = rect.position
		ctrl.custom_minimum_size = rect.size
		ctrl.size = rect.size
		if ctrl is Label:
			(ctrl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if local in [FeedDefs.BANNER_LV_LOCAL, FeedDefs.BANNER_KEY_LOCAL] else HORIZONTAL_ALIGNMENT_LEFT


func refresh_tab(active_tab: String, on_intel_pending: Callable) -> void:
	_active_tab = active_tab
	if area == null:
		return
	for c in area.get_children():
		if c.name in ["ArtistPlaceholder", "MarketBagBtn"]:
			c.queue_free()
	FeedBannerText.hide_overlays(_status, _rate, _lv, _key, _bar, _flash)
	var show_area := active_tab in [FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ARTIST, FeedDefs.TAB_ACCOUNT, FeedDefs.TAB_MARKET]
	area.visible = show_area
	if not show_area:
		return
	match active_tab:
		FeedDefs.TAB_ARTIST:
			_set_bg_texture()
		FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ACCOUNT:
			_set_bg_texture()
			_lv.visible = true
			_key.visible = true
			if active_tab == FeedDefs.TAB_FANDOM and on_intel_pending.is_valid() and on_intel_pending.call():
				play_intel_flash()
		FeedDefs.TAB_MARKET:
			var bag_btn := Button.new()
			bag_btn.name = "MarketBagBtn"
			bag_btn.text = "背包"
			bag_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			bag_btn.pressed.connect(func() -> void: market_bag_pressed.emit())
			area.add_child(bag_btn)


func apply_snapshot(snap: Dictionary) -> void:
	if _lv != null:
		_lv.text = "Lv.%d" % int(snap.get("intellevel", 0))
	if _key != null:
		var target: int = int(snap.get("keypost_target", 0))
		var current: int = int(snap.get("keypost_current", 0))
		_key.text = "%d/%d" % [current, target] if target > 0 else "MAX"
	var mode: String = str(snap.get("banner_state", "default_static"))
	var status_text: String = FeedBannerText.status_text(mode, snap)
	if _status != null:
		_status.visible = mode != "default_static" or not status_text.is_empty()
		_status.text = status_text
	var show_bar := mode == "exposing"
	var bar_ratio := 0.0
	if mode == "exposing":
		var remain: float = float(snap.get("remaining_sec", -1.0))
		if remain >= 0.0:
			bar_ratio = clampf(1.0 - remain / 150.0, 0.0, 1.0)
	if _bar != null:
		_bar.visible = show_bar
		if _bar.visible:
			_bar.value = bar_ratio
	if _rate != null:
		_rate.visible = false
		_rate.text = ""


func shows_dynamic_overlay(active_tab: String) -> bool:
	return active_tab in [FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ACCOUNT]


func play_intel_flash() -> void:
	if _flash == null or area == null:
		return
	_flash.visible = true
	_flash.modulate.a = 1.0
	var tw := area.create_tween()
	tw.tween_property(_flash, "modulate:a", 0.2, 0.35)
	tw.tween_property(_flash, "modulate:a", 1.0, 0.35)
	tw.tween_property(_flash, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if _flash != null:
			_flash.visible = false
	)


func _set_bg_texture() -> void:
	if _bg == null:
		return
	var path := FeedDefs.PATH_BANNER_SISTER if _active_tab == FeedDefs.TAB_ARTIST else FeedDefs.PATH_BANNER
	_bg.texture = FeedDefs.load_tex(path)
