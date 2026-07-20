extends RefCounted
class_name FeedDefs

## feed_page 共享常量（PSD 1280×720）

const FEED_JSON_PATH := "res://data/feed_posts.json"
const CARD_SCENE := preload("res://scenes/feed_post_card.tscn")

const PATH_POSTBG := "res://art/mainui/postui/postbg.png"
const PATH_BACK := "res://art/mainui/postui/back.png"
const PATH_MY_AVATAR := "res://art/post/myimage.png"
const PATH_MOMO_AVATAR := "res://art/post/momo.png"
const PATH_FAN_AVATAR_FALLBACK := "res://art/post/artist1.png"
const MYPOST_DISPLAY_NAME := "爱豆谈恋爱要杀头"
const PATH_LOVE := "res://art/mainui/postui/love.png"
const PATH_BANNER := "res://art/mainui/storeui/banner.png"
const PATH_BANNER_SISTER := "res://art/mainui/storeui/banner0.png"

const TYPE_ARTIST := 901

const TAB_ARTIST := "artist"
const TAB_FANDOM := "fandom"
const TAB_ACCOUNT := "account"
const TAB_SISTER := "sister"
const TAB_MARKET := "market"
const TAB_FAVORITES := "favorites"

const TABTYPE_FANDOM := 0
const TABTYPE_SISTER := 903
const TABTYPE_ACCOUNT := 904

const FEED_CONTENT_X := 356
const FEED_CONTENT_W := 497
const FEED_TOP_Y := 51
const FEED_GAP := 8
const FEED_BOTTOM_Y := 720
const FEED_BANNER_H := 126
const FEED_ARTIST_BANNER_H := 108
## 发帖区 p1（1280×720 PSD）
const P4_COMPOSE_W := 491
const P4_COMPOSE_H := 133
const P4_COMPOSE_INPUT_LOCAL := Rect2(12, 12, 465, 70)
const P4_COMPOSE_TAGS_LOCAL := Rect2(7, 96, 277, 24)
const P4_COMPOSE_SEND_LOCAL := Rect2(404, 96, 80, 24)
const P4_COMPOSE_HEAT_BAR_LOCAL := Rect2(12, 84, 465, 10)

const P1_BANNER_RECT := Rect2(FEED_CONTENT_X, FEED_TOP_Y, FEED_CONTENT_W, FEED_BANNER_H)
const P2_LIST_RECT := Rect2(FEED_CONTENT_X, FEED_TOP_Y + FEED_BANNER_H + FEED_GAP, FEED_CONTENT_W, FEED_BOTTOM_Y - (FEED_TOP_Y + FEED_BANNER_H + FEED_GAP))
const P3_BANNER_RECT := Rect2(FEED_CONTENT_X, FEED_TOP_Y, FEED_CONTENT_W, FEED_ARTIST_BANNER_H)
const P3_LIST_RECT := Rect2(FEED_CONTENT_X, FEED_TOP_Y + FEED_ARTIST_BANNER_H + FEED_GAP, FEED_CONTENT_W, FEED_BOTTOM_Y - (FEED_TOP_Y + FEED_ARTIST_BANNER_H + FEED_GAP))
const P4_COMPOSE_RECT := Rect2(FEED_CONTENT_X, FEED_TOP_Y, P4_COMPOSE_W, P4_COMPOSE_H)
const P4_BANNER_Y := FEED_TOP_Y + P4_COMPOSE_H + FEED_GAP
const P4_BANNER_RECT := Rect2(FEED_CONTENT_X, P4_BANNER_Y, FEED_CONTENT_W, FEED_BANNER_H)
const P5_LIST_Y := P4_BANNER_Y + FEED_BANNER_H + FEED_GAP
const P5_LIST_RECT := Rect2(FEED_CONTENT_X, P5_LIST_Y, FEED_CONTENT_W, FEED_BOTTOM_Y - P5_LIST_Y)
const HOTSEARCH_RECT := Rect2(855, 49, 217, 671)
const BANNER_OVERLAY_SIZE := Vector2(497, 126)
const BANNER_W := 497
const BANNER_H := 126
const BANNER_MARGIN_L := 85
const BANNER_MARGIN_R := 114
const BANNER_CONTENT_X := BANNER_MARGIN_L
const BANNER_CONTENT_W := BANNER_W - BANNER_MARGIN_L - BANNER_MARGIN_R
const BANNER_STATS_X := BANNER_W - BANNER_MARGIN_R
const BANNER_STATS_W := BANNER_MARGIN_R
const BANNER_HEAT_ROW_Y := 80
const BANNER_HEAT_LABEL_W := 30
const BANNER_HEAT_ROW_H := 14
const BANNER_HEAT_LABEL_LOCAL := Rect2(BANNER_CONTENT_X, BANNER_HEAT_ROW_Y, BANNER_HEAT_LABEL_W, BANNER_HEAT_ROW_H)
const BANNER_BAR_LOCAL := Rect2(BANNER_CONTENT_X + BANNER_HEAT_LABEL_W, BANNER_HEAT_ROW_Y, BANNER_CONTENT_W - BANNER_HEAT_LABEL_W, BANNER_HEAT_ROW_H)
const BANNER_STATUS_LOCAL := Rect2(BANNER_CONTENT_X, 8, BANNER_CONTENT_W, 44)
const BANNER_SUBLINE_LOCAL := Rect2(BANNER_CONTENT_X, 48, BANNER_CONTENT_W, 28)
const BANNER_FANS_LOCAL := Rect2(BANNER_STATS_X, 28, BANNER_STATS_W, 22)
const BANNER_FP_LOCAL := Rect2(BANNER_STATS_X, 52, BANNER_STATS_W, 22)
const BANNER_CENTER_FULL := Rect2(0, 0, BANNER_W, BANNER_H)
const BANNER_STATIC_MAIN_LOCAL := Rect2(0, 10, BANNER_W, 48)
const BANNER_STATIC_SUB_LOCAL := Rect2(0, 56, BANNER_W, 32)
const BANNER_KEY_LOCAL := BANNER_CENTER_FULL
const P1_NAV_RECT := Rect2(206, 48, 142, 672)
const HUD_FP_RECT := Rect2(780, 8, 120, 20)
const HUD_FANS_RECT := Rect2(920, 8, 120, 20)
const HUD_STARS_RECT := Rect2(900, 8, 90, 20)
const HUD_CLUE_RECT := Rect2(1000, 8, 90, 20)
const HUD_STATION_RECT := Rect2(640, 8, 90, 20)
const HUD_PANEL_BAR_RECT := Rect2(780, 8, 220, 24)
const BACK_BTN_SIZE := Vector2(36, 36)


static func postclass_badge_label(postclass: int) -> String:
	match postclass:
		2:
			return "高级"
		3:
			return "关键"
		4:
			return "主线"
		_:
			return "普通"


static func postclass_border_color(postclass: int) -> Color:
	match postclass:
		2:
			return Color(0.45, 0.35, 0.82, 1)
		3:
			return Color(0.92, 0.55, 0.18, 1)
		4:
			return Color(0.28, 0.62, 0.42, 1)
		_:
			return Color(0.9, 0.88, 0.94, 1)


static func load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


static func resolve_avatar_path(preferred: String, fallback: String = PATH_FAN_AVATAR_FALLBACK) -> String:
	var p := preferred.strip_edges()
	if p != "" and ResourceLoader.exists(p):
		return p
	if fallback != "" and ResourceLoader.exists(fallback):
		return fallback
	return p if p != "" else fallback


static func resolve_template_avatar_path(tpl: Dictionary) -> String:
	var custom := str(tpl.get("avatarpath", ""))
	if custom.strip_edges() != "":
		return resolve_avatar_path(custom)
	if int(tpl.get("tabtype", -1)) == TABTYPE_SISTER:
		return resolve_avatar_path(PATH_MOMO_AVATAR)
	return resolve_avatar_path(PATH_FAN_AVATAR_FALLBACK)


static func resolve_mypost_avatar_path() -> String:
	return resolve_avatar_path(PATH_MY_AVATAR)


static func normalize_tab_name(tab: String) -> String:
	var t := tab.to_lower()
	if t == "square":
		return TAB_FANDOM
	if t in [TAB_ARTIST, TAB_FANDOM, TAB_ACCOUNT, TAB_SISTER, TAB_MARKET, TAB_FAVORITES]:
		return t
	return TAB_ARTIST


static func exposure_tabtype_for_name(tab: String) -> int:
	match tab:
		FeedDefs.TAB_FANDOM:
			return TABTYPE_FANDOM
		FeedDefs.TAB_SISTER:
			return TABTYPE_SISTER
		FeedDefs.TAB_ACCOUNT:
			return TABTYPE_ACCOUNT
		_:
			return -1
