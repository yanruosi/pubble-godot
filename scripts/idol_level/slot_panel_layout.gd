extends RefCounted
class_name SlotPanelLayout

## 槽位面板共享 PSD 布局（1280×720）

const DESIGN_SIZE := Vector2(1280, 720)
const SCENE_MASK_COLOR := Color(0, 0, 0, 0.55)

const TEX_WORD_BG := "res://art/mainui/level/wordbg.png"
const TEX_CHIP_1 := "res://art/mainui/level/citiaobg1.png"
const TEX_CHIP_2 := "res://art/mainui/level/citiaobg2.png"
const TEX_CHIP_3 := "res://art/mainui/level/citiaobg3.png"

const WORD_BG_RECT := Rect2(705, 33, 427, 524)
const CHIP_SIZE := Vector2(133, 61)
const CHIP_GRID_ORIGIN := Vector2(716, 122)
const CHIP_COLS := 3
const CHIP_H_SEP := 5
const CHIP_V_SEP := 25
const CHIP_FONT_SIZE := 28
const CHIP_LONG_FONT_SIZE := 21
const CHIP_LONG_TEXT_LEN := 5
const DRAG_OVERLAY_LAYER := 350

static func chip_slot_position(slot_index: int) -> Vector2:
	var col: int = slot_index % CHIP_COLS
	var row: int = int(slot_index / CHIP_COLS)
	return Vector2(
		CHIP_GRID_ORIGIN.x + col * (CHIP_SIZE.x + CHIP_H_SEP),
		CHIP_GRID_ORIGIN.y + row * (CHIP_SIZE.y + CHIP_V_SEP)
	)

static func chip_texture_for_tag(tag: String) -> String:
	match tag:
		"name":
			return TEX_CHIP_2
		"drink":
			return TEX_CHIP_3
		_:
			return TEX_CHIP_1

static func chip_font_size_for_text(text: String) -> int:
	if text.length() >= CHIP_LONG_TEXT_LEN:
		return CHIP_LONG_FONT_SIZE
	return CHIP_FONT_SIZE

static func should_keep_open_on_click(local_pos: Vector2, puzzle_rect: Rect2) -> bool:
	if puzzle_rect.has_point(local_pos):
		return true
	if WORD_BG_RECT.has_point(local_pos):
		return true
	if IdolBottomBar.BOTTOM_UI_BLOCK_RECT.has_point(local_pos):
		return true
	return false

static func make_scene_mask() -> ColorRect:
	var mask := ColorRect.new()
	mask.name = "SceneMask"
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.offset_right = 0
	mask.offset_bottom = 0
	mask.color = SCENE_MASK_COLOR
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	return mask
