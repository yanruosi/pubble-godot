extends Node
class_name InventoryManager

var _save_manager: SaveManager


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager


func add_item(itemid: int, count: int = 1) -> void:
	if _save_manager == null or count <= 0:
		return
	_save_manager.add_inventory_item(itemid, count)
	_save_manager.save_progress()


func remove_item(itemid: int, count: int = 1) -> bool:
	if _save_manager == null:
		return false
	if not _save_manager.remove_inventory_item(itemid, count):
		return false
	_save_manager.save_progress()
	return true


func get_count(itemid: int) -> int:
	if _save_manager == null:
		return 0
	return _save_manager.get_inventory_count(itemid)


func has_enough(itemid: int, count: int) -> bool:
	return get_count(itemid) >= count
