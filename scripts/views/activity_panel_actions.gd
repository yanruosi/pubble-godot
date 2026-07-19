extends RefCounted


static func on_action_pressed(
	view,
	activity: ActivityManager,
	sign,
	get_activity_state: Callable
) -> void:
	var act: Dictionary = view._current_activity()
	if act.is_empty() or activity == null or sign == null:
		return
	var aid: String = str(act.get("activityid", ""))
	var cat: int = int(act.get("category", 0))
	var state: String = str(get_activity_state.call(aid))
	if cat == 1:
		if state == ActivityManager.STATE_DEPARTED:
			return
		var result: Dictionary = activity.participate(aid)
		if not bool(result.get("ok", false)):
			sign.show_toast(str(result.get("reason", "活动失败")))
		else:
			sign.show_settle(result)
		view.refresh()
		return
	if state == ActivityManager.STATE_DEPARTED:
		return
	if state == ActivityManager.STATE_WON:
		sign.do_depart(aid)
		return
	sign.do_draw(aid, act)
