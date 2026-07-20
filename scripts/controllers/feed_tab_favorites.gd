extends RefCounted
class_name FeedTabFavorites

const FavoritesView := preload("res://scripts/views/favorites_view.gd")

var _ctrl: FeedController
var _cards
var _view: FavoritesView


func _init(ctrl: FeedController, cards) -> void:
	_ctrl = ctrl
	_cards = cards
	_view = FavoritesView.new()


func refresh() -> void:
	var expose: ExposeManager = _ctrl._expose()
	if expose == null or _ctrl._list.list_box == null:
		return
	var rows: Array = _ctrl._vm.build_favorites_vm()
	var rendered := _view.render(_ctrl._list, _cards, rows, Callable(self, "_bind_fav_card"))
	if rendered == 0:
		_cards.add_empty_tip("暂无收藏，在饭圈动态收藏帖子后会显示在这里")


func _bind_fav_card(card: Node, row: Dictionary) -> void:
	var expose: ExposeManager = _ctrl._expose()
	if expose == null:
		return
	var kind: String = str(row.get("kind", ""))
	if kind == "mypost":
		var item: Dictionary = row.get("item", {})
		_ctrl._actions.connect_mypost_card_signals(card, item, expose)
		return
	var inst: Dictionary = row.get("inst", {})
	var tpl: Dictionary = row.get("tpl", {})
	_ctrl._actions.bind_instance_card(card, inst, tpl)
