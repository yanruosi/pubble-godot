extends SceneTree

const REPORT_PATH := "D:/GAMES/pubble/tools/flow_test_report.txt"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== pubble flow test ===")
	await process_frame
	await process_frame

	await _step_title_to_main()
	await _step_home_entry()
	await _step_feed_artist()
	await _step_level_scene()

	_print_summary()
	_write_report()
	quit(0 if _failures.is_empty() else 1)


func _ok(label: String) -> void:
	print("[PASS] ", label)


func _fail(label: String, detail: String = "") -> void:
	var line := label if detail.is_empty() else "%s — %s" % [label, detail]
	_failures.append(line)
	print("[FAIL] ", line)


func _step_title_to_main() -> void:
	var title_packed: PackedScene = load("res://scenes/title_screen.tscn") as PackedScene
	if title_packed == null:
		_fail("load title_screen")
		return
	var title: Node = title_packed.instantiate()
	root.add_child(title)
	await process_frame
	await process_frame

	var sm := root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		_fail("SaveManager missing in flow")
		title.queue_free()
		return

	sm.reset_progress()
	sm.boot_target = "home"

	if title.has_method("_on_new_game_pressed"):
		title.call("_on_new_game_pressed")
	else:
		_fail("title_screen missing _on_new_game_pressed")
		title.queue_free()
		return

	await process_frame
	await process_frame
	await process_frame

	var main := root.get_node_or_null("MainUI")
	if main == null:
		_fail("MainUI not loaded after new game")
		return
	_ok("title new game -> MainUI")


func _step_home_entry() -> void:
	var main := root.get_node_or_null("MainUI")
	if main == null:
		return

	var bottom_nav := main.get_node_or_null("SafeArea/RootVBox/BottomNav") as Control
	if bottom_nav == null or bottom_nav.visible:
		_fail("bottom nav should be hidden")
	else:
		_ok("bottom nav hidden")

	var btn := main.get_node_or_null("SafeArea/RootVBox/ContentStack/HomePage/BtnArtistFeed") as Button
	if btn == null:
		_fail("BtnArtistFeed missing")
		return
	if btn.text != "艺人动态":
		_fail("BtnArtistFeed text", btn.text)
	else:
		_ok("home has 艺人动态 button")

	var main_bg := main.get_node_or_null("SafeArea/RootVBox/ContentStack/HomePage/MainBg") as TextureRect
	if main_bg == null or main_bg.texture == null:
		_fail("MainBg texture missing")
	else:
		_ok("home mainbg loaded")


func _step_feed_artist() -> void:
	var main := root.get_node_or_null("MainUI")
	if main == null:
		return
	if not main.has_method("open_feed_artist_tab"):
		_fail("ui_router open_feed_artist_tab missing")
		return

	main.call("open_feed_artist_tab")
	await process_frame
	await process_frame

	var feed := main.get_node_or_null("SafeArea/RootVBox/ContentStack/FeedPage")
	if feed == null or not feed.visible:
		_fail("feed page not visible after entry")
		return
	_ok("feed page opens from 艺人动态")

	if feed.has_method("get_active_tab") and str(feed.call("get_active_tab")) != "artist":
		_fail("feed default tab", str(feed.call("get_active_tab")))
	else:
		_ok("feed default tab = artist")

	await process_frame
	await process_frame
	if feed.has_method("get_artist_visible_count"):
		var visible_count: int = int(feed.call("get_artist_visible_count"))
		if visible_count <= 0:
			_fail("artist tab shows no posts on new game", str(visible_count))
		else:
			_ok("artist tab shows ch1 posts count=%d" % visible_count)

	var raw: String = FileAccess.get_file_as_string("res://data/feed_posts.json")
	var posts: Variant = JSON.parse_string(raw)
	if posts is Array:
		var has_artist_post := false
		for item in posts:
			if item is Dictionary and int((item as Dictionary).get("type", 0)) == 901:
				has_artist_post = true
				break
		if has_artist_post:
			_ok("feed_posts.json has artist type posts")
		else:
			_fail("feed_posts.json missing type 901 posts")

	var cc := root.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	var sm := root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if cc == null or sm == null:
		_fail("ConditionChecker or SaveManager missing")
		return
	sm.intellevel = 0
	if cc.is_feed_post_visible({"condition_id": 4}):
		_fail("type5 should hide artist post at intel lv0")
	else:
		_ok("type5 hides artist post until intel level")


func _step_level_scene() -> void:
	var path := "res://scenes/idol/ch1_l01.tscn"
	if not ResourceLoader.exists(path):
		_fail("ch1_l01 scene missing")
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		_fail("ch1_l01 load failed")
		return
	var level: Node = packed.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	_ok("ch1_l01 instantiates")
	level.queue_free()


func _print_summary() -> void:
	print("---")
	print("Failed: %d" % _failures.size())
	for f in _failures:
		print("  - ", f)


func _write_report() -> void:
	var lines: PackedStringArray = ["pubble flow test", "failed=%d" % _failures.size()]
	for f in _failures:
		lines.append("FAIL: " + f)
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines))
		f.close()
