extends SceneTree

## 模拟：在 chip A 按下并拖过 B/C，验证只触发一次 vocab_drag_begin

const DEBUG_LOG := "res://debug-45c98c.log"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== drag cross chip test ===")
	if FileAccess.file_exists(DEBUG_LOG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEBUG_LOG))

	await process_frame
	await process_frame

	var packed: PackedScene = load("res://scenes/idol/ch1_l01.tscn") as PackedScene
	if packed == null:
		print("[FAIL] load scene")
		quit(1)
		return

	var level: Node = packed.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame

	var scroll_panel: ScrollSlotPanel = level.get_node_or_null("ScrollPanel") as ScrollSlotPanel
	var vocab_bank: VocabBank = level.get_node_or_null("VocabBank") as VocabBank
	if scroll_panel == null or vocab_bank == null:
		print("[FAIL] missing ScrollPanel or VocabBank")
		quit(1)
		return

	for vocab_id in ["vocab_aroz", "vocab_may", "vocab_hzs"]:
		vocab_bank.collect(vocab_id)

	scroll_panel.open_panel()
	await process_frame
	await process_frame

	var chip_layer: Control = scroll_panel.get_node_or_null("VocabChipLayer") as Control
	if chip_layer == null or chip_layer.get_child_count() < 2:
		print("[FAIL] need at least 2 vocab chips")
		quit(1)
		return

	var chip_a: Control = chip_layer.get_child(0) as Control
	var chip_b: Control = chip_layer.get_child(1) as Control
	var chip_c: Control = chip_layer.get_child(min(2, chip_layer.get_child_count() - 1)) as Control

	_inject_press(chip_a, Vector2(20, 20))
	await process_frame

	var begins: Array[String] = []
	var rejects := 0
	var ghost_shows := 0
	var ghost_pos_logs := 0

	_inject_motion(chip_a, Vector2(40, 20))
	await process_frame
	await process_frame
	_inject_motion(chip_b, Vector2(40, 20))
	await process_frame
	await process_frame
	_inject_motion(chip_c, Vector2(40, 20))
	await process_frame
	await process_frame

	if FileAccess.file_exists(DEBUG_LOG):
		var f := FileAccess.open(DEBUG_LOG, FileAccess.READ)
		while not f.eof_reached():
			var line := f.get_line()
			if line.is_empty():
				continue
			var parsed: Variant = JSON.parse_string(line)
			if not (parsed is Dictionary):
				continue
			var msg: String = str((parsed as Dictionary).get("message", ""))
			var data: Dictionary = (parsed as Dictionary).get("data", {})
			if msg == "vocab_drag_begin" and str(data.get("runId", "")) == "drag-fix-v2":
				begins.append(str(data.get("vocab_id", "")))
			if msg == "vocab_drag_rejected":
				rejects += 1
			if msg == "drag_ghost_show" and str(data.get("runId", "")) == "drag-ghost-v1":
				ghost_shows += 1
			if msg == "drag_ghost_pos" and str(data.get("runId", "")) == "drag-ghost-v1":
				ghost_pos_logs += 1

	_inject_release(chip_c, Vector2(50, 20))

	print("drag_begin count:", begins.size(), " ids:", begins, " rejects:", rejects)
	print("drag_ghost_show:", ghost_shows, " drag_ghost_pos:", ghost_pos_logs)
	if begins.size() == 1 and ghost_shows >= 1:
		print("[PASS] single drag begin with overlay ghost")
		quit(0)
	elif begins.size() == 1:
		print("[PASS] single drag begin")
		quit(0)
	else:
		print("[FAIL] expected 1 drag begin, got ", begins.size())
		quit(1)


func _inject_press(control: Control, local_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = local_pos
	control.call("_on_gui_input", ev)


func _inject_motion(control: Control, local_pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	ev.position = local_pos
	ev.relative = Vector2(10, 0)
	control.call("_on_gui_input", ev)


func _inject_release(control: Control, local_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = local_pos
	control.call("_on_gui_input", ev)
