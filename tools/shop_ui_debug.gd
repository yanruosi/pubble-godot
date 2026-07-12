extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await process_frame
	var sm: SaveManager = root.get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	var eco: EconomyManager = root.get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	if sm == null:
		quit(1)
		return
	sm.reset_progress()
	eco.add_currency(22, 200, "debug")
	var overlays := HomeOverlays.new()
	root.add_child(overlays)
	overlays.setup(null)
	await process_frame
	overlays.call("_open_shop_panel")
	await process_frame
	if overlays._shop_slot_buy.size() > 0:
		overlays.call("_on_shop_slot_buy_pressed", 0)
	await process_frame
	quit(0)
