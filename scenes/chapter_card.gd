extends Button

const STATE_LOCKED := 0
const STATE_IN_PROGRESS := 1
const STATE_DONE := 2

const DIM_COLOR := Color(0.55, 0.55, 0.55, 1.0)

@onready var title_label: Label = $ContentMargin/Row/LeftVBox/TitleLabel
@onready var desc_label: Label = $ContentMargin/Row/LeftVBox/DescLabel
@onready var state_label: Label = $ContentMargin/Row/LeftVBox/StateLabel
@onready var new_badge: Label = $ContentMargin/NewBadge

func setup(chapter: Dictionary, state: int) -> void:
	var artist_name: String = str(chapter.get("artist_name", ""))
	var chapter_name: String = str(chapter.get("chapter_name", ""))
	var title := title_label
	var desc := desc_label
	var state_node := state_label
	if title == null:
		title = get_node_or_null("ContentMargin/Row/LeftVBox/TitleLabel") as Label
	if desc == null:
		desc = get_node_or_null("ContentMargin/Row/LeftVBox/DescLabel") as Label
	if state_node == null:
		state_node = get_node_or_null("ContentMargin/Row/LeftVBox/StateLabel") as Label

	if title != null:
		title.text = "%s Ticket" % artist_name
	if desc != null:
		desc.text = chapter_name
	if state_node != null:
		state_node.text = "状态：%s" % _state_text(state)
	_apply_style(state)

func _state_text(state: int) -> String:
	match state:
		STATE_LOCKED:
			return "未解锁"
		STATE_IN_PROGRESS:
			return "使用中"
		STATE_DONE:
			return "已消耗"
		_:
			return "未知"

func _apply_style(state: int) -> void:
	var bg := StyleBoxFlat.new()
	bg.corner_radius_top_left = 18
	bg.corner_radius_top_right = 18
	bg.corner_radius_bottom_right = 18
	bg.corner_radius_bottom_left = 18
	bg.border_width_left = 2
	bg.border_width_top = 2
	bg.border_width_right = 2
	bg.border_width_bottom = 2
	bg.border_color = Color("9A8FB8")

	match state:
		STATE_LOCKED:
			bg.bg_color = Color("DADADA")
		STATE_IN_PROGRESS:
			bg.bg_color = Color("FFFFFF")
		STATE_DONE:
			bg.bg_color = Color("ECECEC")

	add_theme_stylebox_override("normal", bg)
	add_theme_stylebox_override("hover", bg)
	add_theme_stylebox_override("pressed", bg)

func set_dim(dim: bool) -> void:
	if dim:
		modulate = DIM_COLOR
	else:
		modulate = Color.WHITE

func set_new_badge_visible(visible_flag: bool) -> void:
	if new_badge != null:
		new_badge.visible = visible_flag
