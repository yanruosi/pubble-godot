extends Node
class_name VocabBank

signal vocab_collected(vocab: Dictionary)
signal changed(collected_count: int, total_count: int)

var _vocab_by_id: Dictionary = {}
var _collected_ids: Dictionary = {}
var _collected_order: Array[String] = []
var _total_count: int = 0

func setup(vocab_rows: Array, vocab_total: int) -> void:
	_vocab_by_id.clear()
	_collected_ids.clear()
	_collected_order.clear()
	_total_count = max(vocab_total, vocab_rows.size())
	for item in vocab_rows:
		if not (item is Dictionary):
			continue
		var row: Dictionary = (item as Dictionary).duplicate(true)
		var vocab_id: String = str(row.get("vocab_id", ""))
		if vocab_id.is_empty():
			continue
		_vocab_by_id[vocab_id] = row
	changed.emit(collected_count(), _total_count)

func collect(vocab_id: String) -> bool:
	if vocab_id.is_empty():
		return false
	if not _vocab_by_id.has(vocab_id):
		push_warning("【词条收集警告】vocab_id=%s 不存在，无法收录" % vocab_id)
		return false
	if bool(_collected_ids.get(vocab_id, false)):
		return false
	_collected_ids[vocab_id] = true
	_collected_order.append(vocab_id)
	var vocab: Dictionary = _vocab_by_id[vocab_id].duplicate(true)
	vocab_collected.emit(vocab)
	changed.emit(collected_count(), _total_count)
	return true

func has_vocab(vocab_id: String) -> bool:
	return bool(_collected_ids.get(vocab_id, false))

func collected_count() -> int:
	return _collected_ids.size()

func total_count() -> int:
	return _total_count

func get_vocab(vocab_id: String) -> Dictionary:
	return _vocab_by_id.get(vocab_id, {}).duplicate(true)

func get_vocab_text(vocab_id: String) -> String:
	var row: Dictionary = get_vocab(vocab_id)
	return str(row.get("text", vocab_id))

func get_collected_vocab(filter_tag: String = "") -> Array:
	var result: Array = []
	for vocab_id in _collected_order:
		if not bool(_collected_ids.get(vocab_id, false)):
			continue
		var row: Dictionary = _vocab_by_id.get(vocab_id, {})
		if row.is_empty():
			continue
		if not filter_tag.is_empty() and str(row.get("tag", "")) != filter_tag:
			continue
		result.append(row.duplicate(true))
	return result

func is_name_vocab(vocab_id: String) -> bool:
	var row: Dictionary = get_vocab(vocab_id)
	return str(row.get("tag", "")) == "name"


func restore_collected(vocab_ids: Array) -> void:
	var changed_any := false
	for item in vocab_ids:
		var vocab_id: String = str(item)
		if vocab_id.is_empty() or not _vocab_by_id.has(vocab_id):
			continue
		if bool(_collected_ids.get(vocab_id, false)):
			continue
		_collected_ids[vocab_id] = true
		_collected_order.append(vocab_id)
		changed_any = true
	if changed_any:
		changed.emit(collected_count(), _total_count)
