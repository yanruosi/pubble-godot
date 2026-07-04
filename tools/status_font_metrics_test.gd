extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var bg_tex: Texture2D = load("res://art/mainui/level/caowei2bg.png") as Texture2D
	var bg_size := bg_tex.get_size() if bg_tex != null else Vector2.ZERO
	print("caowei2bg native:", bg_size, " code_rect:", IdentitySlotPanel.IDENTITY_BG_RECT.size)

	var font := ThemeDB.fallback_font
	var fs := IdentitySlotPanel.STATUS_FONT_SIZE
	for text in [
		IdentitySlotPanel.STATUS_INCOMPLETE,
		IdentitySlotPanel.STATUS_CORRECT,
		IdentitySlotPanel.STATUS_INCORRECT,
	]:
		var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		print("text:", text, " width:", sz.x, " psd_box_w:", IdentitySlotPanel.STATUS_RECT.size.x)

	print("psd_status_rect:", IdentitySlotPanel.STATUS_RECT)
	print("code_status_rect:", IdentitySlotPanel.new()._status_label_rect())
	quit(0)
