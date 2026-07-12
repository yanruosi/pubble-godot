extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== loop_test ===")
	await process_frame
	await process_frame
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var eco: EconomyManager = root.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	var expose: ExposeManager = root.get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	var shop: ShopManager = root.get_node_or_null("/root/ShopManagerSingleton") as ShopManager
	var act: ActivityManager = root.get_node_or_null("/root/ActivityManagerSingleton") as ActivityManager
	var cc: ConditionChecker = root.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	var cm: ChapterManager = root.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	if sm == null or eco == null or expose == null:
		_fail("autoload missing")
		_print_summary()
		quit(1)
		return
	cc.setup(cm, sm)
	sm.reset_progress()
	expose.seed_tutorial_instance()
	expose.on_tab_entered(903)
	if sm.intellevel < 1:
		_fail("intel upgrade after sister enter")
	elif sm.intel <= 0:
		_fail("intel after sister enter")
	else:
		_ok("seed collect intel + auto upgrade")
	eco.add_currency(22, 100, "test")
	if not shop.purchase(1):
		_fail("shop purchase")
	else:
		_ok("shop purchase")
	if sm.get_inventory_count(1001) < 1:
		_fail("shop inventory")
	else:
		_ok("shop inventory")
	if not eco.try_upgrade_fan():
		_fail("fan upgrade")
	else:
		_ok("fan upgrade")
	var draw_res: Dictionary = act.draw_lottery("7")
	if not bool(draw_res.get("ok", false)) or not bool(draw_res.get("won", false)):
		_fail("sign draw", str(draw_res.get("reason", "")))
	else:
		_ok("sign draw won")
	var sign_res: Dictionary = act.depart("7")
	if not bool(sign_res.get("ok", false)):
		_fail("sign depart", str(sign_res.get("reason", "")))
	else:
		var drawn: Array = sign_res.get("drawn", [])
		if drawn.is_empty():
			_fail("sign activity no post")
		elif str((drawn[0] as Dictionary).get("postid", "")) != "3010":
			_fail("sign activity not A tier", str((drawn[0] as Dictionary).get("postid", "")))
		else:
			_ok("sign activity A tier")
	var airport_res: Dictionary = act.participate("1")
	if not bool(airport_res.get("ok", false)):
		_fail("airport activity", str(airport_res.get("reason", "")))
	elif (airport_res.get("drawn", []) as Array).is_empty():
		_fail("airport activity no post")
	else:
		_ok("airport activity")
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
