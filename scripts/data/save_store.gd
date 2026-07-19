extends RefCounted
class_name SaveStore

## L1：progress.cfg 读写（零游戏逻辑）

const SAVE_PATH := "user://progress.cfg"


static func load_config() -> ConfigFile:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return null
	return config


static func save_config(config: ConfigFile) -> int:
	return config.save(SAVE_PATH)


static func ensure_config() -> ConfigFile:
	var config := load_config()
	if config != null:
		return config
	config = ConfigFile.new()
	return config


static func read_game_started() -> bool:
	var config := load_config()
	if config == null:
		return false
	return bool(config.get_value("player", "game_started", false))


static func write_game_started(started: bool) -> void:
	var config := ensure_config()
	config.set_value("player", "game_started", started)
	save_config(config)
