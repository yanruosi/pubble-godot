extends Control

signal feed_open_level(level: Dictionary)
signal feed_back_requested

const FEED_JSON_PATH := "res://data/feed_posts.json"
const CARD_SCENE := preload("res://scenes/feed_post_card.tscn")

const PATH_POSTBG := "res://art/mainui/postui/postbg.png"
const PATH_BACK := "res://art/mainui/postui/back.png"
const PATH_LOVE := "res://art/mainui/postui/love.png"

const TYPE_ARTIST := 901

const TAB_ARTIST := "artist"
const TAB_FANDOM := "fandom"
const TAB_ACCOUNT := "account"
const TAB_SISTER := "sister"
const TAB_MARKET := "market"

const TABTYPE_FANDOM := 0
const TABTYPE_SISTER := 903

const P1_RECT := Rect2(206, 48, 142, 672)
const P2_RECT := Rect2(356, 31, 401, 133)
const P3_RECT := Rect2(353, 187, 495, 77)
const P4_RECT := Rect2(358, 264, 488, 456)
const P5_RECT := Rect2(855, 49, 217, 671)
const BACK_BTN_SIZE := Vector2(36, 36)

var _active_tab: String = TAB_ARTIST
var _posts_raw: Array = []
var _tab_buttons: Dictionary = {}
var _list_box: VBoxContainer
var _scroll: ScrollContainer
var _content_root: Control
var _manual_dragging: bool = false
var _scroll_started: bool = false
var _love_effect_tex: Texture2D

var _post_area: Control
var _banner_area: Control
var _banner_bar: ProgressBar
var _banner_hint: Label
var _banner_intel_label: Label
var _banner_flash: Label
var _hot_list: VBoxContainer

var _fp_label: Label
var _stars_label: Label
var _intel_level_label: Label
var _toast_label: Label

func _ready() -> void:
	_load_json()
	_love_effect_tex = _load_tex(PATH_LOVE)
	call_deferred("_build_ui")
	call_deferred("_enter_initial_tab")


func _enter_initial_tab() -> void:
	set_active_tab(TAB_ARTIST)


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


func set_active_tab(tab: String) -> void:
	var normalized := _normalize_tab_name(tab)
	var old_exposure := _exposure_tabtype_for_name(_active_tab)
	var new_exposure := _exposure_tabtype_for_name(normalized)
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose != null and old_exposure >= 0:
		expose.on_tab_left(old_exposure)
	_active_tab = normalized
	_scroll_started = false
	if expose != null and new_exposure >= 0:
		expose.on_tab_entered(new_exposure)
	if is_inside_tree():
		_update_layout_visibility()
		_set_tab_visual()
		_refresh_banner_area()
		_update_currency_hud()
		refresh_feed()
	var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
	if tutor != null:
		tutor.notify_tab_opened(normalized)


func _normalize_tab_name(tab: String) -> String:
	var t := tab.to_lower()
	if t == "square":
		return TAB_FANDOM
	if t in [TAB_ARTIST, TAB_FANDOM, TAB_ACCOUNT, TAB_SISTER, TAB_MARKET]:
		return t
	return TAB_ARTIST


func _exposure_tabtype_for_name(tab: String) -> int:
	match tab:
		TAB_FANDOM:
			return TABTYPE_FANDOM
		TAB_SISTER:
			return TABTYPE_SISTER
		_:
			return -1


func get_active_tab() -> String:
	return _active_tab


func _load_json() -> void:
	_posts_raw.clear()
	if not FileAccess.file_exists(FEED_JSON_PATH):
		push_warning("feed_page: 未找到 %s" % FEED_JSON_PATH)
		return
	var t: String = FileAccess.get_file_as_string(FEED_JSON_PATH)
	if t.is_empty():
		return
	var p: Variant = JSON.parse_string(t)
	if p is Array:
		_posts_raw = p
	else:
		push_warning("feed_page: feed_posts.json 非数组")


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	_content_root = Control.new()
	_content_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content_root)

	var bg_tex := _load_tex(PATH_POSTBG)
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.name = "PostBg"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.texture = bg_tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_root.add_child(bg)
	else:
		var bg_fallback := ColorRect.new()
		bg_fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_fallback.color = Color(0.95, 0.95, 0.97, 1)
		bg_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_root.add_child(bg_fallback)

	var back_tex := _load_tex(PATH_BACK)
	if back_tex != null:
		var back_btn := TextureButton.new()
		back_btn.name = "BtnBack"
		back_btn.position = Vector2(12, 12)
		back_btn.texture_normal = back_tex
		back_btn.ignore_texture_size = true
		back_btn.custom_minimum_size = BACK_BTN_SIZE
		back_btn.size = BACK_BTN_SIZE
		back_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		back_btn.focus_mode = Control.FOCUS_NONE
		back_btn.pressed.connect(func() -> void: feed_back_requested.emit())
		_content_root.add_child(back_btn)

	_build_p6_hud()
	_build_p5_hotsearch()
	_build_p1_tabs()
	_build_p2_post_area()
	_build_p3_banner()
	_build_p4_list()

	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose != null:
		if not expose.banner_progress_changed.is_connected(_on_banner_progress):
			expose.banner_progress_changed.connect(_on_banner_progress)
		if not expose.lump_granted.is_connected(_on_lump_granted):
			expose.lump_granted.connect(_on_lump_granted)
		if not expose.intel_level_up.is_connected(_on_intel_level_up):
			expose.intel_level_up.connect(_on_intel_level_up)
		if not expose.instance_changed.is_connected(_on_instance_changed):
			expose.instance_changed.connect(_on_instance_changed)

	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.z_index = 100
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.add_theme_color_override("font_color", Color(0.2, 0.15, 0.35, 1))
	_content_root.add_child(_toast_label)

	_update_layout_visibility()
	_set_tab_visual()
	_refresh_banner_area()
	_update_currency_hud()


func _build_p1_tabs() -> void:
	var panel := PanelContainer.new()
	panel.position = P1_RECT.position
	panel.custom_minimum_size = P1_RECT.size
	panel.size = P1_RECT.size
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.35)
	panel.add_theme_stylebox_override("panel", ps)
	_content_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	var title := Label.new()
	title.text = "pubble"
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)

	var tabs: Array = [
		[TAB_ARTIST, "艺人动态"],
		[TAB_FANDOM, "饭圈动态"],
		[TAB_ACCOUNT, "我的账号"],
		[TAB_SISTER, "嫂子站"],
		[TAB_MARKET, "周边中转站"],
	]
	_tab_buttons.clear()
	for pair in tabs:
		var btn := Button.new()
		btn.flat = true
		btn.text = pair[1]
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tab_id: String = pair[0]
		btn.pressed.connect(func() -> void: set_active_tab(tab_id))
		col.add_child(btn)
		_tab_buttons[tab_id] = btn


func _build_p2_post_area() -> void:
	_post_area = PanelContainer.new()
	_post_area.name = "PostArea"
	_post_area.position = P2_RECT.position
	_post_area.custom_minimum_size = P2_RECT.size
	_post_area.size = P2_RECT.size
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.92)
	ps.corner_radius_top_left = 6
	ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6
	ps.corner_radius_bottom_right = 6
	_post_area.add_theme_stylebox_override("panel", ps)
	_content_root.add_child(_post_area)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	_post_area.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var input := LineEdit.new()
	input.placeholder_text = "点击输入..."
	input.editable = false
	root.add_child(input)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)

	for label_text in ["安利", "反黑", "情报", "其他"]:
		var b := Button.new()
		b.text = label_text
		b.disabled = true
		row.add_child(b)

	var send := Button.new()
	send.text = "发送"
	send.disabled = true
	send.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(send)


func _build_p3_banner() -> void:
	_banner_area = Control.new()
	_banner_area.name = "BannerArea"
	_banner_area.position = P3_RECT.position
	_banner_area.custom_minimum_size = P3_RECT.size
	_banner_area.size = P3_RECT.size
	_content_root.add_child(_banner_area)

	_banner_hint = Label.new()
	_banner_hint.position = Vector2(8, 8)
	_banner_hint.size = Vector2(P3_RECT.size.x - 16, 24)
	_banner_hint.add_theme_font_size_override("font_size", 14)
	_banner_area.add_child(_banner_hint)

	_banner_intel_label = Label.new()
	_banner_intel_label.position = Vector2(8, 8)
	_banner_intel_label.size = Vector2(P3_RECT.size.x - 16, 24)
	_banner_intel_label.add_theme_font_size_override("font_size", 14)
	_banner_intel_label.visible = false
	_banner_area.add_child(_banner_intel_label)

	_banner_bar = ProgressBar.new()
	_banner_bar.position = Vector2(8, 40)
	_banner_bar.custom_minimum_size = Vector2(P3_RECT.size.x - 16, 24)
	_banner_bar.size = Vector2(P3_RECT.size.x - 16, 24)
	_banner_bar.max_value = 1.0
	_banner_bar.show_percentage = false
	_banner_bar.visible = false
	_banner_area.add_child(_banner_bar)

	_banner_flash = Label.new()
	_banner_flash.text = "情报等级提升！"
	_banner_flash.position = Vector2(8, 8)
	_banner_flash.size = P3_RECT.size - Vector2(16, 16)
	_banner_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_flash.add_theme_font_size_override("font_size", 18)
	_banner_flash.add_theme_color_override("font_color", Color(0.55, 0.25, 0.85, 1))
	_banner_flash.visible = false
	_banner_area.add_child(_banner_flash)


func _build_p4_list() -> void:
	_scroll = ScrollContainer.new()
	_scroll.position = P4_RECT.position
	_scroll.size = P4_RECT.size
	_scroll.custom_minimum_size = P4_RECT.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.gui_input.connect(_on_scroll_gui_input)
	_content_root.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 12)
	_list_box.custom_minimum_size.x = P4_RECT.size.x
	_scroll.add_child(_list_box)


func _build_p5_hotsearch() -> void:
	var panel := PanelContainer.new()
	panel.position = P5_RECT.position
	panel.custom_minimum_size = P5_RECT.size
	panel.size = P5_RECT.size
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.25)
	panel.add_theme_stylebox_override("panel", ps)
	_content_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	margin.add_child(col)

	var title := Label.new()
	title.text = "饭圈热搜"
	title.add_theme_font_size_override("font_size", 16)
	col.add_child(title)

	_hot_list = VBoxContainer.new()
	_hot_list.add_theme_constant_override("separation", 4)
	col.add_child(_hot_list)

	var samples: PackedStringArray = [
		"1. Beave回归预告",
		"2. 新歌难听",
		"3. 新人男团疑似恋爱",
		"4. 新人男团疑似恋爱",
		"5. 新人男团疑似恋爱",
		"6. 新人男团疑似恋爱",
		"7. 新人男团疑似恋爱",
		"8. 新人男团疑似恋爱",
		"9. 新人男团疑似恋爱",
		"10. 新人男团疑似恋爱",
	]
	for line in samples:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 13)
		_hot_list.add_child(l)


func _build_p6_hud() -> void:
	_fp_label = Label.new()
	_fp_label.position = Vector2(900, 8)
	_fp_label.add_theme_font_size_override("font_size", 14)
	_content_root.add_child(_fp_label)

	_stars_label = Label.new()
	_stars_label.position = Vector2(900, 28)
	_stars_label.add_theme_font_size_override("font_size", 14)
	_content_root.add_child(_stars_label)

	_intel_level_label = Label.new()
	_intel_level_label.position = Vector2(1039, 8)
	_intel_level_label.add_theme_font_size_override("font_size", 21)
	_content_root.add_child(_intel_level_label)


func _update_layout_visibility() -> void:
	if _post_area != null:
		_post_area.visible = _active_tab != TAB_MARKET
	_refresh_banner_area()


func _refresh_banner_area() -> void:
	if _banner_area == null:
		return
	for c in _banner_area.get_children():
		if c != _banner_hint and c != _banner_intel_label and c != _banner_bar and c != _banner_flash:
			c.queue_free()

	var placeholder := _banner_area.get_node_or_null("ArtistPlaceholder") as ColorRect
	if placeholder != null:
		placeholder.queue_free()
	if _banner_area.get_node_or_null("MarketBagBtn") != null:
		_banner_area.get_node_or_null("MarketBagBtn").queue_free()

	_banner_hint.visible = false
	_banner_intel_label.visible = false
	_banner_bar.visible = false
	_banner_flash.visible = false

	match _active_tab:
		TAB_ARTIST:
			var rect := ColorRect.new()
			rect.name = "ArtistPlaceholder"
			rect.color = Color(0.55, 0.35, 0.82, 0.85)
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			rect.offset_left = 0
			rect.offset_top = 0
			rect.offset_right = 0
			rect.offset_bottom = 0
			_banner_area.add_child(rect)
			rect.show_behind_parent = true
			_banner_area.move_child(rect, 0)
		TAB_FANDOM:
			_banner_hint.visible = true
			_banner_hint.text = "停留阅读帖子获得饭圈积分"
			_banner_bar.visible = true
			_banner_bar.value = 0.0
		TAB_SISTER:
			_banner_intel_label.visible = true
			_banner_bar.visible = true
			_update_sister_banner_intel_text()
			var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
			if expose != null and expose.consume_pending_intel_level_up():
				_play_intel_level_flash()
		TAB_ACCOUNT:
			var rect := ColorRect.new()
			rect.name = "ArtistPlaceholder"
			rect.color = Color(0.75, 0.72, 0.88, 0.85)
			rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_banner_area.add_child(rect)
			rect.show_behind_parent = true
			_banner_area.move_child(rect, 0)
		TAB_MARKET:
			var bag_btn := Button.new()
			bag_btn.name = "MarketBagBtn"
			bag_btn.text = "背包"
			bag_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			bag_btn.offset_left = 0
			bag_btn.offset_top = 0
			bag_btn.offset_right = 0
			bag_btn.offset_bottom = 0
			bag_btn.pressed.connect(_on_market_bag_pressed)
			_banner_area.add_child(bag_btn)


func _update_sister_banner_intel_text() -> void:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if sm == null or _banner_intel_label == null:
		return
	var threshold: int = expose.get_next_intel_threshold() if expose != null else 0
	if threshold <= 0:
		_banner_intel_label.text = "情报点 %d / MAX" % sm.intel
	else:
		_banner_intel_label.text = "情报点 %d / %d" % [sm.intel, threshold]


func _play_intel_level_flash() -> void:
	if _banner_flash == null:
		return
	_banner_flash.visible = true
	_banner_flash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_banner_flash, "modulate:a", 0.2, 0.35)
	tw.tween_property(_banner_flash, "modulate:a", 1.0, 0.35)
	tw.tween_property(_banner_flash, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		if _banner_flash != null:
			_banner_flash.visible = false
	)


func _on_market_bag_pressed() -> void:
	_show_toast("背包功能 M3 开放")


func _show_toast(msg: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = msg
	_toast_label.position = Vector2(400, 340)
	_toast_label.visible = true
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(func() -> void:
		if _toast_label != null:
			_toast_label.visible = false
	)


func _set_tab_visual() -> void:
	var active_color := Color(0.17, 0.14, 0.24, 1)
	var inactive_color := Color(0.55, 0.51, 0.64, 1)
	for tab_id: String in _tab_buttons.keys():
		var btn: Button = _tab_buttons[tab_id]
		var on: bool = _active_tab == tab_id
		btn.add_theme_font_size_override("font_size", 18 if on else 16)
		btn.add_theme_color_override("font_color", active_color if on else inactive_color)


func refresh_feed() -> void:
	_load_json()
	_update_currency_hud()
	if _list_box == null:
		return
	for c in _list_box.get_children():
		c.queue_free()

	match _active_tab:
		TAB_ARTIST:
			_refresh_artist_tab()
		TAB_FANDOM, TAB_SISTER:
			_refresh_instance_tab(_exposure_tabtype_for_name(_active_tab))
		TAB_ACCOUNT, TAB_MARKET:
			var tip := Label.new()
			tip.text = "敬请期待"
			tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
			_list_box.add_child(tip)


func _refresh_artist_tab() -> void:
	var save_manager: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var chapter_manager: ChapterManager = get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	var condition_checker: ConditionChecker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	if save_manager == null or chapter_manager == null or condition_checker == null:
		return

	var enriched: Array = []
	for item in _posts_raw:
		if not (item is Dictionary):
			continue
		var post: Dictionary = (item as Dictionary).duplicate(true)
		if int(post.get("type", 0)) != TYPE_ARTIST:
			continue
		if not condition_checker.is_feed_post_visible(post):
			continue
		var e: Dictionary = _enrich_post(post, chapter_manager)
		if e.is_empty():
			continue
		var chapter_levels: Array = e.get("_chapter_levels", [])
		e["_locked"] = condition_checker.is_feed_post_locked_visible(post, chapter_levels)
		enriched.append(e)

	_sort_artist_list(enriched, save_manager, chapter_manager)

	if enriched.is_empty():
		var tip := Label.new()
		tip.text = "暂无艺人动态（提升情报等级解锁）"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_list_box.add_child(tip)
		return

	for e in enriched:
		var card: Node = CARD_SCENE.instantiate()
		if card is Control:
			(card as Control).custom_minimum_size.x = P4_RECT.size.x
		_list_box.add_child(card)
		if card.has_method("setup"):
			card.call("setup", _card_view_dict(e))
		var ebind: Dictionary = e.duplicate(true)
		if card.has_signal("media_pressed"):
			card.media_pressed.connect(func() -> void: _on_media_pressed(ebind, save_manager, chapter_manager))
		if card.has_signal("like_pressed"):
			card.like_pressed.connect(func(anchor_global: Vector2) -> void: _on_like_pressed(card, anchor_global))
		if card.has_signal("pin_toggled"):
			card.pin_toggled.connect(func(is_pinned: bool) -> void:
				_on_pin_toggled(str(ebind.get("post_id", "")), is_pinned, save_manager)
			)


func _refresh_instance_tab(tabtype: int) -> void:
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose == null:
		return
	var fp_side := tabtype == TABTYPE_FANDOM
	for inst in expose.get_instances_for_tab(tabtype):
		if not (inst is Dictionary):
			continue
		var inst_dict: Dictionary = inst as Dictionary
		var tpl: Dictionary = expose.get_template(str(inst_dict.get("postid", "")))
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(P4_RECT.size.x, 64)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.88)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		row.add_theme_stylebox_override("panel", style)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		row.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)

		var title := Label.new()
		title.text = str(tpl.get("title", inst_dict.get("postid", "")))
		vbox.add_child(title)

		var reward := Label.new()
		var collected: bool = bool(inst_dict.get("fpcollected" if fp_side else "intelcollected", false))
		var amount: int = int(tpl.get("grantfp" if fp_side else "grantintel", 0))
		if collected or amount <= 0:
			reward.text = "已收取"
			reward.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1))
			style.bg_color = Color(0.92, 0.92, 0.94, 0.88)
		else:
			var unit := "饭圈积分" if fp_side else "情报点"
			reward.text = "+%d %s" % [amount, unit]
		vbox.add_child(reward)
		_list_box.add_child(row)

	if _list_box.get_child_count() == 0:
		var tip := Label.new()
		tip.text = "暂无放置帖子"
		_list_box.add_child(tip)


func _on_banner_progress(tabtype: int, ratio: float) -> void:
	if _banner_bar == null:
		return
	if tabtype != _exposure_tabtype_for_name(_active_tab):
		return
	_banner_bar.visible = true
	_banner_bar.value = ratio


func _on_lump_granted(tabtype: int, _grant_type: int, amount: int) -> void:
	_update_currency_hud()
	if tabtype == TABTYPE_SISTER:
		_update_sister_banner_intel_text()
	var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
	if tutor != null and tabtype == TABTYPE_SISTER and amount > 0:
		if tutor.get_step() == 1:
			tutor.advance_step()
		if tutor.get_step() == 2:
			tutor.notify_instance_collected()
	refresh_feed()


func _on_intel_level_up(_new_level: int) -> void:
	_update_currency_hud()
	_update_sister_banner_intel_text()
	if _active_tab == TAB_SISTER:
		_play_intel_level_flash()
	else:
		var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
		if expose != null:
			expose.consume_pending_intel_level_up()
	refresh_feed()


func _on_instance_changed() -> void:
	refresh_feed()


func _update_currency_hud() -> void:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return
	if _fp_label != null:
		_fp_label.text = "饭圈积分 %d" % sm.fp
	if _stars_label != null:
		_stars_label.text = "星星 %d" % sm.stars
	if _intel_level_label != null:
		_intel_level_label.text = "情报等级 lv.%d" % sm.intellevel
	_update_sister_banner_intel_text()


func _enrich_post(post: Dictionary, chapter_manager: ChapterManager) -> Dictionary:
	var level_id: String = str(post.get("level_id", ""))
	var level_row: Dictionary = {}
	var chapter_id: int = 1
	var chapter_levels: Array = chapter_manager.get_levels_for_chapter(chapter_id)

	if not level_id.is_empty():
		level_row = chapter_manager.get_level_by_id(level_id)
		if level_row.is_empty():
			push_warning("feed_page: 未知 level_id %s" % level_id)
			return {}
		chapter_id = int(level_row.get("chapter_id", 1))
		chapter_levels = chapter_manager.get_levels_for_chapter(chapter_id)

	var out: Dictionary = post.duplicate(true)
	out["artist_name"] = str(post.get("name", ""))
	out["time_display"] = str(post.get("time", ""))
	out["_level_row"] = level_row.duplicate(true)
	out["_chapter_id"] = chapter_id
	out["_chapter_levels"] = chapter_levels.duplicate(true)
	return out


func _card_view_dict(e: Dictionary) -> Dictionary:
	return {
		"layout": "artist",
		"artist_name": e.get("artist_name", ""),
		"time_display": e.get("time_display", ""),
		"text": e.get("text", ""),
		"image_path": e.get("image_path", ""),
		"image_path2": e.get("image_path2", ""),
		"avatar_path": e.get("avatar_path", ""),
		"is_pinned": bool(e.get("_is_pinned", false)),
		"locked": bool(e.get("_locked", false)),
	}


func _sort_artist_list(items: Array, save_manager: SaveManager, chapter_manager: ChapterManager) -> void:
	var pinned_post_id: String = save_manager.get_feed_pinned_post_id()
	var current_level_id: String = _current_level_id(save_manager, chapter_manager)
	for item in items:
		if item is Dictionary:
			(item as Dictionary)["_is_pinned"] = str((item as Dictionary).get("post_id", "")) == pinned_post_id
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: Array = _artist_rank(a, current_level_id, pinned_post_id, chapter_manager)
		var rb: Array = _artist_rank(b, current_level_id, pinned_post_id, chapter_manager)
		for i in range(mini(ra.size(), rb.size())):
			if ra[i] != rb[i]:
				return ra[i] < rb[i]
		return false
	)


func _artist_rank(
	e: Dictionary,
	current_level_id: String,
	pinned_post_id: String,
	chapter_manager: ChapterManager
) -> Array:
	var post_id: String = str(e.get("post_id", ""))
	var level_id: String = str(e.get("level_id", ""))
	var tier: int = 2
	if not pinned_post_id.is_empty() and post_id == pinned_post_id:
		tier = 0
	elif not level_id.is_empty() and level_id == current_level_id:
		tier = 1
	var level_order: int = -1 if level_id.is_empty() else _level_order(chapter_manager, level_id)
	return [tier, -level_order, post_id]


func _current_level_id(save_manager: SaveManager, chapter_manager: ChapterManager) -> String:
	var best_order: int = -1
	var best_id: String = ""
	for item in chapter_manager.get_levels_for_chapter(1):
		if not (item is Dictionary):
			continue
		var level: Dictionary = item as Dictionary
		var level_id: String = str(level.get("levelid", ""))
		if not _is_level_playable(level, 1, chapter_manager.get_levels_for_chapter(1), save_manager, chapter_manager):
			continue
		var order: int = int(level.get("order", 0))
		if order > best_order:
			best_order = order
			best_id = level_id
	return best_id


func _level_order(chapter_manager: ChapterManager, level_id: String) -> int:
	var row: Dictionary = chapter_manager.get_level_by_id(level_id)
	return int(row.get("order", 999))


func _is_level_playable(
	level: Dictionary,
	chapter_id: int,
	chapter_levels: Array,
	save_manager: SaveManager,
	chapter_manager: ChapterManager
) -> bool:
	if level.is_empty():
		return false
	var level_id: String = str(level.get("levelid", ""))
	if save_manager.is_level_unlocked(level_id) or save_manager.is_level_completed(level_id):
		return true
	var condition_id: int = int(level.get("unlockconditionid", 0))
	if condition_id <= 0:
		return true
	var condition_checker: ConditionChecker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	if condition_checker == null:
		return false
	return condition_checker.is_level_condition_met(condition_id, level, chapter_levels)


func _on_media_pressed(e: Dictionary, save_manager: SaveManager, chapter_manager: ChapterManager) -> void:
	if bool(e.get("_locked", false)):
		var cc: ConditionChecker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
		var msg := "关卡尚未解锁"
		if cc != null:
			var level_row: Dictionary = e.get("_level_row", {})
			var cid: int = int(level_row.get("unlockconditionid", 0))
			msg = cc.get_fail_text(cid) if cid > 0 else msg
		push_warning("feed locked: %s" % msg)
		return
	var pid: String = str(e.get("post_id", ""))
	if not pid.is_empty():
		save_manager.mark_feed_post_seen(pid)
	var level_row: Dictionary = e.get("_level_row", {}).duplicate(true)
	if level_row.is_empty():
		return
	var chapter_id: int = int(e.get("_chapter_id", 1))
	var chapter_levels: Array = e.get("_chapter_levels", [])
	if _is_level_playable(level_row, chapter_id, chapter_levels, save_manager, chapter_manager):
		feed_open_level.emit(level_row.duplicate(true))


func _on_like_pressed(card: Node, anchor_global: Vector2 = Vector2.ZERO) -> void:
	var anchor_pos := anchor_global
	if anchor_pos == Vector2.ZERO and card is Control:
		anchor_pos = (card as Control).global_position
	_play_heart_effect(card, anchor_pos)


func _on_pin_toggled(post_id: String, is_pinned: bool, save_manager: SaveManager) -> void:
	if save_manager == null:
		return
	if is_pinned:
		save_manager.set_feed_pinned_post_id(post_id)
	else:
		save_manager.set_feed_pinned_post_id("")
	refresh_feed()


func _on_scroll_gui_input(event: InputEvent) -> void:
	var scrolled_down := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			scrolled_down = true
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_manual_dragging = mb.pressed
	elif event is InputEventMouseMotion and _manual_dragging and _scroll != null:
		var mm := event as InputEventMouseMotion
		if mm.relative.y > 0.5:
			scrolled_down = true
		var next_v: float = _scroll.scroll_vertical - mm.relative.y
		var max_v: int = 0
		if _scroll.get_v_scroll_bar() != null:
			max_v = int(_scroll.get_v_scroll_bar().max_value)
		_scroll.scroll_vertical = clampi(int(next_v), 0, max_v)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_manual_dragging = st.pressed
	elif event is InputEventScreenDrag and _manual_dragging and _scroll != null:
		var sd := event as InputEventScreenDrag
		if sd.relative.y > 0.5:
			scrolled_down = true
		var next_v_touch: float = _scroll.scroll_vertical - sd.relative.y
		var max_v_touch: int = 0
		if _scroll.get_v_scroll_bar() != null:
			max_v_touch = int(_scroll.get_v_scroll_bar().max_value)
		_scroll.scroll_vertical = clampi(int(next_v_touch), 0, max_v_touch)

	if scrolled_down and not _scroll_started:
		_scroll_started = true
		var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
		if expose != null:
			expose.notify_list_scrolled(_exposure_tabtype_for_name(_active_tab))


func _play_heart_effect(anchor: Node, anchor_global: Vector2 = Vector2.ZERO) -> void:
	var anchor_pos := anchor_global
	if anchor_pos == Vector2.ZERO and anchor is Control:
		anchor_pos = (anchor as Control).global_position
	if _love_effect_tex != null:
		var heart := TextureRect.new()
		heart.texture = _love_effect_tex
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(22, 22)
		heart.size = Vector2(22, 22)
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart.global_position = anchor_pos + Vector2(-11, -18)
		add_child(heart)
		var tw := create_tween()
		tw.tween_property(heart, "position:y", heart.position.y - 18, 0.35)
		tw.parallel().tween_property(heart, "modulate:a", 0.0, 0.35)
		tw.tween_callback(heart.queue_free)
		return
	var heart_label := Label.new()
	heart_label.text = "❤"
	heart_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart_label.modulate = Color(1.0, 0.42, 0.56, 1)
	heart_label.add_theme_font_size_override("font_size", 22)
	add_child(heart_label)
	heart_label.global_position = anchor_pos + Vector2(-14, -14)
	var tw_fallback := create_tween()
	tw_fallback.tween_property(heart_label, "position:y", heart_label.position.y - 18, 0.35)
	tw_fallback.parallel().tween_property(heart_label, "modulate:a", 0.0, 0.35)
	tw_fallback.tween_callback(heart_label.queue_free)
