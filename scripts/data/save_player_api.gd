extends RefCounted
class_name SavePlayerApi

## currency / inventory / post_counts API 委托


static func get_currency(sm, category: int) -> int:
	match category:
		SaveManager.CAT_FP: return sm.fp
		SaveManager.CAT_STARS: return sm.stars
		SaveManager.CAT_INTEL: return sm.intel
		_: return 0


static func set_currency(sm, category: int, value: int) -> void:
	var v: int = max(value, 0)
	match category:
		SaveManager.CAT_FP: sm.fp = v
		SaveManager.CAT_STARS: sm.stars = v
		SaveManager.CAT_INTEL: sm.intel = v


static func add_currency(sm, category: int, amount: int) -> void:
	if amount <= 0:
		return
	set_currency(sm, category, get_currency(sm, category) + amount)


static func consume_currency(sm, category: int, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_currency(sm, category) < amount:
		return false
	set_currency(sm, category, get_currency(sm, category) - amount)
	return true


static func get_inventory_count(sm, itemid: int) -> int:
	return int(sm.inventory.get(str(itemid), 0))


static func set_inventory_count(sm, itemid: int, count: int) -> void:
	var key := str(itemid)
	if count <= 0:
		sm.inventory.erase(key)
	else:
		sm.inventory[key] = count


static func add_inventory_item(sm, itemid: int, count: int = 1) -> void:
	if count <= 0:
		return
	set_inventory_count(sm, itemid, get_inventory_count(sm, itemid) + count)


static func remove_inventory_item(sm, itemid: int, count: int = 1) -> bool:
	if count <= 0:
		return true
	if get_inventory_count(sm, itemid) < count:
		return false
	set_inventory_count(sm, itemid, get_inventory_count(sm, itemid) - count)
	return true


static func next_instance_id(sm) -> String:
	sm._instance_id_counter += 1
	return "inst_%d" % sm._instance_id_counter


static func next_queue_id(sm) -> String:
	sm._instance_id_counter += 1
	return "q_%d" % sm._instance_id_counter


static func is_activity_first_cleared(sm, activityid: String) -> bool:
	return bool(sm.activity_first_clear.get(activityid, false))


static func mark_activity_first_cleared(sm, activityid: String) -> void:
	if activityid.is_empty():
		return
	sm.activity_first_clear[activityid] = true


static func get_post_count(sm, tagid: String) -> int:
	return int(sm.post_counts.get(tagid, 0))


static func add_post_count(sm, tagid: String, count: int) -> void:
	if tagid.is_empty() or count == 0:
		return
	sm.post_counts[tagid] = maxi(get_post_count(sm, tagid) + count, 0)


static func consume_post_count(sm, tagid: String, count: int = 1) -> bool:
	if tagid.is_empty() or count <= 0:
		return false
	if get_post_count(sm, tagid) < count:
		return false
	sm.post_counts[tagid] = get_post_count(sm, tagid) - count
	return true
