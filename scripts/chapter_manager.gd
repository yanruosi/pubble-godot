extends Node
class_name ChapterManager

const CHAPTERS_JSON_PATH := "res://data/chapters.json"
const CONDITIONS_JSON_PATH := "res://data/conditions.json"
const LEVELS_JSON_PATH := "res://data/levels.json"

var _chapters: Array = []
var _conditions_by_id: Dictionary = {}
var _levels: Array = []
var _levels_by_id: Dictionary = {}
var _levels_by_chapter_id: Dictionary = {}

func _init() -> void:
	_load_json_data()

func _load_json_data() -> void:
	_chapters.clear()
	_conditions_by_id.clear()
	_levels.clear()
	_levels_by_id.clear()
	_levels_by_chapter_id.clear()

	var chapters_raw: Variant = TableRepo.get_table("chapters")
	if chapters_raw is Array:
		for item in chapters_raw:
			if item is Dictionary:
				_chapters.append(item)
		_chapters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("order", 0)) < int(b.get("order", 0))
		)

	var conditions_raw: Variant = TableRepo.get_table("conditions")
	if conditions_raw is Array:
		for item in conditions_raw:
			if item is Dictionary:
				var condition_id: int = int(item.get("id", 0))
				_conditions_by_id[condition_id] = item

	var levels_raw: Variant = TableRepo.get_table("levels")
	if levels_raw is Array:
		for item in levels_raw:
			if item is Dictionary:
				var item_dict: Dictionary = item
				var level: Dictionary = item_dict.duplicate(true)
				var level_id: String = str(level.get("levelid", ""))
				var chapter_id: int = int(level.get("chapter_id", 0))
				if level_id.is_empty() or chapter_id <= 0:
					continue
				_levels.append(level)
				_levels_by_id[level_id] = level
				if not _levels_by_chapter_id.has(chapter_id):
					_levels_by_chapter_id[chapter_id] = []
				_levels_by_chapter_id[chapter_id].append(level)

		_levels.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("order", 0)) < int(b.get("order", 0))
		)
		for chapter_id in _levels_by_chapter_id.keys():
			_levels_by_chapter_id[chapter_id].sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("order", 0)) < int(b.get("order", 0))
			)

func get_all_chapters() -> Array:
	return _chapters.duplicate(true)

func get_chapter_by_id(chapter_id: int) -> Dictionary:
	for chapter in _chapters:
		if int(chapter.get("id", 0)) == chapter_id:
			return chapter.duplicate(true)
	return {}

func get_condition_by_id(condition_id: int) -> Dictionary:
	return _conditions_by_id.get(condition_id, {}).duplicate(true)

func get_all_levels() -> Array:
	return _levels.duplicate(true)

func get_levels_for_chapter(chapter_id: int) -> Array:
	return Array(_levels_by_chapter_id.get(chapter_id, [])).duplicate(true)

func get_level_by_id(level_id: String) -> Dictionary:
	return _levels_by_id.get(level_id, {}).duplicate(true)
