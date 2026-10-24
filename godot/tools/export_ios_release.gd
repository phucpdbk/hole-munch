@tool
extends SceneTree

# App Store build: production bundle/name/version applied in memory over the
# checked-in "iOS Godot" preset, then Godot archives and exports a signed IPA
# through Xcode. Run via tools/build-ios-release.sh; `--check` works on Windows.
func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning(): await process_frame
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOLE_RELEASE_SETTINGS")))
	if not data is Dictionary:
		fail("Set HOLE_RELEASE_SETTINGS to a valid builds/release-settings.json.")
		return
	for field in ["package_id", "app_name", "version_code", "version_name"]:
		if not data.has(field) or str(data[field]).is_empty():
			fail("Missing release setting: " + field)
			return
	if "prototype" in str(data.package_id) or "example" in str(data.package_id) or not RegEx.create_from_string("^[a-z][a-z0-9-]*(\\.[a-z][a-z0-9-]*)+$").search(str(data.package_id)):
		fail("Invalid production bundle ID.")
		return
	if str(data.app_name).length() > 30:
		fail("App name must be at most 30 characters.")
		return
	if float(data.version_code) != int(data.version_code) or int(data.version_code) < 1 or not RegEx.create_from_string("^[0-9]+\\.[0-9]+\\.[0-9]+$").search(str(data.version_name)):
		fail("Invalid release version.")
		return
	if ProjectSettings.get_setting("application_custom/testing/unlock_all_levels", false):
		fail("Disable unlock_all_levels before release.")
		return
	var platform := EditorExportPlatformIOS.new()
	var preset := platform.create_preset()
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		fail("Cannot load iOS preset.")
		return
	for key in config.get_section_keys("preset.1.options"):
		preset.set(key, config.get_value("preset.1.options", key))
	# Standard HTTPS only (policy link opens in Safari), so the build is exempt
	# from export compliance and uploads skip the encryption question.
	var overrides := {
		"application/bundle_identifier": str(data.package_id),
		"application/short_version": str(data.version_name),
		"application/version": str(int(data.version_code)),
		"application/export_method_release": 0,
		"application/export_project_only": false,
		"application/additional_plist_content": "<key>ITSAppUsesNonExemptEncryption</key><false/>",
	}
	for key in overrides:
		preset.set(key, overrides[key])
		if preset.get(key) != overrides[key]:
			fail("Unsupported iOS release option: " + key)
			return
	if str(preset.get("icons/icon_1024x1024")).is_empty() or not FileAccess.file_exists(preset.get("icons/icon_1024x1024")):
		fail("Set icons/icon_1024x1024 to the opaque App Store icon.")
		return
	# The iOS build ships without ads, so the privacy manifest must stay empty
	# of tracking and collected data. Enabling AdMob needs a new review first.
	if preset.get("privacy/tracking_enabled") or ProjectSettings.get_setting("admob/general/ios/enabled", false):
		fail("iOS ads/tracking enabled: update App Privacy and the privacy manifest first.")
		return
	ProjectSettings.set_setting("application/config/name", str(data.app_name))
	ProjectSettings.set_setting("application_custom/build_code", int(data.version_code))
	if "--check" in OS.get_cmdline_user_args():
		print("IOS RELEASE CONFIG: OK (not archived or signed)")
		quit()
		return
	if OS.get_name() != "macOS":
		fail("App Store export requires macOS and Xcode. Use --check on Windows.")
		return
	var team := OS.get_environment("HOLE_IOS_TEAM_ID")
	if not RegEx.create_from_string("^[A-Z0-9]{10}$").search(team):
		fail("Set HOLE_IOS_TEAM_ID to your 10-character Apple Team ID.")
		return
	preset.set("application/app_store_team_id", team)
	var output := OS.get_environment("HOLE_IOS_OUTPUT")
	if output.is_empty() or not output.is_absolute_path() or output.get_extension() != "ipa":
		fail("HOLE_IOS_OUTPUT must be an absolute .ipa path in a fresh export directory.")
		return
	var error := platform.export_project(preset, false, output)
	for i in platform.get_message_count(): print(platform.get_message_text(i))
	print("IOS RELEASE EXPORT: ", error_string(error))
	quit(0 if error == OK else 1)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
