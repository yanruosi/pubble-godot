extends RefCounted


const FeedDefs := preload("res://scripts/views/feed_defs.gd")


static func status_text(mode: String, snap: Dictionary) -> String:
	var title: String = str(snap.get("title", ""))
	var short_title := title if title.length() <= 12 else title.substr(0, 12) + "..."
	var disp_fp: int = int(snap.get("display_fp", 0))
	var disp_fans: int = int(snap.get("display_fans", 0))
	match mode:
		"exposing":
			var remain: float = float(snap.get("remaining_sec", -1.0))
			if remain >= 0.0 and not short_title.is_empty():
				return "《%s》曝光中 %d秒" % [short_title, int(ceil(remain))]
			if not short_title.is_empty():
				return "《%s》正在曝光中..." % short_title
			return "帖子正在曝光中..."
		"hot_success":
			if not short_title.is_empty():
				return "《%s》热帖中 积分+%d 粉丝+%d" % [short_title, disp_fp, disp_fans]
			return "成为今日热帖 放置收益中..."
		"hot_fail":
			return "推流中 积分+%d 粉丝+%d" % [disp_fp, disp_fans]
		"new_replaced":
			if not short_title.is_empty():
				return "《%s》正在置顶曝光中" % short_title
			return "置顶帖已更新"
		_:
			return ""


static func hide_overlays(status: Label, rate: Label, lv: Label, key: Label, bar: ProgressBar, flash: Label) -> void:
	if status != null:
		status.visible = false
	if rate != null:
		rate.visible = false
	if lv != null:
		lv.visible = false
	if key != null:
		key.visible = false
	if bar != null:
		bar.visible = false
	if flash != null:
		flash.visible = false


static func make_label(local_rect: Rect2, font_size: int, align: HorizontalAlignment, banner_rect: Rect2) -> Label:
	var rect := local_rect_scaled(local_rect, banner_rect)
	var lbl := Label.new()
	lbl.position = rect.position
	lbl.custom_minimum_size = rect.size
	lbl.size = rect.size
	lbl.horizontal_alignment = align
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.35, 0.18, 0.55, 1))
	return lbl


static func local_rect_scaled(local_rect: Rect2, banner_rect: Rect2) -> Rect2:
	var scale := banner_rect.size / FeedDefs.BANNER_OVERLAY_SIZE
	return Rect2(local_rect.position * scale, local_rect.size * scale)
