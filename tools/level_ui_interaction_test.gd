extends SceneTree

## 关卡底栏槽位 + 气泡关闭 自动化点击测试

const SLOT1_CENTER := Vector2(122.5, 653.0)
const SCENE_CLICK := Vector2(640.0, 360.0)
const HOTSPOT_CLICK := Vector2(375.0, 264.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== level ui interaction test ===")
	await process_frame
	await process_frame

	var packed: PackedScene = load("res://scenes/idol/ch1_l01.tscn") as PackedScene
	if packed == null:
		_fail("load ch1_l01")
		_finish()
		return

	var level: Node = packed.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame

	var bottom_bar: IdolBottomBar = level.get_node_or_null("BottomBar") as IdolBottomBar
	var scroll_panel: ScrollSlotPanel = level.get_node_or_null("ScrollPanel") as ScrollSlotPanel
	var popup_layer: IdolPopupPanel = level.get_node_or_null("PopupLayer") as IdolPopupPanel
	var hotspot_layer: HotspotLayer = level.get_node_or_null("HotspotLayer") as HotspotLayer

	if bottom_bar == null or scroll_panel == null or popup_layer == null or hotspot_layer == null:
		_fail("missing level nodes")
		_finish()
		return

	# 气泡：直接 show_bubble + 点击场景中央关闭（验证 PopupLayer z=350 关闭层）
	popup_layer.show_bubble("穿着演出服的男人", false)
	await process_frame
	if not _is_bubble_visible(popup_layer):
		_fail("bubble should be visible after show_bubble")
	else:
		_ok("bubble visible after show_bubble")

	_inject_bubble_canvas_click(popup_layer, SCENE_CLICK)
	await process_frame
	await process_frame

	if _is_bubble_visible(popup_layer):
		_fail("bubble should dismiss on outside click")
	else:
		_ok("bubble dismisses on outside click")

	# 通过 BottomBar._input 注入点击（与实机鼠标路径一致）
	_inject_bottom_bar_click(bottom_bar, SLOT1_CENTER)
	await process_frame
	await process_frame

	if _is_bubble_visible(popup_layer):
		_fail("bubble should not reappear when clicking slot1")
	else:
		_ok("no bubble when clicking slot1")

	if not scroll_panel.visible:
		_fail("scroll panel should open after slot1 _input click")
	else:
		_ok("scroll panel opens on slot1 _input click")

	# 直接发信号，验证槽位链路（与合成点击无关）
	scroll_panel.close_panel(false)
	await process_frame
	bottom_bar.slot_pressed.emit("slot1")
	await process_frame
	await process_frame
	if scroll_panel.visible:
		_ok("scroll panel opens via slot_pressed signal")
	else:
		_fail("scroll panel should open via slot_pressed signal")

	_finish()


func _inject_bubble_canvas_click(popup_layer: IdolPopupPanel, global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = global_pos
	popup_layer.call("_on_bubble_dismiss_catcher_gui_input", press)


func _inject_bottom_bar_click(bottom_bar: IdolBottomBar, global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = global_pos
	bottom_bar._input(press)


func _simulate_click(global_pos: Vector2) -> void:
	var vp := root.get_viewport()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = global_pos
	press.position = global_pos
	vp.push_input(press)
	await process_frame

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = global_pos
	release.position = global_pos
	vp.push_input(release)


func _is_bubble_visible(popup_layer: IdolPopupPanel) -> bool:
	var bubble := popup_layer.get_node_or_null("BubblePanel") as Control
	if bubble != null and bubble.visible:
		return true
	var canvas_bubble := popup_layer.get_node_or_null("BubbleDismissCanvas/BubblePanel") as Control
	return canvas_bubble != null and canvas_bubble.visible


func _ok(label: String) -> void:
	print("[PASS] ", label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[FAIL] ", label)


func _finish() -> void:
	print("---")
	print("Failed: %d" % _failures.size())
	for f in _failures:
		print("  - ", f)
	if FileAccess.file_exists(DEBUG_LOG):
		print("Debug log: ", DEBUG_LOG)
	quit(0 if _failures.is_empty() else 1)
