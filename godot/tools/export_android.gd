@tool
extends SceneTree

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	# Allow the editor's resource scan to complete before gathering dependencies.
	await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var settings := EditorInterface.get_editor_settings()
	var sdk := OS.get_environment("HOLE_ANDROID_SDK")
	var jdk := OS.get_environment("HOLE_JAVA_SDK")
	if sdk.is_empty() or jdk.is_empty():
		push_error("Set HOLE_ANDROID_SDK and HOLE_JAVA_SDK before exporting.")
		quit(1)
		return
	var sdk_key := "export/android/android_sdk_path"
	var jdk_key := "export/android/java_sdk_path"
	var previous_sdk = settings.get_setting(sdk_key)
	var previous_jdk = settings.get_setting(jdk_key)
	settings.set_setting(sdk_key,sdk)
	settings.set_setting(jdk_key,jdk)
	var platform := EditorExportPlatformAndroid.new()
	var preset := platform.create_preset()
	var config := ConfigFile.new()
	var error := config.load("res://export_presets.cfg")
	if error==OK:
		# Newly created presets export all resources. Build/test/tool folders carry
		# .gdignore files, so they are not picked up by the resource scan.
		for key in config.get_section_keys("preset.0.options"):
			preset.set(key,config.get_value("preset.0.options",key))
		error = platform.export_project(preset,true,ProjectSettings.globalize_path("res://builds/hole-munch-prototype.apk"))
	settings.set_setting(sdk_key,previous_sdk)
	settings.set_setting(jdk_key,previous_jdk)
	for i in platform.get_message_count():
		print(platform.get_message_text(i))
	print("ANDROID EXPORT: ", error_string(error))
	quit(0 if error==OK else 1)
