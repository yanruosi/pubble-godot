extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")


static func apply_bar_styles(bar: ProgressBar) -> void:
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
	bar.add_theme_stylebox_override("background", bar_style)
	bar.add_theme_stylebox_override("fill", fill_style)


static func banner_bg_path(active_tab: String, account_idle: bool = false) -> String:
	if active_tab == FeedDefs.TAB_ARTIST:
		return FeedDefs.PATH_BANNER_SISTER
	if active_tab == FeedDefs.TAB_ACCOUNT and account_idle:
		return FeedDefs.PATH_BANNER_SISTER
	return FeedDefs.PATH_BANNER
