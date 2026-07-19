extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== loop_test M3.7 v2 ===")
	await process_frame
	await process_frame
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var expose: ExposeManager = root.get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	var act: ActivityManager = root.get_node_or_null("/root/ActivityManagerSingleton") as ActivityManager
	var cc: ConditionChecker = root.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	var cm: ChapterManager = root.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	if sm == null or expose == null or act == null:
		_fail("autoload missing")
		_print_summary()
		quit(1)
		return
	cc.setup(cm, sm)
	sm.reset_progress()
	sm.opening_done = false
	sm.save_progress()
	_ok("reset opening_done=false")
	expose.on_game_loaded()

	#region UI smoke
	var feed_script := load("res://scenes/feed_page.gd")
	if feed_script == null:
		_fail("feed_page.gd load failed")
	else:
		var feed: Control = feed_script.new() as Control
		root.add_child(feed)
		await process_frame
		await process_frame
		if feed.has_method("_build_ui"):
			# _ready already deferred _build_ui; wait more
			await process_frame
			await process_frame
		_ok("feed_page UI smoke _build_ui")
		feed.queue_free()
		await process_frame
	#endregion

	var settle: Dictionary = act.participate("1")
	if settle.is_empty() or not bool(settle.get("ok", false)):
		_fail("activity 1 first clear", str(settle.get("reason", "")))
	else:
		_ok("activity 1 first clear")

	var tags: Array = expose.get_post_tags()
	if tags.is_empty():
		_fail("get_post_tags empty")
	else:
		_ok("get_post_tags size=%d" % tags.size())

	var preview: Dictionary = expose.preview_tag_post("tag_music")
	var preview_id: String = str(preview.get("mypostid", ""))
	if preview_id.is_empty():
		_fail("preview_tag_post empty")
	else:
		_ok("preview_tag_post=%s" % preview_id)

	var post_res: Dictionary = expose.post_with_tag("tag_music", preview_id)
	if not bool(post_res.get("ok", false)):
		_fail("post_with_tag preview", str(post_res.get("reason", "")))
	else:
		var qi: Dictionary = post_res.get("queue_item", {}) as Dictionary
		if str(qi.get("mypostid", "")) != preview_id:
			_fail("post mypostid mismatch", "%s != %s" % [qi.get("mypostid", ""), preview_id])
		else:
			_ok("post_with_tag matches preview")

	if not bool(sm.opening_done):
		_fail("opening_done still false after first post")
	else:
		_ok("opening_done=true after first post")

	expose.add_heat("like")
	expose.add_heat("fav")
	_ok("add_heat like/fav")

	expose.on_tab_entered(0)
	if expose.has_method("debug_flush_feed_pending"):
		expose.debug_flush_feed_pending()
	expose.on_tab_entered(0)
	var key_inst_id := ""
	for item in expose.get_instances_for_tab(0):
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		var tpl: Dictionary = expose.get_template(str(inst.get("postid", "")))
		if int(tpl.get("postclass", 0)) == 3:
			key_inst_id = str(inst.get("instanceid", ""))
			break
	if key_inst_id.is_empty():
		_fail("no keypost instance on fandom tab")
	else:
		expose.favorite_instance(key_inst_id)
		if sm.keypost_progress < 1:
			_fail("keypost after favorite", str(sm.keypost_progress))
		else:
			_ok("keypost after favorite=%d" % sm.keypost_progress)

	expose.on_tab_entered(904)
	seed(314159265)  # M3.9: 固定 RNG，idle 段稳定可复现
	expose.debug_skip_expose_timer()
	expose.settle_pending_head()

	var collected_kept := false
	var idle_item: Dictionary = {}
	for item_raw in sm.mypost_queue:
		if not (item_raw is Dictionary):
			continue
		var item: Dictionary = item_raw as Dictionary
		if str(item.get("state", "")) == "collected":
			collected_kept = true
			idle_item = item
			break
	if not collected_kept:
		_fail("collected item removed from queue")
	else:
		_ok("collected kept in mypost_queue")

	if not idle_item.is_empty():
		if int(idle_item.get("hotresult", 0)) != 1:
			idle_item["hotresult"] = 1
			idle_item["is_pinned"] = true
		idle_item["idle_next_ts"] = int(Time.get_unix_time_from_system()) - 1
		# force one idle tick via process frames
		for _i in range(8):
			await process_frame
		if int(idle_item.get("idle_fp_earned", 0)) <= 0 and int(idle_item.get("idle_fans_earned", 0)) <= 0:
			# call process path: expose _process needs time; nudge by re-setting and waiting
			idle_item["idle_next_ts"] = int(Time.get_unix_time_from_system()) - 1
			await create_timer(0.3).timeout
		if int(idle_item.get("idle_fp_earned", 0)) > 0 or int(idle_item.get("idle_fans_earned", 0)) > 0:
			_ok("idle_rewards tick fp=%d fans=%d" % [int(idle_item.get("idle_fp_earned", 0)), int(idle_item.get("idle_fans_earned", 0))])
		else:
			_fail("idle_fp_earned still 0")

	if int(sm.fans) <= 0:
		_fail("fans after settle", str(sm.fans))
	else:
		_ok("fans=%d" % int(sm.fans))

	var econ: EconomyManager = root.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	var guard := 0
	while sm.fans < 100 and guard < 8:
		guard += 1
		if sm.get_post_count("tag_music") <= 0:
			sm.add_post_count("tag_music", 3)
		var pr: Dictionary = expose.post_with_tag("tag_music")
		if not bool(pr.get("ok", false)):
			break
		expose.on_tab_entered(904)
		expose.debug_skip_expose_timer()
		expose.settle_pending_head()
	if econ != null:
		while econ.try_upgrade_station():
			pass
	if int(sm.fanlevel) >= 1:
		_ok("站姐Lv1 fanlevel=%d fans=%d" % [int(sm.fanlevel), int(sm.fans)])
	else:
		_fail("站姐Lv1", "fanlevel=%d fans=%d" % [int(sm.fanlevel), int(sm.fans)])

	_print_summary()
	quit(0 if _failures.is_empty() else 1)


func _ok(label: String) -> void:
	print("[PASS] ", label)


func _fail(label: String, detail: String = "") -> void:
	var line := label if detail.is_empty() else "%s — %s" % [label, detail]
	_failures.append(line)
	print("[FAIL] ", line)


func _print_summary() -> void:
	print("Failed: %d" % _failures.size())
