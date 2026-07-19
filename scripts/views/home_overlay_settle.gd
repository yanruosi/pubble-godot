extends RefCounted
class_name HomeOverlaySettle

static func tag_display_name(tagid: String, expose: ExposeManager) -> String:
	if expose != null and expose.has_method("get_tag_name"):
		return str(expose.call("get_tag_name", tagid))
	match tagid:
		"tag_music":
			return "音乐节"
		"tag_airport":
			return "机场"
		"tag_rural":
			return "乡下表演"
		_:
			return tagid


static func format_reward_text(result: Dictionary, act: Dictionary, expose: ExposeManager) -> String:
	var lines: PackedStringArray = []
	var grant_count: int = int(result.get("grant_count", act.get("grantcountfirst", 0)))
	var grant_tag: String = str(result.get("grant_tagid", act.get("granttagid", "")))
	if grant_count > 0:
		lines.append("发帖次数 +%d" % grant_count)
	if not grant_tag.is_empty():
		lines.append("解锁标签「%s」" % tag_display_name(grant_tag, expose))
	var fh: int = int(result.get("fandom_hq_count", 0))
	var sc: int = int(result.get("sister_count", 0))
	var fn: int = int(result.get("feed_normal_count", act.get("feednormalcount", 0)))
	var fa: int = int(result.get("feed_advanced_count", act.get("feedadvancedcount", 0)))
	var fk: int = int(result.get("feed_key_count", act.get("feedkeycount", 0)))
	if fn > 0:
		lines.append("饭圈普通帖 %d 条" % fn)
	if fa > 0:
		lines.append("饭圈高级帖 %d 条" % fa)
	if fk > 0:
		lines.append("关键帖 %d 条" % fk)
	if fh > 0:
		lines.append("饭圈新增高质量帖子 %d 条" % fh)
	if sc > 0:
		lines.append("嫂子相关帖子 %d 条" % sc)
	if lines.is_empty():
		lines.append("本次暂无新帖子产出")
	return "\n".join(lines)
