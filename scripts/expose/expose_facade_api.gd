extends Node

## ExposeManager 公开 API 委托层（façade 下半 · 非 Autoload）

var _ctx


func add_instance(postid: String, tabsource: int = -1) -> Dictionary:
	return _ctx.instances.add_instance(postid, tabsource)


func mark_instances_for_reveal(instances: Array) -> void:
	_ctx.instances.mark_instances_for_reveal(instances)


func take_pending_reveal_ids(tabtype: int) -> Array:
	return _ctx.instances.take_pending_reveal_ids(tabtype)


func get_instances_for_tab(tabtype: int) -> Array:
	return _ctx.instances.get_instances_for_tab(tabtype)


func get_template(postid: String) -> Dictionary:
	return _ctx.instances.get_template(postid)


func get_keypost_display() -> Dictionary:
	return _ctx.keypost_display()


func get_mypost_queue() -> Array:
	return get_expose_queue()


func get_expose_queue() -> Array:
	return _ctx.save.mypost_queue.duplicate(true) if _ctx.save != null else []


func get_expose_queue_size() -> int:
	return get_mypost_queue().size()


func get_post_count(tagid: String) -> int:
	return _ctx.save.get_post_count(tagid) if _ctx.save != null else 0


func get_post_tags() -> Array:
	return _ctx.posts.get_post_tags()


func preview_tag_post(tagid: String) -> Dictionary:
	return _ctx.posts.preview_tag_post(tagid)


func clear_preview_cursor(tagid: String = "") -> void:
	_ctx.posts.clear_preview_cursor(tagid)


func get_my_post(mypostid: String) -> Dictionary:
	return _ctx.posts.get_my_post(mypostid)


func post_with_tag(tagid: String, mypostid: String = "") -> Dictionary:
	return _ctx.posts.post_with_tag(tagid, mypostid)


func post_mainline(mypostid: String) -> Dictionary:
	return _ctx.posts.post_mainline(mypostid)


func add_heat(actiontype: String) -> bool:
	return _ctx.heat.add_heat(actiontype)


func get_post_display_date(_instanceid: String = "") -> String:
	return _ctx.banner.get_post_display_date(_instanceid)


func favorite_instance(inst_id: String) -> bool:
	return _ctx.instances.favorite_instance(inst_id)


func is_instance_favorited(inst_id: String) -> bool:
	return _ctx.instances.is_instance_favorited(inst_id)


func is_mypost_favorited(queue_id: String) -> bool:
	return _ctx.queue.is_mypost_favorited(queue_id)


func get_queue_item(queue_id: String) -> Dictionary:
	return _ctx.queue.find_item(queue_id).duplicate(true)


func toggle_instance_favorite(inst_id: String, favorited: bool) -> bool:
	return _ctx.instances.toggle_instance_favorite(inst_id, favorited)


func toggle_mypost_pin(queue_id: String, pinned: bool) -> bool:
	return _ctx.queue.toggle_pin(queue_id, pinned)


func try_collect_instance(instance_id: String, tabtype: int) -> bool:
	return _ctx.instances.try_collect_instance(instance_id, tabtype)


func refresh_feed_on_tab(tabtype: int) -> Array:
	return _ctx.feed.poll_due(tabtype)


func get_banner_snapshot() -> Dictionary:
	return _ctx.banner.get_snapshot()


func consume_pending_intel_level_up() -> bool:
	if not _ctx.pending_intel_level_up:
		return false
	_ctx.pending_intel_level_up = false
	return true


func queue_feed_pending(postid: String, tabsource: int, delay_sec: int) -> void:
	_ctx.feed.queue_pending(postid, tabsource, delay_sec)


func debug_add_keypost() -> void:
	_ctx.debug.add_keypost()


func debug_skip_expose() -> void:
	_ctx.debug.skip_expose(Callable(self, "_on_head_matured"))


func debug_skip_expose_timer() -> void:
	debug_skip_expose()


func debug_flush_feed_pending() -> void:
	_ctx.debug.flush_feed_pending()


func debug_add_post_count(tagid: String, count: int = 1) -> void:
	_ctx.debug.add_post_count(tagid, count)


func settle_pending_head() -> bool:
	return _ctx.queue.settle_head_if_ready()


func is_tab_p1_visible(tabtype: int) -> bool:
	return _ctx.posts.supports_unified_banner(tabtype)


func is_tab_p2_visible(tabtype: int) -> bool:
	return _ctx.posts.is_tab_p2_visible(tabtype)


func is_tab_p3_visible(tabtype: int) -> bool:
	return is_tab_p1_visible(tabtype)


func is_tab_p4_visible(tabtype: int) -> bool:
	return _ctx.posts.is_tab_p4_visible(tabtype)


func is_tab_p5_visible(tabtype: int) -> bool:
	return _ctx.posts.is_tab_p5_visible(tabtype)
