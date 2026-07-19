extends RefCounted
class_name FeedTabCards

const FeedDefs := preload("res://scripts/views/feed_defs.gd")

var _ctrl: FeedController


func _init(ctrl: FeedController) -> void:
	_ctrl = ctrl


func mount_card(view: Dictionary, list_width: float, meta: Dictionary = {}) -> Node:
	var card: Node = FeedDefs.CARD_SCENE.instantiate()
	if card is Control:
		(card as Control).custom_minimum_size.x = list_width
	_ctrl._list.list_box.add_child(card)
	_ctrl._list.bind_card(card)
	if card.has_method("setup"):
		card.call("setup", view)
	if card is Node:
		for k in meta:
			(card as Node).set_meta(str(k), meta[k])
	return card


func add_empty_tip(text: String) -> void:
	var tip := Label.new()
	tip.text = text
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_color_override("font_color", Color(0.45, 0.42, 0.52, 1))
	_ctrl._list.list_box.add_child(tip)
