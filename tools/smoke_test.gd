extends SceneTree

const REPORT_PATH := "D:/GAMES/pubble/tools/smoke_test_report.txt"

var _failures: Array[String] = []
var _passes: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== pubble smoke test ===")
	await process_frame
	await process_frame

	_test_autoloads()
	_test_chapter_data()
	_test_unlock_chain()
	_test_scene_loads()
	_test_level_data()

	_print_summary()
	_write_report()
	if _failures.is_empty():
		quit(0)
	else:
		quit(1)


func _ok(label: String) -> void:
	_passes += 1
	print("[PASS] ", label)


func _fail(label: String, detail: String = "") -> void:
	var line := label if detail.is_empty() else "%s — %s" % [label, detail]
	_failures.append(line)
	print("[FAIL] ", line)


func _test_autoloads() -> void:
	var cm: Node = root.get_node_or_null("/root/ChapterManagerSingleton")
	var sm: Node = root.get_node_or_null("/root/SaveManagerSingleton")
	var cc: Node = root.get_node_or_null("/root/ConditionCheckerSingleton")
	if cm == null:
		_fail("ChapterManagerSingleton missing")
	else:
		_ok("ChapterManagerSingleton loaded")
	if sm == null:
		_fail("SaveManagerSingleton missing")
	else:
		_ok("SaveManagerSingleton loaded")
	if cc == null:
		_fail("ConditionCheckerSingleton missing")
	else:
		_ok("ConditionCheckerSingleton loaded")
	if cm != null and sm != null and cc != null:
		(cc as ConditionChecker).setup(cm as ChapterManager, sm as SaveManager)


func _test_chapter_data() -> void:
	var cm := root.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	if cm == null:
		return
	var chapters: Array = cm.get_all_chapters()
	if chapters.size() != 4:
		_fail("chapter count", "expected 4 got %d" % chapters.size())
	else:
		_ok("chapters count = 4")

	var ch1: Dictionary = cm.get_chapter_by_id(1)
	if int(ch1.get("condition_id", -1)) != 0:
		_fail("chapter 1 condition_id", str(ch1.get("condition_id")))
	else:
		_ok("chapter 1 condition_id = 0")

	var ch2: Dictionary = cm.get_chapter_by_id(2)
	if int(ch2.get("condition_id", -1)) != 2001:
		_fail("chapter 2 condition_id", str(ch2.get("condition_id")))
	else:
		_ok("chapter 2 condition_id = 2001")

	var cond2001: Dictionary = cm.get_condition_by_id(2001)
	if int(cond2001.get("type", 0)) != 2:
		_fail("condition 2001 type", str(cond2001.get("type")))
	else:
		_ok("condition 2001 type = 2 (chapter chain)")


func _test_unlock_chain() -> void:
	var cm := root.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	var sm := root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var cc := root.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	if cm == null or sm == null or cc == null:
		return

	if not sm.is_chapter_available(1, cm, cc):
		_fail("chapter 1 should be available")
	else:
		_ok("chapter 1 available")

	var ch2_before: bool = sm.is_chapter_available(2, cm, cc)
	if ch2_before:
		_fail("chapter 2 should be locked before ch1 complete")
	else:
		_ok("chapter 2 locked before ch1 complete")

	sm.mark_chapter_completed(1, true)
	if not sm.is_chapter_available(2, cm, cc):
		_fail("chapter 2 should unlock after ch1 complete")
	else:
		_ok("chapter 2 unlocks after ch1 complete")


func _test_scene_loads() -> void:
	var scenes := {
		"title_screen": "res://scenes/title_screen.tscn",
		"main_ui": "res://scenes/main_ui.tscn",
		"ch1_l01": "res://scenes/idol/ch1_l01.tscn",
		"settings_panel": "res://scenes/settings_panel.tscn",
	}
	for name in scenes:
		var path: String = scenes[name]
		if not ResourceLoader.exists(path):
			_fail("scene missing", path)
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			_fail("scene load failed", path)
			continue
		var node: Node = packed.instantiate()
		if node == null:
			_fail("scene instantiate failed", path)
			continue
		root.add_child(node)
		await process_frame
		if name == "main_ui":
			var cheer := node.find_child("CheerGroup", true, false)
			if cheer != null:
				_fail("main_ui still has CheerGroup")
			else:
				_ok("main_ui has no CheerGroup")
		node.queue_free()
		await process_frame
		_ok("scene ok: %s" % name)


func _test_level_data() -> void:
	var path := "res://data/levels/ch1_l01/level.json"
	if not FileAccess.file_exists(path):
		_fail("level.json missing", path)
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Array) or (parsed as Array).is_empty():
		_fail("level.json parse")
		return
	var row: Dictionary = (parsed as Array)[0]
	if int(row.get("art_base_width", 0)) != 1280 or int(row.get("art_base_height", 0)) != 720:
		_fail("ch1_l01 art_base", "%s x %s" % [row.get("art_base_width"), row.get("art_base_height")])
	else:
		_ok("ch1_l01 art_base = 1280x720")


func _print_summary() -> void:
	print("---")
	print("Passed: %d" % _passes)
	print("Failed: %d" % _failures.size())
	for f in _failures:
		print("  - ", f)


func _write_report() -> void:
	var lines: PackedStringArray = []
	lines.append("pubble smoke test")
	lines.append("passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		lines.append("FAIL: " + f)
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
		print("Report: ", REPORT_PATH)
