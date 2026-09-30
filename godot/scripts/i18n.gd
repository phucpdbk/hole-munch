extends RefCounted

# Game text lookup. Strings live in i18n_strings.gd, one row per key with a
# column per language (LANGS order). Missing cells fall back to English, then
# to Vietnamese (the source language), then to the key itself.
const Strings = preload("res://scripts/i18n_strings.gd")
const LANGS := ["vi", "en", "es", "pt", "fr", "id"]
const NAMES := {"vi":"Tiếng Việt", "en":"English", "es":"Español", "pt":"Português", "fr":"Français", "id":"Bahasa Indonesia"}
const FALLBACK := "en"

static var lang := "vi"

# First launch follows the phone's language when the game speaks it.
static func system_lang() -> String:
	var code := OS.get_locale_language()
	return code if code in LANGS else FALLBACK

static func set_lang(code: String) -> void:
	lang = code if code in LANGS else FALLBACK

static func has(key: String) -> bool:
	return Strings.S.has(key)

# t("combo", [5]) -> "COMBO 5". Arguments use GDScript % formatting.
static func t(key: String, args: Variant = null) -> String:
	var row: Array = Strings.S.get(key, [])
	var text := key
	if not row.is_empty():
		text = cell(row, LANGS.find(lang))
		if text == "": text = cell(row, LANGS.find(FALLBACK))
		if text == "": text = cell(row, 0)
	if args == null: return text
	return text % (args if args is Array else [args])

static func cell(row: Array, index: int) -> String:
	return str(row[index]) if index >= 0 and index < row.size() else ""
