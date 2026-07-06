extends Control
class_name HotspotLayer

signal popup_requested(text: String, hotspot: Dictionary)
signal modal_opened(modal_id: String, title: String, asset_path: String, popup_layout: String, hotspot: Dictionary)
signal modal_close_requested(hotspot: Dictionary)
signal vocab_requested(vocab_id: String, hotspot: Dictionary)
signal event_emitted(event_id: String, hotspot: Dictionary)

const ROOT_LAYER := "root"
const SUBLAYER_Z_INDEX := 100

var _hotspots_by_parent: Dictionary = {}
var _used_hotspots: Dictionary = {}
var _viewed_hotspots: Dictionary = {}
var _level_config: Dictionary = {}
var _current_parent: String = ROOT_LAYER
var _last_opened_row: Dictionary = {}
var _layer_open_assets: Dictionary = {}
var _layer_open_layouts: Dictionary = {}
var _layer_coord_bases: Dictionary = {}
var _layer_parents: Dictionary = {}
var _dismiss_outside_modals: Dictionary = {}
var _level_id: String = ""
var _save_manager: SaveManager = null
var _popup_panel: IdolPopupPanel = null
var _level_completed := false
var _root_pan_x := 0.0
var _root_scene_size := Vector2.ZERO

func _ready() -> void:
	z_index = 0

## 根层气泡显示时暂时禁用热点点击，避免抢走关闭层事件
func set_hotspot_input_enabled(enabled: bool) -> void:
	for child in get_children():
		if not (child is HotspotNode):
			continue
		var node := child as HotspotNode
		node.disabled = not enabled
		node.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE

static func coord_base_from_row(row: Dictionary) -> Vector2:
	var bw: float = float(row.get("coord_base_width", 0))
	var bh: float = float(row.get("coord_base_height", 0))
	if bw > 0.0 and bh > 0.0:
		return Vector2(bw, bh)
	return Vector2.ZERO

## editor_note 含 anchor=X,Y 时返回 PSD 1280×720 左上角锚点；否则 (-1,-1) 表示居中
static func anchor_from_row(row: Dictionary) -> Vector2:
	var note: String = str(row.get("editor_note", ""))
	var token := "anchor="
	var idx: int = note.find(token)
	if idx < 0:
		return Vector2(-1, -1)
	var rest: String = note.substr(idx + token.length()).strip_edges()
	var comma_idx: int = rest.find(",")
	if comma_idx < 0:
		return Vector2(-1, -1)
	var xs: String = rest.substr(0, comma_idx).strip_edges()
	var ys: String = rest.substr(comma_idx + 1).strip_edges()
	if ys.contains(" "):
		ys = ys.split(" ", false)[0]
	if xs.is_empty() or ys.is_empty():
		return Vector2(-1, -1)
	return Vector2(float(xs), float(ys))

func set_popup_panel(panel: IdolPopupPanel) -> void:
	if _popup_panel != null:
		if _popup_panel.asset_layout_changed.is_connected(_on_popup_asset_layout_changed):
			_popup_panel.asset_layout_changed.disconnect(_on_popup_asset_layout_changed)
		if _popup_panel.overlay_closed.is_connected(_on_popup_overlay_closed):
			_popup_panel.overlay_closed.disconnect(_on_popup_overlay_closed)
	_popup_panel = panel
	if _popup_panel != null:
		_popup_panel.set_hotspot_layer(self)
		if not _popup_panel.asset_layout_changed.is_connected(_on_popup_asset_layout_changed):
			_popup_panel.asset_layout_changed.connect(_on_popup_asset_layout_changed)
		if not _popup_panel.overlay_closed.is_connected(_on_popup_overlay_closed):
			_popup_panel.overlay_closed.connect(_on_popup_overlay_closed)

func try_activate_at_global_pos(global_pos: Vector2) -> bool:
	if _current_parent == ROOT_LAYER:
		return false
	for child in get_children():
		if not (child is HotspotNode):
			continue
		var node := child as HotspotNode
		var gr: Rect2 = node.get_global_rect()
		var contains: bool = gr.size.x > 1.0 and gr.has_point(global_pos)
		if contains:
			node._on_pressed()
			return true
	return false

func set_root_view(pan_x: float, scene_size: Vector2) -> void:
	_root_pan_x = pan_x
	_root_scene_size = scene_size
	if _current_parent == ROOT_LAYER and not _hotspots_by_parent.is_empty():
		show_layer(ROOT_LAYER)

func setup(hotspots: Array, level_config: Dictionary, level_id: String = "", save_manager: SaveManager = null) -> void:
	_hotspots_by_parent.clear()
	_used_hotspots.clear()
	_viewed_hotspots.clear()
	_layer_open_assets.clear()
	_layer_open_layouts.clear()
	_layer_coord_bases.clear()
	_layer_parents.clear()
	_dismiss_outside_modals.clear()
	_level_config = level_config.duplicate(true)
	_level_id = level_id
	_save_manager = save_manager
	_level_completed = _save_manager != null and not _level_id.is_empty() and _save_manager.is_level_completed(_level_id)
	for item in hotspots:
		if not (item is Dictionary):
			continue
		var row: Dictionary = (item as Dictionary).duplicate(true)
		var hotspot_id: String = str(row.get("hotspot_id", ""))
		if _level_completed or (_save_manager != null and _save_manager.is_hotspot_clicked(_level_id, hotspot_id)):
			_viewed_hotspots[hotspot_id] = true
		var parent_id: String = str(row.get("parent_id", ""))
		if parent_id.is_empty():
			parent_id = ROOT_LAYER
		if not _hotspots_by_parent.has(parent_id):
			_hotspots_by_parent[parent_id] = []
		var group: Array = _hotspots_by_parent[parent_id]
		group.append(row)
		_hotspots_by_parent[parent_id] = group
		var open_modal: String = str(row.get("open_modal", ""))
		if not open_modal.is_empty():
			_layer_parents[open_modal] = parent_id
			var asset_path: String = str(row.get("asset", ""))
			if not asset_path.is_empty():
				_layer_open_assets[open_modal] = asset_path
			var layout: String = str(row.get("popup_layout", ""))
			if not layout.is_empty():
				_layer_open_layouts[open_modal] = layout
			_register_layer_coord_base(open_modal, row)
			if int(row.get("dismiss_on_outside_click", 0)) == 1:
				_dismiss_outside_modals[open_modal] = true
	if _popup_panel != null:
		_popup_panel.set_dismiss_outside_modals(_dismiss_outside_modals)
	show_layer(ROOT_LAYER)

func _register_layer_coord_base(layer_id: String, row: Dictionary) -> void:
	var base: Vector2 = coord_base_from_row(row)
	if base.x > 0.0 and base.y > 0.0:
		_layer_coord_bases[layer_id] = base

func get_layer_coord_base(layer_id: String) -> Vector2:
	if _layer_coord_bases.has(layer_id):
		return _layer_coord_bases[layer_id]
	return Vector2.ZERO

func get_current_layer() -> String:
	return _current_parent

func has_hotspots_for_parent(parent_id: String) -> bool:
	return not _hotspots_by_parent.get(parent_id, []).is_empty()

func get_parent_layer(layer_id: String) -> String:
	return str(_layer_parents.get(layer_id, ROOT_LAYER))

func get_layer_asset(layer_id: String) -> String:
	return str(_layer_open_assets.get(layer_id, ""))

func get_layer_layout(layer_id: String) -> String:
	return str(_layer_open_layouts.get(layer_id, ""))

func consume_last_opened_once_only() -> void:
	var hotspot_id: String = str(_last_opened_row.get("hotspot_id", ""))
	var once_only: int = int(_last_opened_row.get("once_only", 0))
	if once_only != 1:
		return
	if int(_last_opened_row.get("hide_question_only", 0)) == 1:
		return
	mark_hotspot_used(hotspot_id)

func mark_hotspot_used(hotspot_id: String) -> void:
	if hotspot_id.is_empty():
		return
	_used_hotspots[hotspot_id] = true
	if _save_manager != null and not _level_id.is_empty():
		_save_manager.mark_hotspot_used(_level_id, hotspot_id)
	show_layer(_current_parent)

func restore_used_hotspots(ids: Array) -> void:
	for item in ids:
		var hid: String = str(item)
		if not hid.is_empty():
			_used_hotspots[hid] = true
	if not _hotspots_by_parent.is_empty():
		show_layer(_current_parent)

func get_used_hotspot_ids() -> Array:
	var result: Array = []
	for key in _used_hotspots.keys():
		if bool(_used_hotspots[key]):
			result.append(str(key))
	return result

func mark_hotspot_viewed(hotspot_id: String) -> void:
	if hotspot_id.is_empty():
		return
	_viewed_hotspots[hotspot_id] = true
	if _save_manager != null and not _level_id.is_empty():
		_save_manager.mark_hotspot_clicked(_level_id, hotspot_id)
	show_layer(_current_parent)

func _should_hide_question_only(row: Dictionary) -> bool:
	return int(row.get("once_only", 0)) == 1 and int(row.get("hide_question_only", 0)) == 1

func _apply_once_only_after_trigger(row: Dictionary) -> void:
	var hotspot_id: String = str(row.get("hotspot_id", ""))
	if hotspot_id.is_empty() or int(row.get("once_only", 0)) != 1:
		return
	if _should_hide_question_only(row):
		mark_hotspot_viewed(hotspot_id)
	else:
		mark_hotspot_used(hotspot_id)

func show_layer(parent_id: String) -> void:
	_current_parent = parent_id
	var is_root := parent_id == ROOT_LAYER
	z_index = 0 if is_root else SUBLAYER_Z_INDEX
	# 子层必须用 IGNORE：父节点 PASS 时 Godot 往往无法把点击分发给子 Button（日志已证实 P/KKT 热区建了但收不到 pressed）
	mouse_filter = Control.MOUSE_FILTER_PASS if is_root else Control.MOUSE_FILTER_IGNORE
	_clear_nodes()
	var rows: Array = _hotspots_by_parent.get(parent_id, [])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("z_order", 0)) < int(b.get("z_order", 0))
	)
	var target_rect: Rect2 = _target_rect_for_parent(parent_id)
	var base_size: Vector2 = _base_size_for_parent(parent_id)
	for row in rows:
		var hotspot := HotspotNode.new()
		add_child(hotspot)
		hotspot.z_index = clampi(int(row.get("z_order", 0)), 0, 10)
		var scaled: Rect2 = _scaled_rect(row, target_rect, base_size)
		hotspot.setup(row, scaled)
		var hotspot_id: String = str(row.get("hotspot_id", ""))
		if bool(_used_hotspots.get(hotspot_id, false)):
			hotspot.set_used()
		elif bool(_viewed_hotspots.get(hotspot_id, false)):
			hotspot.set_viewed()
		hotspot.triggered.connect(_on_hotspot_triggered)

func return_to_root() -> void:
	show_layer(ROOT_LAYER)

func restore_after_popup_close() -> Dictionary:
	var parent_layer: String = get_parent_layer(_current_parent)
	var result := {
		"parent_layer": parent_layer,
		"asset_path": get_layer_asset(parent_layer if parent_layer != ROOT_LAYER else _current_parent),
		"popup_layout": get_layer_layout(parent_layer if parent_layer != ROOT_LAYER else _current_parent),
		"design_size": get_layer_coord_base(parent_layer if parent_layer != ROOT_LAYER else _current_parent),
		"title": "",
		"closed_hotspot_id": str(_last_opened_row.get("hotspot_id", ""))
	}
	if parent_layer == ROOT_LAYER:
		return_to_root()
	else:
		show_layer(parent_layer)
		result["asset_path"] = get_layer_asset(parent_layer)
		result["popup_layout"] = get_layer_layout(parent_layer)
		result["design_size"] = get_layer_coord_base(parent_layer)
	return result

func _on_popup_asset_layout_changed(modal_id: String) -> void:
	if modal_id.is_empty():
		return
	if modal_id == _current_parent:
		show_layer(_current_parent)
		return
	if _current_parent.begins_with("panel_") and modal_id == get_parent_layer(_current_parent):
		show_layer(_current_parent)

func _on_popup_overlay_closed(_overlay_id: String) -> void:
	var parent_layer: String = get_parent_layer(_current_parent)
	if parent_layer == ROOT_LAYER:
		return_to_root()
	else:
		show_layer(parent_layer)

func _mark_question_discovered(row: Dictionary) -> void:
	var hotspot_id: String = str(row.get("hotspot_id", ""))
	if hotspot_id.is_empty() or bool(_viewed_hotspots.get(hotspot_id, false)):
		return
	if not HotspotNode.uses_question_badge(row):
		return
	mark_hotspot_viewed(hotspot_id)

func _on_hotspot_triggered(row: Dictionary) -> void:
	_mark_question_discovered(row)
	var hotspot_type: String = str(row.get("hotspot_type", "normal"))
	match hotspot_type:
		"close":
			modal_close_requested.emit(row.duplicate(true))
			_apply_once_only_after_trigger(row)
		"collect":
			var vocab_id: String = str(row.get("collect_vocab", ""))
			vocab_requested.emit(vocab_id, row.duplicate(true))
			var collect_event: String = str(row.get("unlock_event", ""))
			if not collect_event.is_empty():
				event_emitted.emit(collect_event, row.duplicate(true))
			_apply_once_only_after_trigger(row)
		"modal":
			_open_sub_layer(row)
			_apply_once_only_after_trigger(row)
		"panel":
			var vocab_id: String = str(row.get("collect_vocab", ""))
			if not vocab_id.is_empty():
				vocab_requested.emit(vocab_id, row.duplicate(true))
			var event_id: String = str(row.get("unlock_event", ""))
			if not event_id.is_empty():
				event_emitted.emit(event_id, row.duplicate(true))
			var open_modal: String = str(row.get("open_modal", ""))
			if not open_modal.is_empty():
				_open_sub_layer(row)
			else:
				var text: String = str(row.get("popup_text", ""))
				if text.is_empty():
					text = "此线索已加入思考面板。"
				popup_requested.emit(text, row.duplicate(true))
			_apply_once_only_after_trigger(row)
		_:
			var unlock_event: String = str(row.get("unlock_event", ""))
			if not unlock_event.is_empty():
				event_emitted.emit(unlock_event, row.duplicate(true))
			popup_requested.emit(_normal_bubble_text(row), row.duplicate(true))

func _open_sub_layer(row: Dictionary) -> void:
	var modal_id: String = str(row.get("open_modal", ""))
	var title: String = str(row.get("display_name", "线索"))
	if title.is_empty():
		title = "线索"
	if modal_id.is_empty():
		popup_requested.emit("这个热点还没有配置弹层。", row.duplicate(true))
		return
	_last_opened_row = row.duplicate(true)
	var unlock_event: String = str(row.get("unlock_event", ""))
	if not unlock_event.is_empty():
		event_emitted.emit(unlock_event, row.duplicate(true))
	var asset_path: String = str(row.get("asset", ""))
	if asset_path.is_empty():
		asset_path = get_layer_asset(modal_id)
	var popup_layout: String = str(row.get("popup_layout", ""))
	if popup_layout.is_empty():
		popup_layout = get_layer_layout(modal_id)
	_register_layer_coord_base(modal_id, row)
	modal_opened.emit(modal_id, title, asset_path, popup_layout, row.duplicate(true))
	show_layer(modal_id)

func _clear_nodes() -> void:
	for child in get_children():
		child.queue_free()

func _target_rect_for_parent(parent_id: String) -> Rect2:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size
	if parent_id == ROOT_LAYER:
		if _root_scene_size.x > 0.0 and _root_scene_size.y > 0.0:
			return Rect2(Vector2(-_root_pan_x, 0.0), _root_scene_size)
		return Rect2(Vector2.ZERO, s)
	if _popup_panel != null and _popup_panel.get_current_modal_id() == parent_id:
		var asset_rect: Rect2 = _popup_panel.get_asset_display_rect()
		if asset_rect.size.x > 1.0 and asset_rect.size.y > 1.0:
			return _global_rect_to_local(asset_rect)
	if _popup_panel != null and parent_id.begins_with("panel_"):
		var base_id: String = _popup_panel.get_base_modal_id()
		if not base_id.is_empty() and _popup_panel.get_current_modal_id() == parent_id:
			var asset_rect: Rect2 = _popup_panel.get_asset_display_rect()
			if asset_rect.size.x > 1.0 and asset_rect.size.y > 1.0:
				return _global_rect_to_local(asset_rect)
	return _fallback_modal_rect(parent_id, s)

func _global_rect_to_local(global_rect: Rect2) -> Rect2:
	var top_left: Vector2 = get_global_transform().affine_inverse() * global_rect.position
	var bottom_right: Vector2 = get_global_transform().affine_inverse() * global_rect.end
	return Rect2(top_left, bottom_right - top_left)

func _fallback_modal_rect(parent_id: String, viewport_size: Vector2) -> Rect2:
	var design: Vector2 = get_layer_coord_base(parent_id)
	if design.x <= 0.0 or design.y <= 0.0:
		design = Vector2(280, 400)
	var pos := (viewport_size - design) * 0.5
	return Rect2(pos, design)

func _base_size_for_parent(parent_id: String) -> Vector2:
	if parent_id == ROOT_LAYER:
		return Vector2(
			maxf(1.0, float(_level_config.get("art_base_width", 1280))),
			maxf(1.0, float(_level_config.get("art_base_height", 720)))
		)
	var base: Vector2 = get_layer_coord_base(parent_id)
	if base.x > 0.0 and base.y > 0.0:
		return base
	return Vector2(280, 400)

func _normal_bubble_text(row: Dictionary) -> String:
	var text: String = str(row.get("popup_text", ""))
	if not text.is_empty():
		return text
	return str(row.get("display_name", "这里暂时没有更多信息。"))

func _scaled_rect(row: Dictionary, target_rect: Rect2, base_size: Vector2) -> Rect2:
	var sx: float = target_rect.size.x / maxf(1.0, base_size.x)
	var sy: float = target_rect.size.y / maxf(1.0, base_size.y)
	var min_size: float = 16.0 if HotspotNode.is_hidden_visual(row) else 24.0
	return Rect2(
		target_rect.position + Vector2(float(row.get("x", 0.0)) * sx, float(row.get("y", 0.0)) * sy),
		Vector2(
			maxf(min_size, float(row.get("width", 1.0)) * sx),
			maxf(min_size, float(row.get("height", 1.0)) * sy)
		)
	)
