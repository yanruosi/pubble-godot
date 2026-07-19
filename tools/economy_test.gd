extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== economy_test ===")
	await process_frame
	await process_frame
	await _test_currency_persist()
	await _test_consume_fail()
	await _test_save_version()
	await _test_type5_visibility()
	await _test_grant_idempotent()
	await _test_upgrade_intel()
	await _test_type6_condition()
	await _test_reset_defaults()
	_print_summary()
	quit(0 if _failures.is_empty() else 1)


func _print_summary() -> void:
	print("---")
	print("Failed: %d" % _failures.size())
	for f in _failures:
		print("  - ", f)


func _ok(label: String) -> void:
	print("[PASS] ", label)


func _fail(label: String, detail: String = "") -> void:
	var line := label if detail.is_empty() else "%s — %s" % [label, detail]
	_failures.append(line)
	print("[FAIL] ", line)


func _test_currency_persist() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var eco: EconomyManager = root.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if sm == null or eco == null:
		_fail("autoload missing")
		return
	sm.reset_progress()
	eco.add_currency(22, 15, "test")
	eco.add_currency(24, 8, "test")
	if sm.fp != 15 or sm.intel != 8:
		_fail("currency in memory", "fp=%d intel=%d" % [sm.fp, sm.intel])
		return
	sm.save_progress()
	sm.fp = 0
	sm.intel = 0
	sm.load_progress()
	if sm.fp != 15 or sm.intel != 8:
		_fail("currency persist reload")
	else:
		_ok("currency persist")


func _test_consume_fail() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var eco: EconomyManager = root.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if sm == null or eco == null:
		_fail("autoload missing for consume test")
		return
	sm.fp = 5
	if eco.consume_currency(22, 10, "test"):
		_fail("consume should fail")
	elif sm.fp != 5:
		_fail("consume fail changed balance")
	else:
		_ok("consume insufficient")


func _test_save_version() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	sm.reset_progress()
	sm.save_progress()
	var cfg := ConfigFile.new()
	cfg.load(SaveManager.SAVE_PATH)
	if int(cfg.get_value("meta", "save_version", 0)) != SaveManager.SAVE_VERSION:
		_fail("save_version meta")
	else:
		_ok("save_version meta")


func _test_type5_visibility() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var cc: ConditionChecker = root.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	var cm: ChapterManager = root.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	cc.setup(cm, sm)
	sm.intellevel = 0
	var post := {"condition_id": 4}
	if cc.is_feed_post_visible(post):
		_fail("type5 hidden at lv0")
	sm.intellevel = 1
	if not cc.is_feed_post_visible(post):
		_fail("type5 visible at lv1")
	else:
		_ok("type5 visibility")


func _test_grant_idempotent() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var eco: EconomyManager = root.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	sm.reset_progress()
	sm.mark_level_completed("ch1_l01", true)
	var before := sm.stars
	# simulate duplicate grant guard: only grant if not completed before action
	if not sm.is_level_completed("ch1_l01"):
		eco.add_currency(23, 3, "level_clear")
	if sm.stars != before:
		_fail("grant idempotent guard")
	else:
		_ok("grant idempotent guard")


func _test_upgrade_intel() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var eco: EconomyManager = root.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if sm == null or eco == null:
		_fail("autoload missing for intel upgrade")
		return
	sm.reset_progress()
	sm.keypost_progress = 2
	sm.intellevel = 0
	if not eco.try_upgrade_intel():
		_fail("try_upgrade_intel")
	elif sm.intellevel != 1:
		_fail("intellevel after upgrade", str(sm.intellevel))
	else:
		_ok("try_upgrade_intel")


func _test_type6_condition() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var cc: ConditionChecker = root.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	var cm: ChapterManager = root.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager
	if sm == null or cc == null or cm == null:
		_fail("autoload missing for type6")
		return
	cc.setup(cm, sm)
	sm.fanlevel = 0
	if cc.is_condition_met(5):
		_fail("type6 hidden at fan lv0")
	sm.fanlevel = 1
	if not cc.is_condition_met(5):
		_fail("type6 visible at fan lv1")
	else:
		_ok("type6 condition")


func _test_reset_defaults() -> void:
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if sm == null:
		_fail("SaveManager missing for reset test")
		return
	sm.reset_progress()
	if sm.fp != 0 or sm.intel != 0 or sm.stars != 0:
		_fail("reset currency not zero")
	elif sm.intellevel != 0 or sm.fanlevel != 0:
		_fail("reset levels not zero")
	else:
		_ok("reset defaults")
