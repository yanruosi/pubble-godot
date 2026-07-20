extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const CurrencyBarView := preload("res://scripts/views/currency_bar_view.gd")
const _Hotsearch = preload("res://scripts/controllers/feed_ui_hotsearch.gd")

var _ctrl: FeedController


func _init(ctrl: FeedController) -> void:
	_ctrl = ctrl


func build_ui() -> void:
	for c in _ctrl._page.get_children():
		c.queue_free()
	_ctrl._content_root = Control.new()
	_ctrl._content_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctrl._page.add_child(_ctrl._content_root)
	var bg_tex := FeedDefs.load_tex(FeedDefs.PATH_POSTBG)
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.name = "PostBg"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ctrl._content_root.add_child(bg)
	else:
		var bg_fallback := ColorRect.new()
		bg_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_fallback.color = Color(0.95, 0.95, 0.97, 1)
		bg_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ctrl._content_root.add_child(bg_fallback)
	var back_tex := FeedDefs.load_tex(FeedDefs.PATH_BACK)
	if back_tex != null:
		var back_btn := TextureButton.new()
		back_btn.name = "BtnBack"
		back_btn.position = Vector2(12, 12)
		back_btn.texture_normal = back_tex
		back_btn.ignore_texture_size = true
		back_btn.custom_minimum_size = FeedDefs.BACK_BTN_SIZE
		back_btn.size = FeedDefs.BACK_BTN_SIZE
		back_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		back_btn.focus_mode = Control.FOCUS_NONE
		back_btn.pressed.connect(func() -> void: _ctrl._page.feed_back_requested.emit())
		_ctrl._content_root.add_child(back_btn)
	build_hud()
	_Hotsearch.build(_ctrl)
	build_bag_panel()
	_ctrl._banner.build(_ctrl._content_root)
	_ctrl._list.build(_ctrl._content_root, get_active_list_rect())
	_ctrl._composer.build(_ctrl._content_root)
	_ctrl._tab_bar.build(_ctrl._content_root)
	if _ctrl._tab_bar.root != null:
		_ctrl._tab_bar.root.z_index = 30
		_ctrl._tab_bar.root.mouse_filter = Control.MOUSE_FILTER_STOP
	_ctrl._toast_label = Label.new()
	_ctrl._toast_label.visible = false
	_ctrl._toast_label.z_index = 100
	_ctrl._toast_label.add_theme_font_size_override("font_size", 16)
	_ctrl._toast_label.add_theme_color_override("font_color", Color(0.2, 0.15, 0.35, 1))
	_ctrl._content_root.add_child(_ctrl._toast_label)


func build_hud() -> void:
	_ctrl._currency_bar = CurrencyBarView.new()
	_ctrl._currency_bar.build(_ctrl._content_root, CurrencyBarView.MODE_FEED)


func build_bag_panel() -> void:
	_ctrl._bag_panel = PanelContainer.new()
	_ctrl._bag_panel.name = "BagPanel"
	_ctrl._bag_panel.position = FeedDefs.P4_COMPOSE_RECT.position
	_ctrl._bag_panel.custom_minimum_size = FeedDefs.P4_COMPOSE_RECT.size
	_ctrl._bag_panel.size = FeedDefs.P4_COMPOSE_RECT.size
	_ctrl._bag_panel.visible = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.98, 0.96, 1, 0.97)
	ps.corner_radius_top_left = 6
	ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6
	ps.corner_radius_bottom_right = 6
	_ctrl._bag_panel.add_theme_stylebox_override("panel", ps)
	_ctrl._content_root.add_child(_ctrl._bag_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_ctrl._bag_panel.add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "背包"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(func() -> void:
		if _ctrl._bag_panel != null:
			_ctrl._bag_panel.visible = false
	)
	header.add_child(close_btn)
	root.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(FeedDefs.P4_COMPOSE_RECT.size.x - 16, FeedDefs.P4_COMPOSE_RECT.size.y - 40)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_ctrl._bag_grid = GridContainer.new()
	_ctrl._bag_grid.columns = 4
	_ctrl._bag_grid.add_theme_constant_override("h_separation", 6)
	_ctrl._bag_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_ctrl._bag_grid)


func get_active_banner_rect() -> Rect2:
	match _ctrl._active_tab:
		FeedDefs.TAB_ARTIST:
			return FeedDefs.P3_BANNER_RECT
		FeedDefs.TAB_ACCOUNT:
			return FeedDefs.P4_BANNER_RECT
		FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_FAVORITES:
			return FeedDefs.P1_BANNER_RECT
		_:
			return FeedDefs.P1_BANNER_RECT


func get_active_list_rect() -> Rect2:
	match _ctrl._active_tab:
		FeedDefs.TAB_ARTIST:
			return FeedDefs.P3_LIST_RECT
		FeedDefs.TAB_ACCOUNT:
			return FeedDefs.P5_LIST_RECT
		FeedDefs.TAB_FAVORITES:
			return FeedDefs.P2_LIST_RECT
		FeedDefs.TAB_FANDOM, FeedDefs.TAB_SISTER, FeedDefs.TAB_MARKET:
			return FeedDefs.P2_LIST_RECT
		_:
			return FeedDefs.P2_LIST_RECT


func update_layout_visibility() -> void:
	apply_tab_layout()
	if _ctrl._bag_panel != null and _ctrl._active_tab != FeedDefs.TAB_MARKET:
		_ctrl._bag_panel.visible = false
	if _ctrl._active_tab == FeedDefs.TAB_ACCOUNT:
		_ctrl.refresh_compose_area()


func apply_tab_layout() -> void:
	_ctrl._banner.relayout(_ctrl._active_tab, get_active_banner_rect())
	_ctrl._list.relayout(get_active_list_rect())
	_ctrl._composer.set_visible_for_tab(_ctrl._active_tab)
	if _ctrl._active_tab == FeedDefs.TAB_ACCOUNT and _ctrl._composer.root != null:
		_ctrl._composer.root.position = FeedDefs.P4_COMPOSE_RECT.position
		_ctrl._composer.root.size = FeedDefs.P4_COMPOSE_RECT.size
		_ctrl._composer.root.custom_minimum_size = FeedDefs.P4_COMPOSE_RECT.size
	if _ctrl._bag_panel != null and _ctrl._active_tab == FeedDefs.TAB_MARKET:
		_ctrl._bag_panel.position = FeedDefs.P4_COMPOSE_RECT.position
		_ctrl._bag_panel.size = FeedDefs.P4_COMPOSE_RECT.size
		_ctrl._bag_panel.custom_minimum_size = FeedDefs.P4_COMPOSE_RECT.size
