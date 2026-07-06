extends Node
class_name ActivityManager

const ACTIVITIES_PATH := "res://data/activities.json"
const POST_TEMPLATES_PATH := "res://data/post_templates.json"

var _save_manager: SaveManager
var _economy_manager: EconomyManager
var _condition_checker: ConditionChecker
var _expose_manager: ExposeManager
var _activities: Array = []
var _templates: Array = []


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_economy_manager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_condition_checker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	_expose_manager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	_activities = _read_json_array(ACTIVITIES_PATH)
	_templates = _read_json_array(POST_TEMPLATES_PATH)


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []


func get_activities() -> Array:
	return _activities.duplicate(true)


func participate(activityid: String) -> bool:
	var act: Dictionary = _get_activity(activityid)
	if act.is_empty():
		return false
	var condition_id: int = int(act.get("conditionid", 0))
	if _condition_checker != null and condition_id > 0:
		if not _condition_checker.is_condition_met(condition_id):
			return false
	var cost_fp: int = int(act.get("costfp", 0))
	if cost_fp > 0 and _economy_manager != null:
		if not _economy_manager.consume_currency(22, cost_fp, "activity"):
			return false
	var cost_item: int = int(act.get("costitemid", 0))
	var cost_count: int = int(act.get("costitemcount", 0))
	if cost_item > 0 and cost_count > 0 and _save_manager != null:
		if not _save_manager.remove_inventory_item(cost_item, cost_count):
			return false
	_draw_posts(act)
	if _save_manager != null:
		var tier: String = "mid"
		if _economy_manager != null:
			tier = _economy_manager.get_opinion_tier()
		var exp_key := "stexpmid"
		if tier == "low":
			exp_key = "stexplow"
		elif tier == "high":
			exp_key = "stexphigh"
		_save_manager.stationexp += int(act.get(exp_key, 0))
		_save_manager.save_progress()
	if int(act.get("category", 0)) == 3:
		var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
		if tutor != null:
			tutor.notify_sign_done()
	return true


func _draw_posts(act: Dictionary) -> void:
	if _expose_manager == null:
		return
	var draw_count: int = int(act.get("drawcount", 1))
	var types: Array = []
	var t1: int = int(act.get("outputposttype1", 0))
	var t2: int = int(act.get("outputposttype2", 0))
	if t1 > 0:
		types.append(t1)
	if t2 > 0 and t2 != t1:
		types.append(t2)
	var tutorial_only: bool = int(act.get("tutorialonly", 0)) == 1
	for _i in range(draw_count):
		var picked: Dictionary = _pick_template(types, tutorial_only)
		if picked.is_empty():
			continue
		_expose_manager.add_instance(str(picked.get("postid", "")), int(picked.get("tabtype", 903)))


func _pick_template(posttypes: Array, tutorial_only: bool) -> Dictionary:
	var tier: String = "mid"
	if _economy_manager != null:
		tier = _economy_manager.get_opinion_tier()
	var weight_key := "weightmid"
	if tier == "low":
		weight_key = "weightlow"
	elif tier == "high":
		weight_key = "weighthigh"
	var candidates: Array = []
	for tpl in _templates:
		if not (tpl is Dictionary):
			continue
		if not posttypes.has(int(tpl.get("posttype", -1))):
			continue
		if tutorial_only and str(tpl.get("tier", "")) != "A":
			continue
		candidates.append(tpl)
	if candidates.is_empty():
		return {}
	if tutorial_only:
		return candidates[0]
	var total := 0
	for tpl in candidates:
		total += int(tpl.get(weight_key, 0))
	if total <= 0:
		return candidates[0]
	var roll := randi_range(1, total)
	var acc := 0
	for tpl in candidates:
		acc += int(tpl.get(weight_key, 0))
		if roll <= acc:
			return tpl
	return candidates[0]


func _get_activity(activityid: String) -> Dictionary:
	for item in _activities:
		if item is Dictionary and str(item.get("activityid", "")) == activityid:
			return item
	return {}
