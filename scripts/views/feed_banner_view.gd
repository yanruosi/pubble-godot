extends RefCounted
class_name FeedBannerView

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const FeedBannerText := preload("res://scripts/views/feed_banner_text.gd")
const FeedBannerAnim := preload("res://scripts/views/feed_banner_anim.gd")
const FeedBannerBuild := preload("res://scripts/views/feed_banner_build.gd")

signal market_bag_pressed

var area: Control
var _anim_root: Control
var _bg: TextureRect
var _status: Label
var _subline: Label
var _key: Label
var _reward_fans: Label
var _reward_fp: Label
var _bar: ProgressBar
var _heat_label: Label
var _flash: Label
var _active_tab: String = FeedDefs.TAB_ARTIST
var _banner_rect: Rect2 = FeedDefs.P1_BANNER_RECT
var _current_state: String = ""
var _last_reward_fp: int = -1
var _last_reward_fans: int = -1
var _layout_split: bool = false
var _account_idle_banner: bool = false


func build(parent: Control) -> void:
	area = Control.new()
	area.name = "BannerArea"
	area.position = FeedDefs.P1_BANNER_RECT.position
	area.custom_minimum_size = FeedDefs.P1_BANNER_RECT.size
	area.size = FeedDefs.P1_BANNER_RECT.size
	parent.add_child(area)
	_anim_root = Control.new()
	_anim_root.name = "BannerAnimRoot"
	_anim_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_anim_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_anim_root)
	_bg = TextureRect.new()
	_bg.name = "BannerBg"
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_bg)
	area.move_child(_bg, 0)
	_key = FeedBannerText.make_label(FeedDefs.BANNER_KEY_LOCAL, 18, HORIZONTAL_ALIGNMENT_CENTER, _banner_rect, VERTICAL_ALIGNMENT_CENTER)
	_key.name = "BannerKeypost"
	_anim_root.add_child(_key)
	_reward_fans = FeedBannerText.make_label(FeedDefs.BANNER_FANS_LOCAL, 11, HORIZONTAL_ALIGNMENT_LEFT, _banner_rect)
	_reward_fans.name = "BannerRewardFans"
	_anim_root.add_child(_reward_fans)
	_reward_fp = FeedBannerText.make_label(FeedDefs.BANNER_FP_LOCAL, 11, HORIZONTAL_ALIGNMENT_LEFT, _banner_rect)
	_reward_fp.name = "BannerRewardFp"
	_anim_root.add_child(_reward_fp)
	_subline = FeedBannerText.make_label(FeedDefs.BANNER_SUBLINE_LOCAL, 11, HORIZONTAL_ALIGNMENT_CENTER, _banner_rect)
	_subline.name = "BannerSubline"
	_anim_root.add_child(_subline)
	_status = FeedBannerText.make_label(FeedDefs.BANNER_STATUS_LOCAL, 11, HORIZONTAL_ALIGNMENT_CENTER, _banner_rect)
	_status.name = "BannerStatusText"
	_anim_root.add_child(_status)
	_heat_label = FeedBannerText.make_label(FeedDefs.BANNER_HEAT_LABEL_LOCAL, 11, HORIZONTAL_ALIGNMENT_LEFT, _banner_rect)
	_heat_label.name = "BannerHeatLabel"
	_heat_label.text = "热度"
	_heat_label.visible = false
	_anim_root.add_child(_heat_label)
	var bar_rect := FeedBannerText.local_rect_scaled(FeedDefs.BANNER_BAR_LOCAL, _banner_rect)
	_bar = ProgressBar.new()
	_bar.name = "BannerHeatBar"
	_bar.position = bar_rect.position
	_bar.custom_minimum_size = bar_rect.size
	_bar.size = bar_rect.size
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.visible = false
	FeedBannerBuild.apply_bar_styles(_bar)
	_anim_root.add_child(_bar)
	_flash = Label.new()
	_flash.text = "线索等级提升！"
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash.add_theme_font_size_override("font_size", 18)
	_flash.add_theme_color_override("font_color", Color(0.55, 0.25, 0.85, 1))
	_flash.visible = false
	_anim_root.add_child(_flash)
	_set_bg_texture()


func relayout(active_tab: String, banner_rect: Rect2) -> void:
	_active_tab = active_tab
	_banner_rect = banner_rect
	if area == null:
		return
	area.position = banner_rect.position
	area.size = banner_rect.size
	area.custom_minimum_size = banner_rect.size
	_apply_widget_layout()


func _uses_split_layout(mode: String) -> bool:
	return mode in ["exposing", "hot_success", "hot_fail"]


func _apply_widget_layout() -> void:
	var status_rect := FeedDefs.BANNER_STATUS_LOCAL if _layout_split else _status_local()
	var subline_rect := FeedDefs.BANNER_SUBLINE_LOCAL if _layout_split else _subline_local()
	for entry in [
		[_heat_label, FeedDefs.BANNER_HEAT_LABEL_LOCAL],
		[_bar, FeedDefs.BANNER_BAR_LOCAL],
		[_subline, subline_rect],
		[_reward_fans, FeedDefs.BANNER_FANS_LOCAL],
		[_reward_fp, FeedDefs.BANNER_FP_LOCAL],
		[_key, _key_local()],
		[_status, status_rect],
	]:
		var ctrl: Control = entry[0]
		var local: Rect2 = entry[1]
		if ctrl == null:
			continue
		var rect := FeedBannerText.local_rect_scaled(local, _banner_rect)
		ctrl.position = rect.position
		ctrl.custom_minimum_size = rect.size
		ctrl.size = rect.size
		if ctrl is Label:
			var lbl := ctrl as Label
			if _layout_split and ctrl in [_reward_fans, _reward_fp, _heat_label, _status, _subline]:
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			elif ctrl == _key:
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			else:
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _status_local() -> Rect2:
	if _active_tab in [FeedDefs.TAB_SISTER, FeedDefs.TAB_FAVORITES]:
		return FeedDefs.BANNER_STATIC_MAIN_LOCAL
	return FeedDefs.BANNER_CENTER_FULL


func _subline_local() -> Rect2:
	if _active_tab in [FeedDefs.TAB_SISTER, FeedDefs.TAB_FAVORITES]:
		return FeedDefs.BANNER_STATIC_SUB_LOCAL
	return FeedDefs.BANNER_CENTER_FULL


func _key_local() -> Rect2:
	return FeedDefs.BANNER_KEY_LOCAL


func _set_layout_split(mode: String) -> void:
	var split := _uses_split_layout(mode)
	if split == _layout_split:
		return
	_layout_split = split
	_apply_widget_layout()


func refresh_tab(active_tab: String, on_intel_pending: Callable) -> void:
	_active_tab = active_tab
	if area == null:
		return
	for c in area.get_children():
		if c.name in ["ArtistPlaceholder", "MarketBagBtn"]:
			c.queue_free()
	FeedBannerText.hide_overlays(_status, _subline, _key, _bar, _flash, _reward_fans, _reward_fp, _heat_label)
	_current_state = ""
	_last_reward_fp = -1
	_last_reward_fans = -1
	_layout_split = false
	_account_idle_banner = active_tab == FeedDefs.TAB_ACCOUNT
	_apply_widget_layout()
	var show_area := active_tab in [FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ARTIST, FeedDefs.TAB_ACCOUNT, FeedDefs.TAB_MARKET, FeedDefs.TAB_FAVORITES]
	area.visible = show_area
	if not show_area:
		return
	match active_tab:
		FeedDefs.TAB_ARTIST:
			_set_bg_texture()
		FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ACCOUNT, FeedDefs.TAB_FAVORITES:
			_set_bg_texture()
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
	if _active_tab == FeedDefs.TAB_ACCOUNT and str(snap.get("banner_state", "")) != "exposing":
		_apply_account_idle_banner()
		return
	if not _uses_dynamic_states():
		_apply_keypost_only(snap)
		return
	if _active_tab == FeedDefs.TAB_ACCOUNT:
		_account_idle_banner = false
		_set_bg_texture()
	var mode: String = str(snap.get("banner_state", "default_static"))
	if mode != _current_state:
		play_state_anim(mode, snap)
	else:
		_apply_state_widgets(mode, snap)


func play_state_anim(state: String, snap: Dictionary) -> void:
	_current_state = state
	_account_idle_banner = _active_tab == FeedDefs.TAB_ACCOUNT and state != "exposing"
	_set_bg_texture()
	var widgets: Array = _widgets_for_state(state)
	FeedBannerAnim.play_enter(_anim_root, widgets)
	_apply_state_widgets(state, snap)


func _widgets_for_state(state: String) -> Array:
	if state == "default_static":
		if _active_tab in [FeedDefs.TAB_SISTER, FeedDefs.TAB_FAVORITES, FeedDefs.TAB_FANDOM, FeedDefs.TAB_ACCOUNT]:
			return [_key]
		return []
	if state == "exposing":
		return [_status, _subline, _reward_fans, _reward_fp, _heat_label, _bar]
	return [_status, _subline, _reward_fans, _reward_fp]


func shows_dynamic_overlay(active_tab: String) -> bool:
	return active_tab in [FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_ACCOUNT]


func play_intel_flash() -> void:
	if _flash == null or _anim_root == null:
		return
	_flash.visible = true
	_flash.modulate.a = 1.0
	var tw := _anim_root.create_tween()
	tw.tween_property(_flash, "modulate:a", 0.2, 0.35)
	tw.tween_property(_flash, "modulate:a", 1.0, 0.35)
	tw.tween_property(_flash, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if _flash != null:
			_flash.visible = false
	)


func _uses_dynamic_states() -> bool:
	return _active_tab in [FeedDefs.TAB_FANDOM, FeedDefs.TAB_ACCOUNT]


func _apply_account_idle_banner() -> void:
	_current_state = "default_static"
	_account_idle_banner = true
	_set_layout_split("default_static")
	_set_bg_texture()
	FeedBannerText.hide_overlays(_status, _subline, _key, _bar, _flash, _reward_fans, _reward_fp, _heat_label)


func _apply_keypost_only(snap: Dictionary) -> void:
	_set_layout_split("default_static")
	var show_static := _active_tab in [FeedDefs.TAB_SISTER, FeedDefs.TAB_FAVORITES]
	if _key != null:
		_key.visible = true
		_key.text = FeedBannerText.keypost_text(snap)
		_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _status != null:
		if show_static:
			_status.visible = true
			_status.text = FeedBannerText.static_banner_status(snap)
			_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			_status.visible = false
			_status.text = ""
	if _subline != null:
		if show_static:
			var sub := FeedBannerText.static_banner_subline(snap)
			_subline.visible = not sub.is_empty()
			_subline.text = sub
			_subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			_subline.visible = false
			_subline.text = ""
	if _bar != null:
		_bar.visible = false
	if _heat_label != null:
		_heat_label.visible = false


func _apply_reward_labels(mode: String, snap: Dictionary) -> void:
	var show := mode in ["exposing", "hot_success", "hot_fail"]
	if _reward_fans != null:
		var fans_txt := FeedBannerText.reward_fans_text(mode, snap) if show else ""
		_reward_fans.visible = not fans_txt.is_empty()
		_reward_fans.text = fans_txt
		_ensure_opaque(_reward_fans)
	if _reward_fp != null:
		var fp_txt := FeedBannerText.reward_fp_text(mode, snap) if show else ""
		_reward_fp.visible = not fp_txt.is_empty()
		_reward_fp.text = fp_txt
		_ensure_opaque(_reward_fp)


func _apply_state_widgets(mode: String, snap: Dictionary) -> void:
	_set_layout_split(mode)
	var is_static_tab := _active_tab in [FeedDefs.TAB_SISTER, FeedDefs.TAB_FAVORITES]
	if _key != null:
		if mode == "default_static" or is_static_tab:
			_key.visible = true
			_key.text = FeedBannerText.keypost_text(snap)
			_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		else:
			_key.visible = false
			_key.text = ""
		_ensure_opaque(_key)
	var is_dynamic := mode != "default_static"
	if _status != null:
		_status.visible = is_dynamic
		_status.text = FeedBannerText.status_text(mode, snap) if is_dynamic else ""
		if _status.visible:
			_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _layout_split else HORIZONTAL_ALIGNMENT_CENTER
		_ensure_opaque(_status)
	if _subline != null:
		var sub := FeedBannerText.subline_text(mode, snap) if is_dynamic else ""
		_subline.visible = not sub.is_empty()
		_subline.text = sub
		if _subline.visible:
			_subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if _layout_split else HORIZONTAL_ALIGNMENT_CENTER
		_ensure_opaque(_subline)
	var show_bar := mode == "exposing"
	if _heat_label != null:
		_heat_label.visible = show_bar
		if show_bar:
			_ensure_opaque(_heat_label)
	if _bar != null:
		_bar.visible = show_bar
		if show_bar:
			_bar.value = FeedBannerText.heat_bar_ratio(snap)
			_ensure_opaque(_bar)
	if mode == "hot_success":
		_maybe_pulse_idle(snap)
	_apply_reward_labels(mode, snap)


func _ensure_opaque(node: CanvasItem) -> void:
	if node != null and node.visible:
		node.modulate = Color(1, 1, 1, 1)


func _maybe_pulse_idle(snap: Dictionary) -> void:
	var fp: int = int(snap.get("idle_fp_earned", 0))
	var fans: int = int(snap.get("idle_fans_earned", 0))
	if fp == _last_reward_fp and fans == _last_reward_fans:
		return
	_last_reward_fp = fp
	_last_reward_fans = fans
	_apply_reward_labels("hot_success", snap)
	FeedBannerAnim.pulse_reward(_reward_fans, _reward_fp, _anim_root)


func _set_bg_texture() -> void:
	if _bg == null:
		return
	var tex := FeedDefs.load_tex(FeedBannerBuild.banner_bg_path(_active_tab, _account_idle_banner))
	_bg.texture = tex
