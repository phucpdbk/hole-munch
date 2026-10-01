extends Node

# AdMob bridge for ads.gd (Poing Studios plugin in res://addons/admob). Loaded
# only on Android, so desktop runs and headless tests never touch the SDK.
# Unit IDs are Google's public test units; replace them with your own AdMob
# units (and the app ID in Project Settings → admob/general/android/app_id)
# before publishing, and never tap your own live ads.
const REWARDED_UNIT := "ca-app-pub-3940256099942544/5224354917"
const INTERSTITIAL_UNIT := "ca-app-pub-3940256099942544/1033173712"
const RETRY_SECONDS := 30.0

var rewarded: RewardedAd
var interstitial: InterstitialAd
var rewarded_loader := RewardedAdLoader.new()
var interstitial_loader := InterstitialAdLoader.new()
var initialized := false

func _ready() -> void:
	request_consent()

# GDPR/CCPA: ask the User Messaging Platform first, then start the SDK either way.
func request_consent() -> void:
	var info: ConsentInformation = UserMessagingPlatform.consent_information
	info.update(ConsentRequestParameters.new(), func() -> void:
		if info.get_is_consent_form_available() and info.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
			UserMessagingPlatform.load_consent_form(
				func(form: ConsentForm) -> void: form.show(func(_error: FormError) -> void: initialize()),
				func(_error: FormError) -> void: initialize())
		else:
			initialize(),
		func(_error: FormError) -> void: initialize())

func initialize() -> void:
	if initialized: return
	initialized = true
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		load_rewarded()
		load_interstitial()
	MobileAds.initialize(listener)

func retry(loader: Callable) -> void:
	get_tree().create_timer(RETRY_SECONDS).timeout.connect(loader)

func load_rewarded() -> void:
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void: rewarded = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void: retry(load_rewarded)
	rewarded_loader.load(REWARDED_UNIT, AdRequest.new(), callback)

func load_interstitial() -> void:
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void: interstitial = ad
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void: retry(load_interstitial)
	interstitial_loader.load(INTERSTITIAL_UNIT, AdRequest.new(), callback)

func is_rewarded_ready() -> bool:
	return rewarded != null

func is_interstitial_ready() -> bool:
	return interstitial != null

# done(granted) runs once, after the ad closes or fails to show.
func show_rewarded(done: Callable) -> void:
	var ad := rewarded
	rewarded = null
	var earned := [false]
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		load_rewarded()
		done.call(earned[0])
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		ad.destroy()
		load_rewarded()
		done.call(false)
	ad.full_screen_content_callback = callbacks
	var reward := OnUserEarnedRewardListener.new()
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void: earned[0] = true
	ad.show(reward)

func show_interstitial() -> void:
	var ad := interstitial
	interstitial = null
	var callbacks := FullScreenContentCallback.new()
	var finish := func() -> void:
		ad.destroy()
		load_interstitial()
	callbacks.on_ad_dismissed_full_screen_content = finish
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: finish.call()
	ad.full_screen_content_callback = callbacks
	ad.show()
