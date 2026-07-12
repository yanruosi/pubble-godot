extends Node
class_name ActivityManager

const ACTIVITIES_PATH := "res://data/activities.json"
const POST_TEMPLATES_PATH := "res://data/post_templates.json"
const ACTIVITY_EVENTS_PATH := "res://data/activity_events.json"

const STATE_WON := "won"
const STATE_DEPARTED := "departed"

const TAB_FANDOM := 0
const TAB_SISTER := 903

var _save_manager: SaveManager
var _economy_manager: EconomyManager
var _condition_checker: ConditionChecker
var _expose_manager: ExposeManager
var _activities: Array = []
var _templates: Array = []
var _activity_events: Array = []


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_economy_manager = get_node_or_null("/root/EconomyManagerSingleton") as EconomyManager
	_condition_checker = get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
	_expose_manager = get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager
	_activities = _read_json_array(ACTIVITIES_PATH)
	_templates = _read_json_array(POST_TEMPLATES_PATH)
	_activity_events = _read_json_array(ACTIVITY_EVENTS_PATH)


func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		return parsed
	return []


func get_activities() -> Array:
	return _activities.duplicate(true)


func get_visible_activities() -> Array:
	var out: Array = []
	for item in _activities:
		if item is Dictionary and _is_activity_visible(item as Dictionary):
			out.append((item as Dictionary).duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("sort", 0)) < int(b.get("sort", 0))
	)
	return out


func _is_activity_visible(act: Dictionary) -> bool:
	if int(act.get("tutorialonly", 0)) == 1:
		var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
		if tutor == null or not tutor.is_active():
			return false
	var condition_id: int = int(act.get("conditionid", 0))
	if condition_id > 0 and _condition_checker != null:
		if not _condition_checker.is_condition_met(condition_id):
			return false
	if int(act.get("opinionlock", 0)) == 1:
		pass
	return true


func _needs_lottery(act: Dictionary) -> bool:
	var cat: int = int(act.get("category", 0))
	return cat == 2 or cat == 3


func draw_lottery(activityid: String) -> Dictionary:
	var act: Dictionary = _get_activity(activityid)
	if act.is_empty():
		return {"ok": false, "reason": "活动不存在"}
	if not _needs_lottery(act):
		return {"ok": false, "reason": "该活动无需抽选"}
	var state := _get_saved_state(activityid)
	if state == STATE_DEPARTED:
		return {"ok": false, "reason": "已出发"}
	if state == STATE_WON:
		return {"ok": false, "reason": "已中签，请出发"}
	var gate: Dictionary = _check_participation_gate(act)
	if not bool(gate.get("ok", false)):
		return gate
	var pay: Dictionary = _pay_activity_cost(act)
	if not bool(pay.get("ok", false)):
		return pay
	var won := _roll_win(act)
	if won and _save_manager != null:
		_save_manager.set_activity_state(activityid, STATE_WON)
	return {"ok": true, "won": won, "activity": act}


func depart(activityid: String) -> Dictionary:
	var act: Dictionary = _get_activity(activityid)
	if act.is_empty():
		return {"ok": false, "reason": "活动不存在"}
	if not _needs_lottery(act):
		return participate(activityid)
	if _get_saved_state(activityid) != STATE_WON:
		return {"ok": false, "reason": "请先中签"}
	var gate: Dictionary = _check_participation_gate(act)
	if not bool(gate.get("ok", false)):
		return gate
	var drawn: Array = _draw_posts(act)
	return _finalize_settlement(act, drawn, activityid)


func participate(activityid: String) -> Dictionary:
	var act: Dictionary = _get_activity(activityid)
	if act.is_empty():
		return {"ok": false, "reason": "活动不存在"}
	if _needs_lottery(act):
		return {"ok": false, "reason": "请先抽选并出发"}
	if _get_saved_state(activityid) == STATE_DEPARTED:
		return {"ok": false, "reason": "已参与"}
	var gate: Dictionary = _check_participation_gate(act)
	if not bool(gate.get("ok", false)):
		return gate
	var pay: Dictionary = _pay_activity_cost(act)
	if not bool(pay.get("ok", false)):
		return pay
	var drawn: Array = _draw_posts(act)
	return _finalize_settlement(act, drawn, activityid)


func _finalize_settlement(act: Dictionary, drawn: Array, activityid: String) -> Dictionary:
	var event_text: String = _pick_result_event(activityid)
	var counts: Dictionary = _count_settlement_posts(drawn)
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
		_save_manager.set_activity_state(activityid, STATE_DEPARTED)
	if _expose_manager != null and not drawn.is_empty():
		_expose_manager.mark_instances_for_reveal(drawn)
	if int(act.get("category", 0)) == 3:
		var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
		if tutor != null:
			tutor.notify_sign_done()
	return {
		"ok": true,
		"drawn": drawn,
		"activity": act,
		"event_text": event_text,
		"fandom_hq_count": int(counts.get("fandom_hq", 0)),
		"sister_count": int(counts.get("sister", 0)),
		"reveal_tab": _resolve_reveal_tab(counts),
	}


func _resolve_reveal_tab(counts: Dictionary) -> String:
	if int(counts.get("sister", 0)) > 0:
		return "sister"
	if int(counts.get("fandom_hq", 0)) > 0:
		return "fandom"
	return "fandom"


func _check_participation_gate(act: Dictionary) -> Dictionary:
	if not _is_activity_visible(act):
		return {"ok": false, "reason": "活动未解锁"}
	var condition_id: int = int(act.get("conditionid", 0))
	if condition_id > 0 and _condition_checker != null:
		if not _condition_checker.is_condition_met(condition_id):
			return {"ok": false, "reason": _condition_checker.get_fail_text(condition_id)}
	return {"ok": true}


func _pay_activity_cost(act: Dictionary) -> Dictionary:
	var cost_fp: int = int(act.get("costfp", 0))
	if cost_fp > 0:
		if _economy_manager == null or not _economy_manager.can_afford(22, cost_fp):
			return {"ok": false, "reason": "饭圈积分不足"}
		if not _economy_manager.consume_currency(22, cost_fp, "activity"):
			return {"ok": false, "reason": "饭圈积分不足"}
	var cost_item: int = int(act.get("costitemid", 0))
	var cost_count: int = int(act.get("costitemcount", 0))
	if cost_item > 0 and cost_count > 0:
		if _save_manager == null or not _save_manager.remove_inventory_item(cost_item, cost_count):
			return {"ok": false, "reason": "道具不足"}
	return {"ok": true}


func _roll_win(act: Dictionary) -> bool:
	if int(act.get("tutorialonly", 0)) == 1:
		return true
	var base_rate: int = clampi(int(act.get("winrate", 0)), 0, 100)
	var bonus: int = _get_win_bonus()
	var final_rate: int = clampi(base_rate + bonus, 0, 100)
	if final_rate <= 0:
		return false
	if final_rate >= 100:
		return true
	return randi_range(1, 100) <= final_rate


func _get_win_bonus() -> int:
	# P2：咕包装备加成；v1 固定 0
	return 0


func _get_saved_state(activityid: String) -> String:
	if _save_manager == null:
		return ""
	return _save_manager.get_activity_state(activityid)


func _draw_posts(act: Dictionary) -> Array:
	var out: Array = []
	if _expose_manager == null:
		return out
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
		var inst: Dictionary = _expose_manager.add_instance(
			str(picked.get("postid", "")),
			int(picked.get("tabtype", TAB_SISTER))
		)
		if not inst.is_empty():
			out.append(inst)
	return out


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


func _pick_result_event(activityid: String) -> String:
	var tier: String = "mid"
	if _economy_manager != null:
		tier = _economy_manager.get_opinion_tier()
	var weight_key := "weightmid"
	if tier == "low":
		weight_key = "weightlow"
	elif tier == "high":
		weight_key = "weighthigh"
	var candidates: Array = []
	for row in _activity_events:
		if not (row is Dictionary):
			continue
		if str(row.get("activityid", "")) != activityid:
			continue
		candidates.append(row)
	if candidates.is_empty():
		return ""
	if candidates.size() == 1:
		return str((candidates[0] as Dictionary).get("text", ""))
	var total := 0
	for row in candidates:
		total += int((row as Dictionary).get(weight_key, 0))
	if total <= 0:
		return str((candidates[0] as Dictionary).get("text", ""))
	var roll := randi_range(1, total)
	var acc := 0
	for row in candidates:
		acc += int((row as Dictionary).get(weight_key, 0))
		if roll <= acc:
			return str((row as Dictionary).get("text", ""))
	return str((candidates[0] as Dictionary).get("text", ""))


func _count_settlement_posts(drawn: Array) -> Dictionary:
	var fandom_hq := 0
	var sister := 0
	for item in drawn:
		if not (item is Dictionary):
			continue
		var inst: Dictionary = item as Dictionary
		var tpl: Dictionary = {}
		if _expose_manager != null:
			tpl = _expose_manager.get_template(str(inst.get("postid", "")))
		var tabsource: int = int(inst.get("tabsource", tpl.get("tabtype", TAB_SISTER)))
		var tier: String = str(tpl.get("tier", ""))
		if tabsource == TAB_FANDOM and (tier == "A" or tier == "B"):
			fandom_hq += 1
		elif tabsource == TAB_SISTER:
			sister += 1
	return {"fandom_hq": fandom_hq, "sister": sister}


func get_activity(activityid: String) -> Dictionary:
	return _get_activity(activityid)


func _get_activity(activityid: String) -> Dictionary:
	for item in _activities:
		if item is Dictionary and str(item.get("activityid", "")) == activityid:
			return item as Dictionary
	return {}
