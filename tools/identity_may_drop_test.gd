extends SceneTree



func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(DEBUG_LOG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEBUG_LOG))

	await process_frame
	await process_frame

	var level = load("res://scenes/idol/ch1_l01.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	await process_frame

	var panel: IdentitySlotPanel = level.get_node("IdentityPanel") as IdentitySlotPanel
	var bank: VocabBank = level.get_node("VocabBank") as VocabBank
	bank.collect("vocab_may")
	panel.set_unlock_events({"leo_portrait_unlocked": true})
	panel.open_panel()
	await process_frame

	var may_row: Dictionary = {}
	for row in panel._rows:
		if str(row.get("row_id", "")) == "portrait_right":
			may_row = row
			break
	var may_unlocked := panel._is_row_unlocked(may_row)
	var accepts := panel._row_accepts_vocab("portrait_right", "vocab_may")
	var blank = panel._blank_slots.get("portrait_right")
	var can_drop := false
	if blank != null and blank.has_method("_can_drop_data"):
		can_drop = blank.call("_can_drop_data", Vector2.ZERO, {"vocab_id": "vocab_may", "from_row_id": ""})

	print("may_unlocked:", may_unlocked, " accepts:", accepts, " can_drop:", can_drop)
	print("active_rows:", panel._active_rows.size())
	print("portrait_y:", IdentitySlotPanel.PORTRAIT_MAY_RECT.position.y)

	var ok := may_unlocked and accepts and can_drop and panel._active_rows.size() == 2
	if ok:
		print("[PASS] identity may drop")
	else:
		print("[FAIL] identity may drop")
	quit(0 if ok else 1)
