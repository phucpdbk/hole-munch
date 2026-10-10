extends SceneTree

const Backend = preload("res://scripts/admob_backend.gd")
var failures := 0

class FakeBackend extends Backend:
	var allowed := false
	func _ready() -> void: pass
	func can_request_ads() -> bool: return allowed and not consent_busy
	func load_rewarded() -> void: pass
	func load_interstitial() -> void: pass

class FakeRewarded extends RewardedAd:
	var destroyed := 0
	var listener: OnUserEarnedRewardListener
	func _init() -> void: super(1)
	func destroy() -> void: destroyed += 1
	func show(value := OnUserEarnedRewardListener.new()) -> void: listener = value

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ") + label)

func run() -> void:
	if Engine.is_editor_hint():
		await process_frame
		while EditorInterface.get_resource_filesystem().is_scanning(): await process_frame
	for status in 4:
		check(not Backend.consent_allows_ads(false, status), "failed refresh blocks status %d" % status)
	check(not Backend.consent_allows_ads(true, 0), "unknown consent blocks ads")
	check(not Backend.consent_allows_ads(true, 2), "required consent blocks ads")
	check(Backend.consent_allows_ads(true, 1), "fresh not-required status allows ads")
	check(Backend.consent_allows_ads(true, 3), "fresh obtained status allows ads")
	var backend := FakeBackend.new()
	root.add_child(backend)
	var result: Array = []
	backend.show_rewarded(func(ok: bool): result.append(ok))
	check(result == [false], "unavailable rewarded ad completes without reward")
	var ad := FakeRewarded.new()
	backend.rewarded = ad
	check(not backend.is_rewarded_ready(), "loaded ads cannot bypass consent")
	backend.allowed = true
	check(backend.is_rewarded_ready(), "consented loaded ad becomes available")
	backend.consent_busy = true
	check(not backend.is_rewarded_ready(), "privacy form blocks loaded ads")
	backend.invalidate_ads()
	check(ad.destroyed == 1 and backend.rewarded == null and backend.generation == 1, "changing choices destroys old ads and invalidates pending callbacks")
	backend.consent_busy = false
	ad = FakeRewarded.new()
	backend.rewarded = ad
	result.clear()
	backend.show_rewarded(func(ok: bool): result.append(ok))
	ad.listener.on_user_earned_reward.call(null)
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content.call()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content.call(null)
	check(result == [true] and ad.destroyed == 1, "duplicate terminal callbacks cannot pay twice")
	ad.full_screen_content_callback = FullScreenContentCallback.new()
	ad.listener = null
	backend.free()
	if Engine.is_editor_hint():
		var exporter := EditorExportPlatformAndroid.new()
		var preset := exporter.create_preset()
		preset.set("gradle_build/export_format", 1)
		preset.set("gradle_build/target_sdk", "36")
		check(preset.get("gradle_build/export_format") == 1 and preset.get("gradle_build/target_sdk") == "36", "installed exporter supports AAB and API 36")
	print("PRIVACY CHECKS: ", failures, " failures")
	quit(0 if failures == 0 else 1)
