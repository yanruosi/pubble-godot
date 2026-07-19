extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")


static func build(ctrl: FeedController) -> void:
	var panel := PanelContainer.new()
	panel.position = FeedDefs.HOTSEARCH_RECT.position
	panel.custom_minimum_size = FeedDefs.HOTSEARCH_RECT.size
	panel.size = FeedDefs.HOTSEARCH_RECT.size
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.25)
	panel.add_theme_stylebox_override("panel", ps)
	ctrl._content_root.add_child(panel)
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
	ctrl._hot_list = VBoxContainer.new()
	ctrl._hot_list.add_theme_constant_override("separation", 4)
	col.add_child(ctrl._hot_list)
	for line in [
		"1. Beave回归预告", "2. 新歌难听", "3. 新人男团疑似恋爱",
		"4. 新人男团疑似恋爱", "5. 新人男团疑似恋爱", "6. 新人男团疑似恋爱",
		"7. 新人男团疑似恋爱", "8. 新人男团疑似恋爱", "9. 新人男团疑似恋爱",
		"10. 新人男团疑似恋爱",
	]:
		var l := Label.new()
		l.text = line
		l.add_theme_font_size_override("font_size", 13)
		ctrl._hot_list.add_child(l)
