@tool
extends SceneTree

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning(): await process_frame
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HOLE_RELEASE_SETTINGS")))
	if not data is Dictionary:
		fail("Use build-android-release.ps1 with a valid release settings file.")
		return
	# Revalidate at the exporter boundary, even if called without PowerShell.
	for field in ["package_id", "app_name", "version_code", "version_name", "audience", "admob_app_id", "rewarded_unit", "interstitial_unit"]:
		if not data.has(field) or str(data[field]).is_empty():
			fail("Missing release setting: " + field)
			return
	for field in ["admob_app_id", "rewarded_unit", "interstitial_unit"]:
		var separator := "~" if field == "admob_app_id" else "/"
		if not RegEx.create_from_string("^ca-app-pub-[0-9]{16}" + separator + "[0-9]{10}$").search(str(data[field])) or "3940256099942544" in str(data[field]):
			fail("Invalid or test AdMob ID: " + field)
			return
	if data.audience != "general_not_child_directed" or "prototype" in str(data.package_id) or "example" in str(data.package_id) or not RegEx.create_from_string("^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$").search(str(data.package_id)):
		fail("Invalid production package/audience.")
		return
	if data.rewarded_unit == data.interstitial_unit or str(data.app_name).length() > 30:
		fail("Use distinct ad units and an app name of at most 30 characters.")
		return
	if float(data.version_code) != int(data.version_code) or int(data.version_code) < 13 or int(data.version_code) > 2100000000 or not RegEx.create_from_string("^[0-9]+\\.[0-9]+\\.[0-9]+$").search(str(data.version_name)):
		fail("Invalid release version.")
		return
	for key in ["HOLE_ANDROID_SDK", "HOLE_JAVA_SDK", "HOLE_ANDROID_KEYSTORE", "HOLE_ANDROID_KEY_ALIAS", "HOLE_ANDROID_KEYSTORE_PASSWORD"]:
		if OS.get_environment(key).is_empty():
			fail("Missing environment variable: " + key)
			return
	if OS.get_environment("HOLE_ANDROID_KEY_ALIAS") == "androiddebugkey" or not FileAccess.file_exists(OS.get_environment("HOLE_ANDROID_KEYSTORE")):
		fail("A real upload keystore is required.")
		return
	if ProjectSettings.get_setting("application_custom/testing/unlock_all_levels", false):
		fail("Disable unlock_all_levels before release.")
		return
	var platform := EditorExportPlatformAndroid.new()
	var preset := platform.create_preset()
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		fail("Cannot load Android preset.")
		return
	for key in config.get_section_keys("preset.0.options"):
		preset.set(key, config.get_value("preset.0.options", key))
	# Resource scan excludes builds/tools via their checked-in .gdignore files.
	var overrides := {
		"gradle_build/use_gradle_build": true, "gradle_build/export_format": 1,
		"gradle_build/target_sdk": "36", "package/unique_name": str(data.package_id),
		"package/name": str(data.app_name), "package/signed": true,
		"version/code": int(data.version_code), "version/name": str(data.version_name),
		"keystore/release": OS.get_environment("HOLE_ANDROID_KEYSTORE"),
		"keystore/release_user": OS.get_environment("HOLE_ANDROID_KEY_ALIAS"),
		"keystore/release_password": OS.get_environment("HOLE_ANDROID_KEYSTORE_PASSWORD"),
	}
	for key in overrides:
		preset.set(key, overrides[key])
		if preset.get(key) != overrides[key]:
			fail("Unsupported Android release option: " + key)
			return
	# Export serializes these non-secret settings into project.binary. No project
	# file or checked-in credential file is changed by this process.
	ProjectSettings.set_setting("admob/general/android/app_id", str(data.admob_app_id))
	ProjectSettings.set_setting("application_custom/ads/rewarded_unit", str(data.rewarded_unit))
	ProjectSettings.set_setting("application_custom/ads/interstitial_unit", str(data.interstitial_unit))
	ProjectSettings.set_setting("application_custom/build_code", int(data.version_code))
	ProjectSettings.set_setting("application/config/name", str(data.app_name))
	if "--check" in OS.get_cmdline_user_args():
		print("ANDROID RELEASE CONFIG: OK (not built or signed)")
		quit()
		return
	var settings := EditorInterface.get_editor_settings()
	var sdk_key := "export/android/android_sdk_path"
	var jdk_key := "export/android/java_sdk_path"
	var previous_sdk = settings.get_setting(sdk_key)
	var previous_jdk = settings.get_setting(jdk_key)
	settings.set_setting(sdk_key, OS.get_environment("HOLE_ANDROID_SDK"))
	settings.set_setting(jdk_key, OS.get_environment("HOLE_JAVA_SDK"))
	var output := ProjectSettings.globalize_path("res://builds/hole-munch-release.aab")
	var error := platform.export_project(preset, false, output)
	settings.set_setting(sdk_key, previous_sdk)
	settings.set_setting(jdk_key, previous_jdk)
	# Avoid dumping arbitrary exporter messages that might include signing args.
	print("ANDROID RELEASE EXPORT: ", error_string(error))
	quit(0 if error == OK else 1)

func fail(message: String) -> void:
	push_error(message)
	quit(1)
