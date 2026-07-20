extends RefCounted
class_name CurrencyBarView

const FeedDefs := preload("res://scripts/views/feed_defs.gd")

const MODE_FEED := "feed"
const MODE_PANEL := "panel"

var root: Control
var _fp_label: Label
var _fans_label: Label
var _stars_label: Label
var _mode: String = MODE_FEED


func build(parent: Control, mode: String = MODE_FEED) -> void:
	_mode = mode
	root = Control.new()
	root.name = "CurrencyBar"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	_fp_label = _make_label(FeedDefs.HUD_FP_RECT, 14)
	_fp_label.name = "HudFp"
	root.add_child(_fp_label)
	if mode == MODE_FEED:
		_fans_label = _make_label(FeedDefs.HUD_FANS_RECT, 14)
		_fans_label.name = "HudFans"
		root.add_child(_fans_label)
	else:
		_stars_label = _make_label(FeedDefs.HUD_STARS_RECT, 14)
		_stars_label.name = "HudStars"
		root.add_child(_stars_label)


func apply(save: SaveManager) -> void:
	if save == null:
		return
	if _fp_label != null:
		_fp_label.text = "饭圈积分 %d" % save.fp
	if _fans_label != null:
		_fans_label.text = "粉丝 %d" % save.fans
	if _stars_label != null:
		_stars_label.text = "星星 %d" % save.stars


func pulse_fp(host: Control) -> void:
	if _fp_label == null or host == null:
		return
	var tw := host.create_tween()
	tw.tween_property(_fp_label, "scale", Vector2(1.12, 1.12), 0.1)
	tw.tween_property(_fp_label, "scale", Vector2.ONE, 0.12)


func _make_label(rect: Rect2, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.position = rect.position
	lbl.custom_minimum_size = rect.size
	lbl.size = rect.size
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.2, 0.15, 0.35, 1))
	lbl.clip_text = true
	return lbl
