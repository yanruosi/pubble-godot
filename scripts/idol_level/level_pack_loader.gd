extends RefCounted
class_name LevelPackLoader

const LEVEL_FILE := "level.json"
const VOCAB_FILE := "vocab.json"
const HOTSPOTS_FILE := "hotspots.json"
const SLOTS_FILE := "slots.json"

func load_pack(level_id: String, chapter_manager: ChapterManager) -> Dictionary:
	var pack := {
		"ok": false,
		"level_id": level_id,
		"data_dir": "",
		"level_row": {},
		"level": {},
		"vocab": [],
		"hotspots": [],
		"slots": [],
		"messages": []
	}
	if level_id.is_empty():
		_warn(pack, "缺少 level_id，无法加载关卡包")
		return pack
	if chapter_manager == null:
		_warn(pack, "缺少 ChapterManagerSingleton，无法通过 levels.json 查找 data_dir")
		return pack

	var level_row: Dictionary = chapter_manager.get_level_by_id(level_id)
	if level_row.is_empty():
		_warn(pack, "levels.json 中找不到 level_id=%s" % level_id)
		return pack

	var data_dir: String = str(level_row.get("data_dir", ""))
	if data_dir.is_empty():
		data_dir = level_id
	pack["level_row"] = level_row
	pack["data_dir"] = data_dir

	var base_dir := "res://data/levels/%s" % data_dir
	var level_raw: Variant = _read_json("%s/%s" % [base_dir, LEVEL_FILE], pack)
	var vocab_raw: Variant = _read_json("%s/%s" % [base_dir, VOCAB_FILE], pack)
	var hotspots_raw: Variant = _read_json("%s/%s" % [base_dir, HOTSPOTS_FILE], pack)
	var slots_raw: Variant = _read_json("%s/%s" % [base_dir, SLOTS_FILE], pack)

	pack["level"] = _first_dict(level_raw)
	pack["vocab"] = _as_array(vocab_raw)
	pack["hotspots"] = _as_array(hotspots_raw)
	pack["slots"] = _as_array(slots_raw)

	if Dictionary(pack["level"]).is_empty():
		_warn(pack, "缺少有效 level.json，进入制作中占位")
		return pack

	var validator := LevelPackValidator.new()
	validator.validate(pack)

	print(
		"【关卡包自检】【%s】vocab=%d hotspots=%d slots=%d"
		% [level_id, Array(pack["vocab"]).size(), Array(pack["hotspots"]).size(), Array(pack["slots"]).size()]
	)
	pack["ok"] = true
	return pack

func _read_json(path: String, pack: Dictionary) -> Variant:
	if not FileAccess.file_exists(path):
		_warn(pack, "缺少 %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		_warn(pack, "%s 内容为空" % path)
		return null
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_warn(pack, "%s 解析失败" % path)
		return null
	return parsed

func _first_dict(raw: Variant) -> Dictionary:
	if raw is Dictionary:
		return (raw as Dictionary).duplicate(true)
	if raw is Array and not raw.is_empty() and raw[0] is Dictionary:
		return (raw[0] as Dictionary).duplicate(true)
	return {}

func _as_array(raw: Variant) -> Array:
	if raw is Array:
		return (raw as Array).duplicate(true)
	if raw is Dictionary:
		return [raw]
	return []

func _warn(pack: Dictionary, message: String) -> void:
	var level_id: String = str(pack.get("level_id", ""))
	var text := "【关卡配置错误】【%s】%s" % [level_id, message]
	var messages: Array = pack.get("messages", [])
	messages.append(text)
	pack["messages"] = messages
	push_warning(text)
