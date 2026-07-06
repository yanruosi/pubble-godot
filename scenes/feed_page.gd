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
const TAB_SQUARE := "square"
const TAB_SISTER := "sister"
const TABTYPE_SQUARE := 0
const TABTYPE_SISTER := 903

const DESIGN_W := 1280.0
const DESIGN_H := 720.0
const TAB_X := 286.0
const TAB_Y := 17.0
const TAB_W := 707.0
const TAB_H := 64.0
const LIST_X := 288.0
const LIST_Y := 130.0
const LIST_W := 701.0
const BACK_BTN_SIZE := Vector2(36, 36)

var _active_tab: String = TAB_ARTIST
var _posts_raw: Array = []
var _tab_artist: Button
var _tab_square: Button
var _tab_sister: Button
var _tab_bar: PanelContainer
var _list_box: VBoxContainer
var _scroll: ScrollContainer
var _content_root: Control
var _manual_dragging: bool = false
var _love_effect_tex: Texture2D
var _banner_bar: ProgressBar
var _currency_label: Label
var _prev_tabtype: int = -1

func _ready() -> void:
	_load_json()
	_love_effect_tex = _load_tex(PATH_LOVE)
	call_deferred("_build_ui")
	call_deferred("refresh_feed")


func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


func set_active_tab(tab: String) -> void:
	var normalized := tab.to_lower()
	if normalized not in [TAB_ARTIST, TAB_SQUARE, TAB_SISTER]:
		normalized = TAB_ARTIST
	if _prev_tabtype >= 0:
		var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
		if expose != null:
			expose.on_tab_left()
	_prev_tabtype = _tabtype_for_name(normalized)
	_active_tab = normalized
	if _tab_artist != null:
		_set_tab_visual()
		_start_banner_for_current_tab()
	refresh_feed()
	var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
	if tutor != null:
		tutor.notify_tab_opened(normalized)


func _tabtype_for_name(tab: String) -> int:
	match tab:
		TAB_SQUARE:
			return TABTYPE_SQUARE
		TAB_SISTER:
			return TABTYPE_SISTER
		_:
			return -1


func _start_banner_for_current_tab() -> void:
	var tabtype := _tabtype_for_name(_active_tab)
	if tabtype < 0:
		return
	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose != null:
		expose.start_active_timer(tabtype)


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
		# 手动 position 的控件必须显式设 size，否则仍按纹理原尺寸 122×124 绘制
		back_btn.ignore_texture_size = true
		back_btn.custom_minimum_size = BACK_BTN_SIZE
		back_btn.size = BACK_BTN_SIZE
		back_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		back_btn.focus_mode = Control.FOCUS_NONE
		back_btn.pressed.connect(func() -> void: feed_back_requested.emit())
		_content_root.add_child(back_btn)

	_tab_bar = _build_tab_bar()
	_content_root.add_child(_tab_bar)

	_currency_label = Label.new()
	_currency_label.position = Vector2(900, 12)
	_currency_label.add_theme_font_size_override("font_size", 14)
	_content_root.add_child(_currency_label)

	var banner_panel := PanelContainer.new()
	banner_panel.position = Vector2(TAB_X, 88)
	banner_panel.custom_minimum_size = Vector2(TAB_W, 32)
	_content_root.add_child(banner_panel)
	_banner_bar = ProgressBar.new()
	_banner_bar.custom_minimum_size = Vector2(TAB_W - 20, 24)
	_banner_bar.max_value = 1.0
	_banner_bar.show_percentage = false
	banner_panel.add_child(_banner_bar)

	var expose: ExposeManager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	if expose != null and not expose.banner_progress_changed.is_connected(_on_banner_progress):
		expose.banner_progress_changed.connect(_on_banner_progress)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(LIST_X, LIST_Y)
	_scroll.size = Vector2(LIST_W, maxf(100.0, size.y - LIST_Y))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.gui_input.connect(_on_scroll_gui_input)
	_content_root.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 16)
	_list_box.custom_minimum_size.x = LIST_W
	_scroll.add_child(_list_box)
	_set_tab_visual()
	_update_currency_hud()


func _on_banner_progress(tabtype: int, ratio: float) -> void:
	if _banner_bar == null:
		return
	if tabtype != _tabtype_for_name(_active_tab):
		return
	_banner_bar.value = ratio


func _update_currency_hud() -> void:
	if _currency_label == null:
		return
	var sm: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		return
	_currency_label.text = "fp:%d  intel:%d  ★:%d  Lv:%d/%d" % [
		sm.fp, sm.intel, sm.stars, sm.intellevel, sm.fanlevel
	]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _scroll != null:
		_scroll.size = Vector2(LIST_W, maxf(100.0, size.y - LIST_Y))


func _build_tab_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = Vector2(TAB_X, TAB_Y)
	panel.custom_minimum_size = Vector2(TAB_W, TAB_H)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 1)
	ps.corner_radius_top_left = 8
	ps.corner_radius_top_right = 8
	ps.corner_radius_bottom_right = 8
	ps.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", ps)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 32)
	margin.add_child(tab_row)

	_tab_artist = Button.new()
	_tab_artist.flat = true
	_tab_artist.text = "艺人"
	_tab_artist.focus_mode = Control.FOCUS_NONE
	_tab_artist.pressed.connect(func() -> void: set_active_tab("artist"))
	tab_row.add_child(_tab_artist)

	_tab_sister = Button.new()
	_tab_sister.flat = true
	_tab_sister.text = "嫂子站"
	_tab_sister.focus_mode = Control.FOCUS_NONE
	_tab_sister.pressed.connect(func() -> void: set_active_tab(TAB_SISTER))
	tab_row.add_child(_tab_sister)

	_tab_square = Button.new()
	_tab_square.flat = true
	_tab_square.text = "广场"
	_tab_square.focus_mode = Control.FOCUS_NONE
	_tab_square.pressed.connect(func() -> void: set_active_tab(TAB_SQUARE))
	tab_row.add_child(_tab_square)

	return panel


func _on_feed_tab_changed(_idx: int) -> void:
	pass


func _set_tab_visual() -> void:
	if _tab_artist == null:
		return
	var active := Color(0.17, 0.14, 0.24, 1)
	var inactive := Color(0.55, 0.51, 0.64, 1)
	for pair in [
		[_tab_artist, TAB_ARTIST],
		[_tab_square, TAB_SQUARE],
		[_tab_sister, TAB_SISTER],
	]:
		var btn: Button = pair[0]
		var name: String = pair[1]
		var on := _active_tab == name
		btn.add_theme_font_size_override("font_size", 20 if on else 18)
		btn.add_theme_color_override("font_color", active if on else inactive)


func refresh_feed() -> void:
	_load_json()
	_update_currency_hud()
	if _list_box == null:
		return
	for c in _list_box.get_children():
		c.queue_free()

	if _active_tab == TAB_ARTIST:
		_refresh_artist_tab()
	else:
		_refresh_instance_tab(_tabtype_for_name(_active_tab))


func _refresh_artist_tab() -> void:
	var save_manager: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var chapter_manager: ChapterManager = get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	var condition_checker: ConditionChecker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	#region agent log
	_agent_debug_log("H2", "feed_page.gd:_refresh_artist_tab", "entry", {
		"active_tab": _active_tab,
		"posts_raw_count": _posts_raw.size(),
		"save_ok": save_manager != null,
		"chapter_ok": chapter_manager != null,
		"checker_ok": condition_checker != null,
		"intellevel": save_manager.intellevel if save_manager else -1,
		"fanlevel": save_manager.fanlevel if save_manager else -1,
	})
	#endregion
	if save_manager == null or chapter_manager == null or condition_checker == null:
		#region agent log
		_agent_debug_log("H2", "feed_page.gd:_refresh_artist_tab", "early_return_missing_autoload", {})
		#endregion
		return

	var enriched: Array = []
	for item in _posts_raw:
		if not (item is Dictionary):
			continue
		var post: Dictionary = (item as Dictionary).duplicate(true)
		if int(post.get("type", 0)) != TYPE_ARTIST:
			continue
		var visible: bool = condition_checker.is_feed_post_visible(post)
		#region agent log
		_agent_debug_log("H1", "feed_page.gd:_refresh_artist_tab", "post_filter", {
			"post_id": str(post.get("post_id", "")),
			"condition_id": int(post.get("condition_id", 0)),
			"visible": visible,
		})
		#endregion
		if not visible:
			continue
		var e: Dictionary = _enrich_post(post, chapter_manager)
		if e.is_empty():
			#region agent log
			_agent_debug_log("H4", "feed_page.gd:_refresh_artist_tab", "enrich_failed", {
				"post_id": str(post.get("post_id", "")),
				"level_id": str(post.get("level_id", "")),
			})
			#endregion
			continue
		var chapter_levels: Array = e.get("_chapter_levels", [])
		e["_locked"] = condition_checker.is_feed_post_locked_visible(post, chapter_levels)
		enriched.append(e)

	_sort_artist_list(enriched, save_manager, chapter_manager)
	#region agent log
	_agent_debug_log("H1", "feed_page.gd:_refresh_artist_tab", "result", {
		"enriched_count": enriched.size(),
		"show_empty_tip": enriched.is_empty(),
	})
	#endregion

	if enriched.is_empty():
		var tip := Label.new()
		tip.text = "暂无艺人动态（提升情报等级解锁）"
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_list_box.add_child(tip)
		return

	for e in enriched:
		var card: Node = CARD_SCENE.instantiate()
		if card is Control:
			(card as Control).custom_minimum_size.x = LIST_W
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
	for inst in expose.get_instances_for_tab(tabtype):
		if not (inst is Dictionary):
			continue
		var row: PanelContainer = PanelContainer.new()
		row.custom_minimum_size = Vector2(LIST_W, 72)
		var h := HBoxContainer.new()
		row.add_child(h)
		var tpl: Dictionary = expose.get_template(str(inst.get("postid", "")))
		var title := Label.new()
		title.text = str(tpl.get("title", inst.get("postid", "")))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(title)
		var status := Label.new()
		status.text = str(inst.get("exposestatus", "idle"))
		h.add_child(status)
		var expose_btn := Button.new()
		expose_btn.text = "曝光"
		var iid: String = str(inst.get("instanceid", ""))
		expose_btn.pressed.connect(func() -> void:
			expose.start_expose(iid)
			refresh_feed()
		)
		h.add_child(expose_btn)
		var collect_btn := Button.new()
		collect_btn.text = "收取"
		collect_btn.pressed.connect(func() -> void:
			if expose.collect_instance(iid):
				var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
				if tutor != null:
					tutor.notify_instance_collected()
			refresh_feed()
		)
		h.add_child(collect_btn)
		_list_box.add_child(row)
	if _list_box.get_child_count() == 0:
		var tip := Label.new()
		tip.text = "暂无放置帖子"
		_list_box.add_child(tip)


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


# 从 post_id 提取第一段连续数字，如 fans_12_post → 12
func _extract_fan_post_id_number(post_id: String) -> int:
	var digits := ""
	for i in range(post_id.length()):
		var ch := post_id[i]
		if ch >= "0" and ch <= "9":
			digits += ch
		elif not digits.is_empty():
			break
	if digits.is_empty():
		return 0
	return int(digits)


func _sort_fans_list(items: Array) -> void:
	# 粉丝帖：post_id 数字部分倒序，数字大的在最上面
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var na := _extract_fan_post_id_number(str(a.get("post_id", "")))
		var nb := _extract_fan_post_id_number(str(b.get("post_id", "")))
		if na != nb:
			return na > nb
		return str(a.get("post_id", "")) > str(b.get("post_id", ""))
	)
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
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_manual_dragging = mb.pressed
	elif event is InputEventMouseMotion and _manual_dragging and _scroll != null:
		var mm := event as InputEventMouseMotion
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
		var next_v_touch: float = _scroll.scroll_vertical - sd.relative.y
		var max_v_touch: int = 0
		if _scroll.get_v_scroll_bar() != null:
			max_v_touch = int(_scroll.get_v_scroll_bar().max_value)
		_scroll.scroll_vertical = clampi(int(next_v_touch), 0, max_v_touch)


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


#region agent log
func _agent_debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "580f3e",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"runId": "pre-fix",
	}
	var file := FileAccess.open("res://debug-580f3e.log", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("res://debug-580f3e.log", FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_string(JSON.stringify(payload) + "\n")
	file.close()
#endregion
