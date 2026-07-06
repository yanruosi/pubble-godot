extends SceneTree

## 验证：从左侧拖回词库时，词条追加到右侧末尾（非字母重排）



func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== pool order test ===")
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
		print("[FAIL] missing nodes")
		quit(1)
		return

	for vocab_id in ["vocab_aroz", "vocab_may", "vocab_keycard", "vocab_hzs"]:
		vocab_bank.collect(vocab_id)

	scroll_panel.open_panel()
	await process_frame
	await process_frame

	var order_before: Array = scroll_panel.call("_visible_pool_order")
	if order_before.size() < 3:
		print("[FAIL] need at least 3 pool chips")
		quit(1)
		return

	# 模拟：把最后一个可见词条放到左侧，再拖回词库
	var last_id: String = str(order_before[order_before.size() - 1])
	var target_row: String = "v_leo"
	scroll_panel.call("_drag_apply_fill", target_row, last_id, "")
	await process_frame
	await process_frame

	var order_mid: Array = scroll_panel.call("_visible_pool_order")
	if order_mid.has(last_id):
		print("[FAIL] placed vocab should be hidden from pool")
		quit(1)
		return

	scroll_panel.call("_drag_clear_row", target_row)
	await process_frame
	await process_frame

	var order_after: Array = scroll_panel.call("_visible_pool_order")
	print("before:", order_before)
	print("after return:", order_after)

	if str(order_after[order_after.size() - 1]) != last_id:
		print("[FAIL] returned vocab should be last, got ", order_after)
		quit(1)
		return

	var append_logs := 0
	if FileAccess.file_exists(DEBUG_LOG):
		var f := FileAccess.open(DEBUG_LOG, FileAccess.READ)
		while not f.eof_reached():
			var line := f.get_line()
			if line.is_empty():
				continue
			var parsed: Variant = JSON.parse_string(line)
			if not (parsed is Dictionary):
				continue
			if str((parsed as Dictionary).get("message", "")) == "pool_order_append":
				append_logs += 1

	if append_logs < 1:
		print("[FAIL] missing pool_order_append log")
		quit(1)
		return

	print("[PASS] returned vocab appended to pool end")
	quit(0)
