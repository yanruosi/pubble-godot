extends Control
class_name HotspotLayer

signal popup_requested(text: String, hotspot: Dictionary)
signal modal_opened(modal_id: String, title: String, asset_path: String, popup_layout: String, hotspot: Dictionary)
signal vocab_requested(vocab_id: String, hotspot: Dictionary)
signal event_emitted(event_id: String, hotspot: Dictionary)

const ROOT_LAYER := "root"
const SUBLAYER_Z_INDEX := 45
const MODAL_INNER_TOP := 56.0
const MODAL_INNER_BOTTOM := 36.0
const MODAL_INNER_SIDE := 12.0

var _hotspots_by_parent: Dictionary = {}
var _used_hotspots: Dictionary = {}
var _viewed_hotspots: Dictionary = {}
var _level_config: Dictionary = {}
var _current_parent: String = ROOT_LAYER
var _last_opened_row: Dictionary = {}
var _layer_open_assets: Dictionary = {}
var _layer_open_layouts: Dictionary = {}
var _level_id: String = ""
var _save_manager: SaveManager = null
var _level_completed := false
var _root_pan_x := 0.0
var _root_scene_size := Vector2.ZERO

func _ready() -> void:
	z_index = 0

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
		var parent_id: String = str(row.get("parent_id", ROOT_LAYER))
		if parent_id.is_empty():
			parent_id = ROOT_LAYER
		if not _hotspots_by_parent.has(parent_id):
			_hotspots_by_parent[parent_id] = []
		var group: Array = _hotspots_by_parent[parent_id]
		group.append(row)
		_hotspots_by_parent[parent_id] = group
		var open_modal: String = str(row.get("open_modal", ""))
		if not open_modal.is_empty():
			var asset_path: String = str(row.get("asset", ""))
			if not asset_path.is_empty():
				_layer_open_assets[open_modal] = asset_path
			var layout: String = str(row.get("popup_layout", ""))
			if not layout.is_empty():
				_layer_open_layouts[open_modal] = layout
	show_layer(ROOT_LAYER)

func get_current_layer() -> String:
	return _current_parent

func get_parent_layer(layer_id: String) -> String:
	match layer_id:
		"panel_receipt", "panel_keycard", "panel_apple":
			return "modal_pink_bag"
		"modal_corp_card", "modal_bag", "modal_pink_bag", "modal_poster_lee", "modal_badge_may":
			return ROOT_LAYER
		_:
			return ROOT_LAYER

func get_layer_asset(layer_id: String) -> String:
	return str(_layer_open_assets.get(layer_id, ""))

func get_layer_layout(layer_id: String) -> String:
	return str(_layer_open_layouts.get(layer_id, ""))

func consume_last_opened_once_only() -> void:
	var hotspot_id: String = str(_last_opened_row.get("hotspot_id", ""))
	var once_only: int = int(_last_opened_row.get("once_only", 0))
	#region agent log
	DebugSessionLog.write("hotspot_layer.gd:consume_last_opened_once_only", "consume_check", "A", {
		"hotspot_id": hotspot_id,
		"once_only": once_only,
		"will_mark_used": once_only == 1 and not hotspot_id.is_empty()
	})
	#endregion
	if once_only != 1:
		return
	if int(_last_opened_row.get("hide_question_only", 0)) == 1:
		return
	mark_hotspot_used(hotspot_id)

func mark_hotspot_used(hotspot_id: String) -> void:
	if hotspot_id.is_empty():
		return
	_viewed_hotspots[hotspot_id] = true
	show_layer(_current_parent)

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
	z_index = 0 if parent_id == ROOT_LAYER else SUBLAYER_Z_INDEX
	_clear_nodes()
	var rows: Array = _hotspots_by_parent.get(parent_id, [])
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("z_order", 0)) < int(b.get("z_order", 0))
	)
	var target_rect: Rect2 = _target_rect_for_parent(parent_id, rows)
	var base_size: Vector2 = _base_size_for_parent(parent_id, rows)
	#region agent log
	DebugSessionLog.write("hotspot_layer.gd:show_layer", "layer_shown", "B", {
		"parent_id": parent_id,
		"z_index": z_index,
		"row_count": rows.size(),
		"target_rect": [target_rect.position.x, target_rect.position.y, target_rect.size.x, target_rect.size.y],
		"layout": get_layer_layout(parent_id)
	})
	#endregion
	for row in rows:
		var hotspot := HotspotNode.new()
		add_child(hotspot)
		hotspot.setup(row, _scaled_rect(row, target_rect, base_size))
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
		"title": "",
		"closed_hotspot_id": str(_last_opened_row.get("hotspot_id", ""))
	}
	if parent_layer == ROOT_LAYER:
		return_to_root()
	else:
		show_layer(parent_layer)
		result["asset_path"] = get_layer_asset(parent_layer)
		result["popup_layout"] = get_layer_layout(parent_layer)
	return result

func _mark_question_discovered(row: Dictionary) -> void:
	var hotspot_id: String = str(row.get("hotspot_id", ""))
	if hotspot_id.is_empty() or bool(_viewed_hotspots.get(hotspot_id, false)):
		return
	if not HotspotNode.uses_question_badge(row):
		return
	mark_hotspot_viewed(hotspot_id)
	#region agent log
	DebugSessionLog.write("hotspot_layer.gd:_mark_question_discovered", "question_hidden", "Q", {
		"hotspot_id": hotspot_id,
		"display_name": str(row.get("display_name", ""))
	})
	#endregion

func _on_hotspot_triggered(row: Dictionary) -> void:
	_mark_question_discovered(row)
	var hotspot_type: String = str(row.get("hotspot_type", "normal"))
	var hotspot_id: String = str(row.get("hotspot_id", ""))
	match hotspot_type:
		"collect":
			var vocab_id: String = str(row.get("collect_vocab", ""))
			vocab_requested.emit(vocab_id, row.duplicate(true))
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
			var event_id: String = str(row.get("unlock_event", ""))
			if not event_id.is_empty():
				event_emitted.emit(event_id, row.duplicate(true))
			popup_requested.emit(_normal_bubble_text(row), row.duplicate(true))

func _open_sub_layer(row: Dictionary) -> void:
	var modal_id: String = str(row.get("open_modal", ""))
	var title: String = str(row.get("modal_title", ""))
	if title.is_empty():
		title = str(row.get("display_name", "线索"))
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
	modal_opened.emit(modal_id, title, asset_path, popup_layout, row.duplicate(true))
	show_layer(modal_id)
	#region agent log
	DebugSessionLog.write("hotspot_layer.gd:_open_sub_layer", "sub_layer_opened", "C", {
		"hotspot_id": str(row.get("hotspot_id", "")),
		"modal_id": modal_id,
		"popup_layout": popup_layout
	})
	#endregion

func _clear_nodes() -> void:
	for child in get_children():
		child.queue_free()

func _target_rect_for_parent(parent_id: String, _rows: Array) -> Rect2:
	var s: Vector2 = size
	if s.x <= 0.0 or s.y <= 0.0:
		s = get_viewport_rect().size
	if parent_id == ROOT_LAYER:
		if _root_scene_size.x > 0.0 and _root_scene_size.y > 0.0:
			return Rect2(Vector2(-_root_pan_x, 0.0), _root_scene_size)
		return Rect2(Vector2.ZERO, s)
	var layout: String = get_layer_layout(parent_id)
	if layout.is_empty():
		layout = "modal_full" if parent_id.begins_with("modal_") else "panel_rect"
	if layout == "panel_rect":
		return _inner_content_rect(
			Rect2(Vector2(36.0, 430.0), Vector2(maxf(20.0, s.x - 72.0), maxf(20.0, s.y - 640.0)))
		)
	return _inner_content_rect(
		Rect2(Vector2(24.0, 360.0), Vector2(maxf(20.0, s.x - 48.0), maxf(20.0, s.y - 510.0)))
	)

func _inner_content_rect(outer: Rect2) -> Rect2:
	return Rect2(
		outer.position + Vector2(MODAL_INNER_SIDE, MODAL_INNER_TOP),
		Vector2(
			maxf(20.0, outer.size.x - MODAL_INNER_SIDE * 2.0),
			maxf(20.0, outer.size.y - MODAL_INNER_TOP - MODAL_INNER_BOTTOM)
		)
	)

func _base_size_for_parent(parent_id: String, rows: Array) -> Vector2:
	if parent_id == ROOT_LAYER:
		return Vector2(
			maxf(1.0, float(_level_config.get("art_base_width", 1920))),
			maxf(1.0, float(_level_config.get("art_base_height", 1080)))
		)
	var max_x := 1.0
	var max_y := 1.0
	for item in rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		max_x = maxf(max_x, float(row.get("x", 0.0)) + float(row.get("width", 1.0)))
		max_y = maxf(max_y, float(row.get("y", 0.0)) + float(row.get("height", 1.0)))
	return Vector2(max_x, max_y)

func _normal_bubble_text(row: Dictionary) -> String:
	var text: String = str(row.get("popup_text", ""))
	if not text.is_empty():
		return text
	return str(row.get("display_name", "这里暂时没有更多信息。"))

func _scaled_rect(row: Dictionary, target_rect: Rect2, base_size: Vector2) -> Rect2:
	var sx: float = target_rect.size.x / maxf(1.0, base_size.x)
	var sy: float = target_rect.size.y / maxf(1.0, base_size.y)
	return Rect2(
		target_rect.position + Vector2(float(row.get("x", 0.0)) * sx, float(row.get("y", 0.0)) * sy),
		Vector2(maxf(24.0, float(row.get("width", 1.0)) * sx), maxf(24.0, float(row.get("height", 1.0)) * sy))
	)
