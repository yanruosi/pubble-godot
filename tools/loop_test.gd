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
	var inst_id := str(sm.feed_instances[0].get("instanceid", ""))
	expose.start_expose(inst_id)
	if not expose.collect_instance(inst_id):
		_fail("collect seed")
	elif sm.intel <= 0:
		_fail("intel after collect")
	else:
		_ok("seed collect intel")
	eco.try_upgrade_intel()
	if sm.intellevel < 1:
		_fail("intel upgrade")
	else:
		_ok("intel upgrade")
	eco.add_currency(22, 100, "test")
	if not shop.purchase(1):
		_fail("shop purchase")
	else:
		_ok("shop purchase")
	if not eco.try_upgrade_fan():
		_fail("fan upgrade")
	else:
		_ok("fan upgrade")
	if not act.participate("7"):
		_fail("sign activity")
	else:
		_ok("sign activity")
	if not act.participate("1"):
		_fail("airport activity")
	else:
		_ok("airport activity")
	_print_summary()
	quit(0 if _failures.is_empty() else 1)


func _ok(label: String) -> void:
	print("[PASS] ", label)


func _fail(label: String) -> void:
	_failures.append(label)
	print("[FAIL] ", label)


func _print_summary() -> void:
	print("Failed: %d" % _failures.size())
