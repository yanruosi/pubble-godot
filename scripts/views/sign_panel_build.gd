extends RefCounted
class_name SignPanelBuild

const Defs := preload("res://scripts/views/home_overlay_defs.gd")
const Ui := preload("res://scripts/views/home_overlay_ui.gd")


static func build_win_overlay(parent: Control, on_input: Callable) -> Control:
	var win_overlay := Control.new()
	win_overlay.name = "ActivityWinOverlay"
	win_overlay.visible = false
	win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	win_overlay.gui_input.connect(on_input)
	parent.add_child(win_overlay)
	if ResourceLoader.exists(Defs.ACTIVITY_WIN_BG_PATH):
		var win_bg := TextureRect.new()
		win_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		win_bg.texture = load(Defs.ACTIVITY_WIN_BG_PATH) as Texture2D
		win_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		win_bg.stretch_mode = TextureRect.STRETCH_SCALE
		win_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		win_overlay.add_child(win_bg)
	else:
		push_warning("中签弹层缺失: %s" % Defs.ACTIVITY_WIN_BG_PATH)
	return win_overlay


static func build_settle_overlay(layer: CanvasLayer, on_close: Callable, on_go: Callable) -> Dictionary:
	var settle_overlay := Control.new()
	settle_overlay.name = "ActivitySettleOverlay"
	settle_overlay.visible = false
	settle_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settle_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(settle_overlay)
	if ResourceLoader.exists(Defs.ACTIVITY_SETTLE_BG_PATH):
		var bg := TextureRect.new()
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.texture = load(Defs.ACTIVITY_SETTLE_BG_PATH) as Texture2D
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		settle_overlay.add_child(bg)
	else:
		push_warning("结算底图缺失: %s" % Defs.ACTIVITY_SETTLE_BG_PATH)
	var close_btn := Ui.make_hit_button(Defs.ACTIVITY_CLOSE, "")
	close_btn.pressed.connect(on_close)
	settle_overlay.add_child(close_btn)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settle_overlay.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var settle_event := Label.new()
	settle_event.name = "SettleEvent"
	settle_event.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settle_event.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settle_event.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settle_event.custom_minimum_size = Vector2(620, 0)
	settle_event.add_theme_font_size_override("font_size", 15)
	settle_event.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18, 1))
	box.add_child(settle_event)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	var settle_rewards := Label.new()
	settle_rewards.name = "SettleRewards"
	settle_rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settle_rewards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settle_rewards.custom_minimum_size = Vector2(520, 0)
	settle_rewards.add_theme_font_size_override("font_size", 14)
	settle_rewards.add_theme_color_override("font_color", Color(0.18, 0.32, 0.22, 1))
	box.add_child(settle_rewards)
	var go_btn := Ui.make_hit_button(Rect2(490, 600, 300, 44), "前往pubble查看")
	go_btn.add_theme_font_size_override("font_size", 15)
	go_btn.add_theme_color_override("font_color", Color(0.12, 0.28, 0.18, 1))
	go_btn.pressed.connect(on_go)
	settle_overlay.add_child(go_btn)
	return {
		"overlay": settle_overlay,
		"event": settle_event,
		"rewards": settle_rewards,
		"go_btn": go_btn,
	}
