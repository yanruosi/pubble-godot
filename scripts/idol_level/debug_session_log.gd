extends RefCounted
class_name DebugSessionLog

const LOG_PATH := "res://debug-b9ced2.log"
const DEBUG_LOG_PATH := "res://debug-b9ced2.log"
const DEBUG_SESSION_ID := "b9ced2"

static func write_debug(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": DEBUG_SESSION_ID,
		"runId": "initial",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var line: String = JSON.stringify(payload) + "\n"
	var file := FileAccess.open(DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(DEBUG_LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_string(line)
	file.close()

static func write(hypothesis_id: String, location: String, message: String, data: Dictionary = {}) -> void:
	var payload := {
		"sessionId": DEBUG_SESSION_ID,
		"runId": "initial",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000
	}
	var line: String = JSON.stringify(payload) + "\n"
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_string(line)
	file.close()
