@tool
extends SceneTree

# Team/bundle overrides live only in memory, never in the checked-in preset.
func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning(): await process_frame
	var platform := EditorExportPlatformIOS.new()
	var preset := platform.create_preset()
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		fail("Cannot load export_presets.cfg.")
		return
	var properties: Array = []
	for property in preset.get_property_list(): properties.append(property.name)
	for key in config.get_section_keys("preset.1.options"):
		if key not in properties:
			fail("Unsupported iOS option: " + key)
			return
		preset.set(key, config.get_value("preset.1.options", key))
		if preset.get(key) != config.get_value("preset.1.options", key):
			fail("Could not apply iOS option: " + key)
			return
	if not preset.get("application/export_project_only"):
		fail("Export must create an Xcode project; signing happens in Xcode.")
		return
	if "--check" in OS.get_cmdline_user_args():
		print("IOS CONFIG CHECK: OK (no Xcode build or signing performed)")
		quit()
		return
	if OS.get_name() != "macOS":
		fail("iOS export requires macOS and Xcode. Use --check on Windows.")
		return
	var team := OS.get_environment("HOLE_IOS_TEAM_ID")
	var team_pattern := RegEx.create_from_string("^[A-Z0-9]{10}$")
	if not team_pattern.search(team):
		fail("Set HOLE_IOS_TEAM_ID to your 10-character Apple Team ID.")
		return
	preset.set("application/app_store_team_id", team)
	var bundle := OS.get_environment("HOLE_IOS_BUNDLE_ID")
	if not bundle.is_empty():
		var pattern := RegEx.create_from_string("^[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)+$")
		if not pattern.search(bundle):
			fail("HOLE_IOS_BUNDLE_ID must be a reverse-DNS identifier.")
			return
		preset.set("application/bundle_identifier", bundle)
	var output := OS.get_environment("HOLE_IOS_OUTPUT")
	if output.is_empty() or not output.is_absolute_path() or output.get_extension() != "ipa":
		fail("HOLE_IOS_OUTPUT must be an absolute .ipa path in a fresh export directory.")
		return
	var error := platform.export_project(preset, true, output)
	for i in platform.get_message_count(): print(platform.get_message_text(i))
	print("IOS XCODE EXPORT: ", error_string(error))
	quit(0 if error == OK else 1)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
