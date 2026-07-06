extends Node
class_name ShopManager

const SHOP_OFFERS_PATH := "res://data/shop_offers.json"

var _save_manager: SaveManager
var _economy_manager: EconomyManager
var _inventory_manager: InventoryManager
var _condition_checker: ConditionChecker
var _offers: Array = []


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_economy_manager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_inventory_manager = get_node_or_null("/root/InventoryManagerSingleton") as InventoryManager
	_condition_checker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	_offers = _read_json_array(SHOP_OFFERS_PATH)


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []


func get_offers() -> Array:
	return _offers.duplicate(true)


func purchase(offerid: int) -> bool:
	var offer: Dictionary = _get_offer(offerid)
	if offer.is_empty():
		return false
	var condition_id: int = int(offer.get("conditionid", 0))
	if _condition_checker != null and condition_id > 0:
		if not _condition_checker.is_condition_met(condition_id):
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


func _get_offer(offerid: int) -> Dictionary:
	for item in _offers:
		if item is Dictionary and int(item.get("offerid", 0)) == offerid:
			return item
	return {}
