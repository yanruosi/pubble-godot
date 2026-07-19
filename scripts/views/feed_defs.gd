extends RefCounted
class_name FeedDefs

## feed_page 共享常量（PSD 1280×720）

const FEED_JSON_PATH := "res://data/feed_posts.json"
const CARD_SCENE := preload("res://scenes/feed_post_card.tscn")

const PATH_POSTBG := "res://art/mainui/postui/postbg.png"
const PATH_BACK := "res://art/mainui/postui/back.png"
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

const P1_BANNER_RECT := Rect2(356, 51, 497, 126)
const P2_LIST_RECT := Rect2(356, 179, 497, 541)
const P3_BANNER_RECT := Rect2(356, 49, 497, 108)
const P3_LIST_RECT := Rect2(356, 157, 497, 563)
const P4_COMPOSE_RECT := Rect2(356, 31, 497, 155)
const P4_BANNER_RECT := Rect2(353, 186, 497, 126)
const P5_LIST_RECT := Rect2(356, 319, 497, 401)
const HOTSEARCH_RECT := Rect2(855, 49, 217, 671)
const BANNER_OVERLAY_SIZE := Vector2(497, 126)
const BANNER_BAR_LOCAL := Rect2(101, 54, 279, 23)
const BANNER_RATE_LOCAL := Rect2(259, 30, 28, 23)
const BANNER_LV_LOCAL := Rect2(411, 21, 57, 23)
const BANNER_KEY_LOCAL := Rect2(452, 66, 28, 19)
const BANNER_STATUS_LOCAL := Rect2(101, 30, 380, 40)
const P1_NAV_RECT := Rect2(206, 48, 142, 672)
const BACK_BTN_SIZE := Vector2(36, 36)


static func load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	return null


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
