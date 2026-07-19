extends RefCounted


static func is_my_post_template(tpl: Dictionary) -> bool:
	return int(tpl.get("tabtype", 0)) == ExposeManager.TAB_ACCOUNT


static func is_sister_or_key_template(tpl: Dictionary, postclass: int) -> bool:
	if postclass == ExposeManager.POSTCLASS_KEY:
		return true
	return int(tpl.get("tabtype", 0)) == ExposeManager.TAB_SISTER
