extends Control
class_name IdolPopupPanel

signal close_requested
signal popup_closed(modal_id: String)
signal overlay_closed(overlay_id: String)
signal bubble_dismissed(should_restore_layer: bool)
signal asset_layout_changed(modal_id: String)

var _dismiss_rect: ColorRect
var _modal_center: Control
var _overlay_center: Control
var _overlay_wrap: Control
var _modal_content: Control
var _modal_panel: PanelContainer
var _modal_title: Label
var _modal_body: Label
var _modal_image: TextureRect
var _overlay_image: TextureRect
var _modal_placeholder: ColorRect
var _bubble_panel: PanelContainer
var _bubble_label: Label
var _base_modal_id: String = ""
var _base_layout: String = ""
var _current_modal_id: String = ""
var _overlay_modal_id: String = ""
var _current_layout: String = ""
var _bubble_only: bool = false
var _base_design_size: Vector2 = Vector2.ZERO
var _overlay_design_size: Vector2 = Vector2.ZERO
var _base_anchor: Vector2 = Vector2(-1, -1)
var _overlay_anchor: Vector2 = Vector2(-1, -1)
var _base_display_rect: Rect2 = Rect2()
var _overlay_display_rect: Rect2 = Rect2()
var _base_render_size: Vector2 = Vector2.ZERO
var _overlay_render_size: Vector2 = Vector2.ZERO
var _dismiss_outside_modals: Dictionary = {}
var _hotspot_layer: HotspotLayer = null
var _bubble_dismiss_canvas: CanvasLayer
var _bubble_dismiss_catcher: ColorRect
var _bubble_on_canvas := false

const Z_INDEX_DEFAULT := 120
const Z_INDEX_BUBBLE_TOP := 350
const BUBBLE_DISMISS_CANVAS_LAYER := 400

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = Z_INDEX_DEFAULT
	_build_ui()
	hide_all()

func set_hotspot_layer(layer: HotspotLayer) -> void:
	_hotspot_layer = layer

func show_modal(
	modal_id: String,
	title: String,
	asset_path: String = "",
	popup_layout: String = "",
	design_size: Vector2 = Vector2.ZERO,
	design_anchor: Vector2 = Vector2(-1, -1)
) -> void:
	var layout: String = _resolve_layout(modal_id, popup_layout)
	if modal_id.begins_with("panel_") and not _base_modal_id.is_empty() and _modal_center.visible:
		_overlay_design_size = design_size
		_show_overlay(modal_id, asset_path, layout, design_anchor)
		return
	_hide_overlay()
	_base_modal_id = modal_id
	_base_layout = layout
	_current_modal_id = modal_id
	_current_layout = layout
	_base_design_size = design_size
	_base_anchor = design_anchor
	_overlay_design_size = Vector2.ZERO
	_overlay_anchor = Vector2(-1, -1)
	_bubble_panel.visible = false
	_modal_center.visible = true
	_apply_asset_display(title, asset_path, _base_design_size)
	_sync_base_dismiss_rect(modal_id)
	call_deferred("_refresh_asset_layout")

func set_dismiss_outside_modals(modals: Dictionary) -> void:
	_dismiss_outside_modals = modals.duplicate(true)
	if not _base_modal_id.is_empty():
		_sync_base_dismiss_rect(_base_modal_id)

func show_bubble(text: String, keep_modal: bool = false) -> void:
	_bubble_label.text = text
	_bubble_panel.visible = true
	_bubble_panel.z_index = 30
	_dismiss_rect.visible = true
	_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_dismiss_rect.z_index = 20 if keep_modal else 0
	_bubble_only = keep_modal
	# 根层气泡：CanvasLayer 全屏点击层关闭（高于热点 GUI）
	if not keep_modal:
		z_index = Z_INDEX_BUBBLE_TOP
		set_process_unhandled_input(true)
		_show_root_bubble_dismiss_canvas()
	if keep_modal:
		return
	_current_modal_id = ""
	_current_layout = ""
	_base_modal_id = ""
	_base_layout = ""
	_base_design_size = Vector2.ZERO
	_hide_overlay()
	_modal_center.visible = false
	_base_display_rect = Rect2()

func show_message(text: String) -> void:
	show_bubble(text, false)

func get_current_modal_id() -> String:
	if not _overlay_modal_id.is_empty():
		return _overlay_modal_id
	return _current_modal_id

func get_base_modal_id() -> String:
	return _base_modal_id

func has_overlay() -> bool:
	return not _overlay_modal_id.is_empty()

func get_asset_display_rect() -> Rect2:
	if not _overlay_display_rect.size.is_zero_approx() and not _overlay_modal_id.is_empty():
		return _overlay_display_rect
	return _base_display_rect

func get_popup_canvas_rect() -> Rect2:
	return _base_display_rect

func close_base_modal() -> void:
	if _base_modal_id.is_empty() and _current_modal_id.is_empty():
		return
	var closed_modal_id: String = _base_modal_id if not _base_modal_id.is_empty() else _current_modal_id
	hide_all()
	popup_closed.emit(closed_modal_id)
	close_requested.emit()

func hide_all() -> void:
	set_process_unhandled_input(false)
	_base_modal_id = ""
	_base_layout = ""
	_current_modal_id = ""
	_overlay_modal_id = ""
	_current_layout = ""
	_bubble_only = false
	_base_design_size = Vector2.ZERO
	_overlay_design_size = Vector2.ZERO
	_base_anchor = Vector2(-1, -1)
	_overlay_anchor = Vector2(-1, -1)
	_base_display_rect = Rect2()
	_overlay_display_rect = Rect2()
	_base_render_size = Vector2.ZERO
	_overlay_render_size = Vector2.ZERO
	if _dismiss_rect != null:
		_dismiss_rect.visible = false
		_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dismiss_rect.z_index = 0
	if _modal_center != null:
		_modal_center.visible = false
	if _bubble_panel != null:
		_bubble_panel.visible = false
	_hide_root_bubble_dismiss_canvas()
	z_index = Z_INDEX_DEFAULT
	if _overlay_center != null:
		_overlay_center.visible = false
	_hide_overlay()

func close_overlay() -> void:
	if _overlay_modal_id.is_empty():
		return
	var closed_id: String = _overlay_modal_id
	_hide_overlay()
	if _base_modal_id.is_empty():
		set_process_unhandled_input(false)
	elif _uses_dismiss_outside_base() or _forwards_sublayer_clicks():
		_sync_base_dismiss_rect(_base_modal_id)
	_current_modal_id = _base_modal_id
	_current_layout = _base_layout
	overlay_closed.emit(closed_id)
	asset_layout_changed.emit(_base_modal_id)

func _resolve_layout(modal_id: String, popup_layout: String) -> String:
	var layout: String = popup_layout
	if layout.is_empty():
		if modal_id.begins_with("panel_"):
			layout = "panel_rect"
		else:
			layout = "modal_full"
	return layout

func _apply_asset_display(title: String, asset_path: String, design_size: Vector2) -> void:
	var use_placeholder: bool = asset_path.is_empty() or asset_path.contains("母体")
	_set_panel_frame_visible(use_placeholder)
	_modal_image.visible = false
	if _modal_placeholder != null:
		_modal_placeholder.visible = use_placeholder
	if use_placeholder:
		_modal_title.visible = true
		_modal_body.visible = true
		_modal_title.text = title
		_modal_body.text = "（占位预览区，请点击图上热点）"
		var placeholder_size: Vector2 = _resolved_design_size(design_size, Vector2.ZERO)
		_base_render_size = placeholder_size
		if _modal_placeholder != null:
			_modal_placeholder.color = _placeholder_color(title)
			_modal_placeholder.custom_minimum_size = placeholder_size
		_modal_content.custom_minimum_size = placeholder_size
		return
	var has_asset: bool = ResourceLoader.exists(asset_path)
	if has_asset:
		var tex := load(asset_path) as Texture2D
		if tex != null:
			_modal_image.texture = tex
			_modal_image.visible = true
			if _modal_placeholder != null:
				_modal_placeholder.visible = false
			_modal_title.visible = false
			_modal_body.visible = false
			var display_size: Vector2 = _fit_size_to_viewport(tex.get_size(), _resolved_design_size(design_size, tex.get_size()))
			_base_render_size = display_size
			_apply_texture_to_rect(_modal_image, display_size)
			return
	_modal_title.visible = true
	_modal_body.visible = true
	_set_panel_frame_visible(true)
	_modal_title.text = title
	_modal_body.text = "物件图加载失败：%s" % asset_path

func _show_overlay(overlay_id: String, asset_path: String, layout: String, design_anchor: Vector2 = Vector2(-1, -1)) -> void:
	_overlay_modal_id = overlay_id
	if design_anchor.x >= 0.0 and design_anchor.y >= 0.0:
		_overlay_anchor = design_anchor
	elif _base_anchor.x >= 0.0 and _base_anchor.y >= 0.0:
		_overlay_anchor = _base_anchor
	else:
		_overlay_anchor = Vector2(-1, -1)
	_current_modal_id = overlay_id
	_current_layout = layout
	set_process_unhandled_input(true)
	_dismiss_rect.visible = true
	_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_dismiss_rect.z_index = 0
	_overlay_image.visible = false
	if asset_path.is_empty() or not ResourceLoader.exists(asset_path):
		call_deferred("_refresh_asset_layout")
		return
	var tex := load(asset_path) as Texture2D
	if tex == null:
		call_deferred("_refresh_asset_layout")
		return
	_overlay_image.texture = tex
	_overlay_image.visible = true
	if _overlay_center != null:
		_overlay_center.visible = true
		_overlay_center.z_index = 1
	var display_size: Vector2 = _fit_size_to_viewport(
		tex.get_size(),
		_resolved_design_size(_overlay_design_size, tex.get_size())
	)
	_overlay_render_size = display_size
	_overlay_image.custom_minimum_size = display_size
	_overlay_image.size = display_size
	if _overlay_wrap != null:
		_overlay_wrap.custom_minimum_size = display_size
		_overlay_wrap.size = display_size
	call_deferred("_refresh_asset_layout")

func _hide_overlay() -> void:
	_overlay_modal_id = ""
	_overlay_design_size = Vector2.ZERO
	_overlay_anchor = Vector2(-1, -1)
	_overlay_display_rect = Rect2()
	_overlay_render_size = Vector2.ZERO
	if _overlay_center != null:
		_overlay_center.visible = false
	if _overlay_image != null:
		_overlay_image.visible = false
		_overlay_image.texture = null

func _apply_texture_to_rect(image: TextureRect, display_size: Vector2) -> void:
	image.custom_minimum_size = display_size
	image.size = display_size
	image.position = Vector2.ZERO
	_modal_content.custom_minimum_size = display_size
	_modal_content.size = display_size

func _resolved_design_size(configured: Vector2, tex_size: Vector2) -> Vector2:
	if configured.x > 0.0 and configured.y > 0.0:
		return configured
	if tex_size.x > 0.0 and tex_size.y > 0.0:
		return tex_size
	return Vector2(280, 400)

func _fit_size_to_viewport(tex_size: Vector2, design_cap: Vector2) -> Vector2:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return design_cap
	var vp: Vector2 = get_viewport_rect().size
	var margin: Vector2 = Vector2(24.0, 120.0)
	var max_box: Vector2 = Vector2(
		maxf(80.0, minf(design_cap.x, vp.x - margin.x)),
		maxf(80.0, minf(design_cap.y, vp.y - margin.y))
	)
	var scale: float = minf(max_box.x / tex_size.x, max_box.y / tex_size.y)
	return tex_size * scale

func _set_panel_frame_visible(show_frame: bool) -> void:
	if _modal_panel == null:
		return
	if show_frame:
		_modal_panel.add_theme_stylebox_override(
			"panel",
			_panel_style(Color(0.08, 0.075, 0.16, 0.96), Color(0.86, 0.75, 0.46, 1), 1, 0)
		)
	else:
		var transparent := StyleBoxEmpty.new()
		_modal_panel.add_theme_stylebox_override("panel", transparent)

func _refresh_asset_layout() -> void:
	if not _modal_center.visible:
		_base_display_rect = Rect2()
		_overlay_display_rect = Rect2()
		return
	var notify_id: String = _overlay_modal_id if not _overlay_modal_id.is_empty() else _current_modal_id
	_apply_modal_placement()
	if _modal_center.visible:
		_base_display_rect = _modal_center.get_global_rect()
	else:
		_base_display_rect = Rect2()
	if _overlay_center != null and _overlay_center.visible:
		_overlay_display_rect = _overlay_center.get_global_rect()
	else:
		_overlay_display_rect = Rect2()
	asset_layout_changed.emit(notify_id)

func _modal_display_size() -> Vector2:
	if _base_render_size.x > 1.0 and _base_render_size.y > 1.0:
		return _base_render_size
	return _resolved_design_size(_base_design_size, Vector2.ZERO)

func _overlay_display_size() -> Vector2:
	if _overlay_render_size.x > 1.0 and _overlay_render_size.y > 1.0:
		return _overlay_render_size
	return _resolved_design_size(_overlay_design_size, Vector2.ZERO)

func _apply_modal_placement() -> void:
	if _modal_center != null and _modal_center.visible:
		var base_size: Vector2 = _modal_display_size()
		_place_modal_container(_modal_center, _base_anchor, base_size)
		_layout_modal_children_fill()
	if _overlay_center != null and _overlay_center.visible:
		var overlay_size: Vector2 = _overlay_display_size()
		_place_modal_container(_overlay_center, _overlay_anchor, overlay_size)
		_layout_overlay_children_fill()

func _place_modal_container(container: Control, anchor: Vector2, display_size: Vector2) -> void:
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.set_offsets_preset(Control.PRESET_TOP_LEFT)
	container.size = display_size
	if anchor.x >= 0.0 and anchor.y >= 0.0:
		container.position = anchor
	else:
		var vp: Vector2 = get_viewport_rect().size
		container.position = (vp - display_size) * 0.5

func _layout_modal_children_fill() -> void:
	if _modal_panel == null:
		return
	_modal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_panel.set_offsets_preset(Control.PRESET_FULL_RECT)
	if _modal_content != null:
		_modal_content.set_anchors_preset(Control.PRESET_FULL_RECT)
		_modal_content.set_offsets_preset(Control.PRESET_FULL_RECT)
	if _modal_image != null and _modal_image.visible:
		_modal_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		_modal_image.set_offsets_preset(Control.PRESET_FULL_RECT)

func _layout_overlay_children_fill() -> void:
	if _overlay_wrap == null:
		return
	_overlay_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_wrap.set_offsets_preset(Control.PRESET_FULL_RECT)
	if _overlay_image != null and _overlay_image.visible:
		_overlay_image.set_anchors_preset(Control.PRESET_FULL_RECT)
		_overlay_image.set_offsets_preset(Control.PRESET_FULL_RECT)
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _current_modal_id.is_empty():
		if not _overlay_modal_id.is_empty():
			if _overlay_image != null and _overlay_image.texture != null:
				_relayout_overlay()
			call_deferred("_refresh_asset_layout")
			return
		if _modal_image.visible and _modal_image.texture != null:
			var display_size: Vector2 = _fit_size_to_viewport(
				_modal_image.texture.get_size(),
				_resolved_design_size(_base_design_size, _modal_image.texture.get_size())
			)
			_apply_texture_to_rect(_modal_image, display_size)
		call_deferred("_refresh_asset_layout")

func _relayout_overlay() -> void:
	if _overlay_image == null or _overlay_image.texture == null:
		return
	var display_size: Vector2 = _fit_size_to_viewport(
		_overlay_image.texture.get_size(),
		_resolved_design_size(_overlay_design_size, _overlay_image.texture.get_size())
	)
	_overlay_render_size = display_size
	_overlay_image.custom_minimum_size = display_size
	_overlay_image.size = display_size
	if _overlay_wrap != null:
		_overlay_wrap.custom_minimum_size = display_size
		_overlay_wrap.size = display_size

func _placeholder_color(title: String) -> Color:
	var hash_val: int = title.hash()
	return Color(
		0.22 + float(hash_val % 7) * 0.08,
		0.18 + float((hash_val >> 3) % 7) * 0.07,
		0.32 + float((hash_val >> 6) % 7) * 0.06,
		0.88
	)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click_pos: Vector2 = (event as InputEventMouseButton).global_position
	# 根层场景气泡（无弹窗）：点击任意处关闭
	if _bubble_panel != null and _bubble_panel.visible and _base_modal_id.is_empty() and _overlay_modal_id.is_empty():
		hide_all()
		bubble_dismissed.emit(true)
		get_viewport().set_input_as_handled()
		return
	if not _overlay_modal_id.is_empty():
		if _overlay_display_rect.size.x > 1.0 and _overlay_display_rect.has_point(click_pos):
			if _hotspot_layer != null and _hotspot_layer.try_activate_at_global_pos(click_pos):
				get_viewport().set_input_as_handled()
			return
		close_overlay()
		get_viewport().set_input_as_handled()
		return
	if _uses_dismiss_outside_base() or _forwards_sublayer_clicks():
		if _base_display_rect.size.x > 1.0 and _base_display_rect.has_point(click_pos):
			if _hotspot_layer != null and _hotspot_layer.try_activate_at_global_pos(click_pos):
				get_viewport().set_input_as_handled()
			return
		if _uses_dismiss_outside_base():
			close_base_modal()
			get_viewport().set_input_as_handled()

func _on_dismiss_rect_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click_pos: Vector2 = (event as InputEventMouseButton).global_position
	# 点击落在底栏槽位区：关气泡并放行，让 BottomBar._input 处理槽位
	if IdolBottomBar.blocks_hotspot_at(click_pos):
		_bubble_panel.visible = false
		_bubble_only = false
		z_index = Z_INDEX_DEFAULT
		set_process_unhandled_input(false)
		if _dismiss_rect != null:
			_dismiss_rect.visible = false
			_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble_dismissed.emit(false)
		get_viewport().set_input_as_handled()
		return
	if _bubble_only:
		_bubble_panel.visible = false
		_bubble_only = false
		bubble_dismissed.emit(false)
		if not _overlay_modal_id.is_empty() or _uses_dismiss_outside_base() or _forwards_sublayer_clicks():
			_dismiss_rect.visible = true
			_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_STOP
			_dismiss_rect.z_index = 0
		else:
			_dismiss_rect.visible = false
			_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_viewport().set_input_as_handled()
		return
	if _handle_modal_click(click_pos):
		get_viewport().set_input_as_handled()
		return
	hide_all()
	bubble_dismissed.emit(true)
	get_viewport().set_input_as_handled()

func _handle_modal_click(click_pos: Vector2) -> bool:
	if not _overlay_modal_id.is_empty():
		if _overlay_display_rect.size.x > 1.0 and _overlay_display_rect.has_point(click_pos):
			if _hotspot_layer != null and _hotspot_layer.try_activate_at_global_pos(click_pos):
				return true
			return true
		close_overlay()
		return true
	if _uses_dismiss_outside_base() or _forwards_sublayer_clicks():
		if _base_display_rect.size.x > 1.0 and _base_display_rect.has_point(click_pos):
			if _hotspot_layer != null and _hotspot_layer.try_activate_at_global_pos(click_pos):
				return true
			return true
		if _uses_dismiss_outside_base():
			close_base_modal()
			return true
		return true
	return false

func _uses_dismiss_outside_base() -> bool:
	return not _base_modal_id.is_empty() and bool(_dismiss_outside_modals.get(_base_modal_id, false))

func _forwards_sublayer_clicks() -> bool:
	if _base_modal_id.is_empty() or _hotspot_layer == null:
		return false
	return _hotspot_layer.has_hotspots_for_parent(_base_modal_id)

func _sync_base_dismiss_rect(modal_id: String) -> void:
	if _dismiss_rect == null:
		return
	var dismiss_outside: bool = bool(_dismiss_outside_modals.get(modal_id, false))
	var forward_clicks: bool = dismiss_outside or (
		_hotspot_layer != null and _hotspot_layer.has_hotspots_for_parent(modal_id)
	)
	_dismiss_rect.visible = forward_clicks
	_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_STOP if forward_clicks else Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_input(dismiss_outside)
	_dismiss_rect.z_index = 0
	if _modal_center != null:
		_modal_center.z_index = 1
func _ensure_bubble_dismiss_canvas() -> void:
	if _bubble_dismiss_canvas != null:
		return
	_bubble_dismiss_canvas = CanvasLayer.new()
	_bubble_dismiss_canvas.name = "BubbleDismissCanvas"
	_bubble_dismiss_canvas.layer = BUBBLE_DISMISS_CANVAS_LAYER
	_bubble_dismiss_canvas.visible = false
	add_child(_bubble_dismiss_canvas)

	_bubble_dismiss_catcher = ColorRect.new()
	_bubble_dismiss_catcher.name = "BubbleDismissCatcher"
	_bubble_dismiss_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubble_dismiss_catcher.color = Color(0, 0, 0, 0.01)
	_bubble_dismiss_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_bubble_dismiss_catcher.gui_input.connect(_on_bubble_dismiss_catcher_gui_input)
	_bubble_dismiss_canvas.add_child(_bubble_dismiss_catcher)

func _show_root_bubble_dismiss_canvas() -> void:
	_ensure_bubble_dismiss_canvas()
	if _hotspot_layer != null:
		_hotspot_layer.set_hotspot_input_enabled(false)
	if _bubble_panel != null and not _bubble_on_canvas:
		if _bubble_panel.get_parent() != null:
			_bubble_panel.get_parent().remove_child(_bubble_panel)
		_bubble_dismiss_canvas.add_child(_bubble_panel)
		_bubble_panel.z_index = 10
		_bubble_on_canvas = true
	_bubble_dismiss_canvas.visible = true
func _hide_root_bubble_dismiss_canvas() -> void:
	if _bubble_dismiss_canvas != null:
		_bubble_dismiss_canvas.visible = false
	if _bubble_panel != null and _bubble_on_canvas:
		if _bubble_panel.get_parent() == _bubble_dismiss_canvas:
			_bubble_dismiss_canvas.remove_child(_bubble_panel)
		add_child(_bubble_panel)
		_bubble_panel.z_index = 30
		_bubble_on_canvas = false
	if _hotspot_layer != null:
		_hotspot_layer.set_hotspot_input_enabled(true)

func _on_bubble_dismiss_catcher_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var click_pos: Vector2 = (event as InputEventMouseButton).global_position
	# 底栏区域不吞事件，交给 BottomBar 处理槽位
	if IdolBottomBar.blocks_hotspot_at(click_pos):
		return
	hide_all()
	bubble_dismissed.emit(true)
	if _bubble_dismiss_catcher != null:
		_bubble_dismiss_catcher.accept_event()

func _build_ui() -> void:
	_dismiss_rect = ColorRect.new()
	_dismiss_rect.name = "DismissRect"
	_dismiss_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dismiss_rect.color = Color(0, 0, 0, 0.01)
	_dismiss_rect.visible = false
	_dismiss_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dismiss_rect.gui_input.connect(_on_dismiss_rect_input)
	add_child(_dismiss_rect)

	_modal_center = Control.new()
	_modal_center.name = "ModalCenter"
	_modal_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_modal_center)

	_overlay_center = Control.new()
	_overlay_center.name = "OverlayCenter"
	_overlay_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_center.visible = false
	add_child(_overlay_center)

	_overlay_wrap = Control.new()
	_overlay_wrap.name = "OverlayWrap"
	_overlay_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_wrap.set_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_center.add_child(_overlay_wrap)

	_overlay_image = TextureRect.new()
	_overlay_image.name = "OverlayImage"
	_overlay_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_overlay_image.visible = false
	_overlay_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_wrap.add_child(_overlay_image)

	_modal_panel = PanelContainer.new()
	_modal_panel.name = "ModalPanel"
	_modal_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_panel.set_offsets_preset(Control.PRESET_FULL_RECT)
	_set_panel_frame_visible(false)
	_modal_center.add_child(_modal_panel)

	var modal_margin := MarginContainer.new()
	modal_margin.name = "ModalMargin"
	modal_margin.add_theme_constant_override("margin_left", 0)
	modal_margin.add_theme_constant_override("margin_top", 0)
	modal_margin.add_theme_constant_override("margin_right", 0)
	modal_margin.add_theme_constant_override("margin_bottom", 0)
	_modal_panel.add_child(modal_margin)

	_modal_content = Control.new()
	_modal_content.name = "ModalContent"
	_modal_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_content.set_offsets_preset(Control.PRESET_FULL_RECT)
	modal_margin.add_child(_modal_content)

	_modal_image = TextureRect.new()
	_modal_image.name = "ModalImage"
	_modal_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_modal_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_modal_image.visible = false
	_modal_content.add_child(_modal_image)

	_modal_placeholder = ColorRect.new()
	_modal_placeholder.name = "ModalPlaceholder"
	_modal_placeholder.visible = false
	_modal_content.add_child(_modal_placeholder)

	_modal_title = Label.new()
	_modal_title.text = "线索"
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_title.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1))
	_modal_title.add_theme_font_size_override("font_size", 18)
	_modal_content.add_child(_modal_title)

	_modal_body = Label.new()
	_modal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_modal_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modal_body.add_theme_color_override("font_color", Color(0.84, 0.82, 0.9, 1))
	_modal_body.text = ""
	_modal_content.add_child(_modal_body)

	_bubble_panel = PanelContainer.new()
	_bubble_panel.name = "BubblePanel"
	_bubble_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bubble_panel.offset_left = -170
	_bubble_panel.offset_top = -220
	_bubble_panel.offset_right = 170
	_bubble_panel.offset_bottom = -168
	_bubble_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.10, 0.18, 0.96), Color(0.93, 0.86, 0.66, 1), 1, 8))
	add_child(_bubble_panel)

	var bubble_margin := MarginContainer.new()
	bubble_margin.add_theme_constant_override("margin_left", 14)
	bubble_margin.add_theme_constant_override("margin_top", 10)
	bubble_margin.add_theme_constant_override("margin_right", 14)
	bubble_margin.add_theme_constant_override("margin_bottom", 10)
	_bubble_panel.add_child(bubble_margin)

	_bubble_label = Label.new()
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86, 1))
	_bubble_label.add_theme_font_size_override("font_size", 17)
	bubble_margin.add_child(_bubble_label)

	_ignore_modal_content_mouse()

func _ignore_modal_content_mouse() -> void:
	_set_ignore_recursive(_modal_center)
	if _overlay_center != null:
		_set_ignore_recursive(_overlay_center)
	_set_ignore_recursive(_bubble_panel)

func _set_ignore_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_ignore_recursive(child)

func _panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style
