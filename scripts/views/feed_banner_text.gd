extends RefCounted

const FeedDefs := preload("res://scripts/views/feed_defs.gd")


static func short_title(snap: Dictionary) -> String:
	var title: String = str(snap.get("title", ""))
	if title.length() <= 12:
		return title
	return title.substr(0, 12) + "..."


static func status_text(mode: String, snap: Dictionary) -> String:
	var st := short_title(snap)
	match mode:
		"exposing":
			var remain: float = float(snap.get("remaining_sec", -1.0))
			if not st.is_empty():
				if remain >= 0.0:
					return "《%s》正在曝光中...剩余%d秒" % [st, int(ceil(remain))]
				return "《%s》正在曝光中..." % st
			if remain >= 0.0:
				return "帖子正在曝光中...剩余%d秒" % int(ceil(remain))
			return "帖子正在曝光中..."
		"hot_success":
			if not st.is_empty():
				return "《%s》已上饭圈热门..." % st
			return "已上饭圈热门..."
		"hot_fail":
			if not st.is_empty():
				return "《%s》未能上饭圈热门..." % st
			return "未能上饭圈热门..."
		"new_replaced":
			return "参与互动收集更多艺人关键投稿，解锁新的艺人帖子"
		_:
			return ""


static func subline_text(mode: String, _snap: Dictionary) -> String:
	match mode:
		"exposing":
			return "参与pubble社区互动有概率上热门获得更多积分"
		"new_replaced":
			return keypost_progress_label(_snap)
		_:
			return ""


static func static_banner_status(_snap: Dictionary) -> String:
	return "参与互动收集更多艺人关键投稿，解锁新的艺人帖子"


static func static_banner_subline(snap: Dictionary) -> String:
	var next_title: String = str(snap.get("next_artist_title", ""))
	if next_title.is_empty():
		return ""
	return "当前《%s》待解锁" % next_title


static func keypost_text(snap: Dictionary) -> String:
	return keypost_progress_label(snap)


static func keypost_progress_label(snap: Dictionary) -> String:
	var target: int = int(snap.get("keypost_target", 0))
	var current: int = int(snap.get("keypost_current", 0))
	if target > 0:
		return "目前关键线索收集进度：%d/%d" % [current, target]
	return "目前关键线索收集进度：MAX"


static func heat_bar_ratio(snap: Dictionary) -> float:
	var heat_max: float = float(snap.get("heat_max", 50))
	if heat_max <= 0.0:
		heat_max = 50.0
	return clampf(float(snap.get("heat", 0)) / heat_max, 0.0, 1.0)


static func reward_fans_text(mode: String, snap: Dictionary) -> String:
	match mode:
		"exposing":
			return "我的粉丝：%d" % int(snap.get("fans", 0))
		"hot_success":
			var settle: int = int(snap.get("settle_fans", 0))
			var idle: int = int(snap.get("idle_fans_earned", 0))
			return "我的粉丝：%d+%d" % [settle, idle]
		"hot_fail":
			return "我的粉丝：+%d" % int(snap.get("display_fans", 0))
		_:
			return ""


static func reward_fp_text(mode: String, snap: Dictionary) -> String:
	match mode:
		"exposing":
			return "我的积分：%d" % int(snap.get("fp", 0))
		"hot_success":
			var settle: int = int(snap.get("settle_fp", 0))
			var idle: int = int(snap.get("idle_fp_earned", 0))
			return "我的积分：%d+%d" % [settle, idle]
		"hot_fail":
			return "我的积分：+%d" % int(snap.get("display_fp", 0))
		_:
			return ""


static func hide_overlays(status: Label, subline: Label, key: Label, bar: ProgressBar, flash: Label, fans: Label = null, fp: Label = null, heat_label: Label = null) -> void:
	if status != null:
		status.visible = false
	if subline != null:
		subline.visible = false
	if key != null:
		key.visible = false
	if bar != null:
		bar.visible = false
	if heat_label != null:
		heat_label.visible = false
	if flash != null:
		flash.visible = false
	if fans != null:
		fans.visible = false
	if fp != null:
		fp.visible = false


static func make_label(local_rect: Rect2, font_size: int, h_align: HorizontalAlignment, banner_rect: Rect2, v_align: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER) -> Label:
	var rect := local_rect_scaled(local_rect, banner_rect)
	var lbl := Label.new()
	lbl.position = rect.position
	lbl.custom_minimum_size = rect.size
	lbl.size = rect.size
	lbl.horizontal_alignment = h_align
	lbl.vertical_alignment = v_align
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	return lbl


static func local_rect_scaled(local_rect: Rect2, banner_rect: Rect2) -> Rect2:
	var scale := banner_rect.size / FeedDefs.BANNER_OVERLAY_SIZE
	return Rect2(local_rect.position * scale, local_rect.size * scale)
