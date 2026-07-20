extends RefCounted

## 热度累加与档位加成

var _ctx
var _heat_actions: Dictionary = {}
var _hot_rates: Array = []


func _init(ctx) -> void:
	_ctx = ctx


func load_tables() -> void:
	_heat_actions.clear()
	for row in TableRepo.get_table("heat_actions"):
		if row is Dictionary:
			_heat_actions[str(row.get("actiontype", ""))] = row
	_hot_rates = TableRepo.get_table("hot_rates")


func add_heat(actiontype: String, source_key: String = "") -> bool:
	if _ctx.save == null:
		return false
	var head: Dictionary = _ctx.queue.get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return false
	if not source_key.is_empty():
		var sources: Array = head.get("heat_sources", [])
		if source_key in sources:
			return false
		sources.append(source_key)
		head["heat_sources"] = sources
	var action: Dictionary = _heat_actions.get(actiontype, {})
	if action.is_empty():
		return false
	head["heat"] = int(head.get("heat", 0)) + int(action.get("heatvalue", 0))
	_ctx.save.save_progress()
	_ctx.banner.notify_changed()
	return true


func get_tier_bonus(heat: int) -> int:
	for row in _hot_rates:
		if not (row is Dictionary):
			continue
		var r: Dictionary = row as Dictionary
		if heat >= int(r.get("heatmin", 0)) and heat <= int(r.get("heatmax", 999)):
			return int(r.get("bonusrate", 0))
	return 0


func roll_hot(item: Dictionary) -> void:
	var def: Dictionary = _ctx.my_posts_by_id.get(str(item.get("mypostid", "")), {})
	var heat: int = int(item.get("heat", 0))
	var base_chance: int = int(def.get("hotbasechance", 0))
	var bonus: int = get_tier_bonus(heat)
	var final_rate: int = mini(95, base_chance + bonus)
	var hot_ok := final_rate >= 100 or (final_rate > 0 and randi_range(1, 100) <= final_rate)
	item["hotresult"] = 1 if hot_ok else 0
	if hot_ok:
		item["is_pinned"] = true
		_ctx.banner.set_override(ExposeManager.BANNER_HOT_SUCCESS)
	else:
		item["is_pinned"] = false
		_ctx.banner.set_override(ExposeManager.BANNER_HOT_FAIL)
