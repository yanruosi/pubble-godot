extends RefCounted
class_name TableRepo

## L1：配表 JSON 读取与内存缓存（零游戏逻辑）

static var _cache: Dictionary = {}


static func get_table(name: String) -> Variant:
	var path := "res://data/%s.json" % name
	if _cache.has(path):
		return _duplicate_table(_cache[path])
	if not FileAccess.file_exists(path):
		_cache[path] = []
		return _duplicate_table(_cache[path])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		_cache[path] = []
		return _duplicate_table(_cache[path])
	_cache[path] = parsed
	return _duplicate_table(parsed)


static func _duplicate_table(parsed: Variant) -> Variant:
	if parsed is Array:
		return (parsed as Array).duplicate(true)
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return parsed


static func get_row(name: String, key: String, id: Variant) -> Dictionary:
	var table: Variant = get_table(name)
	if table is Array:
		for row in table:
			if row is Dictionary and str((row as Dictionary).get(key, "")) == str(id):
				return (row as Dictionary).duplicate(true)
	elif table is Dictionary:
		var d: Dictionary = table as Dictionary
		if d.has(id) and d[id] is Dictionary:
			return (d[id] as Dictionary).duplicate(true)
		var sid: String = str(id)
		if d.has(sid) and d[sid] is Dictionary:
			return (d[sid] as Dictionary).duplicate(true)
	return {}


static func clear_cache() -> void:
	_cache.clear()
