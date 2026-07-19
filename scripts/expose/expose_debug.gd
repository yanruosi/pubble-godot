extends RefCounted

var _ctx


func _init(ctx) -> void:
	_ctx = ctx


func add_keypost() -> void:
	if _ctx.save == null:
		return
	_ctx.save.keypost_progress += 1
	_ctx.try_auto_upgrade_intel()
	_ctx.save.save_progress()
	_ctx.host.banner_state_changed.emit()
	_ctx.host.instance_changed.emit()


func skip_expose(on_head_matured: Callable) -> void:
	var head: Dictionary = _ctx.queue.get_exposing_item()
	if head.is_empty() or str(head.get("state", "")) != "exposing":
		return
	head["expose_end_ts"] = int(Time.get_unix_time_from_system())
	on_head_matured.call(head)


func flush_feed_pending() -> void:
	_ctx.posts.debug_flush_feed_pending()


func add_post_count(tagid: String, count: int = 1) -> void:
	if _ctx.save == null:
		return
	_ctx.save.add_post_count(tagid, count)
	_ctx.save.save_progress()
