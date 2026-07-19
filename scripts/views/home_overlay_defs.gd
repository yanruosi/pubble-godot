extends RefCounted
class_name HomeOverlayDefs

const SHOP_SIZE := Vector2(1280, 720)
const ACTIVITY_SIZE := Vector2(1280, 720)
const ACTIVITY_BG_PATH := "res://art/mainui/storeui/store2.png"
const ACTIVITY_WIN_BG_PATH := "res://art/mainui/storeui/store3.png"
const ACTIVITY_SETTLE_BG_PATH := "res://art/mainui/storeui/store5.png"

const ACTIVITY_P1_DESC := Rect2(339, 327, 243, 154)
const ACTIVITY_P2_PREV := Rect2(279, 347, 43, 42)
const ACTIVITY_P3_NEXT := Rect2(1065, 347, 43, 42)
const ACTIVITY_P4_TAB_SHOW := Rect2(1134, 126, 49, 105)
const ACTIVITY_P5_TAB_DAILY := Rect2(1134, 231, 49, 105)
const ACTIVITY_P6_TAB_SPECIAL := Rect2(1134, 336, 49, 105)
const ACTIVITY_CLOSE := Rect2(1069, 138, 46, 39)
const ACTIVITY_ACTION_HIT := Rect2(500, 530, 400, 60)
const ACTIVITY_ACTION_TEXT := Rect2(679, 569, 65, 27)
const ACTIVITY_COST_TEXT := Rect2(651, 523, 123, 26)
const ACTIVITY_OWN_TEXT := Rect2(978, 583, 123, 26)

const TAB_SHOW := 0
const TAB_DAILY := 1
const TAB_SPECIAL := 2

const HOME_BTN_ACTIVITY_POS := Vector2(985, 260)
const HOME_BTN_ACTIVITY_SIZE := Vector2(177, 56)
const SHOP_BG_PATH := "res://art/mainui/storeui/store1.png"

const SHOP_P1_UPGRADE := Rect2(288, 546, 155, 47)
const SHOP_P7_CLOSE := Rect2(1069, 138, 46, 39)
const SHOP_P8_CURRENT := Rect2(342, 197, 67, 22)
const SHOP_P9_NEXT := Rect2(342, 268, 120, 22)
const SHOP_P10_NAME := Rect2(342, 220, 120, 22)

const SHOP_SLOT_DESC_RECTS := [
	Rect2(516, 443, 157, 68),
	Rect2(712, 443, 157, 68),
]
const SHOP_SLOT_PRICE_RECTS := [
	Rect2(516, 514, 157, 28),
	Rect2(712, 514, 157, 28),
]
const SHOP_SLOT_BUY_RECTS := [
	Rect2(516, 548, 157, 39),
	Rect2(712, 548, 157, 39),
]
const SHOP_SLOT_ICON_RECTS := [
	Rect2(516, 303, 156, 138),
	Rect2(722, 303, 156, 138),
]
