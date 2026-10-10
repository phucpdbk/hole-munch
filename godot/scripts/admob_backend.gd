extends Node

# Android only. Release IDs are injected at export; debug always uses test ads.
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const RETRY_SECONDS := 30.0
var rewarded: RewardedAd
var interstitial: InterstitialAd
var rewarded_loader := RewardedAdLoader.new()
var interstitial_loader := InterstitialAdLoader.new()
var initialized := false
var sdk_ready := false
var consent_updated := false
var consent_busy := false
var generation := 0
var rewarded_loading := false
var interstitial_loading := false

func _ready() -> void:
	request_consent()

func request_consent() -> void:
	if consent_busy: return
	consent_busy = true
	consent_updated = false
	invalidate_ads()
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	info.update(ConsentRequestParameters.new(), func() -> void:
		consent_updated = true
		if info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
			if not info.get_is_consent_form_available():
				finish_consent()
				return
			UserMessagingPlatform.load_consent_form(
				func(form: ConsentForm) -> void: form.show(func(_error: FormError) -> void: finish_consent()),
				func(_error: FormError) -> void: finish_consent())
		else:
			finish_consent(),
		func(_error: FormError) -> void: finish_consent())

func finish_consent() -> void:
	consent_busy = false
	if not can_request_ads(): return
	if sdk_ready:
		load_rewarded()
		load_interstitial()
	else:
		initialize()

func can_request_ads() -> bool:
	if consent_busy: return false
	var native = ConsentInformation._plugin
	if native and native.has_method("can_request_ads"):
		return native.call("can_request_ads")
	# Plugin 5.1 does not expose UMP canRequestAds. Fail closed on refresh
	# failure, using only a fresh status from UMP, never our own saved consent.
	return consent_allows_ads(consent_updated, UserMessagingPlatform.consent_information.get_consent_status())

static func consent_allows_ads(fresh: bool, status: int) -> bool:
	return fresh and status in [ConsentInformation.ConsentStatus.NOT_REQUIRED, ConsentInformation.ConsentStatus.OBTAINED]

func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED

func show_privacy_options() -> void:
	if consent_busy or not privacy_options_required(): return
	consent_busy = true
	invalidate_ads()
	UserMessagingPlatform.show_privacy_options_form(func(_error: FormError) -> void: finish_consent())

func invalidate_ads() -> void:
	generation += 1
	rewarded_loading = false
	interstitial_loading = false
	if rewarded != null: rewarded.destroy()
	if interstitial != null: interstitial.destroy()
	rewarded = null
	interstitial = null

func initialize() -> void:
	if initialized or not can_request_ads(): return
	initialized = true
	var configuration := RequestConfiguration.new()
	configuration.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_G
	MobileAds.set_request_configuration(configuration)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		sdk_ready = true
		load_rewarded()
		load_interstitial()
	MobileAds.initialize(listener)

func unit_id(kind: String) -> String:
	if OS.is_debug_build(): return TEST_REWARDED if kind == "rewarded" else TEST_INTERSTITIAL
	return str(ProjectSettings.get_setting("application_custom/ads/" + kind + "_unit", ""))

func retry(loader: Callable, ticket: int) -> void:
	get_tree().create_timer(RETRY_SECONDS).timeout.connect(func() -> void:
		if ticket == generation and can_request_ads(): loader.call())

func load_rewarded() -> void:
	if not sdk_ready or not can_request_ads() or rewarded_loading or rewarded != null: return
	var unit := unit_id("rewarded")
	if unit.is_empty(): return
	rewarded_loading = true
	var ticket := generation
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		if ticket != generation or not can_request_ads():
			ad.destroy()
			return
		rewarded_loading = false
		rewarded = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		if ticket != generation: return
		rewarded_loading = false
		retry(load_rewarded, ticket)
	rewarded_loader.load(unit, AdRequest.new(), callback)

func load_interstitial() -> void:
	if not sdk_ready or not can_request_ads() or interstitial_loading or interstitial != null: return
	var unit := unit_id("interstitial")
	if unit.is_empty(): return
	interstitial_loading = true
	var ticket := generation
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		if ticket != generation or not can_request_ads():
			ad.destroy()
			return
		interstitial_loading = false
		interstitial = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void:
		if ticket != generation: return
		interstitial_loading = false
		retry(load_interstitial, ticket)
	interstitial_loader.load(unit, AdRequest.new(), callback)

func is_rewarded_ready() -> bool:
	return can_request_ads() and rewarded != null

func is_interstitial_ready() -> bool:
	return can_request_ads() and interstitial != null

func show_rewarded(done: Callable) -> void:
	if not is_rewarded_ready():
		done.call(false)
		return
	var ad := rewarded
	rewarded = null
	var earned := [false]
	var completed := [false]
	var finish := func(granted: bool) -> void:
		if completed[0]: return
		completed[0] = true
		ad.destroy()
		load_rewarded()
		done.call(granted)
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void: finish.call(earned[0])
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: finish.call(false)
	ad.full_screen_content_callback = callbacks
	var reward := OnUserEarnedRewardListener.new()
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	ad.show(reward)

func show_interstitial() -> void:
	if not is_interstitial_ready(): return
	var ad := interstitial
	interstitial = null
	var completed := [false]
	var callbacks := FullScreenContentCallback.new()
	var finish := func() -> void:
		if completed[0]: return
		completed[0] = true
		ad.destroy()
		load_interstitial()
	callbacks.on_ad_dismissed_full_screen_content = finish
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: finish.call()
	ad.full_screen_content_callback = callbacks
	ad.show()
