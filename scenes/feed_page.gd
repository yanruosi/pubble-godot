extends Control

signal feed_open_level(level: Dictionary)
signal feed_back_requested

const FEED_JSON_PATH := "res://data/feed_posts.json"
const CARD_SCENE := preload("res://scenes/feed_post_card.tscn")

const PATH_POSTBG := "res://art/mainui/postui/postbg.png"
const PATH_BACK := "res://art/mainui/postui/back.png"
const PATH_LOVE := "res://art/mainui/postui/love.png"
const PATH_BANNER := "res://art/mainui/storeui/banner.png"
const PATH_BANNER_SISTER := "res://art/mainui/storeui/banner0.png"

const TYPE_ARTIST := 901

const TAB_ARTIST := "artist"
const TAB_FANDOM := "fandom"
const TAB_ACCOUNT := "account"
const TAB_SISTER := "sister"
const TAB_MARKET := "market"

const TABTYPE_FANDOM := 0
const TABTYPE_SISTER := 903
const TABTYPE_ACCOUNT := 904

## 1280×720 PSD 区域（p1–p5）
const P1_BANNER_RECT := Rect2(356, 51, 497, 126)   ## 饭圈/嫂子 banner.png + 动态叠层
const P2_LIST_RECT := Rect2(356, 179, 497, 541)    ## 饭圈/嫂子 帖子列表（滑出动画自顶部）
const P3_BANNER_RECT := Rect2(356, 49, 497, 108)   ## 艺人 banner0 静态
const P3_LIST_RECT := Rect2(356, 157, 497, 563)    ## 艺人 帖子列表
const P4_COMPOSE_RECT := Rect2(356, 31, 497, 155)  ## 我的站子 发帖标签/输入（仅 account）
const P4_BANNER_RECT := Rect2(353, 186, 497, 126)  ## 我的站子 banner.png + 动态叠层
const P5_LIST_RECT := Rect2(356, 319, 497, 401)    ## 我的站子 帖子列表
const HOTSEARCH_RECT := Rect2(855, 49, 217, 671)
## banner 内局部坐标（497×126 设计稿）
const BANNER_OVERLAY_SIZE := Vector2(497, 126)
const BANNER_BAR_LOCAL := Rect2(101, 54, 279, 23)
const BANNER_RATE_LOCAL := Rect2(259, 30, 28, 23)
const BANNER_LV_LOCAL := Rect2(411, 21, 57, 23)
const BANNER_KEY_LOCAL := Rect2(452, 66, 28, 19)
const BANNER_STATUS_LOCAL := Rect2(101, 30, 380, 40)  ## banner 主文案区
const P1_NAV_RECT := Rect2(206, 48, 142, 672)
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
var _dbg_scroll_sig: String = ""

var _post_area: Control
var _banner_area: Control
var _banner_bg: TextureRect
var _banner_p2: Label
var _banner_p3: Label
var _banner_p4: Label
var _banner_p5: Label
var _banner_p6: ProgressBar
var _banner_flash: Label
var _hot_list: VBoxContainer

var _compose_input: TextEdit
var _tag_row: HBoxContainer
var _publish_btn: Button
var _selected_tagid: String = ""
var _preview_mypostid: String = ""
var _tag_buttons: Dictionary = {}
var _opening_post_lock: bool = false

var _fp_label: Label
var _stars_label: Label
var _intel_level_label: Label
var _toast_label: Label
var _bag_panel: PanelContainer
var _bag_grid: GridContainer
var _reveal_run_id: int = 0
var _dbg_banner_sig: String = ""

func _ready() -> void:
	_load_json()
	_love_effect_tex = _load_tex(PATH_LOVE)
	call_deferred("_build_ui")
	call_deferred("_enter_initial_tab")
	set_process(true)


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
	if _opening_post_lock and normalized != TAB_ACCOUNT:
		_show_toast("请先完成首次发帖")
		return
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
		_refresh_compose_area()
		refresh_feed(true)


func apply_opening_post_lock(locked: bool) -> void:
	_opening_post_lock = locked
	_set_tab_visual()
	if locked and _active_tab != TAB_ACCOUNT:
		set_active_tab(TAB_ACCOUNT)
	else:
		_refresh_compose_area()


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
		TAB_ACCOUNT:
			return TABTYPE_ACCOUNT
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
	_build_bag_panel()
	_build_p1_banner()
	_build_p4_list()

	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose != null:
		if not expose.lump_granted.is_connected(_on_lump_granted):
			expose.lump_granted.connect(_on_lump_granted)
		if not expose.banner_state_changed.is_connected(_on_banner_state_changed):
			expose.banner_state_changed.connect(_on_banner_state_changed)
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
	_refresh_compose_area()


func _build_p1_tabs() -> void:
	var panel := PanelContainer.new()
	panel.position = P1_NAV_RECT.position
	panel.custom_minimum_size = P1_NAV_RECT.size
	panel.size = P1_NAV_RECT.size
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
		[TAB_ACCOUNT, "我的站子"],
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
	_post_area.position = P4_COMPOSE_RECT.position
	_post_area.custom_minimum_size = P4_COMPOSE_RECT.size
	_post_area.size = P4_COMPOSE_RECT.size
	_post_area.visible = false
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

	var input := TextEdit.new()
	input.name = "ComposeInput"
	input.placeholder_text = "选择标签后预览帖子内容..."
	input.editable = false
	input.focus_mode = Control.FOCUS_NONE
	input.custom_minimum_size = Vector2(0, 72)
	input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	root.add_child(input)
	_compose_input = input

	_tag_row = HBoxContainer.new()
	_tag_row.name = "TagRow"
	_tag_row.add_theme_constant_override("separation", 6)
	root.add_child(_tag_row)

	var pub_row := HBoxContainer.new()
	pub_row.add_theme_constant_override("separation", 8)
	root.add_child(pub_row)

	_publish_btn = Button.new()
	_publish_btn.name = "PublishBtn"
	_publish_btn.text = "发布"
	_publish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_publish_btn.disabled = true
	_publish_btn.pressed.connect(_on_publish_pressed)
	pub_row.add_child(_publish_btn)


func _build_bag_panel() -> void:
	_bag_panel = PanelContainer.new()
	_bag_panel.name = "BagPanel"
	_bag_panel.position = P4_COMPOSE_RECT.position
	_bag_panel.custom_minimum_size = P4_COMPOSE_RECT.size
	_bag_panel.size = P4_COMPOSE_RECT.size
	_bag_panel.visible = false
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.98, 0.96, 1, 0.97)
	ps.corner_radius_top_left = 6
	ps.corner_radius_top_right = 6
	ps.corner_radius_bottom_left = 6
	ps.corner_radius_bottom_right = 6
	_bag_panel.add_theme_stylebox_override("panel", ps)
	_content_root.add_child(_bag_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_bag_panel.add_child(margin)

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
		if _bag_panel != null:
			_bag_panel.visible = false
	)
	header.add_child(close_btn)
	root.add_child(header)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(P4_COMPOSE_RECT.size.x - 16, P4_COMPOSE_RECT.size.y - 40)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_bag_grid = GridContainer.new()
	_bag_grid.columns = 4
	_bag_grid.add_theme_constant_override("h_separation", 6)
	_bag_grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_bag_grid)


func _build_p1_banner() -> void:
	_banner_area = Control.new()
	_banner_area.name = "BannerArea"
	_banner_area.position = P1_BANNER_RECT.position
	_banner_area.custom_minimum_size = P1_BANNER_RECT.size
	_banner_area.size = P1_BANNER_RECT.size
	_content_root.add_child(_banner_area)

	_banner_bg = TextureRect.new()
	_banner_bg.name = "BannerBg"
	_banner_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_bg.offset_left = 0
	_banner_bg.offset_top = 0
	_banner_bg.offset_right = 0
	_banner_bg.offset_bottom = 0
	_banner_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_area.add_child(_banner_bg)
	_update_banner_bg_texture()

	_banner_p4 = _make_banner_label(BANNER_LV_LOCAL, 13, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_p4.name = "BannerP3Lv"
	_banner_area.add_child(_banner_p4)

	_banner_p5 = _make_banner_label(BANNER_KEY_LOCAL, 18, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_p5.name = "BannerP4Key"
	_banner_area.add_child(_banner_p5)

	_banner_p3 = _make_banner_label(BANNER_RATE_LOCAL, 16, HORIZONTAL_ALIGNMENT_LEFT)
	_banner_p3.name = "BannerP2Rate"
	_banner_area.add_child(_banner_p3)

	_banner_p2 = _make_banner_label(BANNER_STATUS_LOCAL, 11, HORIZONTAL_ALIGNMENT_LEFT)
	_banner_p2.name = "BannerStatusText"
	_banner_area.add_child(_banner_p2)

	var p1_rect := _banner_local_rect(BANNER_BAR_LOCAL)
	_banner_p6 = ProgressBar.new()
	_banner_p6.name = "BannerP1Bar"
	_banner_p6.position = p1_rect.position
	_banner_p6.custom_minimum_size = p1_rect.size
	_banner_p6.size = p1_rect.size
	_banner_p6.max_value = 1.0
	_banner_p6.show_percentage = false
	_banner_p6.visible = false
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
	_banner_p6.add_theme_stylebox_override("background", bar_style)
	_banner_p6.add_theme_stylebox_override("fill", fill_style)
	_banner_area.add_child(_banner_p6)

	_banner_flash = Label.new()
	_banner_flash.text = "情报等级提升！"
	_banner_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner_flash.offset_left = 0
	_banner_flash.offset_top = 0
	_banner_flash.offset_right = 0
	_banner_flash.offset_bottom = 0
	_banner_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_flash.add_theme_font_size_override("font_size", 18)
	_banner_flash.add_theme_color_override("font_color", Color(0.55, 0.25, 0.85, 1))
	_banner_flash.visible = false
	_banner_area.add_child(_banner_flash)


func _make_banner_label(local_rect: Rect2, font_size: int, align: HorizontalAlignment) -> Label:
	var rect := _banner_local_rect(local_rect)
	var lbl := Label.new()
	lbl.position = rect.position
	lbl.custom_minimum_size = rect.size
	lbl.size = rect.size
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.18, 0.55, 1))
	return lbl


func _get_list_scroll_rect() -> Rect2:
	return _get_active_list_rect()


func _get_active_banner_rect() -> Rect2:
	match _active_tab:
		TAB_ARTIST:
			return P3_BANNER_RECT
		TAB_ACCOUNT:
			return P4_BANNER_RECT
		TAB_FANDOM, TAB_SISTER:
			return P1_BANNER_RECT
		_:
			return P1_BANNER_RECT


func _get_active_list_rect() -> Rect2:
	match _active_tab:
		TAB_ARTIST:
			return P3_LIST_RECT
		TAB_ACCOUNT:
			return P5_LIST_RECT
		TAB_FANDOM, TAB_SISTER, TAB_MARKET:
			return P2_LIST_RECT
		_:
			return P2_LIST_RECT


func _banner_local_rect(local_rect: Rect2) -> Rect2:
	var banner_size := _get_active_banner_rect().size
	var scale := banner_size / BANNER_OVERLAY_SIZE
	return Rect2(local_rect.position * scale, local_rect.size * scale)


func _relayout_banner_children() -> void:
	if _banner_area == null:
		return
	var pairs: Array = [
		[_banner_p6, BANNER_BAR_LOCAL, true],
		[_banner_p3, BANNER_RATE_LOCAL, false],
		[_banner_p4, BANNER_LV_LOCAL, false],
		[_banner_p5, BANNER_KEY_LOCAL, false],
		[_banner_p2, BANNER_STATUS_LOCAL, false],
	]
	for entry in pairs:
		var ctrl: Control = entry[0]
		var local: Rect2 = entry[1]
		var is_bar: bool = entry[2]
		if ctrl == null:
			continue
		var rect := _banner_local_rect(local)
		ctrl.position = rect.position
		ctrl.custom_minimum_size = rect.size
		ctrl.size = rect.size
		if is_bar and ctrl is ProgressBar:
			continue
		if ctrl is Label:
			(ctrl as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if local == BANNER_LV_LOCAL or local == BANNER_KEY_LOCAL else HORIZONTAL_ALIGNMENT_LEFT


func _apply_tab_layout() -> void:
	var banner_rect := _get_active_banner_rect()
	var list_rect := _get_active_list_rect()

	if _banner_area != null:
		_banner_area.position = banner_rect.position
		_banner_area.size = banner_rect.size
		_banner_area.custom_minimum_size = banner_rect.size
		_relayout_banner_children()

	_relayout_scroll()

	if _post_area != null:
		_post_area.visible = _active_tab == TAB_ACCOUNT
		if _active_tab == TAB_ACCOUNT:
			_post_area.position = P4_COMPOSE_RECT.position
			_post_area.size = P4_COMPOSE_RECT.size
			_post_area.custom_minimum_size = P4_COMPOSE_RECT.size

	if _bag_panel != null and _active_tab == TAB_MARKET:
		_bag_panel.position = P4_COMPOSE_RECT.position
		_bag_panel.size = P4_COMPOSE_RECT.size
		_bag_panel.custom_minimum_size = P4_COMPOSE_RECT.size


func _process(_delta: float) -> void:
	if _shows_banner_dynamic_overlay():
		_update_unified_banner_text()


func _build_p4_list() -> void:
	var scroll_rect := _get_list_scroll_rect()
	_scroll = ScrollContainer.new()
	_scroll.position = scroll_rect.position
	_scroll.size = scroll_rect.size
	_scroll.custom_minimum_size = scroll_rect.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.gui_input.connect(_on_scroll_gui_input)
	_content_root.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 12)
	_list_box.custom_minimum_size.x = scroll_rect.size.x
	_list_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_list_box.gui_input.connect(_on_scroll_gui_input)
	_scroll.add_child(_list_box)


func _relayout_scroll() -> void:
	if _scroll == null:
		return
	var list_rect := _get_list_scroll_rect()
	_scroll.position = list_rect.position
	_scroll.size = list_rect.size
	_scroll.custom_minimum_size = list_rect.size
	_scroll.clip_contents = true
	if _list_box != null:
		_list_box.custom_minimum_size.x = list_rect.size.x


func _build_p5_hotsearch() -> void:
	var panel := PanelContainer.new()
	panel.position = HOTSEARCH_RECT.position
	panel.custom_minimum_size = HOTSEARCH_RECT.size
	panel.size = HOTSEARCH_RECT.size
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
	_apply_tab_layout()
	if _bag_panel != null and _active_tab != TAB_MARKET:
		_bag_panel.visible = false
	_refresh_banner_area()
	if _active_tab == TAB_ACCOUNT:
		_refresh_compose_area()


func _refresh_banner_area() -> void:
	if _banner_area == null:
		return
	for c in _banner_area.get_children():
		if c.name in ["ArtistPlaceholder", "MarketBagBtn"]:
			c.queue_free()

	_banner_area.visible = _active_tab in [TAB_FANDOM, TAB_SISTER, TAB_ARTIST, TAB_ACCOUNT, TAB_MARKET]
	if _banner_p2 != null:
		_banner_p2.visible = false
	if _banner_p3 != null:
		_banner_p3.visible = false
	if _banner_p4 != null:
		_banner_p4.visible = false
	if _banner_p5 != null:
		_banner_p5.visible = false
	if _banner_p6 != null:
		_banner_p6.visible = false
	if _banner_flash != null:
		_banner_flash.visible = false

	match _active_tab:
		TAB_ARTIST:
			_update_banner_bg_texture()
		TAB_FANDOM, TAB_SISTER, TAB_ACCOUNT:
			_update_banner_bg_texture()
			if _banner_p4 != null:
				_banner_p4.visible = true
			if _banner_p5 != null:
				_banner_p5.visible = true
			_update_unified_banner_text()
			if _active_tab == TAB_FANDOM:
				var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
				if expose != null and expose.consume_pending_intel_level_up():
					_play_intel_level_flash()
		TAB_MARKET:
			var bag_btn := Button.new()
			bag_btn.name = "MarketBagBtn"
			bag_btn.text = "背包"
			bag_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			bag_btn.pressed.connect(_on_market_bag_pressed)
			_banner_area.add_child(bag_btn)


func _uses_banner0() -> bool:
	return _active_tab == TAB_ARTIST


func _shows_banner_dynamic_overlay() -> bool:
	return _active_tab in [TAB_FANDOM, TAB_SISTER, TAB_ACCOUNT]


func _update_banner_bg_texture() -> void:
	if _banner_bg == null:
		return
	var path := PATH_BANNER_SISTER if _uses_banner0() else PATH_BANNER
	_banner_bg.texture = _load_tex(path)


func _update_unified_banner_text() -> void:
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose == null:
		return
	var snap: Dictionary = expose.get_banner_snapshot()
	if _banner_p4 != null:
		_banner_p4.text = "Lv.%d" % int(snap.get("intellevel", 0))
	if _banner_p5 != null:
		var target: int = int(snap.get("keypost_target", 0))
		var current: int = int(snap.get("keypost_current", 0))
		if target > 0:
			_banner_p5.text = "%d/%d" % [current, target]
		else:
			_banner_p5.text = "MAX"
	var mode: String = str(snap.get("banner_state", "default_static"))
	var status_text: String = _default_banner_status_text(mode, snap)
	if _banner_p2 != null:
		_banner_p2.visible = mode != "default_static" or not status_text.is_empty()
		_banner_p2.text = status_text
	var show_bar := mode == "exposing"
	var bar_ratio := 0.0
	if mode == "exposing":
		var remain: float = float(snap.get("remaining_sec", -1.0))
		if remain >= 0.0:
			bar_ratio = clampf(1.0 - remain / 150.0, 0.0, 1.0)
	if _banner_p6 != null:
		_banner_p6.visible = show_bar
		if _banner_p6.visible:
			_banner_p6.value = bar_ratio
	## 旧 M3.5 +N/s 槽位（BannerP2Rate 宽28）已废弃；禁止再叠 +60/30
	if _banner_p3 != null:
		_banner_p3.visible = false
		_banner_p3.text = ""
		#region agent log
		if mode in ["hot_success", "hot_fail"]:
			var sig := "%s|%s|p3off|%d/%d" % [mode, status_text, int(snap.get("display_fp", 0)), int(snap.get("display_fans", 0))]
			if sig != _dbg_banner_sig:
				_dbg_banner_sig = sig
				_dbg_c195("A,B,C", "feed_page.gd:_update_unified_banner_text", "banner overlay state", {
					"mode": mode,
					"status_text": status_text,
					"p3_visible": _banner_p3.visible,
					"p3_text": _banner_p3.text,
					"display_fp": int(snap.get("display_fp", 0)),
					"display_fans": int(snap.get("display_fans", 0)),
					"settle_fp": int(snap.get("settle_fp", 0)),
					"settle_fans": int(snap.get("settle_fans", 0)),
					"idle_fp": int(snap.get("idle_fp_earned", 0)),
					"idle_fans": int(snap.get("idle_fans_earned", 0)),
					"title": str(snap.get("title", "")),
					"runId": "post-fix",
				})
		#endregion


func _default_banner_status_text(mode: String, snap: Dictionary) -> String:
	var title: String = str(snap.get("title", ""))
	var short_title := title if title.length() <= 12 else title.substr(0, 12) + "..."
	var disp_fp: int = int(snap.get("display_fp", 0))
	var disp_fans: int = int(snap.get("display_fans", 0))
	match mode:
		"exposing":
			var remain: float = float(snap.get("remaining_sec", -1.0))
			if remain >= 0.0 and not short_title.is_empty():
				return "《%s》曝光中 %d秒" % [short_title, int(ceil(remain))]
			if not short_title.is_empty():
				return "《%s》正在曝光中..." % short_title
			return "帖子正在曝光中..."
		"hot_success":
			if not short_title.is_empty():
				return "《%s》热帖中 积分+%d 粉丝+%d" % [short_title, disp_fp, disp_fans]
			return "成为今日热帖 放置收益中..."
		"hot_fail":
			return "推流中 积分+%d 粉丝+%d" % [disp_fp, disp_fans]
		"new_replaced":
			if not short_title.is_empty():
				return "《%s》正在置顶曝光中" % short_title
			return "置顶帖已更新"
		_:
			return ""


func _on_banner_state_changed() -> void:
	if _shows_banner_dynamic_overlay():
		_update_unified_banner_text()


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
	if _bag_panel == null:
		return
	_refresh_bag_panel()
	_bag_panel.visible = not _bag_panel.visible


func _refresh_bag_panel() -> void:
	if _bag_grid == null:
		return
	for c in _bag_grid.get_children():
		c.queue_free()
	var inv: InventoryManager = get_node_or_null("/root/InventoryManagerSingleton") as InventoryManager
	if inv == null:
		return
	var entries: Array = inv.get_display_entries()
	if entries.is_empty():
		var tip := Label.new()
		tip.text = "背包为空"
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_bag_grid.add_child(tip)
		return
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(88, 52)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.92, 0.9, 0.98, 1)
		cs.corner_radius_top_left = 4
		cs.corner_radius_top_right = 4
		cs.corner_radius_bottom_left = 4
		cs.corner_radius_bottom_right = 4
		cell.add_theme_stylebox_override("panel", cs)
		var lbl := Label.new()
		lbl.text = "%s\n×%d" % [str(entry.get("name", "")), int(entry.get("count", 0))]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 11)
		cell.add_child(lbl)
		_bag_grid.add_child(cell)


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
	var locked_color := Color(0.78, 0.76, 0.82, 0.55)
	for tab_id: String in _tab_buttons.keys():
		var btn: Button = _tab_buttons[tab_id]
		var on: bool = _active_tab == tab_id
		btn.add_theme_font_size_override("font_size", 18 if on else 16)
		if _opening_post_lock and tab_id != TAB_ACCOUNT:
			btn.disabled = true
			btn.add_theme_color_override("font_color", locked_color)
		else:
			btn.disabled = false
			btn.add_theme_color_override("font_color", active_color if on else inactive_color)


func _clear_list_box() -> void:
	if _list_box == null:
		return
	var kids: Array = _list_box.get_children()
	for c in kids:
		_list_box.remove_child(c)
		c.queue_free()


func refresh_feed(play_reveal: bool = false) -> void:
	_load_json()
	_update_currency_hud()
	if _list_box == null:
		return
	_reveal_run_id += 1
	var run_id := _reveal_run_id
	_clear_list_box()
	#region agent log
	if _active_tab in [TAB_FANDOM, TAB_SISTER, TAB_ACCOUNT]:
		_dbg_c195("E", "feed_page.gd:refresh_feed", "refresh_feed called", {
			"play_reveal": play_reveal,
			"active_tab": _active_tab,
			"run_id": run_id,
		})
	#endregion

	match _active_tab:
		TAB_ARTIST:
			_refresh_artist_tab()
		TAB_FANDOM, TAB_SISTER, TAB_ACCOUNT:
			var tabtype: int = _exposure_tabtype_for_name(_active_tab)
			_refresh_instance_tab(tabtype)
			call_deferred("_relayout_scroll")
			if play_reveal:
				call_deferred("_play_pending_reveals", tabtype, run_id)
		TAB_MARKET:
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

	var chapter_levels: Array = chapter_manager.get_levels_for_chapter(1)
	var levels_sorted: Array = chapter_levels.duplicate()
	levels_sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order", 0)) < int(b.get("order", 0))
	)
	var unlocked_ids: Dictionary = {}
	var next_locked_id := ""
	for level_raw in levels_sorted:
		if not (level_raw is Dictionary):
			continue
		var level: Dictionary = level_raw as Dictionary
		var lid: String = str(level.get("levelid", ""))
		if lid.is_empty():
			continue
		if _is_level_playable(level, 1, chapter_levels, save_manager, chapter_manager):
			unlocked_ids[lid] = true
		elif next_locked_id.is_empty():
			next_locked_id = lid

	var enriched: Array = []
	for item in _posts_raw:
		if not (item is Dictionary):
			continue
		var post: Dictionary = (item as Dictionary).duplicate(true)
		if int(post.get("type", 0)) != TYPE_ARTIST:
			continue
		var level_id: String = str(post.get("level_id", ""))
		var is_unlocked := unlocked_ids.has(level_id)
		var is_next_locked := level_id == next_locked_id and not next_locked_id.is_empty()
		if not is_unlocked and not is_next_locked:
			continue
		var e: Dictionary = _enrich_post(post, chapter_manager)
		if e.is_empty():
			continue
		e["_locked"] = is_next_locked and not is_unlocked
		enriched.append(e)

	_sort_artist_list(enriched, save_manager, chapter_manager)

	if enriched.is_empty():
		var tip := Label.new()
		tip.text = "暂无艺人动态"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_list_box.add_child(tip)
		return

	for e in enriched:
		var card: Node = CARD_SCENE.instantiate()
		if card is Control:
			(card as Control).custom_minimum_size.x = _get_active_list_rect().size.x
			if bool(e.get("_locked", false)):
				(card as Control).modulate = Color(1, 1, 1, 0.55)
		_list_box.add_child(card)
		_bind_card_scroll_input(card)
		if card.has_method("setup"):
			var view: Dictionary = _card_view_dict(e)
			if bool(e.get("_locked", false)):
				view["text"] = "（未解锁）" + str(view.get("text", ""))
			card.call("setup", view)
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
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if tabtype == TABTYPE_ACCOUNT:
		_refresh_account_mypost_list(expose, sm)
		return
	## 规则详述：饭圈动态置顶展示正在曝光/热门的我的帖
	var pinned_my := 0
	if tabtype == TABTYPE_FANDOM:
		pinned_my = _append_fandom_pinned_myposts(expose)
	var instances: Array = expose.get_instances_for_tab(tabtype)
	var pending_count := 0
	if sm != null:
		pending_count = sm.feed_pending.size()
	#region agent log
	_dbg67("F,G", "feed_page.gd:_refresh_instance_tab", "refresh fandom/sister tab", {
		"active_tab": _active_tab,
		"tabtype": tabtype,
		"instances_count": instances.size(),
		"pinned_my_count": pinned_my,
		"queue_size": sm.mypost_queue.size() if sm != null else -1,
		"feed_instances_total": sm.feed_instances.size() if sm != null else -1,
		"feed_pending_total": pending_count,
		"runId": "post-fix",
	})
	#endregion
	for inst in instances:
		if not (inst is Dictionary):
			continue
		var inst_dict: Dictionary = inst as Dictionary
		var tpl: Dictionary = expose.get_template(str(inst_dict.get("postid", "")))
		var card: Node = CARD_SCENE.instantiate()
		if card is Control:
			(card as Control).custom_minimum_size.x = _get_active_list_rect().size.x
		_list_box.add_child(card)
		_bind_card_scroll_input(card)
		if card.has_method("setup"):
			card.call("setup", _instance_card_view_dict(inst_dict, tpl, fp_side))
		if card is Node:
			(card as Node).set_meta("instance_id", str(inst_dict.get("instanceid", "")))
		var inst_bind: Dictionary = inst_dict.duplicate(true)
		var tpl_bind: Dictionary = tpl.duplicate(true)
		if card.has_signal("like_pressed"):
			card.like_pressed.connect(func(anchor_global: Vector2) -> void:
				_on_instance_like_pressed(inst_bind, tpl_bind, card, anchor_global)
			)
		if card.has_signal("pin_toggled"):
			card.pin_toggled.connect(func(is_pinned: bool) -> void:
				if is_pinned:
					_on_instance_fav_pressed(inst_bind, tpl_bind, card)
			)

	#region agent log
	_dbg67("F,G", "feed_page.gd:_refresh_instance_tab", "fandom/sister list rendered", {
		"tabtype": tabtype,
		"list_child_count": _list_box.get_child_count() if _list_box != null else -1,
		"pinned_my_count": pinned_my,
		"instances_count": instances.size(),
		"runId": "post-fix",
	})
	#endregion
	if _list_box.get_child_count() == 0:
		#region agent log
		_dbg67("D", "feed_page.gd:_refresh_instance_tab", "empty list tip shown", {
			"tabtype": tabtype,
			"queue_size": sm.mypost_queue.size() if sm != null else -1,
			"feed_pending_total": pending_count,
			"runId": "post-fix",
		})
		#endregion
		var tip := Label.new()
		tip.text = "暂无帖子，下拉刷新试试" if tabtype == TABTYPE_FANDOM else "暂无放置帖子"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_list_box.add_child(tip)


func _is_sticky_mypost(item: Dictionary) -> bool:
	var state: String = str(item.get("state", ""))
	if state == "exposing":
		return true
	return state == "collected" and bool(item.get("is_pinned", false)) and int(item.get("hotresult", -1)) == 1


func _append_fandom_pinned_myposts(expose: ExposeManager) -> int:
	## 饭圈：我的帖排序靠前，随列表一起滚动（不吸顶）
	var queue: Array = expose.get_mypost_queue().duplicate()
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _mypost_sort_before(a, b)
	)
	var shown := 0
	for item_raw in queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		var state: String = str(item.get("state", ""))
		if state != "exposing" and state != "collected":
			continue
		shown += _add_mypost_card_to_parent(item, expose, _is_sticky_mypost(item))
	#region agent log
	_dbg_c195("G", "feed_page.gd:_append_fandom_pinned_myposts", "myposts in scroll list", {
		"list_children": _list_box.get_child_count() if _list_box != null else -1,
		"shown_myposts": shown,
		"runId": "pin-revert",
	})
	#endregion
	return shown


func _add_mypost_card_to_parent(item: Dictionary, expose: ExposeManager, is_sticky: bool) -> int:
	if _list_box == null:
		return 0
	var mypostid: String = str(item.get("mypostid", ""))
	var def: Dictionary = {}
	if expose.has_method("get_my_post"):
		def = expose.get_my_post(mypostid)
	var card: Node = CARD_SCENE.instantiate()
	if card is Control:
		(card as Control).custom_minimum_size.x = _get_active_list_rect().size.x
	_list_box.add_child(card)
	var view: Dictionary = _mypost_queue_card_view_dict(item, def)
	view["is_pinned"] = is_sticky or _is_sticky_mypost(item)
	if card.has_method("setup"):
		card.call("setup", view)
	if card is Node:
		(card as Node).set_meta("queue_id", str(item.get("queue_id", "")))
		(card as Node).set_meta("mypostid", mypostid)
	if card.has_signal("like_pressed"):
		card.like_pressed.connect(func(anchor_global: Vector2) -> void:
			if expose.has_method("add_heat"):
				expose.add_heat("like")
			_play_heart_effect(card, anchor_global)
			_update_unified_banner_text()
		)
	_bind_card_scroll_input(card)
	return 1


func _bind_card_scroll_input(card: Node) -> void:
	if not (card is Control):
		return
	var cc := card as Control
	if cc.gui_input.is_connected(_on_scroll_gui_input):
		return
	cc.gui_input.connect(_on_scroll_gui_input)


func _mypost_sort_before(a: Dictionary, b: Dictionary) -> bool:
	var ra: Array = _mypost_list_rank(a)
	var rb: Array = _mypost_list_rank(b)
	if int(ra[0]) != int(rb[0]):
		return int(ra[0]) < int(rb[0])
	return int(ra[1]) < int(rb[1])


func _mypost_list_rank(item: Dictionary) -> Array:
	var state: String = str(item.get("state", ""))
	var hot_pin := state == "collected" and bool(item.get("is_pinned", false)) and int(item.get("hotresult", -1)) == 1
	var tier := 2
	if state == "exposing":
		tier = 0
	elif hot_pin:
		tier = 1
	var ts: int = int(item.get("posted_ts", 0))
	if ts <= 0:
		ts = int(item.get("expose_start_ts", 0))
	return [tier, -ts]


func _refresh_account_mypost_list(expose: ExposeManager, sm: SaveManager) -> void:
	var queue: Array = expose.get_mypost_queue().duplicate()
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _mypost_sort_before(a, b)
	)
	#region agent log
	_dbg67("A,C,D", "feed_page.gd:_refresh_account_mypost_list", "refresh account queue list", {
		"active_tab": _active_tab,
		"queue_size": queue.size(),
		"runId": "post-fix",
	})
	#endregion
	for item_raw in queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		var mypostid: String = str(item.get("mypostid", ""))
		var def: Dictionary = {}
		if expose.has_method("get_my_post"):
			def = expose.get_my_post(mypostid)
		var card: Node = CARD_SCENE.instantiate()
		if card is Control:
			(card as Control).custom_minimum_size.x = _get_active_list_rect().size.x
		_list_box.add_child(card)
		_bind_card_scroll_input(card)
		if card.has_method("setup"):
			card.call("setup", _mypost_queue_card_view_dict(item, def))
		if card is Node:
			(card as Node).set_meta("queue_id", str(item.get("queue_id", "")))
			(card as Node).set_meta("mypostid", mypostid)
		if card.has_signal("like_pressed"):
			card.like_pressed.connect(func(anchor_global: Vector2) -> void:
				if expose.has_method("add_heat"):
					expose.add_heat("like")
				_play_heart_effect(card, anchor_global)
				_update_unified_banner_text()
			)
	#region agent log
	_dbg67("A,D", "feed_page.gd:_refresh_account_mypost_list", "account list rendered", {
		"queue_size": queue.size(),
		"list_child_count": _list_box.get_child_count() if _list_box != null else -1,
		"runId": "post-fix",
	})
	#endregion
	if _list_box.get_child_count() == 0:
		#region agent log
		_dbg67("D", "feed_page.gd:_refresh_account_mypost_list", "empty account tip shown", {
			"queue_size": queue.size() if sm != null else -1,
			"runId": "post-fix",
		})
		#endregion
		var tip := Label.new()
		tip.text = "暂无我的帖子，选择标签发布"
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_list_box.add_child(tip)


func _mypost_queue_card_view_dict(item: Dictionary, def: Dictionary) -> Dictionary:
	var state: String = str(item.get("state", ""))
	var state_label := "曝光中"
	if state == "collected":
		if int(item.get("hotresult", -1)) == 1:
			state_label = "热帖中"
		else:
			state_label = "推流中"
	elif state == "exposing":
		state_label = "曝光中"
	return {
		"layout": "fans",
		"artist_name": str(def.get("title", item.get("title", item.get("mypostid", "")))),
		"time_display": state_label,
		"text": str(def.get("text", "")),
		"image_path": str(def.get("imagepath", "")),
		"avatar_path": str(def.get("avatarpath", "")),
		"is_pinned": bool(item.get("is_pinned", false)),
	}


func _instance_card_view_dict(inst: Dictionary, tpl: Dictionary, _fp_side: bool) -> Dictionary:
	var time_display := ""
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	var iid: String = str(inst.get("instanceid", ""))
	if expose != null and expose.has_method("get_post_display_date"):
		time_display = str(expose.call("get_post_display_date", iid))
	var collected := _is_instance_keypost_collected(inst, tpl)
	#region agent log
	if _resolve_tpl_postclass(tpl) == 3:
		var sm_log: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
		_dbg_c195("F", "feed_page.gd:_instance_card_view_dict", "keypost restore state", {
			"instanceid": iid,
			"keypostcollected": bool(inst.get("keypostcollected", false)),
			"in_favorites": sm_log.favorites.has(iid) if sm_log != null else false,
			"is_pinned_render": collected,
			"keypost_progress": sm_log.keypost_progress if sm_log != null else -1,
			"runId": "keypost-restore",
		})
	#endregion
	return {
		"layout": "fans",
		"artist_name": str(tpl.get("title", inst.get("postid", ""))),
		"time_display": time_display,
		"text": str(tpl.get("text", "")),
		"image_path": str(tpl.get("imagepath", "")),
		"avatar_path": str(tpl.get("avatarpath", "")),
		"is_pinned": collected,
	}


func _is_instance_keypost_collected(inst: Dictionary, tpl: Dictionary) -> bool:
	if _resolve_tpl_postclass(tpl) != 3:
		return false
	if bool(inst.get("keypostcollected", false)):
		return true
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return false
	return sm.favorites.has(str(inst.get("instanceid", "")))


func _play_pending_reveals(tabtype: int, run_id: int = -1) -> void:
	if run_id >= 0 and run_id != _reveal_run_id:
		return
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose == null or _list_box == null:
		return
	var ids: Array = expose.take_pending_reveal_ids(tabtype)
	if ids.is_empty():
		return
	if _scroll != null:
		_scroll.scroll_vertical = 0
		_scroll.clip_contents = true
	await get_tree().process_frame
	if run_id >= 0 and run_id != _reveal_run_id:
		return
	var pending: Dictionary = {}
	for iid in ids:
		pending[str(iid)] = true
	var targets: Array[Control] = []
	for child in _list_box.get_children():
		if not (child is Control):
			continue
		if not is_instance_valid(child):
			continue
		var iid: String = str((child as Node).get_meta("instance_id", ""))
		if iid.is_empty() or not pending.has(iid):
			continue
		targets.append(child as Control)
	var order := 0
	for card in targets:
		var slide_h: float = _reveal_slide_height(card)
		var wrapper := _wrap_card_for_reveal_slide(card, slide_h)
		card.position = Vector2(0.0, -slide_h)
		#region agent log
		if order == 0:
			_dbg_c195("I", "feed_page.gd:_play_pending_reveals", "reveal start boundary", {
				"scroll_top": _scroll.global_position.y if _scroll != null else -1.0,
				"wrapper_global_y": wrapper.global_position.y if wrapper != null else -1.0,
				"slide_h": slide_h,
				"runId": "pin-revert",
			})
		#endregion
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(float(order) * 0.32)
		tw.tween_property(card, "position:y", 0.0, 0.36)
		order += 1
	if order > 0:
		var wait_sec: float = float(order - 1) * 0.32 + 0.38
		await get_tree().create_timer(wait_sec).timeout
		if run_id >= 0 and run_id != _reveal_run_id:
			return
		_update_unified_banner_text()
		_update_currency_hud()


func _reveal_slide_height(card: Control) -> float:
	var h: float = card.size.y
	if h <= 0.0:
		h = card.get_combined_minimum_size().y
	if h <= 0.0:
		h = card.custom_minimum_size.y
	return maxf(h, 1.0)


func _wrap_card_for_reveal_slide(card: Control, slide_h: float) -> Control:
	card.scale = Vector2.ONE
	card.modulate = Color.WHITE
	card.pivot_offset = Vector2.ZERO
	var parent := card.get_parent()
	if parent == null:
		return card
	var idx := card.get_index()
	var wrapper := Control.new()
	wrapper.clip_contents = true
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.custom_minimum_size = Vector2(card.custom_minimum_size.x, slide_h)
	parent.remove_child(card)
	parent.add_child(wrapper)
	parent.move_child(wrapper, idx)
	wrapper.add_child(card)
	card.position = Vector2.ZERO
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return wrapper


func _on_lump_granted(_tabtype: int, _grant_type: int, _amount: int) -> void:
	## idle/结算发奖只刷新 HUD/banner，避免在信号栈里拆列表
	_update_currency_hud()
	if _shows_banner_dynamic_overlay():
		_update_unified_banner_text()


func _on_intel_level_up(_new_level: int) -> void:
	_update_currency_hud()
	_update_unified_banner_text()
	if _active_tab == TAB_FANDOM:
		_play_intel_level_flash()
	else:
		var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
		if expose != null:
			expose.consume_pending_intel_level_up()
	call_deferred("_deferred_refresh_feed", true)


func _on_instance_changed() -> void:
	#region agent log
	_dbg_c195("E", "feed_page.gd:_on_instance_changed", "deferred refresh with slide", {
		"active_tab": _active_tab,
		"play_reveal_arg": true,
		"runId": "post-fix",
	})
	#endregion
	## 延后刷新：避免收藏/发帖信号栈内 free 导致 locked；并播放滑出
	call_deferred("_deferred_refresh_feed", true)


func _deferred_refresh_feed(play_reveal: bool = false) -> void:
	refresh_feed(play_reveal)


func _update_currency_hud() -> void:
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return
	if _fp_label != null:
		_fp_label.text = "饭圈积分 %d" % sm.fp
	if _stars_label != null:
		_stars_label.text = "星星 %d" % sm.stars
	if _intel_level_label != null:
		_intel_level_label.text = "线索 Lv.%d" % sm.intellevel


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
		_show_toast(msg)
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
	if _scroll == null:
		return
	var max_v := 0
	if _scroll.get_v_scroll_bar() != null:
		max_v = int(_scroll.get_v_scroll_bar().max_value)
	#region agent log
	if event is InputEventMouseButton:
		var mb_probe := event as InputEventMouseButton
		if mb_probe.pressed and mb_probe.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_LEFT]:
			_dbg_c195("D", "feed_page.gd:_on_scroll_gui_input", "scroll input received", {
				"button": mb_probe.button_index,
				"max_scroll": max_v,
				"scroll_vertical": _scroll.scroll_vertical,
				"source": str(get_viewport().gui_get_focus_owner().name) if get_viewport().gui_get_focus_owner() != null else "",
				"runId": "post-fix",
			})
	#endregion
	var scrolled_down := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			scrolled_down = true
			_apply_scroll_wheel(48)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_apply_scroll_wheel(-48)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_manual_dragging = mb.pressed
	elif event is InputEventMouseMotion and _manual_dragging:
		var mm := event as InputEventMouseMotion
		if mm.relative.y > 0.5:
			scrolled_down = true
		var next_v: float = _scroll.scroll_vertical - mm.relative.y
		_scroll.scroll_vertical = clampi(int(next_v), 0, max_v)
		_dbg_log_sticky_scroll("drag")
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_manual_dragging = st.pressed
	elif event is InputEventScreenDrag and _manual_dragging:
		var sd := event as InputEventScreenDrag
		if sd.relative.y > 0.5:
			scrolled_down = true
		var next_v_touch: float = _scroll.scroll_vertical - sd.relative.y
		var max_v_touch: int = 0
		if _scroll.get_v_scroll_bar() != null:
			max_v_touch = int(_scroll.get_v_scroll_bar().max_value)
		_scroll.scroll_vertical = clampi(int(next_v_touch), 0, max_v_touch)
		_dbg_log_sticky_scroll("touch")

	if scrolled_down and not _scroll_started and _active_tab == TAB_FANDOM:
		var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
		if expose == null:
			return
		_scroll_started = true
		if expose.has_method("refresh_feed_on_tab"):
			expose.call("refresh_feed_on_tab", TABTYPE_FANDOM)
		refresh_feed(true)


func _apply_scroll_wheel(delta_y: float) -> void:
	if _scroll == null:
		return
	var max_v := 0
	if _scroll.get_v_scroll_bar() != null:
		max_v = int(_scroll.get_v_scroll_bar().max_value)
	_scroll.scroll_vertical = clampi(int(_scroll.scroll_vertical + delta_y), 0, max_v)
	_dbg_log_sticky_scroll("wheel")


func _dbg_log_sticky_scroll(reason: String) -> void:
	#region agent log
	if _scroll == null or _active_tab != TAB_FANDOM:
		return
	var sig := "%d|%s" % [_scroll.scroll_vertical, reason]
	if sig == _dbg_scroll_sig:
		return
	_dbg_scroll_sig = sig
	_dbg_c195("G", "feed_page.gd:_dbg_log_sticky_scroll", "scroll drag/wheel", {
		"reason": reason,
		"scroll_vertical": _scroll.scroll_vertical,
		"runId": "pin-revert",
	})
	#endregion


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


func _refresh_compose_area() -> void:
	if _tag_row == null or _publish_btn == null:
		return
	if _active_tab != TAB_ACCOUNT:
		return
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose == null:
		return
	for c in _tag_row.get_children():
		c.queue_free()
	_tag_buttons.clear()
	var tags: Array = expose.get_post_tags()
	_tag_row.visible = not tags.is_empty()
	var has_selected := false
	for item in tags:
		if not (item is Dictionary):
			continue
		var tag: Dictionary = item as Dictionary
		var tagid: String = str(tag.get("tagid", ""))
		if tagid.is_empty():
			continue
		var btn := Button.new()
		btn.text = "%s(%d)" % [str(tag.get("name", tagid)), int(tag.get("count", 0))]
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void: _on_tag_pressed(tagid))
		_tag_row.add_child(btn)
		_tag_buttons[tagid] = btn
		if tagid == _selected_tagid:
			has_selected = true
	if tags.is_empty():
		_selected_tagid = ""
		_preview_mypostid = ""
		if _compose_input != null:
			_compose_input.text = ""
			_compose_input.placeholder_text = "发帖次数不足，请参加线下活动"
		_publish_btn.disabled = true
		return
	if not has_selected:
		_selected_tagid = ""
		_preview_mypostid = ""
		if _compose_input != null:
			_compose_input.text = ""
			_compose_input.placeholder_text = "选择标签后预览帖子内容..."
	_publish_btn.disabled = _preview_mypostid.is_empty()


func _on_tag_pressed(tagid: String) -> void:
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose == null or tagid.is_empty():
		return
	_selected_tagid = tagid
	var preview: Dictionary = expose.preview_tag_post(tagid)
	_preview_mypostid = str(preview.get("mypostid", ""))
	if _compose_input != null:
		if _preview_mypostid.is_empty():
			_compose_input.text = ""
		else:
			_compose_input.text = "%s\n\n%s" % [str(preview.get("title", "")), str(preview.get("text", ""))]
	for tid: String in _tag_buttons.keys():
		var btn: Button = _tag_buttons[tid]
		btn.add_theme_color_override("font_color", Color(0.35, 0.18, 0.55, 1) if tid == tagid else Color(0.45, 0.42, 0.52, 1))
	_publish_btn.disabled = _preview_mypostid.is_empty()


func _on_publish_pressed() -> void:
	if _selected_tagid.is_empty() or _preview_mypostid.is_empty():
		_show_toast("请先选择标签并预览帖子")
		return
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if expose == null:
		_show_toast("发帖功能未就绪")
		return
	var was_opening := sm != null and not bool(sm.opening_done)
	var res: Dictionary = expose.post_with_tag(_selected_tagid, _preview_mypostid)
	#region agent log
	_dbg67("A,E", "feed_page.gd:_on_publish_pressed", "publish result", {
		"ok": bool(res.get("ok", false)),
		"reason": str(res.get("reason", "")),
		"preview_mypostid": _preview_mypostid,
		"queue_size_after": sm.mypost_queue.size() if sm != null else -1,
		"feed_instances_after": sm.feed_instances.size() if sm != null else -1,
		"active_tab": _active_tab,
		"queue_head_mypostid": str((sm.mypost_queue[0] as Dictionary).get("mypostid", "")) if sm != null and sm.mypost_queue.size() > 0 else "",
	})
	#endregion
	if not bool(res.get("ok", false)):
		_show_toast(str(res.get("reason", "发帖失败")))
		return
	_selected_tagid = ""
	_preview_mypostid = ""
	if expose.has_method("clear_preview_cursor"):
		expose.clear_preview_cursor()
	if _compose_input != null:
		_compose_input.text = ""
	_refresh_compose_area()
	_refresh_banner_area()
	_update_currency_hud()
	refresh_feed(true)
	#region agent log
	_dbg67("B,E", "feed_page.gd:_on_publish_pressed", "after refresh_feed", {
		"active_tab": _active_tab,
		"list_child_count": _list_box.get_child_count() if _list_box != null else -1,
	})
	#endregion
	if was_opening and sm != null and bool(sm.opening_done):
		_notify_opening_post_done()


func _dbg67(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	#region agent log
	var payload := {
		"sessionId": "67dfb8",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"runId": str(data.get("runId", "pre-fix")),
	}
	var paths: PackedStringArray = [
		"res://../debug-67dfb8.log",
		"user://debug-67dfb8.log",
		"D:/GAMES/pubble-v1/debug-67dfb8.log",
		"C:/Users/sameen/.cursor/projects/C-Users-sameen-AppData-Local-Temp-80478286-4eb1-464b-83ec-c5356a96a167/debug-67dfb8.log",
	]
	var line := JSON.stringify(payload)
	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
		if f == null:
			continue
		f.seek_end()
		f.store_line(line)
		f.close()
	#endregion


func _dbg_c195(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	#region agent log
	var payload := {
		"sessionId": "c195b4",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000),
		"runId": str(data.get("runId", "pre-fix")),
	}
	var paths: PackedStringArray = [
		"D:/GAMES/pubble-v1/debug-c195b4.log",
		"C:/Users/sameen/.cursor/projects/C-Users-sameen-AppData-Local-Temp-a9f83106-70af-4714-a6b8-6f5a37772cf3/debug-c195b4.log",
		"user://debug-c195b4.log",
	]
	var line := JSON.stringify(payload)
	for p in paths:
		var f := FileAccess.open(p, FileAccess.READ_WRITE if FileAccess.file_exists(p) else FileAccess.WRITE)
		if f == null:
			continue
		f.seek_end()
		f.store_line(line)
		f.close()
	#endregion


func _notify_opening_post_done() -> void:
	var node: Node = self
	while node != null:
		if node.has_method("clear_pending_first_post"):
			node.call("clear_pending_first_post")
			return
		node = node.get_parent()


func _on_instance_like_pressed(inst: Dictionary, _tpl: Dictionary, card: Node, anchor_global: Vector2) -> void:
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose != null and expose.has_method("add_heat"):
		var iid: String = str(inst.get("instanceid", ""))
		if expose.get_method_argument_count("add_heat") >= 2:
			expose.call("add_heat", "like", iid)
		else:
			expose.call("add_heat", "like")
	_play_heart_effect(card, anchor_global)
	_update_unified_banner_text()


func _on_instance_fav_pressed(inst: Dictionary, tpl: Dictionary, card: Node) -> void:
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose == null:
		return
	var iid: String = str(inst.get("instanceid", ""))
	#region agent log
	_dbg_c195("F", "feed_page.gd:_on_instance_fav_pressed", "keypost fav click", {
		"instanceid": iid,
		"postclass": int(tpl.get("postclass", 1)),
		"postid": str(tpl.get("postid", inst.get("postid", ""))),
		"runId": "post-fix",
	})
	#endregion
	if expose.has_method("add_heat"):
		if expose.get_method_argument_count("add_heat") >= 2:
			expose.call("add_heat", "fav", iid)
		else:
			expose.call("add_heat", "fav")
	var postclass: int = int(tpl.get("postclass", 1))
	if postclass == 3 or _resolve_tpl_postclass(tpl) == 3:
		var ok := false
		if expose.has_method("favorite_instance"):
			ok = bool(expose.call("favorite_instance", iid))
		elif card.has_method("set_pinned"):
			card.call("set_pinned", true)
			ok = true
		if ok and card.has_method("set_pinned"):
			card.call("set_pinned", true)
		var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
		if sm != null and ok:
			var target: int = 0
			var eco: EconomyManager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
			if eco != null:
				target = eco.get_keypost_target()
			if target > 0:
				_show_toast("找到关键线索帖 %d/%d" % [sm.keypost_progress, target])
	_update_unified_banner_text()
	_update_currency_hud()


func _resolve_tpl_postclass(tpl: Dictionary) -> int:
	if tpl.has("postclass"):
		return int(tpl.get("postclass", 1))
	## 兼容旧表：嫂子站且有情报产出的当关键帖
	if int(tpl.get("tabtype", 0)) == TABTYPE_SISTER and int(tpl.get("grantintel", 0)) > 0:
		return 3
	return 1
