extends Control

signal feed_open_level(level: Dictionary)
signal feed_open_level_select(chapter_id: int, focus_level_id: String)

const FEED_JSON_PATH := "res://data/feed_posts.json"
const CARD_SCENE := preload("res://scenes/feed_post_card.tscn")
const EFFECTS_JSON_PATH := "res://data/effects.json"
const DEBUG_LOG_PATH := "D:/GAMES/pubble/debug-fe0741.log"
const DEBUG_TRACE_LOG_PATH := "D:/GAMES/pubble/debug-8f8638.log"
const DEFAULT_BANNER_PATH := "res://art/ui/banner2.png"

## 推荐页 Banner 图；有图时不显示紫底占位。
@export var recommend_banner_texture: Texture2D
@export var banner_height: float = 104.0
@export var banner_margin_top: int = 6
@export var banner_margin_bottom: int = 4
@export var banner_placeholder_color: Color = Color(0.68, 0.58, 0.94, 0.65)
## 4=KEEP_ASPECT, 5=KEEP_ASPECT_CENTERED, 6=KEEP_ASPECT_COVERED（会裁切）
@export var banner_stretch_mode: TextureRect.StretchMode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

## false = 推荐（与原型一致为首 Tab）
var _use_follow_tab: bool = false
var _posts_raw: Array = []
var _root_margin: MarginContainer
var _tab_recommend: Button
var _tab_follow: Button
var _banner_root: MarginContainer
var _banner_art: TextureRect
var _list_box: VBoxContainer
var _scroll: ScrollContainer
var _drag_probe_active: bool = false
var _manual_dragging: bool = false
var _manual_drag_last_y: float = 0.0
var _effects_map: Dictionary = {}

#region agent log
func _dbg(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "run1") -> void:
	var payload := {
		"sessionId": "fe0741",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f: FileAccess = FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		var wf: FileAccess = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
		if wf != null:
			wf.store_string("")
			wf.close()
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion

#region agent log
func _dbg8(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "run1") -> void:
	var payload := {
		"sessionId": "8f8638",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f: FileAccess = FileAccess.open(DEBUG_TRACE_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_TRACE_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion


func _ready() -> void:
	_load_json()
	_load_effects()
	call_deferred("_build_ui")
	call_deferred("refresh_feed")


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


func _load_effects() -> void:
	_effects_map.clear()
	if not FileAccess.file_exists(EFFECTS_JSON_PATH):
		return
	var raw: String = FileAccess.get_file_as_string(EFFECTS_JSON_PATH)
	if raw.is_empty():
		return
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Array):
		return
	for row in parsed:
		if not (row is Dictionary):
			continue
		var id: String = str((row as Dictionary).get("effect_id", ""))
		if id.is_empty():
			continue
		_effects_map[id] = (row as Dictionary).duplicate(true)


func _build_ui() -> void:
	for c in get_children():
		c.queue_free()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(1, 1, 1, 1)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_root_margin = MarginContainer.new()
	_root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_margin.add_theme_constant_override("margin_left", 8)
	_root_margin.add_theme_constant_override("margin_right", 8)
	_root_margin.add_theme_constant_override("margin_top", 10)
	_root_margin.add_theme_constant_override("margin_bottom", 8)
	add_child(_root_margin)

	var outer := VBoxContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("separation", 0)
	_root_margin.add_child(outer)

	var tab_wrap := MarginContainer.new()
	tab_wrap.add_theme_constant_override("margin_bottom", 4)
	outer.add_child(tab_wrap)

	var tab_row := HBoxContainer.new()
	tab_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_theme_constant_override("separation", 24)
	tab_wrap.add_child(tab_row)

	_tab_recommend = Button.new()
	_tab_recommend.flat = true
	_tab_recommend.text = "推荐"
	_tab_recommend.focus_mode = Control.FOCUS_NONE
	_tab_recommend.pressed.connect(func() -> void: _on_feed_tab_changed(0))
	tab_row.add_child(_tab_recommend)

	_tab_follow = Button.new()
	_tab_follow.flat = true
	_tab_follow.text = "关注"
	_tab_follow.focus_mode = Control.FOCUS_NONE
	_tab_follow.pressed.connect(func() -> void: _on_feed_tab_changed(1))
	tab_row.add_child(_tab_follow)
	_set_tab_visual()

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	outer.add_child(_scroll)
	_scroll.gui_input.connect(_on_scroll_gui_input)

	var scroll_inner := VBoxContainer.new()
	scroll_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_theme_constant_override("separation", 14)
	scroll_inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.add_child(scroll_inner)
	if _scroll.get_v_scroll_bar() != null:
		_scroll.get_v_scroll_bar().value_changed.connect(func(v: float) -> void:
			#region agent log
			_dbg("H1", "feed_page.gd:v_scroll_bar", "scroll changed", {"value": v, "max": _scroll.get_v_scroll_bar().max_value})
			#endregion
		)

	_banner_root = _build_banner_block()
	scroll_inner.add_child(_banner_root)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 16)
	scroll_inner.add_child(_list_box)

	if _banner_root != null:
		_banner_root.visible = not _use_follow_tab


func _on_feed_tab_changed(idx: int) -> void:
	_use_follow_tab = idx == 1
	_set_tab_visual()
	if _banner_root != null:
		_banner_root.visible = not _use_follow_tab
	refresh_feed()


func _set_tab_visual() -> void:
	if _tab_recommend == null or _tab_follow == null:
		return
	var active := Color(0.17, 0.14, 0.24, 1)
	var inactive := Color(0.55, 0.51, 0.64, 1)
	_tab_recommend.add_theme_font_size_override("font_size", 20 if not _use_follow_tab else 18)
	_tab_follow.add_theme_font_size_override("font_size", 20 if _use_follow_tab else 18)
	_tab_recommend.add_theme_color_override("font_color", active if not _use_follow_tab else inactive)
	_tab_follow.add_theme_color_override("font_color", active if _use_follow_tab else inactive)


func _build_banner_block() -> MarginContainer:
	var banner_wrap := MarginContainer.new()
	banner_wrap.add_theme_constant_override("margin_top", banner_margin_top)
	banner_wrap.add_theme_constant_override("margin_bottom", banner_margin_bottom)

	_banner_art = TextureRect.new()
	_banner_art.custom_minimum_size = Vector2(0, banner_height)
	_banner_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_art.stretch_mode = banner_stretch_mode
	_banner_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, banner_height)
	panel.clip_contents = true
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0) if recommend_banner_texture != null else banner_placeholder_color
	ps.corner_radius_top_left = 14
	ps.corner_radius_top_right = 14
	ps.corner_radius_bottom_right = 14
	ps.corner_radius_bottom_left = 14
	panel.add_theme_stylebox_override("panel", ps)
	banner_wrap.add_child(panel)
	panel.add_child(_banner_art)
	_banner_art.set_anchors_preset(Control.PRESET_FULL_RECT)

	var banner_tex: Texture2D = recommend_banner_texture
	if banner_tex == null and ResourceLoader.exists(DEFAULT_BANNER_PATH):
		var loaded := load(DEFAULT_BANNER_PATH)
		if loaded is Texture2D:
			banner_tex = loaded as Texture2D
	if banner_tex != null:
		_banner_art.texture = banner_tex
		_banner_art.modulate = Color.WHITE
	else:
		var ph := ColorRect.new()
		ph.set_anchors_preset(Control.PRESET_FULL_RECT)
		ph.color = banner_placeholder_color
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner_art.add_child(ph)
	#region agent log
	_dbg(
		"H4",
		"feed_page.gd:_build_banner_block",
		"banner initialized",
		{
			"has_texture": banner_tex != null,
			"scene_has_export_binding": recommend_banner_texture != null,
			"default_banner_path": DEFAULT_BANNER_PATH,
			"default_exists": ResourceLoader.exists(DEFAULT_BANNER_PATH),
			"banner_height": banner_height,
			"banner_margin_top": banner_margin_top,
			"banner_margin_bottom": banner_margin_bottom,
			"banner_stretch_mode": banner_stretch_mode,
			"stretch_mode": int(_banner_art.stretch_mode),
			"expand_mode": int(_banner_art.expand_mode)
		}
	)
	#endregion

	return banner_wrap


func refresh_feed() -> void:
	_load_json()
	if _list_box == null:
		return
	for c in _list_box.get_children():
		c.queue_free()
	if _banner_root != null:
		_banner_root.visible = not _use_follow_tab
	var save_manager: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var chapter_manager: ChapterManager = get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	if save_manager == null or chapter_manager == null:
		return
	#region agent log
	_dbg(
		"H1",
		"feed_page.gd:refresh_feed",
		"refresh start",
		{
			"use_follow_tab": _use_follow_tab,
			"raw_posts_count": _posts_raw.size()
		}
	)
	#endregion
	var enriched: Array = []
	var bucket_follow: int = 0
	var bucket_recommend: int = 0
	for item in _posts_raw:
		if not (item is Dictionary):
			continue
		var post: Dictionary = (item as Dictionary).duplicate(true)
		var e: Dictionary = _enrich_post(post, chapter_manager, save_manager)
		if e.is_empty():
			continue
		if _is_post_for_follow(e, save_manager, chapter_manager):
			bucket_follow += 1
		else:
			bucket_recommend += 1
		if not _passes_dynamic_bucket(e, save_manager, chapter_manager):
			continue
		enriched.append(e)
	#region agent log
	_dbg(
		"H1",
		"feed_page.gd:refresh_feed",
		"bucket summary",
		{
			"use_follow_tab": _use_follow_tab,
			"bucket_follow": bucket_follow,
			"bucket_recommend": bucket_recommend,
			"after_filter_count": enriched.size()
		}
	)
	#endregion
	if _use_follow_tab:
		_sort_follow_list(enriched, save_manager, chapter_manager)
	else:
		_sort_recommend_list(enriched, chapter_manager)
	if enriched.is_empty():
		var tip := Label.new()
		tip.text = "暂无动态"
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_list_box.add_child(tip)
		return
	for e in enriched:
		var card: Node = CARD_SCENE.instantiate()
		if card is Control:
			(card as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list_box.add_child(card)
		if card.has_method("setup"):
			card.call("setup", _card_view_dict(e, save_manager))
		var ebind: Dictionary = e.duplicate(true)
		if card.has_signal("avatar_pressed"):
			card.avatar_pressed.connect(func() -> void: _on_avatar_on_post(ebind, save_manager))
		if not _use_follow_tab and card.has_signal("view_more_pressed"):
			card.view_more_pressed.connect(func() -> void: _on_recommend_view_more(ebind, save_manager))
		if _use_follow_tab and card.has_signal("media_pressed"):
			card.media_pressed.connect(func() -> void: _on_follow_media_pressed(ebind, save_manager))
		if _use_follow_tab and card.has_signal("like_pressed"):
			card.like_pressed.connect(func(anchor_global: Vector2) -> void: _on_follow_like_pressed(card, anchor_global))
		if _use_follow_tab and card.has_signal("pin_toggled"):
			card.pin_toggled.connect(func(is_pinned: bool) -> void:
				_on_follow_pin_toggled(str(ebind.get("post_id", "")), is_pinned, save_manager)
			)
	#region agent log
	if _scroll != null and _scroll.get_v_scroll_bar() != null:
		_dbg(
			"H1",
			"feed_page.gd:refresh_feed",
			"scroll metrics after build",
			{
				"cards_count": enriched.size(),
				"scroll_max": _scroll.get_v_scroll_bar().max_value,
				"scroll_page": _scroll.get_v_scroll_bar().page
			}
		)
	#endregion


func _on_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_drag_probe_active = mb.pressed
			_manual_dragging = mb.pressed
			_manual_drag_last_y = mb.position.y
			#region agent log
			_dbg(
				"H1",
				"feed_page.gd:_on_scroll_gui_input",
				"mouse button on scroll",
				{
					"pressed": mb.pressed,
					"x": mb.position.x,
					"y": mb.position.y
				}
			)
			#endregion
	elif event is InputEventMouseMotion and _drag_probe_active:
		var mm := event as InputEventMouseMotion
		if _manual_dragging and _scroll != null:
			var next_v: float = _scroll.scroll_vertical - mm.relative.y
			var max_v: int = 0
			if _scroll.get_v_scroll_bar() != null:
				max_v = int(_scroll.get_v_scroll_bar().max_value)
			_scroll.scroll_vertical = clampi(int(next_v), 0, max_v)
		#region agent log
		_dbg(
			"H1",
			"feed_page.gd:_on_scroll_gui_input",
			"mouse drag over scroll",
			{
				"x": mm.position.x,
				"y": mm.position.y,
				"rel_x": mm.relative.x,
				"rel_y": mm.relative.y
			}
		)
		#endregion
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_manual_dragging = st.pressed
		_manual_drag_last_y = st.position.y
		#region agent log
		_dbg(
			"H1",
			"feed_page.gd:_on_scroll_gui_input",
			"touch on scroll",
			{
				"pressed": st.pressed,
				"x": st.position.x,
				"y": st.position.y
			}
		)
		#endregion
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _manual_dragging and _scroll != null:
			var next_v_touch: float = _scroll.scroll_vertical - sd.relative.y
			var max_v_touch: int = 0
			if _scroll.get_v_scroll_bar() != null:
				max_v_touch = int(_scroll.get_v_scroll_bar().max_value)
			_scroll.scroll_vertical = clampi(int(next_v_touch), 0, max_v_touch)
		#region agent log
		_dbg(
			"H1",
			"feed_page.gd:_on_scroll_gui_input",
			"touch drag on scroll",
			{
				"x": sd.position.x,
				"y": sd.position.y,
				"rel_x": sd.relative.x,
				"rel_y": sd.relative.y
			}
		)
		#endregion


func _passes_dynamic_bucket(e: Dictionary, save_manager: SaveManager, chapter_manager: ChapterManager) -> bool:
	if _is_post_for_follow(e, save_manager, chapter_manager):
		return _use_follow_tab
	return not _use_follow_tab


func _is_post_for_follow(e: Dictionary, save_manager: SaveManager, _chapter_manager: ChapterManager) -> bool:
	var chapter_id: int = int(e.get("chapter_id", 0))
	var unlocked := save_manager.is_chapter_unlocked(chapter_id)
	#region agent log
	_dbg(
		"H2",
		"feed_page.gd:_is_post_for_follow",
		"chapter unlock check",
		{
			"post_id": str(e.get("post_id", "")),
			"chapter_id": chapter_id,
			"chapter_unlocked": unlocked
		}
	)
	#endregion
	return unlocked


func _enrich_post(post: Dictionary, chapter_manager: ChapterManager, save_manager: SaveManager) -> Dictionary:
	var level_id: String = str(post.get("level_id", ""))
	var chapter_id: int = int(post.get("chapter_id", 0))
	var level_row: Dictionary = chapter_manager.get_level_by_id(level_id)
	if level_row.is_empty():
		push_warning("feed_page: 未知 level_id %s" % level_id)
		return {}
	var chapter_levels: Array = chapter_manager.get_levels_for_chapter(chapter_id)
	var chapter_row: Dictionary = chapter_manager.get_chapter_by_id(chapter_id)
	var out: Dictionary = post.duplicate(true)
	out["artist_name"] = _artist_name_from_chapter(chapter_row)
	out["time_display"] = str(level_row.get("text2", ""))
	out["_level_row"] = level_row.duplicate(true)
	out["_chapter_levels"] = chapter_levels.duplicate(true)
	out["show_new"] = not save_manager.is_feed_post_seen(str(post.get("post_id", "")))
	#region agent log
	_dbg(
		"H3",
		"feed_page.gd:_enrich_post",
		"post enriched",
		{
			"post_id": str(out.get("post_id", "")),
			"chapter_id": chapter_id,
			"level_id": level_id,
			"artist_name": str(out.get("artist_name", "")),
			"text_len": str(out.get("text", "")).length()
		}
	)
	#endregion
	return out


func _card_view_dict(e: Dictionary, _save_manager: SaveManager) -> Dictionary:
	var layout: String = "follow" if _use_follow_tab else "recommend"
	return {
		"layout": layout,
		"artist_name": e.get("artist_name", ""),
		"time_display": e.get("time_display", ""),
		"text": e.get("text", ""),
		"image_path": e.get("image_path", ""),
		"avatar_path": e.get("avatar_path", ""),
		"show_new": false,
		"is_pinned": bool(e.get("_is_pinned", false)),
	}


func _artist_name_from_chapter(chapter_row: Dictionary) -> String:
	var artist: String = str(chapter_row.get("artist_name", ""))
	if not artist.is_empty():
		return artist
	var chapter_name: String = str(chapter_row.get("chapter_name", ""))
	if not chapter_name.is_empty():
		return chapter_name
	return "艺人"


func _sort_follow_list(items: Array, save_manager: SaveManager, chapter_manager: ChapterManager) -> void:
	var recent: String = save_manager.get_recent_opened_level_id()
	var pinned_post_id: String = save_manager.get_feed_pinned_post_id()
	for item in items:
		if item is Dictionary:
			(item as Dictionary)["_is_pinned"] = str((item as Dictionary).get("post_id", "")) == pinned_post_id
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra: Array = _follow_rank(a, recent, pinned_post_id, chapter_manager)
		var rb: Array = _follow_rank(b, recent, pinned_post_id, chapter_manager)
		for i in range(mini(ra.size(), rb.size())):
			if int(ra[i]) != int(rb[i]):
				return int(ra[i]) < int(rb[i])
		return false
	)


func _follow_rank(e: Dictionary, recent_level_id: String, pinned_post_id: String, chapter_manager: ChapterManager) -> Array:
	var post_id: String = str(e.get("post_id", ""))
	var level_id: String = str(e.get("level_id", ""))
	var chapter_id: int = int(e.get("chapter_id", 0))
	var tier: int = 2
	if not pinned_post_id.is_empty() and post_id == pinned_post_id:
		tier = 0
	else:
		if level_id == recent_level_id:
			tier = 1
	return [tier, _chapter_order(chapter_manager, chapter_id), _level_order(chapter_manager, level_id)]


func _sort_recommend_list(items: Array, chapter_manager: ChapterManager) -> void:
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: int = _chapter_order(chapter_manager, int(a.get("chapter_id", 0)))
		var cb: int = _chapter_order(chapter_manager, int(b.get("chapter_id", 0)))
		if ca != cb:
			return ca < cb
		return _level_order(chapter_manager, str(a.get("level_id", ""))) < _level_order(chapter_manager, str(b.get("level_id", "")))
	)


func _level_order(chapter_manager: ChapterManager, level_id: String) -> int:
	var row: Dictionary = chapter_manager.get_level_by_id(level_id)
	return int(row.get("order", 999))


func _chapter_order(chapter_manager: ChapterManager, chapter_id: int) -> int:
	var row: Dictionary = chapter_manager.get_chapter_by_id(chapter_id)
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
	if not save_manager.is_chapter_unlocked(chapter_id):
		return false
	var level_id: String = str(level.get("level_id", ""))
	if save_manager.is_level_unlocked(level_id) or save_manager.is_level_completed(level_id):
		return true
	var condition_id: int = int(level.get("unlock_condition_id", 0))
	if condition_id <= 0:
		return true
	if _is_condition_pay_unlock(condition_id, chapter_manager):
		return false
	var condition_checker: ConditionChecker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	if condition_checker == null:
		return false
	return condition_checker.is_level_condition_met(condition_id, level, chapter_levels)


func _is_condition_pay_unlock(condition_id: int, chapter_manager: ChapterManager) -> bool:
	if condition_id <= 0 or chapter_manager == null:
		return false
	var condition: Dictionary = chapter_manager.get_condition_by_id(condition_id)
	return int(condition.get("type", 0)) == 1


func _on_avatar_on_post(e: Dictionary, save_manager: SaveManager) -> void:
	var pid: String = str(e.get("post_id", ""))
	if not pid.is_empty():
		save_manager.mark_feed_post_seen(pid)
	var ch: int = int(e.get("chapter_id", 0))
	var lid: String = str(e.get("level_id", ""))
	feed_open_level_select.emit(ch, lid)


func _on_card_pressed_on_post(e: Dictionary, save_manager: SaveManager) -> void:
	var pid: String = str(e.get("post_id", ""))
	if not pid.is_empty():
		save_manager.mark_feed_post_seen(pid)
	var chapter_manager: ChapterManager = get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	if chapter_manager == null:
		return
	var chapter_id: int = int(e.get("chapter_id", 0))
	var level_id: String = str(e.get("level_id", ""))
	var level_row: Dictionary = e.get("_level_row", {}).duplicate(true)
	var chapter_levels: Array = e.get("_chapter_levels", [])

	if not _use_follow_tab:
		#region agent log
		_dbg8(
			"H2",
			"feed_page.gd:_on_card_pressed_on_post",
			"recommend tab -> open level select",
			{
				"post_id": pid,
				"chapter_id": chapter_id,
				"level_id": level_id
			}
		)
		#endregion
		feed_open_level_select.emit(chapter_id, level_id)
		return
	if save_manager == null:
		return
	var playable: bool = _is_level_playable(level_row, chapter_id, chapter_levels, save_manager, chapter_manager)
	#region agent log
	_dbg8(
		"H2",
		"feed_page.gd:_on_card_pressed_on_post",
		"follow media routing decision",
		{
			"post_id": pid,
			"chapter_id": chapter_id,
			"level_id": level_id,
			"playable": playable,
			"is_follow_tab": _use_follow_tab
		}
	)
	#endregion
	if playable:
		feed_open_level.emit(level_row.duplicate(true))
	else:
		feed_open_level_select.emit(chapter_id, level_id)


func _on_recommend_view_more(e: Dictionary, save_manager: SaveManager) -> void:
	_on_avatar_on_post(e, save_manager)


func _on_follow_media_pressed(e: Dictionary, save_manager: SaveManager) -> void:
	_on_card_pressed_on_post(e, save_manager)


func _on_follow_like_pressed(card: Node, anchor_global: Vector2 = Vector2.ZERO) -> void:
	#region agent log
	var anchor_pos := Vector2.ZERO
	if anchor_global != Vector2.ZERO:
		anchor_pos = anchor_global
	elif card is Control:
		anchor_pos = (card as Control).global_position
	_dbg(
		"H2",
		"feed_page.gd:_on_follow_like_pressed",
		"like signal received in page",
		{
			"anchor_type": card.get_class() if card != null else "null",
			"anchor_name": str(card.name) if card != null else "",
			"anchor_global": anchor_pos,
			"anchor_from_button": anchor_global != Vector2.ZERO
		}
	)
	#endregion
	_play_heart_effect(card, anchor_pos)


func _on_follow_pin_toggled(post_id: String, is_pinned: bool, save_manager: SaveManager) -> void:
	if save_manager == null:
		return
	if is_pinned:
		save_manager.set_feed_pinned_post_id(post_id)
	else:
		save_manager.set_feed_pinned_post_id("")
	refresh_feed()


func _play_heart_effect(anchor: Node, anchor_global: Vector2 = Vector2.ZERO) -> void:
	#region agent log
	var anchor_pos := Vector2.ZERO
	if anchor_global != Vector2.ZERO:
		anchor_pos = anchor_global
	elif anchor is Control:
		anchor_pos = (anchor as Control).global_position
	_dbg("H2", "feed_page.gd:_play_heart_effect", "effect placement base", {"anchor_global": anchor_pos, "has_heart_effect_config": _effects_map.has("heart_point")})
	#endregion
	var effect: Dictionary = _effects_map.get("heart_point", {})
	var resource_path: String = str(effect.get("resource_path", ""))
	if not resource_path.is_empty() and ResourceLoader.exists(resource_path):
		var packed := load(resource_path) as PackedScene
		if packed != null:
			var inst := packed.instantiate()
			if inst is Control and anchor is Control:
				var cinst := inst as Control
				cinst.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cinst.global_position = anchor_pos + Vector2(-8, -10)
				add_child(cinst)
				return
	var heart := Label.new()
	heart.text = "❤"
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heart.modulate = Color(1.0, 0.42, 0.56, 1)
	heart.add_theme_font_size_override("font_size", 22)
	add_child(heart)
	heart.global_position = anchor_pos + Vector2(-14, -14)
	var tw := create_tween()
	tw.tween_property(heart, "position:y", heart.position.y - 18, 0.35)
	tw.parallel().tween_property(heart, "modulate:a", 0.0, 0.35)
	tw.tween_callback(heart.queue_free)
