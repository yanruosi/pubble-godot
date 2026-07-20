extends RefCounted
class_name FeedCardEffects

const FeedDefs := preload("res://scripts/views/feed_defs.gd")

static var _effects_by_id: Dictionary = {}


static func _ensure_effects() -> void:
	if not _effects_by_id.is_empty():
		return
	for row in TableRepo.get_table("effects"):
		if row is Dictionary:
			_effects_by_id[str(row.get("effect_id", ""))] = row


static func effect_id_for_postclass(postclass: int) -> String:
	match postclass:
		ExposeManager.POSTCLASS_ADVANCED:
			return "fx_found_ping"
		ExposeManager.POSTCLASS_KEY:
			return "fx_found_ping"
		_:
			return "heart_point"


static func play_like(list_view, card: Node, anchor_global: Vector2, postclass: int) -> void:
	if postclass <= ExposeManager.POSTCLASS_NORMAL:
		return
	_ensure_effects()
	var host: Control = list_view.get_host() if list_view.has_method("get_host") else null
	var eid := effect_id_for_postclass(postclass)
	var row: Dictionary = _effects_by_id.get(eid, {})
	var path := str(row.get("resource_path", ""))
	if host == null or path.is_empty() or not ResourceLoader.exists(path):
		list_view.play_heart_effect(card, anchor_global)
		_spawn_float_text(host, anchor_global, "赞+1")
		return
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		list_view.play_heart_effect(card, anchor_global)
		return
	var fx: Node = scene.instantiate()
	host.add_child(fx)
	if fx is Control:
		(fx as Control).global_position = anchor_global - Vector2(16, 16)
	_spawn_float_text(host, anchor_global, "赞+1")


static func _spawn_float_text(host: Control, anchor_global: Vector2, text: String) -> void:
	if host == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.62, 1))
	lbl.global_position = anchor_global + Vector2(-12, -28)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(lbl)
	var tw := host.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 20, 0.35)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.35)
	tw.tween_callback(lbl.queue_free)
