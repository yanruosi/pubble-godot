extends RefCounted
class_name FavoritesView

const FeedDefs := preload("res://scripts/views/feed_defs.gd")


func render(list_view, cards, vm_rows: Array, bind_callbacks: Callable) -> int:
	if list_view.list_box == null:
		return 0
	var rendered := 0
	var list_width: float = list_view.get_list_width()
	for row_raw in vm_rows:
		if not (row_raw is Dictionary):
			continue
		var row: Dictionary = row_raw as Dictionary
		var view: Dictionary = row.get("card_view", {})
		if view.is_empty():
			continue
		var meta: Dictionary = row.get("meta", {})
		var card: Node = cards.mount_card(view, list_width, meta)
		if bind_callbacks.is_valid():
			bind_callbacks.call(card, row)
		rendered += 1
	return rendered
