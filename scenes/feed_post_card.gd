extends PanelContainer

signal avatar_pressed
signal view_more_pressed
signal media_pressed
signal like_pressed(anchor_global: Vector2)
signal pin_toggled(is_pinned: bool)

const LAYOUT_RECOMMEND := "recommend"
const LAYOUT_FOLLOW := "follow"
const DEBUG_LOG_PATH := "D:/GAMES/pubble/debug-fe0741.log"

@onready var _avatar_btn: TextureButton = $CardMargin/MainVBox/HeaderRow/AvatarBtn
@onready var _name_label: Label = $CardMargin/MainVBox/HeaderRow/HeaderTexts/NameLabel
@onready var _time_label: Label = $CardMargin/MainVBox/HeaderRow/HeaderTexts/TimeLabel
@onready var _body_label: Label = $CardMargin/MainVBox/BodyLabel
@onready var _single_image: TextureRect = $CardMargin/MainVBox/SingleImage
@onready var _single_image_placeholder: ColorRect = $CardMargin/MainVBox/SingleImage/SingleImagePlaceholder
@onready var _split_row: HBoxContainer = $CardMargin/MainVBox/SplitRow
@onready var _recommend_footer: MarginContainer = $CardMargin/MainVBox/RecommendFooter
@onready var _btn_view_more: Button = $CardMargin/MainVBox/RecommendFooter/BtnViewMore
@onready var _follow_bar: PanelContainer = $CardMargin/MainVBox/FollowBar
@onready var _like_btn: TextureButton = $CardMargin/MainVBox/FollowBar/FollowBarMargin/FollowActions/LikeCol/LikeBtn
@onready var _pin_btn: TextureButton = $CardMargin/MainVBox/FollowBar/FollowBarMargin/FollowActions/PinCol/PinBtn
@onready var _pin_text: Label = $CardMargin/MainVBox/FollowBar/FollowBarMargin/FollowActions/PinCol/PinText
@onready var _split_left: ColorRect = $CardMargin/MainVBox/SplitRow/SplitLeft
@onready var _split_right: ColorRect = $CardMargin/MainVBox/SplitRow/SplitRight

@export var like_icon_default: Texture2D
@export var like_icon_active: Texture2D
@export var pin_icon_default: Texture2D
@export var pin_icon_active: Texture2D

var _is_follow_layout: bool = false
var _is_pinned: bool = false
var _card_panel_style: StyleBoxFlat

#region agent log
func _dbg(hypothesis_id: String, location: String, message: String, data: Dictionary = {}, run_id: String = "run1") -> void:
	var payload := {
		"sessionId": "fe0741",
		"runId": run_id,
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0)
	}
	var f: FileAccess = FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(payload))
	f.close()
#endregion


func _ready() -> void:
	_avatar_btn.pressed.connect(func() -> void: avatar_pressed.emit())
	_btn_view_more.pressed.connect(func() -> void: view_more_pressed.emit())
	_like_btn.pressed.connect(_on_like_pressed)
	_pin_btn.pressed.connect(_on_pin_pressed)
	_single_image.gui_input.connect(_on_media_gui_input)
	_split_left.gui_input.connect(_on_media_gui_input)
	_split_right.gui_input.connect(_on_media_gui_input)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_panel_style = StyleBoxFlat.new()
	_card_panel_style.bg_color = Color(1, 1, 1, 1)
	_card_panel_style.border_color = Color(0.9, 0.88, 0.94, 1)
	_card_panel_style.set_border_width_all(1)
	_card_panel_style.corner_radius_top_left = 14
	_card_panel_style.corner_radius_top_right = 14
	_card_panel_style.corner_radius_bottom_right = 14
	_card_panel_style.corner_radius_bottom_left = 14
	add_theme_stylebox_override("panel", _card_panel_style)
	var vm_style := StyleBoxFlat.new()
	vm_style.bg_color = Color(0.91, 0.91, 0.93, 1)
	vm_style.corner_radius_top_left = 10
	vm_style.corner_radius_top_right = 10
	vm_style.corner_radius_bottom_right = 10
	vm_style.corner_radius_bottom_left = 10
	_btn_view_more.add_theme_stylebox_override("normal", vm_style)
	var vm_hover := vm_style.duplicate() as StyleBoxFlat
	vm_hover.bg_color = Color(0.87, 0.87, 0.91, 1)
	_btn_view_more.add_theme_stylebox_override("hover", vm_hover)
	var fb := StyleBoxFlat.new()
	fb.bg_color = Color(0.08, 0.08, 0.1, 1)
	fb.corner_radius_top_left = 8
	fb.corner_radius_top_right = 8
	fb.corner_radius_bottom_right = 8
	fb.corner_radius_bottom_left = 8
	_follow_bar.add_theme_stylebox_override("panel", fb)
	_apply_follow_action_visual()


func setup(enriched: Dictionary) -> void:
	var layout: String = str(enriched.get("layout", LAYOUT_RECOMMEND)).to_lower()
	_is_follow_layout = layout == LAYOUT_FOLLOW
	_is_pinned = bool(enriched.get("is_pinned", false))

	var artist: String = str(enriched.get("artist_name", ""))
	var body: String = str(enriched.get("text", ""))
	var img_path: String = str(enriched.get("image_path", ""))
	var av_path: String = str(enriched.get("avatar_path", ""))

	_name_label.text = artist if not artist.is_empty() else "艺人"
	_time_label.visible = false
	_body_label.text = body

	_single_image.visible = not _is_follow_layout
	_split_row.visible = _is_follow_layout
	_recommend_footer.visible = not _is_follow_layout
	_follow_bar.visible = _is_follow_layout
	_single_image.mouse_filter = Control.MOUSE_FILTER_IGNORE if not _is_follow_layout else Control.MOUSE_FILTER_STOP
	_split_row.mouse_filter = Control.MOUSE_FILTER_STOP if _is_follow_layout else Control.MOUSE_FILTER_IGNORE

	if not _is_follow_layout:
		if img_path != "" and ResourceLoader.exists(img_path):
			_single_image.texture = load(img_path) as Texture2D
			_single_image.modulate = Color.WHITE
			_single_image_placeholder.visible = false
		else:
			_single_image.texture = null
			_single_image_placeholder.visible = true
	else:
		_single_image.texture = null
		_single_image_placeholder.visible = false

	if av_path != "" and ResourceLoader.exists(av_path):
		_avatar_btn.texture_normal = load(av_path) as Texture2D
		_avatar_btn.modulate = Color.WHITE
	else:
		_avatar_btn.texture_normal = null
		_avatar_btn.modulate = Color(0.86, 0.84, 0.93, 1)
	_apply_follow_action_visual()


func _on_media_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			media_pressed.emit()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			media_pressed.emit()


func _on_like_pressed() -> void:
	if _is_follow_layout:
		#region agent log
		_dbg(
			"H1",
			"feed_post_card.gd:_on_like_pressed",
			"like button pressed positions",
			{
				"card_global": global_position,
				"like_btn_global": _like_btn.global_position if _like_btn != null else Vector2.ZERO,
				"follow_bar_global": _follow_bar.global_position if _follow_bar != null else Vector2.ZERO
			}
		)
		#endregion
		var anchor := _like_btn.global_position + Vector2(_like_btn.size.x * 0.5, 0.0)
		like_pressed.emit(anchor)


func _on_pin_pressed() -> void:
	if not _is_follow_layout:
		return
	_is_pinned = not _is_pinned
	_apply_follow_action_visual()
	pin_toggled.emit(_is_pinned)


func set_pinned(value: bool) -> void:
	_is_pinned = value
	_apply_follow_action_visual()


func _apply_follow_action_visual() -> void:
	if _like_btn == null or _pin_btn == null or _card_panel_style == null:
		return
	_like_btn.texture_normal = _resolve_icon(like_icon_default, Color(0.92, 0.92, 0.94, 1))
	_like_btn.texture_pressed = _resolve_icon(like_icon_active, Color(1.0, 0.44, 0.58, 1))
	_like_btn.texture_hover = _like_btn.texture_pressed
	_like_btn.texture_disabled = _like_btn.texture_normal

	if _is_pinned:
		var active_icon := _resolve_icon(pin_icon_active, Color(1.0, 0.82, 0.28, 1))
		_pin_btn.texture_normal = active_icon
		_pin_btn.texture_hover = active_icon
		_pin_btn.texture_pressed = active_icon
		_pin_btn.texture_disabled = active_icon
		_pin_text.modulate = Color(1.0, 0.82, 0.28, 1)
		_card_panel_style.bg_color = Color(1.0, 0.989, 0.94, 1)
		_card_panel_style.border_color = Color(1.0, 0.82, 0.28, 1)
		_card_panel_style.set_border_width_all(2)
		var tw_in := create_tween()
		tw_in.tween_property(self, "scale", Vector2(1.01, 1.01), 0.08)
		tw_in.tween_property(self, "scale", Vector2.ONE, 0.10)
	else:
		var normal_icon := _resolve_icon(pin_icon_default, Color(0.92, 0.92, 0.94, 1))
		var active_icon_unpinned := _resolve_icon(pin_icon_active, Color(1.0, 0.82, 0.28, 1))
		_pin_btn.texture_normal = normal_icon
		_pin_btn.texture_hover = normal_icon
		_pin_btn.texture_pressed = active_icon_unpinned
		_pin_btn.texture_disabled = normal_icon
		_pin_text.modulate = Color(0.92, 0.92, 0.94, 1)
		_card_panel_style.bg_color = Color(1, 1, 1, 1)
		_card_panel_style.border_color = Color(0.9, 0.88, 0.94, 1)
		_card_panel_style.set_border_width_all(1)


func _resolve_icon(tex: Texture2D, fallback_color: Color) -> Texture2D:
	if tex != null:
		return tex
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(fallback_color)
	return ImageTexture.create_from_image(image)
