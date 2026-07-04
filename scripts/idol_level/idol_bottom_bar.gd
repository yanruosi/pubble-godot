extends Control
class_name IdolBottomBar

## 关卡内底部栏：PSD 1280×720 绝对坐标贴图布局。

signal slot_pressed(slot_id: String)

# --- 贴图路径（art/mainui/level）---
const TEX_BAR := "res://art/mainui/level/dibulan.png"
const TEX_SLOT1 := "res://art/mainui/level/caowei1ui.png"
const TEX_SLOT2 := "res://art/mainui/level/caowei2level1ui.png"
const TEX_SLOT3 := "res://art/mainui/level/caowei3level1ui.png"
const TEX_PROGRESS_BG := "res://art/mainui/level/jindu_bg.png"
const TEX_PROGRESS_FALLBACK := "res://art/mainui/level/jinduui.png"

# --- PSD 1× 坐标（设计视口 1280×720）---
const BAR_RECT := Rect2(26, 582, 1228, 138)
const SLOT1_RECT := Rect2(77, 601, 91, 104)
const SLOT2_RECT := Rect2(183, 607, 71, 89)
const SLOT3_RECT := Rect2(295, 599, 66, 104)
const PROGRESS_RECT := Rect2(1080, 546, 146, 149)
# 进度圆组件内局部坐标（146×149 画布）
const PROGRESS_LABEL_RECT := Rect2(38, 82, 71, 30)
const PROGRESS_ARC_CENTER := Vector2(72.5, 75.0)
const PROGRESS_ARC_RADIUS := 56.0
const PROGRESS_ARC_WIDTH := 11.0
const PROGRESS_ARC_BORDER_WIDTH := 13.0
const PROGRESS_ARC_START := -PI * 0.5
const PROGRESS_ARC_COLOR := Color(0.96, 0.58, 0.12, 1.0)
const PROGRESS_ARC_BORDER_COLOR := Color(0.1, 0.1, 0.1, 1.0)
# 底栏+进度圆占用区：热点在此区域内不响应（避免 hs_106 等大框盖住槽位）
const BOTTOM_UI_BLOCK_RECT := Rect2(26, 540, 1228, 180)

static func blocks_hotspot_at(global_pos: Vector2) -> bool:
	return BOTTOM_UI_BLOCK_RECT.has_point(global_pos)

var _slot_buttons: Dictionary = {}
var _slot_unlocked: Dictionary = {}
var _completed_slots: Dictionary = {}
var _progress_label: Label
var _progress_arc: ProgressArcLayer

const DEBUG_LOG_PATH := "res://debug-0ae22b.log"
const DEBUG_SESSION_ID := "0ae22b"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 300
	set_process_input(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	call_deferred("_log_slot_layout")

func _log_slot_layout() -> void:
	for slot_id in _slot_buttons.keys():
		var hit: Control = _slot_buttons[slot_id]
		if hit == null:
			continue
		var gr: Rect2 = hit.get_global_rect()
		var icon: TextureRect = hit.get_node_or_null("Icon") as TextureRect
		#region agent log
		_debug_log("H1", "idol_bottom_bar.gd:_log_slot_layout", "slot_layout", {
			"slot_id": str(slot_id),
			"visible": hit.visible,
			"unlocked": bool(_slot_unlocked.get(slot_id, false)),
			"has_texture": icon != null and icon.texture != null,
			"global_rect": [gr.position.x, gr.position.y, gr.size.x, gr.size.y],
			"bar_z_index": z_index
		})
		#endregion

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click_pos: Vector2 = (event as InputEventMouseButton).global_position
	for slot_id in _slot_buttons.keys():
		var hit: Control = _slot_buttons[slot_id]
		if hit == null or not hit.visible or not bool(_slot_unlocked.get(slot_id, false)):
			continue
		var gr: Rect2 = hit.get_global_rect()
		if gr.size.x > 1.0 and gr.has_point(click_pos):
			#region agent log
			_debug_log("H3", "idol_bottom_bar.gd:_input", "click_in_slot_rect", {
				"slot_id": str(slot_id),
				"click_pos": [click_pos.x, click_pos.y],
				"global_rect": [gr.position.x, gr.position.y, gr.size.x, gr.size.y],
				"visible": hit.visible,
				"unlocked": bool(_slot_unlocked.get(slot_id, false))
			})
			_debug_log("H2", "idol_bottom_bar.gd:_input", "slot_pressed_via_input", {"slot_id": slot_id})
			#endregion
			set_active_slot(str(slot_id))
			slot_pressed.emit(str(slot_id))
			get_viewport().set_input_as_handled()
			return

func setup(vocab_total: int) -> void:
	_completed_slots.clear()
	update_progress(0, vocab_total)
	set_slot_unlocked("slot1", true)
	set_slot_unlocked("slot2", false)
	set_slot_unlocked("slot3", false)

func update_progress(collected_count: int, vocab_total: int) -> void:
	if _progress_label != null:
		_progress_label.text = "%d/%d" % [collected_count, vocab_total]
	var ratio := 0.0
	if vocab_total > 0:
		ratio = clampf(float(collected_count) / float(vocab_total), 0.0, 1.0)
	if _progress_arc != null:
		_progress_arc.ratio = ratio
		_progress_arc.queue_redraw()

func set_slot_unlocked(slot_id: String, unlocked: bool) -> void:
	var hit: Control = _slot_buttons.get(slot_id, null)
	if hit == null:
		return
	# 槽1 始终显示；槽2/3 未解锁时隐藏图标，露出底栏合图上的问号框
	if slot_id == "slot1":
		_slot_unlocked[slot_id] = true
		hit.visible = true
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		return
	_slot_unlocked[slot_id] = unlocked
	hit.visible = unlocked
	hit.mouse_filter = Control.MOUSE_FILTER_STOP if unlocked else Control.MOUSE_FILTER_IGNORE

func set_slot_completed(slot_id: String, completed: bool) -> void:
	_completed_slots[slot_id] = completed

func set_active_slot(slot_id: String) -> void:
	for key in _slot_buttons.keys():
		var hit: Control = _slot_buttons[key]
		if hit == null:
			continue
		hit.modulate = Color(1.15, 1.15, 1.05, 1) if key == slot_id else Color.WHITE

func _build_ui() -> void:
	# p1 底部栏底图
	var bar_bg := TextureRect.new()
	bar_bg.name = "BarBg"
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.texture = _load_tex(TEX_BAR)
	bar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_place(bar_bg, BAR_RECT)
	add_child(bar_bg)

	# p2/p3/p4 三个槽位图标（可点击）
	_add_slot_button("slot1", TEX_SLOT1, SLOT1_RECT)
	_add_slot_button("slot2", TEX_SLOT2, SLOT2_RECT)
	_add_slot_button("slot3", TEX_SLOT3, SLOT3_RECT)

	# p5 进度圆：静态底图 + 程序画弧 + 动态 n/n
	var progress_root := Control.new()
	progress_root.name = "ProgressRoot"
	progress_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_root.clip_contents = true
	_place(progress_root, PROGRESS_RECT)
	add_child(progress_root)

	var progress_bg := TextureRect.new()
	progress_bg.name = "ProgressBg"
	progress_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_bg.texture = _load_progress_tex()
	progress_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	progress_bg.stretch_mode = TextureRect.STRETCH_SCALE
	progress_root.add_child(progress_bg)

	_progress_arc = ProgressArcLayer.new()
	_progress_arc.name = "ProgressArc"
	_progress_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_arc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	progress_root.add_child(_progress_arc)

	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.text = "0/9"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place(_progress_label, PROGRESS_LABEL_RECT)
	_progress_label.add_theme_color_override("font_color", Color(0.22, 0.2, 0.18, 1))
	_progress_label.add_theme_font_size_override("font_size", 18)
	progress_root.add_child(_progress_label)

func _add_slot_button(slot_id: String, tex_path: String, rect: Rect2) -> void:
	# 图标仅展示；透明点击层单独接 GUI，避免被底层大热点抢走点击
	var hit := Control.new()
	hit.name = "Slot_%s" % slot_id
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_place(hit, rect)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _load_tex(tex_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.add_child(icon)

	hit.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if not bool(_slot_unlocked.get(slot_id, false)):
			return
		#region agent log
		_debug_log("H2", "idol_bottom_bar.gd:gui_input", "slot_gui_input", {"slot_id": slot_id})
		#endregion
		set_active_slot(slot_id)
		slot_pressed.emit(slot_id)
		hit.accept_event()
	)
	_slot_buttons[slot_id] = hit
	_slot_unlocked[slot_id] = slot_id == "slot1"
	add_child(hit)

func _place(node: Control, rect: Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	push_warning("IdolBottomBar: 找不到贴图 %s" % path)
	return null

func _load_progress_tex() -> Texture2D:
	var tex := _load_tex(TEX_PROGRESS_BG)
	if tex != null:
		return tex
	push_warning("IdolBottomBar: 未找到 jindu_bg.png，回退使用 jinduui.png")
	return _load_tex(TEX_PROGRESS_FALLBACK)

#region agent log
func _debug_log(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": DEBUG_SESSION_ID,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var file := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_string(JSON.stringify(payload) + "\n")
	file.close()
#endregion

class ProgressArcLayer extends Control:
	var ratio: float = 0.0

	func _draw() -> void:
		if ratio <= 0.0:
			return
		var end_angle := PROGRESS_ARC_START + ratio * TAU
		var point_count := maxi(8, int(ratio * 72.0))
		draw_arc(
			PROGRESS_ARC_CENTER,
			PROGRESS_ARC_RADIUS,
			PROGRESS_ARC_START,
			end_angle,
			point_count,
			PROGRESS_ARC_BORDER_COLOR,
			PROGRESS_ARC_BORDER_WIDTH,
			true
		)
		draw_arc(
			PROGRESS_ARC_CENTER,
			PROGRESS_ARC_RADIUS,
			PROGRESS_ARC_START,
			end_angle,
			point_count,
			PROGRESS_ARC_COLOR,
			PROGRESS_ARC_WIDTH,
			true
		)
