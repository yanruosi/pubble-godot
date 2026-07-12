extends Node
class_name ShopManager

const SHOP_OFFERS_PATH := "res://data/shop_offers.json"
const ITEMS_PATH := "res://data/items.json"
const FAN_LEVELS_PATH := "res://data/fan_levels.json"

var _save_manager: SaveManager
var _economy_manager: EconomyManager
var _inventory_manager: InventoryManager
var _condition_checker: ConditionChecker
var _offers: Array = []
var _items_by_id: Dictionary = {}
var _fan_levels: Array = []


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_economy_manager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_inventory_manager = get_node_or_null("/root/InventoryManagerSingleton") as InventoryManager
	_condition_checker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	_offers = _read_json_array(SHOP_OFFERS_PATH)
	for row in _read_json_array(ITEMS_PATH):
		if row is Dictionary:
			_items_by_id[int(row.get("itemid", 0))] = row
	_fan_levels = _read_json_array(FAN_LEVELS_PATH)


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []


func get_offers() -> Array:
	return _offers.duplicate(true)


func get_visible_offers(shoptab: int = 1) -> Array:
	var out: Array = []
	for item in _offers:
		if not (item is Dictionary):
			continue
		var offer: Dictionary = item as Dictionary
		if int(offer.get("shoptab", 1)) != shoptab:
			continue
		if not _is_offer_visible(offer):
			continue
		out.append(offer.duplicate(true))
	return out


func _is_offer_visible(offer: Dictionary) -> bool:
	if int(offer.get("stocklimit", -1)) == 0:
		return false
	if int(offer.get("tutorialonly", 0)) == 1:
		var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
		if tutor == null or not tutor.is_active():
			return false
	var condition_id: int = int(offer.get("conditionid", 0))
	if condition_id > 0 and _condition_checker != null:
		if not _condition_checker.is_condition_met(condition_id):
			return false
	return true


func purchase(offerid: int) -> bool:
	var offer: Dictionary = _get_offer(offerid)
	if offer.is_empty() or not _is_offer_visible(offer):
		return false
	var stock: int = int(offer.get("stocklimit", -1))
	if stock == 0:
		return false
	var currency: int = int(offer.get("currencytype", 22))
	var price: int = int(offer.get("price", 0))
	if _economy_manager == null or not _economy_manager.can_afford(currency, price):
		return false
	if not _economy_manager.consume_currency(currency, price, "shop"):
		return false
	if _inventory_manager != null:
		_inventory_manager.add_item(int(offer.get("itemid", 0)), 1)
	var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
	if tutor != null:
		tutor.notify_shop_purchased()
	return true


func get_fan_level_row(level: int) -> Dictionary:
	for row in _fan_levels:
		if row is Dictionary and int(row.get("level", -1)) == level:
			return row as Dictionary
	return {}


func get_next_fan_level_row() -> Dictionary:
	if _save_manager == null:
		return {}
	return get_fan_level_row(_save_manager.fanlevel + 1)


func count_inventory_by_category(category: int) -> int:
	if _save_manager == null:
		return 0
	var total := 0
	for key in _save_manager.inventory.keys():
		var itemid: int = int(key)
		var item: Dictionary = _items_by_id.get(itemid, {})
		if int(item.get("category", -1)) == category:
			total += _save_manager.get_inventory_count(itemid)
	return total


func get_item_name(itemid: int) -> String:
	var item: Dictionary = _items_by_id.get(itemid, {})
	return str(item.get("name", "道具%d" % itemid))


func _get_offer(offerid: int) -> Dictionary:
	for item in _offers:
		if item is Dictionary and int(item.get("offerid", 0)) == offerid:
			return item as Dictionary
	return {}
