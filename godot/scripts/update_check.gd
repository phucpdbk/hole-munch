extends Node

# Asks a static version file whether a newer build exists; no server of our
# own. version.json in this repo is served by GitHub, so publishing an update
# is: raise version/code in export_presets.cfg and application_custom/build_code
# in project.godot, upload the APK, then bump version.json and push it. For a
# Play Store release, point "url" at market://details?id=<package>.
signal update_available(info: Dictionary)

const VERSION_URL := "https://raw.githubusercontent.com/phucpdbk/hole-munch/main/godot/version.json"
const TIMEOUT := 8.0
# Only these links are ever opened, and only when the player taps the button.
const ALLOWED_URLS := ["https://", "market://"]

func _ready() -> void:
	if OS.get_name() != "Android": return
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200: return
		var info := parse(body.get_string_from_utf8(), current_code())
		if not info.is_empty(): update_available.emit(info))
	if http.request(VERSION_URL) != OK: http.queue_free()

static func current_code() -> int:
	return int(ProjectSettings.get_setting("application_custom/build_code", 0))

# Returns {"code", "name", "url"} for a valid, newer build, else {}.
static func parse(text: String, current: int) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary: return {}
	var code: Variant = data.get("version_code")
	var url: Variant = data.get("url")
	if not (code is float or code is int) or not url is String: return {}
	if int(code) <= current: return {}
	if not ALLOWED_URLS.any(func(prefix): return url.begins_with(prefix)): return {}
	return {"code":int(code), "name":str(data.get("version_name", "")), "url":url}
