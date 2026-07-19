extends RefCounted
class_name FeedCardBag

var _ctrl: FeedController


func _init(ctrl: FeedController) -> void:
	_ctrl = ctrl


func on_market_bag_pressed() -> void:
	if _ctrl._bag_panel == null:
		return
	refresh_bag_panel()
	_ctrl._bag_panel.visible = not _ctrl._bag_panel.visible


func refresh_bag_panel() -> void:
	if _ctrl._bag_grid == null:
		return
	for c in _ctrl._bag_grid.get_children():
		c.queue_free()
	var inv: InventoryManager = _ctrl._page.get_node_or_null("/root/InventoryManagerSingleton") as InventoryManager
	if inv == null:
		return
	var entries: Array = inv.get_display_entries()
	if entries.is_empty():
		var tip := Label.new()
		tip.text = "背包为空"
		tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
		_ctrl._bag_grid.add_child(tip)
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
		_ctrl._bag_grid.add_child(cell)
