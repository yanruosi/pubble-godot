extends SceneTree

const LOG_PATH := "res://debug-17f385.log"
const SESSION := "17f385"

const SCRIPTS: Array[String] = [
	"res://scripts/controllers/feed_card_instance.gd",
	"res://scripts/controllers/feed_card_actions.gd",
	"res://scripts/controllers/feed_tab_cards.gd",
	"res://scripts/controllers/feed_tab_refresh.gd",
	"res://scripts/controllers/feed_controller.gd",
	"res://scenes/feed_page.gd",
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	#region agent log
	_log("H0", "debug_compile_check.gd:run", "godot_version", {
		"version": Engine.get_version_info(),
		"main_scene": ProjectSettings.get_setting("application/run/main_scene", ""),
	})
	#endregion
	for path in SCRIPTS:
		_check_script(path)
	#region agent log
	_log("E", "isolated_preload", "feed_card_actions_chain", {
		"inst_preload_ok": load("res://scripts/controllers/feed_card_instance.gd") != null,
		"actions_preload_ok": load("res://scripts/controllers/feed_card_actions.gd") != null,
		"uses_get_method_argument_count": FileAccess.get_file_as_string(
			"res://scripts/controllers/feed_card_instance.gd"
		).contains("get_method_argument_count"),
	})
	#endregion
	quit(0)


func _check_script(path: String) -> void:
	var exists := FileAccess.file_exists(path)
	var text_len := 0
	var dup_ctrl := 0
	if exists:
		var text: String = FileAccess.get_file_as_string(path)
		text_len = text.length()
		var needle := "var _ctrl: FeedController"
		var idx := 0
		while true:
			var found: int = text.find(needle, idx)
			if found < 0:
				break
			dup_ctrl += 1
			idx = found + needle.length()
	var scr: Variant = load(path) if exists else null
	#region agent log
	_log("A" if path.ends_with("feed_card_instance.gd") else "B", path, "script_load", {
		"exists": exists,
		"text_len": text_len,
		"dup_ctrl_declarations": dup_ctrl,
		"load_ok": scr != null,
		"load_type": typeof(scr),
	})
	#endregion


func _log(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": SESSION,
		"runId": "post-fix-2",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
	}
	var line := JSON.stringify(payload)
	print(line)
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(line)
		f.close()
