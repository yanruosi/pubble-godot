extends RefCounted


static func expose(page: Control) -> ExposeManager:
	return page.get_node_or_null("/root/ExposeManagerSingleton") as ExposeManager


static func save(page: Control) -> SaveManager:
	return page.get_node_or_null("/root/SaveManagerSingleton") as SaveManager


static func chapter(page: Control) -> ChapterManager:
	return page.get_node_or_null("/root/ChapterManagerSingleton") as ChapterManager


static func conditions(page: Control) -> ConditionChecker:
	return page.get_node_or_null("/root/ConditionCheckerSingleton") as ConditionChecker
