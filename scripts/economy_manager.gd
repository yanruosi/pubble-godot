extends Node
class_name EconomyManager

const INTEL_LEVELS_PATH := "res://data/intel_levels.json"
const FAN_LEVELS_PATH := "res://data/fan_levels.json"
const ITEMS_PATH := "res://data/items.json"

const CAT_FP := 22
const CAT_STARS := 23
const CAT_INTEL := 24

var _save_manager: SaveManager
var _intel_levels: Array = []
var _fan_levels: Array = []
var _items_by_id: Dictionary = {}


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_load_tables()


func _load_tables() -> void:
	_intel_levels = _read_json_array(INTEL_LEVELS_PATH)
	_fan_levels = _read_json_array(FAN_LEVELS_PATH)
	_items_by_id.clear()
	for item in _read_json_array(ITEMS_PATH):
		if item is Dictionary:
			var id: int = int(item.get("itemid", 0))
			if id > 0:
				_items_by_id[id] = item


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []


func add_currency(type: int, amount: int, _reason: String = "") -> void:
	if _save_manager == null or amount <= 0:
		return
	_save_manager.add_currency(type, amount)
	_save_manager.save_progress()


func consume_currency(type: int, amount: int, _reason: String = "") -> bool:
	if _save_manager == null:
		return false
	if not _save_manager.consume_currency(type, amount):
		return false
	_save_manager.save_progress()
	return true


func can_afford(type: int, amount: int) -> bool:
	if _save_manager == null:
		return false
	return _save_manager.get_currency(type) >= amount


func get_currency(type: int) -> int:
	if _save_manager == null:
		return 0
	return _save_manager.get_currency(type)


func get_intel_level() -> int:
	if _save_manager == null:
		return 0
	return _save_manager.intellevel


func get_fan_level() -> int:
	if _save_manager == null:
		return 0
	return _save_manager.fanlevel


func get_opinion_tier() -> String:
	return "mid"


func try_upgrade_intel() -> bool:
	if _save_manager == null:
		return false
	var next_level: int = _save_manager.intellevel + 1
	var row: Dictionary = _get_intel_level_row(next_level)
	if row.is_empty():
		return false
	var need: int = int(row.get("thresholdintel", 0))
	if _save_manager.intel < need:
		return false
	_save_manager.intel -= need
	_save_manager.intellevel = next_level
	if int(row.get("grantfp", 0)) > 0:
		_save_manager.add_currency(CAT_FP, int(row.get("grantfp", 0)))
	if int(row.get("grantstars", 0)) > 0:
		_save_manager.add_currency(CAT_STARS, int(row.get("grantstars", 0)))
	_save_manager.save_progress()
	return true


func try_upgrade_fan() -> bool:
	if _save_manager == null:
		return false
	var next_level: int = _save_manager.fanlevel + 1
	var row: Dictionary = _get_fan_level_row(next_level)
	if row.is_empty():
		return false
	var need_cat: int = int(row.get("costitemcategory", 0))
	var need_count: int = int(row.get("costitemcount", 0))
	if need_count <= 0:
		return false
	var owned: int = _count_inventory_by_category(need_cat)
	if owned < need_count:
		return false
	_consume_inventory_by_category(need_cat, need_count)
	_save_manager.fanlevel = next_level
	_save_manager.save_progress()
	var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
	if tutor != null:
		tutor.notify_fan_upgraded()
	return true


func _get_intel_level_row(level: int) -> Dictionary:
	for item in _intel_levels:
		if item is Dictionary and int(item.get("level", -1)) == level:
			return item
	return {}


func _get_fan_level_row(level: int) -> Dictionary:
	for item in _fan_levels:
		if item is Dictionary and int(item.get("level", -1)) == level:
			return item
	return {}


func _count_inventory_by_category(category: int) -> int:
	if _save_manager == null:
		return 0
	var total := 0
	for key in _save_manager.inventory.keys():
		var itemid: int = int(key)
		var item: Dictionary = _items_by_id.get(itemid, {})
		if int(item.get("category", -1)) == category:
			total += _save_manager.get_inventory_count(itemid)
	return total


func _consume_inventory_by_category(category: int, count: int) -> void:
	if _save_manager == null or count <= 0:
		return
	var remaining := count
	for key in _save_manager.inventory.keys():
		if remaining <= 0:
			break
		var itemid: int = int(key)
		var item: Dictionary = _items_by_id.get(itemid, {})
		if int(item.get("category", -1)) != category:
			continue
		var have: int = _save_manager.get_inventory_count(itemid)
		var take: int = mini(have, remaining)
		_save_manager.remove_inventory_item(itemid, take)
		remaining -= take
