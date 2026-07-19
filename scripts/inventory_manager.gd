extends Node
class_name InventoryManager

const ITEMS_PATH := "res://data/items.json"

var _save_manager: SaveManager
var _items_by_id: Dictionary = {}


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	for row in _table_array("items"):
		if row is Dictionary:
			_items_by_id[int(row.get("itemid", 0))] = row


func _table_array(name: String) -> Array:
	var parsed: Variant = TableRepo.get_table(name)
	return parsed if parsed is Array else []


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


func get_display_entries() -> Array:
	if _save_manager == null:
		return []
	var out: Array = []
	for key in _save_manager.inventory.keys():
		var itemid: int = int(key)
		var count: int = _save_manager.get_inventory_count(itemid)
		if count <= 0:
			continue
		var item: Dictionary = _items_by_id.get(itemid, {})
		out.append({
			"itemid": itemid,
			"name": str(item.get("name", "道具%d" % itemid)),
			"category": int(item.get("category", 0)),
			"count": count,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("itemid", 0)) < int(b.get("itemid", 0))
	)
	return out
