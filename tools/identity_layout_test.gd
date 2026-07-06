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
	bank.collect("vocab_leo")
	bank.collect("vocab_may")
	panel.set_unlock_events({"leo_portrait_unlocked": true, "may_portrait_unlocked": false})
	panel.open_panel()
	await process_frame
	await process_frame

	print("rows:", panel._rows.size())

	var portrait_count := 0
	var blank_count := 0
	var leo_size := Vector2.ZERO
	if panel._identity_layer != null:
		for child in panel._identity_layer.get_children():
			if child.name.begins_with("PortraitHost_"):
				portrait_count += 1
				if child.name == "PortraitHost_portrait_left":
					leo_size = (child as Control).size
			if child.name.begins_with("BlankHost_"):
				blank_count += 1

	var mask: ColorRect = panel.get_node("SceneMask") as ColorRect
	print("portraits:", portrait_count, " blanks:", blank_count)
	print("leo portrait size:", leo_size, " expect:", Vector2(91, 92))
	print("mask size:", mask.size, " anchors:", mask.anchor_right, mask.anchor_bottom)
	print("status:", panel._status_label.text)
	var status_host := panel._status_host
	var status_rect := status_host.get_rect() if status_host != null else Rect2()
	print("status rect:", status_rect)
	print("status font:", panel._status_label.get_theme_font_size("font_size"))

	var ok := true
	if portrait_count != 2:
		print("[FAIL] need 2 portraits")
		ok = false
	if blank_count != 2:
		print("[FAIL] need 2 blanks")
		ok = false
	if leo_size != Vector2(91, 92):
		print("[FAIL] leo portrait not PSD size")
		ok = false
	if panel._status_label.text != "信息尚未填写完整":
		print("[FAIL] status text wrong")
		ok = false
	if panel._status_label.get_theme_font_size("font_size") != 27:
		print("[FAIL] status font not 27pt")
		ok = false
	if panel._status_label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		print("[FAIL] status should not autowrap")
		ok = false
	if status_host == null:
		print("[FAIL] missing StatusHost")
		ok = false
	elif status_host.position != IdentitySlotPanel.STATUS_RECT.position:
		print("[FAIL] status position not PSD:", status_host.position)
		ok = false
	elif status_host.size != IdentitySlotPanel.STATUS_RECT.size:
		print("[FAIL] status size not PSD:", status_host.size, " expect:", IdentitySlotPanel.STATUS_RECT.size)
		ok = false
	var bg_bottom := IdentitySlotPanel.IDENTITY_BG_RECT.position.y + IdentitySlotPanel.IDENTITY_BG_RECT.size.y
	var status_bottom := status_host.position.y + status_host.size.y
	if status_bottom > bg_bottom + 8.0:
		print("[FAIL] status box extends too far below identity bg:", status_bottom, " bg_bottom:", bg_bottom)
		ok = false
	if IdentitySlotPanel.IDENTITY_BG_RECT.size != Vector2(540, 263):
		print("[FAIL] identity bg height should match texture 263")
		ok = false
	if mask.size.y < 700:
		print("[FAIL] mask not full height:", mask.size)
		ok = false

	if ok:
		print("[PASS] slot2 layout fix")
	quit(0 if ok else 1)
