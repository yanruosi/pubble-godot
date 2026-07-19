extends RefCounted
class_name FeedListView

const FeedDefs := preload("res://scripts/views/feed_defs.gd")
const _Reveal = preload("res://scripts/views/feed_list_reveal.gd")

signal scrolled_down

var _host: Control
var _scroll: ScrollContainer
var _list_box: VBoxContainer
var list_box: VBoxContainer:
	get: return _list_box
var _manual_dragging: bool = false
var _scroll_started: bool = false
var _reveal_run_id: int = 0
var _love_tex: Texture2D


func build(parent: Control, list_rect: Rect2 = FeedDefs.P2_LIST_RECT) -> void:
	_host = parent
	_love_tex = FeedDefs.load_tex(FeedDefs.PATH_LOVE)
	var r := list_rect
	_scroll = ScrollContainer.new()
	_scroll.position = r.position
	_scroll.size = r.size
	_scroll.custom_minimum_size = r.size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	parent.add_child(_scroll)
	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 12)
	_list_box.custom_minimum_size.x = r.size.x
	_list_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_list_box)
	connect_scroll_input(Callable(self, "handle_scroll_input"))


func clear_list() -> void:
	clear()


func bind_card(card: Node) -> void:
	bind_card_input(card, Callable(self, "handle_scroll_input"))


func scroll_to_top() -> void:
	if _scroll:
		_scroll.scroll_vertical = 0
		_scroll.clip_contents = true


func relayout(list_rect: Rect2) -> void:
	if _scroll == null:
		return
	_scroll.position = list_rect.position
	_scroll.size = list_rect.size
	_scroll.custom_minimum_size = list_rect.size
	_scroll.clip_contents = true
	if _list_box:
		_list_box.custom_minimum_size.x = list_rect.size.x

func clear() -> void:
	if _list_box == null:
		return
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()

func get_list_box() -> VBoxContainer:
	return _list_box

func mount_card(card: Node, list_width: float) -> void:
	if card is Control:
		(card as Control).custom_minimum_size.x = list_width
	_list_box.add_child(card)

func bind_card_input(card: Node, handler: Callable) -> void:
	if card is Control and handler.is_valid():
		var cc := card as Control
		if not cc.gui_input.is_connected(handler):
			cc.gui_input.connect(handler)

func set_scroll_handler(_handler: Callable) -> void:
	pass


func reset_scroll_started() -> void:
	_scroll_started = false
func get_scroll_started() -> bool:
	return _scroll_started
func set_scroll_started(v: bool) -> void:
	_scroll_started = v

func bump_reveal_run() -> int:
	_reveal_run_id += 1
	return _reveal_run_id

func is_reveal_run_current(run_id: int) -> bool:
	return run_id < 0 or run_id == _reveal_run_id

func play_slide_in_reveal(instance_ids: Array, run_id: int, on_done: Callable) -> void:
	if not is_reveal_run_current(run_id) or _list_box == null or instance_ids.is_empty():
		return
	if _scroll:
		_scroll.scroll_vertical = 0
		_scroll.clip_contents = true
	await _host.get_tree().process_frame
	if not is_reveal_run_current(run_id):
		return
	var pending: Dictionary = {}
	for iid in instance_ids:
		pending[str(iid)] = true
	var order := 0
	for child in _list_box.get_children():
		if not (child is Control) or not is_instance_valid(child):
			continue
		var iid: String = str((child as Node).get_meta("instance_id", ""))
		if iid.is_empty() or not pending.has(iid):
			continue
		var card := child as Control
		var slide_h := _Reveal.slide_height(card)
		_Reveal.wrap_card_for_slide(card, slide_h)
		card.position = Vector2(0.0, -slide_h)
		var tw := _host.create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_interval(float(order) * 0.32)
		tw.tween_property(card, "position:y", 0.0, 0.36)
		order += 1
	if order > 0:
		await _host.get_tree().create_timer(float(order - 1) * 0.32 + 0.38).timeout
		if is_reveal_run_current(run_id) and on_done.is_valid():
			on_done.call()

func play_heart_effect(anchor: Node, anchor_global: Vector2 = Vector2.ZERO) -> void:
	var pos := anchor_global
	if pos == Vector2.ZERO and anchor is Control:
		pos = (anchor as Control).global_position
	var node: Control
	if _love_tex:
		var heart := TextureRect.new()
		heart.texture = _love_tex
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(22, 22)
		heart.size = Vector2(22, 22)
		heart.global_position = pos + Vector2(-11, -18)
		node = heart
	else:
		var lbl := Label.new()
		lbl.text = "❤"
		lbl.modulate = Color(1.0, 0.42, 0.56, 1)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.global_position = pos + Vector2(-14, -14)
		node = lbl
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(node)
	var tw := _host.create_tween()
	tw.tween_property(node, "position:y", node.position.y - 18, 0.35)
	tw.parallel().tween_property(node, "modulate:a", 0.0, 0.35)
	tw.tween_callback(node.queue_free)

func connect_scroll_input(on_input: Callable) -> void:
	for node in [_scroll, _list_box]:
		if node and on_input.is_valid() and not node.gui_input.is_connected(on_input):
			node.gui_input.connect(on_input)

func handle_scroll_input(event: InputEvent) -> void:
	if _scroll == null:
		return
	var max_v := int(_scroll.get_v_scroll_bar().max_value) if _scroll.get_v_scroll_bar() else 0
	var _scroll_down_flag := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_scroll_down_flag = true
			_scroll.scroll_vertical = clampi(int(_scroll.scroll_vertical + 48), 0, max_v)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_scroll.scroll_vertical = clampi(int(_scroll.scroll_vertical - 48), 0, max_v)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_manual_dragging = mb.pressed
	elif event is InputEventMouseMotion and _manual_dragging:
		var mm := event as InputEventMouseMotion
		_scroll_down_flag = mm.relative.y > 0.5
		_scroll.scroll_vertical = clampi(int(_scroll.scroll_vertical - mm.relative.y), 0, max_v)
	elif event is InputEventScreenTouch:
		_manual_dragging = (event as InputEventScreenTouch).pressed
	elif event is InputEventScreenDrag and _manual_dragging:
		var sd := event as InputEventScreenDrag
		_scroll_down_flag = sd.relative.y > 0.5
		_scroll.scroll_vertical = clampi(int(_scroll.scroll_vertical - sd.relative.y), 0, max_v)
	if _scroll_down_flag:
		scrolled_down.emit()

