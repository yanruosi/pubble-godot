extends Node
class_name ActivityManager

const ACTIVITIES_PATH := "res://data/activities.json"
const POST_TEMPLATES_PATH := "res://data/post_templates.json"
const ACTIVITY_EVENTS_PATH := "res://data/activity_events.json"

const STATE_WON := "won"
const STATE_DEPARTED := "departed"

const TAB_FANDOM := 0
const TAB_SISTER := 903

const POSTCLASS_NORMAL := 1
const POSTCLASS_ADVANCED := 2
const POSTCLASS_KEY := 3

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
	_activities = _table_array("activities")
	_templates = _table_array("post_templates")
	_activity_events = _table_array("activity_events")


func _table_array(name: String) -> Array:
	var parsed: Variant = TableRepo.get_table(name)
	return parsed if parsed is Array else []


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
	if int(act.get("openingonly", 0)) == 1:
		if _save_manager != null and _save_manager.opening_done:
			return false

	var need_fans: int = int(act.get("needfans", 0))
	if need_fans > 0 and (_save_manager == null or _save_manager.fans < need_fans):
		return false

	var need_keyposts: int = int(act.get("needkeyposts", 0))
	if need_keyposts > 0 and (_save_manager == null or _total_keyposts() < need_keyposts):
		return false

	if int(act.get("tutorialonly", 0)) == 1:
		var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
		if tutor == null or not tutor.is_active():
			return false

	var condition_id: int = int(act.get("conditionid", 0))
	if condition_id > 0 and _condition_checker != null:
		if not _condition_checker.is_condition_met(condition_id):
			return false

	return true


func _total_keyposts() -> int:
	if _save_manager == null:
		return 0
	var total: int = _save_manager.keypost_progress
	for row in _table_array("intel_levels"):
		if not (row is Dictionary):
			continue
		var lvl: int = int((row as Dictionary).get("level", -1))
		if lvl >= 0 and lvl < _save_manager.intellevel:
			total += int((row as Dictionary).get("keypostcount", 0))
	return total


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
	return _finalize_settlement(act, activityid)


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
	return _finalize_settlement(act, activityid)


func _finalize_settlement(act: Dictionary, activityid: String) -> Dictionary:
	var event_text: String = _pick_result_event(activityid)
	var is_first: bool = _save_manager == null or not _save_manager.is_activity_first_cleared(activityid)

	if _save_manager != null:
		var tagid: String = str(act.get("granttagid", ""))
		var grant_count: int = int(act.get("grantcountfirst" if is_first else "grantcountrepeat", 0))
		if not tagid.is_empty() and grant_count > 0:
			_save_manager.add_post_count(tagid, grant_count)

		_save_manager.set_activity_state(activityid, STATE_DEPARTED)
		if is_first:
			_save_manager.mark_activity_first_cleared(activityid)

	var queued: Array = _queue_feed_pending_posts(act)
	if int(act.get("category", 0)) == 3:
		var tutor: TutorialController = get_node_or_null("/root/TutorialControllerSingleton") as TutorialController
		if tutor != null:
			tutor.notify_sign_done()

	var counts: Dictionary = _count_queued_posts(queued)
	return {
		"ok": true,
		"queued": queued,
		"activity": act,
		"event_text": event_text,
		"fandom_hq_count": int(counts.get("fandom_hq", 0)),
		"sister_count": int(counts.get("sister", 0)),
		"reveal_tab": _resolve_reveal_tab(counts),
		"is_first_clear": is_first,
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
	var activityid: String = str(act.get("activityid", ""))
	var is_first: bool = _save_manager == null or not _save_manager.is_activity_first_cleared(activityid)
	var cost_fp: int = int(act.get("costfpfirst" if is_first else "costfp", 0))
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
	var activityid: String = str(act.get("activityid", ""))
	var is_first: bool = _save_manager == null or not _save_manager.is_activity_first_cleared(activityid)
	if is_first and int(act.get("winratefirst", 0)) == 1:
		return true
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
	return 0


func _get_saved_state(activityid: String) -> String:
	if _save_manager == null:
		return ""
	return _save_manager.get_activity_state(activityid)


func _queue_feed_pending_posts(act: Dictionary) -> Array:
	var out: Array = []
	if _expose_manager == null:
		return out
	var types: Array = _activity_output_types(act)
	var key_count: int = int(act.get("feedkeycount", 0))
	var adv_count: int = int(act.get("feedadvancedcount", 0))
	var normal_count: int = int(act.get("feednormalcount", 0))

	for _i in range(key_count):
		var tpl: Dictionary = _pick_template_by_class(types, POSTCLASS_KEY)
		if tpl.is_empty():
			continue
		out.append(_enqueue_pending(tpl))

	for _i in range(adv_count):
		var tpl: Dictionary = _pick_template_by_class(types, POSTCLASS_ADVANCED)
		if tpl.is_empty():
			continue
		out.append(_enqueue_pending(tpl))

	for _i in range(normal_count):
		var tpl: Dictionary = _pick_template_by_class(types, POSTCLASS_NORMAL)
		if tpl.is_empty():
			continue
		out.append(_enqueue_pending(tpl))

	return out


func _enqueue_pending(tpl: Dictionary) -> Dictionary:
	## 结算只入队并掷 delay；冷却从玩家首次进入饭圈动态起算（见 ExposeManager.arm）
	var min_cd: int = int(tpl.get("refreshcdmin", 2))
	var max_cd: int = int(tpl.get("refreshcdmax", min_cd))
	if min_cd <= 0:
		min_cd = 2
	if max_cd < min_cd:
		max_cd = min_cd
	var delay: int = randi_range(min_cd, max_cd)
	var tabsource: int = int(tpl.get("tabtype", TAB_SISTER))
	var postid: String = str(tpl.get("postid", ""))
	_expose_manager.queue_feed_pending(postid, tabsource, delay)
	return {"postid": postid, "tabsource": tabsource, "delay_sec": delay, "release_ts": 0}


func _pick_template_by_class(posttypes: Array, postclass: int) -> Dictionary:
	var candidates: Array = []
	for tpl in _templates:
		if not (tpl is Dictionary):
			continue
		var row: Dictionary = tpl as Dictionary
		if not posttypes.is_empty() and not posttypes.has(int(row.get("posttype", -1))):
			continue
		var cls: int = int(row.get("postclass", POSTCLASS_NORMAL))
		if cls != postclass:
			continue
		if postclass == POSTCLASS_KEY:
			var keylevel: int = _save_manager.intellevel if _save_manager != null else 0
			if int(row.get("keylevel", 0)) != keylevel:
				continue
		candidates.append(row)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]


func _activity_output_types(act: Dictionary) -> Array:
	var types: Array = []
	var t1: int = int(act.get("outputposttype1", 0))
	var t2: int = int(act.get("outputposttype2", 0))
	if t1 > 0:
		types.append(t1)
	if t2 > 0 and t2 != t1:
		types.append(t2)
	return types


func _count_queued_posts(queued: Array) -> Dictionary:
	var fandom_hq := 0
	var sister := 0
	for item in queued:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item as Dictionary
		var tpl: Dictionary = {}
		if _expose_manager != null:
			tpl = _expose_manager.get_template(str(row.get("postid", "")))
		var tabsource: int = int(row.get("tabsource", tpl.get("tabtype", TAB_SISTER)))
		var tier: String = str(tpl.get("tier", ""))
		if tabsource == TAB_FANDOM and (tier == "A" or tier == "B"):
			fandom_hq += 1
		elif tabsource == TAB_SISTER:
			sister += 1
	return {"fandom_hq": fandom_hq, "sister": sister}


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


func get_activity(activityid: String) -> Dictionary:
	return _get_activity(activityid)


func _get_activity(activityid: String) -> Dictionary:
	for item in _activities:
		if item is Dictionary and str(item.get("activityid", "")) == activityid:
			return item as Dictionary
	return {}
