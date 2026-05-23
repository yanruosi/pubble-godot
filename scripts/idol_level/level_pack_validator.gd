extends RefCounted
class_name LevelPackValidator

const VALID_HOTSPOT_TYPES := ["normal", "collect", "modal", "panel"]
const VALID_SLOT_TYPES := ["scroll", "identity", "mapping"]
const CODE_EMITTED_EVENTS := [
	"poster_viewed",
	"badge_viewed",
	"lee_portrait_unlocked",
	"may_portrait_unlocked",
	"americano_icon_unlocked",
	"apple_latte_icon_unlocked"
]

func validate(pack: Dictionary) -> Array:
	var messages: Array = []
	var level_id: String = str(pack.get("level_id", ""))
	var level: Dictionary = pack.get("level", {})
	var vocab: Array = pack.get("vocab", [])
	var hotspots: Array = pack.get("hotspots", [])
	var slots: Array = pack.get("slots", [])

	if level.is_empty():
		_warn(level_id, "level.json: 缺少关卡配置，进入制作中占位", messages)
		return messages

	_validate_vocab_total(level_id, level, vocab, messages)

	var vocab_ids := {}
	var vocab_tags := {}
	for item in vocab:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var vocab_id: String = str(row.get("vocab_id", ""))
		if vocab_id.is_empty():
			_warn(level_id, "vocab.json: 存在空 vocab_id", messages)
			continue
		if vocab_ids.has(vocab_id):
			_warn(level_id, "vocab.json: vocab_id=%s 重复" % vocab_id, messages)
		vocab_ids[vocab_id] = true
		var tag: String = str(row.get("tag", ""))
		if tag.is_empty():
			_warn(level_id, "vocab.json: vocab_id=%s 的 tag 为空" % vocab_id, messages)
		else:
			vocab_tags[tag] = true

	var hotspot_ids := {}
	var parent_ids := {"root": true}
	var layer_ids := {"root": true}
	var emitted_events := {}
	for item in hotspots:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var hotspot_id: String = str(row.get("hotspot_id", ""))
		if hotspot_id.is_empty():
			_warn(level_id, "hotspots.json: 存在空 hotspot_id", messages)
		elif hotspot_ids.has(hotspot_id):
			_warn(level_id, "hotspots.json: hotspot_id=%s 重复" % hotspot_id, messages)
		else:
			hotspot_ids[hotspot_id] = true

		var parent_id: String = str(row.get("parent_id", ""))
		if parent_id.is_empty():
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 parent_id 为空" % hotspot_id, messages)
		else:
			parent_ids[parent_id] = true
			layer_ids[parent_id] = true

		var open_modal: String = str(row.get("open_modal", ""))
		if not open_modal.is_empty():
			layer_ids[open_modal] = true

		var hotspot_type: String = str(row.get("hotspot_type", ""))
		if not VALID_HOTSPOT_TYPES.has(hotspot_type):
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 hotspot_type=%s 不在允许值 normal/collect/modal/panel 内" % [hotspot_id, hotspot_type], messages)

		var collect_vocab: String = str(row.get("collect_vocab", ""))
		if not collect_vocab.is_empty() and not vocab_ids.has(collect_vocab):
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 collect_vocab=%s 不存在于 vocab.json" % [hotspot_id, collect_vocab], messages)

		var unlock_event: String = str(row.get("unlock_event", ""))
		if not unlock_event.is_empty():
			emitted_events[unlock_event] = true
		var popup_layout: String = str(row.get("popup_layout", ""))
		if not popup_layout.is_empty() and popup_layout != "modal_full" and popup_layout != "panel_rect":
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 popup_layout=%s 不在允许值 modal_full/panel_rect 内" % [hotspot_id, popup_layout], messages)
		var highlight: int = int(row.get("highlight", 0))
		if highlight != 0 and highlight != 1:
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 highlight 仅允许 0/1" % hotspot_id, messages)
		var hide_question_only: int = int(row.get("hide_question_only", 0))
		if hide_question_only != 0 and hide_question_only != 1:
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 hide_question_only 仅允许 0/1" % hotspot_id, messages)

		var w: float = float(row.get("width", 0.0))
		var h: float = float(row.get("height", 0.0))
		if w <= 0.0 or h <= 0.0:
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 width/height 无效" % hotspot_id, messages)

	for item in hotspots:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var open_modal: String = str(row.get("open_modal", ""))
		var hotspot_type: String = str(row.get("hotspot_type", ""))
		if not open_modal.is_empty() and not layer_ids.has(open_modal):
			_warn(level_id, "hotspots.json: hotspot_id=%s 的 open_modal=%s 未在 parent_id 或 open_modal 列登记为有效子层" % [str(row.get("hotspot_id", "")), open_modal], messages)
		if hotspot_type == "panel" and open_modal.is_empty():
			_warn(level_id, "hotspots.json: hotspot_id=%s 为 panel 但未配置 open_modal" % str(row.get("hotspot_id", "")), messages)

	var slot_ids := {}
	var row_ids := {}
	for item in slots:
		if not (item is Dictionary):
			continue
		var row: Dictionary = item
		var slot_id: String = str(row.get("slot_id", ""))
		var row_id: String = str(row.get("row_id", ""))
		var slot_type: String = str(row.get("slot_type", ""))
		if slot_id.is_empty():
			_warn(level_id, "slots.json: row_id=%s 的 slot_id 为空" % row_id, messages)
		else:
			slot_ids[slot_id] = true
		if row_id.is_empty():
			_warn(level_id, "slots.json: slot_id=%s 存在空 row_id" % slot_id, messages)
		elif row_ids.has("%s/%s" % [slot_id, row_id]):
			_warn(level_id, "slots.json: slot_id=%s row_id=%s 重复" % [slot_id, row_id], messages)
		else:
			row_ids["%s/%s" % [slot_id, row_id]] = true
		if not VALID_SLOT_TYPES.has(slot_type):
			_warn(level_id, "slots.json: row_id=%s 的 slot_type=%s 不在允许值 scroll/identity/mapping 内" % [row_id, slot_type], messages)
		var answer_vocab: String = str(row.get("answer_vocab", ""))
		if not answer_vocab.is_empty() and not vocab_ids.has(answer_vocab):
			_warn(level_id, "slots.json: row_id=%s 的 answer_vocab=%s 不存在于 vocab.json" % [row_id, answer_vocab], messages)
		var filter_tag: String = str(row.get("filter_tag", ""))
		if not filter_tag.is_empty() and not vocab_tags.has(filter_tag):
			_warn(level_id, "slots.json: row_id=%s 的 filter_tag=%s 没有任何词条匹配" % [row_id, filter_tag], messages)
		var unlock_condition: String = str(row.get("unlock_condition", "always")).strip_edges()
		if not unlock_condition.is_empty() and unlock_condition != "always":
			if not emitted_events.has(unlock_condition) and not CODE_EMITTED_EVENTS.has(unlock_condition):
				_warn(level_id, "slots.json: row_id=%s 的 unlock_condition=%s，没有热点 unlock_event 或代码事件对应" % [row_id, unlock_condition], messages)

	var required_slot: String = str(level.get("required_slot", ""))
	if not required_slot.is_empty() and not slot_ids.has(required_slot):
		_warn(level_id, "level.json: required_slot=%s 但 slots.json 中没有该 slot_id" % required_slot, messages)

	_validate_unlock_value(level_id, "slot2", level, vocab_ids, emitted_events, messages)
	_validate_unlock_value(level_id, "slot3", level, vocab_ids, emitted_events, messages)
	return messages

func _validate_vocab_total(level_id: String, level: Dictionary, vocab: Array, messages: Array) -> void:
	var vocab_total: int = int(level.get("vocab_total", 0))
	if vocab_total != vocab.size():
		_warn(level_id, "level.json: vocab_total=%d，但 vocab.json 实际词条数=%d" % [vocab_total, vocab.size()], messages)

func _validate_unlock_value(level_id: String, slot_id: String, level: Dictionary, vocab_ids: Dictionary, emitted_events: Dictionary, messages: Array) -> void:
	var unlock_type: String = str(level.get("%s_unlock_type" % slot_id, ""))
	var unlock_value: String = str(level.get("%s_unlock_value" % slot_id, ""))
	if unlock_type.is_empty() or unlock_value.is_empty():
		return
	if unlock_type == "any":
		for raw_id in unlock_value.split(",", false):
			var token: String = str(raw_id).strip_edges()
			if token.is_empty():
				continue
			if token.begins_with("vocab_"):
				if not vocab_ids.has(token):
					_warn(level_id, "level.json: %s_unlock_value 含词条 %s，但 vocab.json 中不存在" % [slot_id, token], messages)
			elif not emitted_events.has(token) and not CODE_EMITTED_EVENTS.has(token):
				_warn(level_id, "level.json: %s_unlock_value 含事件 %s，但热点未配置 unlock_event 且非代码约定事件" % [slot_id, token], messages)
	elif unlock_type.begins_with("vocab"):
		for raw_id in unlock_value.split(",", false):
			var vocab_id: String = str(raw_id).strip_edges()
			if not vocab_id.is_empty() and not vocab_ids.has(vocab_id):
				_warn(level_id, "level.json: %s_unlock_value=%s 不存在于 vocab.json" % [slot_id, vocab_id], messages)
	elif unlock_type == "event":
		for raw_id in unlock_value.split(",", false):
			var event_id: String = str(raw_id).strip_edges()
			if event_id.is_empty():
				continue
			if not emitted_events.has(event_id) and not CODE_EMITTED_EVENTS.has(event_id):
				_warn(level_id, "level.json: %s_unlock_value=%s，但没有任何热点发出该 unlock_event" % [slot_id, event_id], messages)

func _warn(level_id: String, message: String, messages: Array) -> void:
	var text := "【关卡配置警告】【%s】%s" % [level_id, message]
	messages.append(text)
	push_warning(text)
