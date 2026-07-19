extends RefCounted
class_name HomeOverlayActivity

const Defs := preload("res://scripts/views/home_overlay_defs.gd")

static func activities_for_tab(
	activity: ActivityManager,
	tab: int,
	is_opening_flow: bool
) -> Array:
	if activity == null:
		return []
	var out: Array = []
	for act in activity.get_visible_activities():
		if not (act is Dictionary):
			continue
		var row: Dictionary = act as Dictionary
		if is_opening_flow and str(row.get("activityid", "")) != "1":
			continue
		var cat: int = int(row.get("category", 0))
		if tab == Defs.TAB_SHOW and (cat == 2 or cat == 3):
			out.append(row)
		elif tab == Defs.TAB_DAILY and cat == 1:
			out.append(row)
	return out


static func bind_empty_tab(desc: Label, cost: Label, own: Label, action_lbl: Label, tab_index: int) -> void:
	if desc != null:
		desc.text = "暂无特殊活动" if tab_index == Defs.TAB_SPECIAL else "暂无可用活动"
	if cost != null:
		cost.text = ""
		cost.visible = false
	if own != null:
		own.text = ""
		own.visible = false
	if action_lbl != null:
		action_lbl.text = ""


static func bind_display(
	desc: Label,
	cost: Label,
	own: Label,
	action_lbl: Label,
	action_btn: Button,
	act: Dictionary,
	inventory: InventoryManager,
	fp: int,
	state: String
) -> void:
	if desc != null:
		desc.text = str(act.get("name", ""))
	var cost_fp: int = int(act.get("costfp", 0))
	var cost_item: int = int(act.get("costitemid", 0))
	var cost_count: int = int(act.get("costitemcount", 0))
	var show_cost := cost_fp > 0 or (cost_item > 0 and cost_count > 0)
	if cost != null:
		cost.visible = show_cost
		if show_cost:
			if cost_item > 0 and cost_count > 0:
				cost.text = "消耗签售专%d张" % cost_count
			elif cost_fp > 0:
				cost.text = "消耗饭圈积分%d" % cost_fp
			else:
				cost.text = ""
	if own != null:
		own.visible = show_cost
		if show_cost:
			if cost_item > 0 and cost_count > 0:
				var owned: int = inventory.get_count(cost_item) if inventory != null else 0
				own.text = "拥有签售专：%d 张" % owned
			elif cost_fp > 0:
				own.text = "拥有饭圈积分：%d" % fp
			else:
				own.text = ""
	var cat: int = int(act.get("category", 0))
	var needs_lottery := cat == 2 or cat == 3
	if action_lbl != null:
		if state == ActivityManager.STATE_DEPARTED:
			action_lbl.text = "已出发"
		elif state == ActivityManager.STATE_WON:
			action_lbl.text = "出发"
		elif needs_lottery:
			action_lbl.text = "抽选"
		else:
			action_lbl.text = "参与"
	if action_btn != null:
		action_btn.disabled = state == ActivityManager.STATE_DEPARTED
