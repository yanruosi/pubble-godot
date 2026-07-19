extends RefCounted
class_name FeedListReveal

static func slide_height(card: Control) -> float:
	var h := card.size.y
	if h <= 0.0:
		h = card.get_combined_minimum_size().y
	if h <= 0.0:
		h = card.custom_minimum_size.y
	return maxf(h, 1.0)


static func wrap_card_for_slide(card: Control, slide_h: float) -> Control:
	card.scale = Vector2.ONE
	card.modulate = Color.WHITE
	card.pivot_offset = Vector2.ZERO
	var parent := card.get_parent()
	if parent == null:
		return card
	var idx := card.get_index()
	var wrapper := Control.new()
	wrapper.clip_contents = true
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.custom_minimum_size = Vector2(card.custom_minimum_size.x, slide_h)
	parent.remove_child(card)
	parent.add_child(wrapper)
	parent.move_child(wrapper, idx)
	wrapper.add_child(card)
	card.position = Vector2.ZERO
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return wrapper
