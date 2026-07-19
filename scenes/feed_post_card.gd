extends PanelContainer

signal avatar_pressed
signal view_more_pressed
signal media_pressed
signal like_pressed(anchor_global: Vector2)
signal pin_toggled(is_pinned: bool)

const LAYOUT_RECOMMEND := "recommend"
const LAYOUT_FOLLOW := "follow"
const LAYOUT_ARTIST := "artist"
const LAYOUT_FANS := "fans"

# 艺人帖配图固定尺寸，左对齐
const SINGLE_IMAGE_SIZE := Vector2(350, 350)

const PATH_ARTIST_POSTBG := "res://art/mainui/postui/artistpostbg.png"
const PATH_LOVE := "res://art/mainui/postui/love.png"
const PATH_COMMENT := "res://art/mainui/postui/comment.png"
const PATH_SHOUCANG := "res://art/mainui/postui/shoucang.png"

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
@onready var _comment_icon: TextureRect = $CardMargin/MainVBox/FollowBar/FollowBarMargin/FollowActions/CommentCol/CommentIcon
@onready var _pin_btn: TextureButton = $CardMargin/MainVBox/FollowBar/FollowBarMargin/FollowActions/PinCol/PinBtn
@onready var _pin_text: Label = $CardMargin/MainVBox/FollowBar/FollowBarMargin/FollowActions/PinCol/PinText
@onready var _split_left: ColorRect = $CardMargin/MainVBox/SplitRow/SplitLeft
@onready var _split_right: ColorRect = $CardMargin/MainVBox/SplitRow/SplitRight

@export var like_icon_default: Texture2D
@export var like_icon_active: Texture2D
@export var pin_icon_default: Texture2D
@export var pin_icon_active: Texture2D

var _is_follow_layout: bool = false
var _is_artist_layout: bool = false
var _is_fans_layout: bool = false
var _is_pinned: bool = false
var _card_panel_style: StyleBoxFlat
var _artist_postbg_tex: Texture2D


func _ready() -> void:
	_avatar_btn.pressed.connect(func() -> void: avatar_pressed.emit())
	_btn_view_more.pressed.connect(func() -> void: view_more_pressed.emit())
	_like_btn.pressed.connect(_on_like_pressed)
	_pin_btn.pressed.connect(_on_pin_pressed)
	_single_image.gui_input.connect(_on_media_gui_input)
	_split_left.gui_input.connect(_on_media_gui_input)
	_split_right.gui_input.connect(_on_media_gui_input)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 默认白底卡片（推荐/粉丝布局用）
	_card_panel_style = StyleBoxFlat.new()
	_card_panel_style.bg_color = Color(1, 1, 1, 1)
	_card_panel_style.border_color = Color(0.9, 0.88, 0.94, 1)
	_card_panel_style.set_border_width_all(1)
	_card_panel_style.corner_radius_top_left = 14
	_card_panel_style.corner_radius_top_right = 14
	_card_panel_style.corner_radius_bottom_right = 14
	_card_panel_style.corner_radius_bottom_left = 14
	add_theme_stylebox_override("panel", _card_panel_style)

	if ResourceLoader.exists(PATH_ARTIST_POSTBG):
		_artist_postbg_tex = load(PATH_ARTIST_POSTBG) as Texture2D

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

	_apply_follow_action_visual()


func setup(enriched: Dictionary) -> void:
	var layout: String = str(enriched.get("layout", LAYOUT_RECOMMEND)).to_lower()
	_is_follow_layout = layout == LAYOUT_FOLLOW
	_is_artist_layout = layout == LAYOUT_ARTIST
	_is_fans_layout = layout == LAYOUT_FANS
	_is_pinned = bool(enriched.get("is_pinned", false))

	var artist: String = str(enriched.get("artist_name", ""))
	var body: String = str(enriched.get("text", ""))
	var time_display: String = str(enriched.get("time_display", ""))
	var img_path: String = str(enriched.get("image_path", ""))
	var av_path: String = str(enriched.get("avatar_path", ""))

	_name_label.text = artist if not artist.is_empty() else ("粉丝" if _is_fans_layout else "艺人")
	_time_label.text = time_display
	_time_label.visible = not time_display.is_empty()
	_body_label.text = body
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 艺人/粉丝动态：底部操作栏 + artistpostbg；旧 follow 布局仍走双图
	var show_action_bar := _is_follow_layout or _uses_feed_theme()
	_split_row.visible = _is_follow_layout
	_recommend_footer.visible = not show_action_bar
	_follow_bar.visible = show_action_bar
	_split_row.mouse_filter = Control.MOUSE_FILTER_STOP if _is_follow_layout else Control.MOUSE_FILTER_IGNORE

	_apply_single_image(img_path)
	_apply_avatar(av_path)

	if _single_image.visible:
		_apply_single_image_left_align()
	_apply_layout_theme()
	_apply_follow_action_visual()
	_apply_scroll_pass_through()
	if _pin_btn != null:
		var pin_col := _pin_btn.get_parent()
		if pin_col is CanvasItem:
			(pin_col as CanvasItem).visible = not _is_artist_layout


# 非交互区域透传滚轮/拖拽给 ScrollContainer
func _apply_scroll_pass_through() -> void:
	if has_node("CardMargin"):
		_pass_mouse_to_scroll(get_node("CardMargin"))


func _pass_mouse_to_scroll(node: Node) -> void:
	if node is BaseButton:
		return
	if node is TextureRect:
		var tr := node as TextureRect
		if tr.mouse_filter == Control.MOUSE_FILTER_STOP:
			return
	if node is ColorRect:
		var cr := node as ColorRect
		if cr.mouse_filter == Control.MOUSE_FILTER_STOP:
			return
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_pass_mouse_to_scroll(child)


# 帖子配图左对齐：控件宽度固定 350，避免在宽卡片内居中
func _apply_single_image_left_align() -> void:
	if _single_image == null:
		return
	_single_image.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_single_image.custom_minimum_size = SINGLE_IMAGE_SIZE
	_single_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_single_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE


# 艺人帖与粉丝帖共用 artistpostbg；操作栏去掉黑底
func _uses_feed_theme() -> bool:
	return _is_artist_layout or _is_fans_layout


# 配图：艺人/粉丝帖表里没 path 则整区隐藏；旧推荐流仍用紫色占位
func _apply_single_image(img_path: String) -> void:
	if _is_follow_layout:
		_single_image.visible = false
		_single_image.texture = null
		_single_image_placeholder.visible = false
		_single_image.custom_minimum_size = Vector2.ZERO
		_single_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	var has_image := img_path != "" and ResourceLoader.exists(img_path)
	if _uses_feed_theme():
		if has_image:
			_single_image.visible = true
			_single_image.texture = load(img_path) as Texture2D
			_single_image.modulate = Color.WHITE
			_single_image_placeholder.visible = false
			_single_image.custom_minimum_size = SINGLE_IMAGE_SIZE
			_single_image.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			# 没配 image_path：不展示配图区，不要 SingleImagePlaceholder / 350 高占位
			_single_image.visible = false
			_single_image.texture = null
			_single_image_placeholder.visible = false
			_single_image.custom_minimum_size = Vector2.ZERO
			_single_image.size = Vector2.ZERO
			_single_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	_single_image.visible = true
	if has_image:
		_single_image.texture = load(img_path) as Texture2D
		_single_image.modulate = Color.WHITE
		_single_image_placeholder.visible = false
		_single_image.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_single_image.texture = null
		_single_image_placeholder.visible = true
		_single_image.mouse_filter = Control.MOUSE_FILTER_STOP


# 头像：粉丝帖表里没配 path 则整颗头像隐藏，不要紫色占位
func _apply_avatar(av_path: String) -> void:
	if _is_fans_layout:
		if av_path != "" and ResourceLoader.exists(av_path):
			_avatar_btn.visible = true
			_avatar_btn.texture_normal = load(av_path) as Texture2D
			_avatar_btn.modulate = Color.WHITE
		else:
			_avatar_btn.visible = false
			_avatar_btn.texture_normal = null
		return
	_avatar_btn.visible = true
	if av_path != "" and ResourceLoader.exists(av_path):
		_avatar_btn.texture_normal = load(av_path) as Texture2D
		_avatar_btn.modulate = Color.WHITE
	else:
		_avatar_btn.texture_normal = null
		_avatar_btn.modulate = Color(0.86, 0.84, 0.93, 1)


func _apply_layout_theme() -> void:
	if _uses_feed_theme() and _artist_postbg_tex != null:
		var sbt := StyleBoxTexture.new()
		sbt.texture = _artist_postbg_tex
		sbt.set_content_margin_all(14)
		add_theme_stylebox_override("panel", sbt)
	elif _card_panel_style != null:
		add_theme_stylebox_override("panel", _card_panel_style)

	if _follow_bar == null:
		return
	if _uses_feed_theme():
		var transparent := StyleBoxEmpty.new()
		_follow_bar.add_theme_stylebox_override("panel", transparent)
	else:
		var fb := StyleBoxFlat.new()
		fb.bg_color = Color(0.08, 0.08, 0.1, 1)
		fb.corner_radius_top_left = 8
		fb.corner_radius_top_right = 8
		fb.corner_radius_bottom_right = 8
		fb.corner_radius_bottom_left = 8
		_follow_bar.add_theme_stylebox_override("panel", fb)


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
	if _is_follow_layout or _uses_feed_theme():
		var anchor := _like_btn.global_position + Vector2(_like_btn.size.x * 0.5, 0.0)
		like_pressed.emit(anchor)


func _on_pin_pressed() -> void:
	if not _is_follow_layout and not _uses_feed_theme():
		return
	_is_pinned = not _is_pinned
	_apply_follow_action_visual()
	pin_toggled.emit(_is_pinned)


func set_pinned(value: bool) -> void:
	_is_pinned = value
	_apply_follow_action_visual()


func _apply_follow_action_visual() -> void:
	if _like_btn == null or _pin_btn == null:
		return

	var love_tex := _load_ui_tex(PATH_LOVE)
	var comment_tex := _load_ui_tex(PATH_COMMENT)
	var pin_tex := _load_ui_tex(PATH_SHOUCANG)

	# 艺人帖与粉丝帖共用 love / comment / shoucang 资源
	if _uses_feed_theme():
		_like_btn.texture_normal = love_tex if love_tex != null else _resolve_icon(like_icon_default, Color(0.92, 0.92, 0.94, 1))
		_like_btn.texture_pressed = _like_btn.texture_normal
		_like_btn.texture_hover = _like_btn.texture_normal
		if _comment_icon != null and comment_tex != null:
			_comment_icon.texture = comment_tex
		_pin_btn.texture_normal = pin_tex if pin_tex != null else _resolve_icon(pin_icon_default, Color(0.92, 0.92, 0.94, 1))
		_pin_btn.texture_pressed = _pin_btn.texture_normal
		_pin_btn.texture_hover = _pin_btn.texture_normal
		_pin_text.modulate = Color(0.45, 0.43, 0.52, 1) if not _is_pinned else Color(1.0, 0.82, 0.28, 1)
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
		if _card_panel_style != null and not _uses_feed_theme():
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
		if _card_panel_style != null and not _uses_feed_theme():
			_card_panel_style.bg_color = Color(1, 1, 1, 1)
			_card_panel_style.border_color = Color(0.9, 0.88, 0.94, 1)
			_card_panel_style.set_border_width_all(1)


func _load_ui_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


func _resolve_icon(tex: Texture2D, fallback_color: Color) -> Texture2D:
	if tex != null:
		return tex
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(fallback_color)
	return ImageTexture.create_from_image(image)
