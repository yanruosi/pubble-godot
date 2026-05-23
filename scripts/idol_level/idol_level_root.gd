extends Control
class_name IdolLevelRoot

@export var level_id: String = ""

const MAIN_UI_PATH := "res://scenes/main_ui.tscn"
const DEBUG_TRACE_LOG_PATH := "D:/GAMES/pubble/debug-8f8638.log"

@onready var bg_solid: ColorRect = $BgSolid
@onready var scene_pan: ScenePanController = $SceneViewport
@onready var bg_image: TextureRect = $SceneViewport/SceneWorld/BgImage
@onready var hotspot_layer: HotspotLayer = $HotspotLayer
@onready var popup_layer: IdolPopupPanel = $PopupLayer
@onready var bottom_bar: IdolBottomBar = $BottomBar
@onready var scroll_panel: ScrollSlotPanel = $ScrollPanel
@onready var identity_panel: IdentitySlotPanel = $IdentityPanel
@onready var mapping_panel: MappingSlotPanel = $MappingPanel

var _chapter_manager: ChapterManager
var _save_manager: SaveManager
var _pack: Dictionary = {}
var _level_config: Dictionary = {}
var _level_row: Dictionary = {}
var _vocab_bank: VocabBank
var _completion_applied := false
var _first_clear_this_finish := false
var _slot2_unlock_events: Dictionary = {}
var _slot3_unlock_events: Dictionary = {}
var _top_title: Label
var _placeholder_label: Label
var _truth_layer: CanvasLayer
var _truth_text_label: Label
var _truth_reward_label: Label
var _menu_layer: CanvasLayer

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
	_chapter_manager = get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if level_id.is_empty() and get_tree().has_meta("pending_level_id"):
		level_id = str(get_tree().get_meta("pending_level_id"))
	if get_tree().has_meta("pending_level_id"):
		get_tree().remove_meta("pending_level_id")
	if level_id.is_empty():
		level_id = "ch1_l01"
	_build_top_chrome()
	_vocab_bank = VocabBank.new()
	_vocab_bank.name = "VocabBank"
	add_child(_vocab_bank)
	_connect_children()
	_load_level()

func _connect_children() -> void:
	scene_pan.pan_changed.connect(_on_scene_pan_changed)
	hotspot_layer.popup_requested.connect(_on_hotspot_popup_requested)
	hotspot_layer.modal_opened.connect(_on_hotspot_modal_opened)
	hotspot_layer.vocab_requested.connect(_on_hotspot_vocab_requested)
	hotspot_layer.event_emitted.connect(_on_hotspot_event_emitted)
	popup_layer.popup_closed.connect(_on_popup_closed)
	popup_layer.bubble_dismissed.connect(_on_popup_bubble_dismissed)
	bottom_bar.slot_pressed.connect(_on_bottom_slot_pressed)
	scroll_panel.completed.connect(_on_scroll_completed)
	scroll_panel.closed.connect(_on_slot_panel_closed)
	identity_panel.completed.connect(_on_identity_completed)
	identity_panel.closed.connect(_on_slot_panel_closed)
	mapping_panel.completed.connect(_on_mapping_completed)
	mapping_panel.closed.connect(_on_slot_panel_closed)
	_vocab_bank.changed.connect(_on_vocab_changed)

func _load_level() -> void:
	var loader := LevelPackLoader.new()
	_pack = loader.load_pack(level_id, _chapter_manager)
	_level_config = _pack.get("level", {})
	_level_row = _pack.get("level_row", {})
	if not bool(_pack.get("ok", false)):
		_show_missing_pack_placeholder()
		return

	_completion_applied = false
	_first_clear_this_finish = false
	_slot2_unlock_events.clear()
	_slot3_unlock_events.clear()
	_apply_background()
	_configure_scene_pan()
	_apply_title()
	_vocab_bank.setup(_pack.get("vocab", []), int(_level_config.get("vocab_total", 0)))
	bottom_bar.setup(_vocab_bank.total_count())
	hotspot_layer.setup(_pack.get("hotspots", []), _level_config, level_id, _save_manager)
	_sync_scene_view_to_hotspots()
	scroll_panel.setup(_pack.get("slots", []), _vocab_bank)
	identity_panel.setup(_pack.get("slots", []), _vocab_bank)
	mapping_panel.setup(_pack.get("slots", []), _vocab_bank)
	_sync_slot_unlock_events()
	popup_layer.hide_all()
	_sync_hotspot_layer_visibility()

func _apply_background() -> void:
	bg_solid.color = Color(0.035, 0.04, 0.045, 1)
	bg_solid.visible = true
	bg_image.texture = null
	bg_image.visible = false
	var image_path: String = str(_level_config.get("scene_image", ""))
	if image_path.is_empty() or not ResourceLoader.exists(image_path):
		push_warning("【关卡资源警告】【%s】底图缺失：%s，使用 ColorRect 占位" % [level_id, image_path])
		return
	var tex := load(image_path) as Texture2D
	if tex == null:
		push_warning("【关卡资源警告】【%s】底图加载失败：%s，使用 ColorRect 占位" % [level_id, image_path])
		return
	bg_image.texture = tex
	bg_image.visible = true

func _configure_scene_pan() -> void:
	var art_w: float = float(_level_config.get("art_base_width", 1536))
	var art_h: float = float(_level_config.get("art_base_height", 1024))
	scene_pan.set_art_base(art_w, art_h)
	_sync_scene_view_to_hotspots()

func _on_scene_pan_changed(pan_x: float, scene_size: Vector2) -> void:
	hotspot_layer.set_root_view(pan_x, scene_size)

func _sync_scene_view_to_hotspots() -> void:
	hotspot_layer.set_root_view(scene_pan.get_pan_x(), scene_pan.get_scene_size())

func _apply_title() -> void:
	var title: String = str(_level_config.get("display_name", ""))
	if title.is_empty():
		title = str(_level_row.get("title", level_id))
	_top_title.text = title

func _show_missing_pack_placeholder() -> void:
	_apply_background()
	_top_title.text = str(_level_row.get("title", level_id))
	if _placeholder_label == null:
		_placeholder_label = Label.new()
		_placeholder_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_placeholder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_placeholder_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.76, 1))
		_placeholder_label.add_theme_font_size_override("font_size", 22)
		add_child(_placeholder_label)
	_placeholder_label.text = "关卡内容制作中\n缺少或无法读取关卡包：%s" % str(_pack.get("data_dir", level_id))
	bottom_bar.setup(0)
	hotspot_layer.visible = false
	popup_layer.hide_all()
	scroll_panel.visible = false
	identity_panel.visible = false
	mapping_panel.visible = false

func _on_hotspot_popup_requested(text: String, hotspot: Dictionary) -> void:
	var in_sub_layer: bool = hotspot_layer.get_current_layer() != "root"
	popup_layer.show_bubble(_resolve_bubble_text(text, hotspot), in_sub_layer)

func _on_hotspot_modal_opened(modal_id: String, title: String, asset_path: String, popup_layout: String, _hotspot: Dictionary) -> void:
	popup_layer.show_modal(modal_id, title, asset_path, popup_layout)
	scene_pan.set_pan_locked(true)

func _on_hotspot_vocab_requested(vocab_id: String, hotspot: Dictionary) -> void:
	var collected: bool = _vocab_bank.collect(vocab_id)
	var vocab: Dictionary = _vocab_bank.get_vocab(vocab_id)
	var in_sub_layer: bool = hotspot_layer.get_current_layer() != "root"
	if vocab.is_empty():
		popup_layer.show_bubble("这个线索还没有配置词条。", in_sub_layer)
		return
	_evaluate_slot2_unlock()
	var bubble_text: String
	if collected:
		if str(vocab.get("tag", "")) == "name":
			bubble_text = "此线索已加入思考面板。"
		else:
			bubble_text = "已收录词条：%s" % str(vocab.get("text", vocab_id))
	else:
		bubble_text = "已收录过：%s" % str(vocab.get("text", vocab_id))
	popup_layer.show_bubble(bubble_text, in_sub_layer)
	#region agent log
	DebugSessionLog.write("idol_level_root.gd:_on_hotspot_vocab_requested", "vocab_collected", "G", {
		"vocab_id": vocab_id,
		"hotspot_id": str(hotspot.get("hotspot_id", "")),
		"current_layer": hotspot_layer.get_current_layer(),
		"keep_modal": in_sub_layer,
		"hotspot_layer_visible": hotspot_layer.visible
	})
	#endregion

func _on_popup_bubble_dismissed(should_restore_layer: bool) -> void:
	if not should_restore_layer:
		return
	if hotspot_layer.get_current_layer() == "root":
		return
	if not popup_layer.get_current_modal_id().is_empty():
		return
	hotspot_layer.return_to_root()
	_sync_pan_lock()
	#region agent log
	DebugSessionLog.write("idol_level_root.gd:_on_popup_bubble_dismissed", "restored_root_after_bubble", "G", {
		"current_layer": hotspot_layer.get_current_layer()
	})
	#endregion

func _on_hotspot_event_emitted(event_id: String, _hotspot: Dictionary) -> void:
	if event_id.is_empty():
		return
	_slot2_unlock_events[event_id] = true
	_slot3_unlock_events[event_id] = true
	_evaluate_slot2_unlock()
	_evaluate_slot3_unlock()
	_sync_slot_unlock_events()

func _resolve_bubble_text(text: String, hotspot: Dictionary) -> String:
	var hint_vocab_id: String = str(hotspot.get("hint_vocab", ""))
	if hint_vocab_id.is_empty():
		return text
	var vocab_row: Dictionary = _vocab_bank.get_vocab(hint_vocab_id)
	if vocab_row.is_empty():
		return text
	var hint: String = str(vocab_row.get("hint_text", ""))
	if not hint.is_empty():
		return hint
	return str(vocab_row.get("text", text))

func _on_popup_closed(closed_modal_id: String) -> void:
	_apply_modal_close_events(closed_modal_id)
	hotspot_layer.consume_last_opened_once_only()
	var restore: Dictionary = hotspot_layer.restore_after_popup_close()
	var parent_layer: String = str(restore.get("parent_layer", "root"))
	if parent_layer != "root":
		popup_layer.show_modal(
			parent_layer,
			"线索",
			str(restore.get("asset_path", "")),
			str(restore.get("popup_layout", ""))
		)
	_sync_pan_lock()

func _apply_modal_close_events(closed_modal_id: String) -> void:
	match closed_modal_id:
		"modal_poster_lee":
			_slot2_unlock_events["poster_viewed"] = true
		"modal_badge_may":
			_slot2_unlock_events["badge_viewed"] = true
	_evaluate_slot2_unlock()
	_sync_slot_unlock_events()

func _on_bottom_slot_pressed(slot_id: String) -> void:
	bottom_bar.set_active_slot(slot_id)
	match slot_id:
		"slot1":
			identity_panel.close_panel(false)
			mapping_panel.close_panel(false)
			scroll_panel.open_panel()
		"slot2":
			scroll_panel.close_panel(false)
			mapping_panel.close_panel(false)
			identity_panel.open_panel()
		"slot3":
			scroll_panel.close_panel(false)
			identity_panel.close_panel(false)
			mapping_panel.open_panel()
	_sync_hotspot_layer_visibility()

func _on_slot_panel_closed() -> void:
	bottom_bar.set_active_slot("")
	_sync_hotspot_layer_visibility()

func _sync_hotspot_layer_visibility() -> void:
	if not bool(_pack.get("ok", false)):
		return
	var slot_open: bool = scroll_panel.visible or identity_panel.visible or mapping_panel.visible
	hotspot_layer.visible = not slot_open
	_sync_pan_lock()

func _sync_pan_lock() -> void:
	var slot_open: bool = scroll_panel.visible or identity_panel.visible or mapping_panel.visible
	var popup_open: bool = popup_layer.get_current_modal_id() != "" or hotspot_layer.get_current_layer() != "root"
	scene_pan.set_pan_locked(slot_open or popup_open)

func _on_vocab_changed(collected_count: int, vocab_total: int) -> void:
	bottom_bar.update_progress(collected_count, vocab_total)

func _evaluate_slot2_unlock() -> void:
	var unlock_type: String = str(_level_config.get("slot2_unlock_type", ""))
	var raw_value: String = str(_level_config.get("slot2_unlock_value", ""))
	if unlock_type.is_empty() or raw_value.is_empty():
		return
	var tokens: Array = []
	for raw_id in raw_value.split(",", false):
		var token: String = str(raw_id).strip_edges()
		if not token.is_empty():
			tokens.append(token)
	if unlock_type == "any":
		for token in tokens:
			var token_str: String = str(token)
			if token_str.begins_with("vocab_") and _vocab_bank.has_vocab(token_str):
				bottom_bar.set_slot_unlocked("slot2", true)
				return
			if _slot2_unlock_events.get(token_str, false):
				bottom_bar.set_slot_unlocked("slot2", true)
				return
	elif unlock_type.begins_with("vocab"):
		for token in tokens:
			if _vocab_bank.has_vocab(str(token)):
				bottom_bar.set_slot_unlocked("slot2", true)
				return
	elif unlock_type == "event":
		for token in tokens:
			if _slot2_unlock_events.get(str(token), false):
				bottom_bar.set_slot_unlocked("slot2", true)
				return

func _evaluate_slot3_unlock() -> void:
	var unlock_type: String = str(_level_config.get("slot3_unlock_type", ""))
	var raw_value: String = str(_level_config.get("slot3_unlock_value", ""))
	if unlock_type.is_empty() or raw_value.is_empty():
		return
	var tokens: Array = []
	for raw_id in raw_value.split(",", false):
		var token: String = str(raw_id).strip_edges()
		if not token.is_empty():
			tokens.append(token)
	if unlock_type == "any":
		for token in tokens:
			var token_str: String = str(token)
			if token_str.begins_with("vocab_") and _vocab_bank.has_vocab(token_str):
				bottom_bar.set_slot_unlocked("slot3", true)
				return
			if _slot3_unlock_events.get(token_str, false):
				bottom_bar.set_slot_unlocked("slot3", true)
				return
	elif unlock_type.begins_with("vocab"):
		for token in tokens:
			if _vocab_bank.has_vocab(str(token)):
				bottom_bar.set_slot_unlocked("slot3", true)
				return
	elif unlock_type == "event":
		for token in tokens:
			if _slot3_unlock_events.get(str(token), false):
				bottom_bar.set_slot_unlocked("slot3", true)
				return

func _sync_slot_unlock_events() -> void:
	var merged: Dictionary = {}
	for key in _slot2_unlock_events.keys():
		merged[key] = true
	for key in _slot3_unlock_events.keys():
		merged[key] = true
	identity_panel.set_unlock_events(merged)
	mapping_panel.set_unlock_events(merged)

func _on_scroll_completed() -> void:
	bottom_bar.set_slot_completed("slot1", true)
	scroll_panel.close_panel(false)
	_sync_hotspot_layer_visibility()
	if str(_level_config.get("required_slot", "slot1")) != "slot1":
		return
	_apply_completion()
	_show_truth_overlay()

func _on_identity_completed() -> void:
	bottom_bar.set_slot_completed("slot2", true)
	identity_panel.close_panel(false)
	_sync_hotspot_layer_visibility()

func _on_mapping_completed() -> void:
	bottom_bar.set_slot_completed("slot3", true)
	mapping_panel.close_panel(false)
	_sync_hotspot_layer_visibility()

func _apply_completion() -> void:
	if _completion_applied:
		return
	_completion_applied = true
	if _save_manager == null:
		return
	var before_completed: bool = _save_manager.is_level_completed(level_id)
	print("【通关存档自检】【%s】通关前 completed=%s" % [level_id, str(before_completed)])
	_first_clear_this_finish = not before_completed
	_save_manager.mark_level_completed(level_id, true)
	var cheer_reward: int = int(_level_row.get("cheer_reward", 0))
	if _first_clear_this_finish and cheer_reward > 0:
		_save_manager.set_cheer_count(_save_manager.get_cheer_count() + cheer_reward)
	print("【通关存档自检】【%s】通关后 completed=%s cheer=%d" % [level_id, str(_save_manager.is_level_completed(level_id)), _save_manager.get_cheer_count()])

func _show_truth_overlay() -> void:
	_ensure_truth_overlay()
	_truth_text_label.text = str(_level_config.get("truth_text", "真相尚未配置。"))
	var cheer_reward: int = int(_level_row.get("cheer_reward", 0))
	if _first_clear_this_finish and cheer_reward > 0:
		_truth_reward_label.text = "获得应援棒 × %d" % cheer_reward
	elif cheer_reward > 0:
		_truth_reward_label.text = "关卡完成（应援棒已在首次通关时领取）"
	else:
		_truth_reward_label.text = "关卡完成"
	_truth_layer.visible = true

func _ensure_truth_overlay() -> void:
	if _truth_layer != null:
		return
	_truth_layer = CanvasLayer.new()
	_truth_layer.layer = 200
	_truth_layer.visible = false
	add_child(_truth_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_truth_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_truth_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 280)
	panel.add_theme_stylebox_override("panel", _truth_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "故事真相"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_truth_text_label = Label.new()
	_truth_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_truth_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_truth_text_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_truth_text_label)

	_truth_reward_label = Label.new()
	_truth_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_truth_reward_label)

	var btn := Button.new()
	btn.text = "返回关卡选择"
	btn.custom_minimum_size = Vector2(220, 48)
	btn.pressed.connect(_on_truth_button_pressed)
	vbox.add_child(btn)

func _on_truth_button_pressed() -> void:
	#region agent log
	_dbg8(
		"H1",
		"idol_level_root.gd:_on_truth_button_pressed",
		"truth confirm nav",
		{
			"target_page": "level_select",
			"chapter_id": int(_level_row.get("chapter_id", 0)),
			"focus_level_id": level_id
		}
	)
	#endregion
	if _save_manager != null:
		_save_manager.set_pending_post_level_nav({
			"page": "level_select",
			"chapter_id": int(_level_row.get("chapter_id", 0)),
			"focus_level_id": level_id
		})
	get_tree().change_scene_to_file(MAIN_UI_PATH)

func _build_top_chrome() -> void:
	_top_title = Label.new()
	_top_title.name = "TopTitle"
	_top_title.text = level_id
	_top_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_title.offset_left = 72
	_top_title.offset_top = 28
	_top_title.offset_right = -120
	_top_title.offset_bottom = 72
	_top_title.add_theme_color_override("font_color", Color(0.92, 0.9, 0.84, 1))
	_top_title.add_theme_font_size_override("font_size", 20)
	add_child(_top_title)

	var search := Button.new()
	search.text = "⌕"
	search.custom_minimum_size = Vector2(52, 52)
	search.offset_left = 16
	search.offset_top = 116
	search.offset_right = 68
	search.offset_bottom = 168
	add_child(search)

	var hint := Button.new()
	hint.text = "?"
	hint.custom_minimum_size = Vector2(52, 52)
	hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hint.offset_left = -116
	hint.offset_top = 24
	hint.offset_right = -64
	hint.offset_bottom = 76
	add_child(hint)

	var menu := Button.new()
	menu.text = "≡"
	menu.custom_minimum_size = Vector2(52, 52)
	menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -58
	menu.offset_top = 24
	menu.offset_right = -6
	menu.offset_bottom = 76
	menu.pressed.connect(_on_menu_pressed)
	add_child(menu)

func _on_menu_pressed() -> void:
	#region agent log
	_dbg8(
		"H1",
		"idol_level_root.gd:_on_menu_pressed",
		"hamburger pressed -> open in-level menu",
		{
			"chapter_id": int(_level_row.get("chapter_id", 0)),
			"level_id": level_id
		}
	)
	#endregion
	_toggle_menu(true)

func _truth_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.84, 0.68, 0.98)
	style.border_color = Color(0.53, 0.39, 0.18, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	return style

func _toggle_menu(visible: bool) -> void:
	_ensure_menu_layer()
	_menu_layer.visible = visible

func _ensure_menu_layer() -> void:
	if _menu_layer != null:
		return
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 180
	_menu_layer.visible = false
	add_child(_menu_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 220)
	panel.add_theme_stylebox_override("panel", _truth_style())
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "关卡菜单"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)

	var btn_restart := Button.new()
	btn_restart.text = "重新开始关卡"
	btn_restart.custom_minimum_size = Vector2(220, 46)
	btn_restart.pressed.connect(_on_menu_restart_pressed)
	vbox.add_child(btn_restart)

	var btn_level_select := Button.new()
	btn_level_select.text = "返回关卡选择"
	btn_level_select.custom_minimum_size = Vector2(220, 46)
	btn_level_select.pressed.connect(_on_menu_return_level_select_pressed)
	vbox.add_child(btn_level_select)

	var btn_cancel := Button.new()
	btn_cancel.text = "取消"
	btn_cancel.custom_minimum_size = Vector2(220, 42)
	btn_cancel.pressed.connect(func() -> void:
		_toggle_menu(false)
	)
	vbox.add_child(btn_cancel)

func _on_menu_restart_pressed() -> void:
	#region agent log
	_dbg8(
		"H1",
		"idol_level_root.gd:_on_menu_restart_pressed",
		"restart level from in-level menu",
		{
			"level_id": level_id
		}
	)
	#endregion
	_toggle_menu(false)
	_load_level()

func _on_menu_return_level_select_pressed() -> void:
	#region agent log
	_dbg8(
		"H1",
		"idol_level_root.gd:_on_menu_return_level_select_pressed",
		"return level select from in-level menu",
		{
			"chapter_id": int(_level_row.get("chapter_id", 0)),
			"focus_level_id": ""
		}
	)
	#endregion
	if _save_manager != null:
		_save_manager.set_pending_post_level_nav({
			"page": "level_select",
			"chapter_id": int(_level_row.get("chapter_id", 0)),
			"focus_level_id": ""
		})
	get_tree().change_scene_to_file(MAIN_UI_PATH)
