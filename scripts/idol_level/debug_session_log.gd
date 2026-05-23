extends RefCounted
class_name DebugSessionLog

const SESSION_ID := "e48a0e"
const LOG_NAME := "debug-e48a0e.log"

static func write(location: String, message: String, hypothesis_id: String, data: Dictionary = {}, run_id: String = "pre-fix") -> void:
	var payload := {
		"sessionId": SESSION_ID,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000,
		"hypothesisId": hypothesis_id,
		"runId": run_id
	}
	var log_path: String = ProjectSettings.globalize_path("res://").path_join(LOG_NAME)
	var exists: bool = FileAccess.file_exists(log_path)
	var mode: int = FileAccess.READ_WRITE if exists else FileAccess.WRITE
	var file := FileAccess.open(log_path, mode)
	if file == null:
		return
	if exists:
		file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.close()
