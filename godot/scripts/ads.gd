extends Node

# Where ads may appear and how often. Ads follow the difficulty: rewarded ads
# are offered only when the player is stuck (time ran out close to the
# landmark) or has something worth doubling, and interstitials stay rare so a
# struggling player is not punished twice.
#
# `backend` is the bridge to a real ad SDK (AdMob plugin); it needs
# is_rewarded_ready(), show_rewarded(done: Callable) that calls done(granted),
# is_interstitial_ready() and show_interstitial(). Without one, debug builds
# simulate an instant rewarded ad so the flow can be played and tested, and
# release builds simply hide every ad offer.

# Time out with the hole at least this share of the way to the landmark:
# close enough that one more try feels worth watching an ad for.
const REVIVE_MIN_GROWTH := 0.6
const REVIVE_SECONDS := 15.0
# The offer declines itself after this many seconds.
const REVIVE_WINDOW := 6.0
# Interstitials: never in the first cities, at most one per few round ends and
# a few minutes, and never right after the player chose to watch a rewarded ad.
const INTERSTITIAL_FROM_LEVEL := 5
const INTERSTITIAL_EVERY := 3
const INTERSTITIAL_GAP_MS := 180000
const REWARDED_QUIET_MS := 120000

var backend: Object = null
var simulate := OS.is_debug_build()
var round_ends := 0
var last_interstitial_ms := -INTERSTITIAL_GAP_MS
var last_rewarded_ms := -REWARDED_QUIET_MS
var showing := false

# On Android the AdMob bridge takes over from the debug simulation. It is loaded
# by path so desktop runs and headless tests never parse the SDK wrappers.
func _ready() -> void:
	if OS.get_name() != "Android": return
	backend = load("res://scripts/admob_backend.gd").new()
	add_child(backend)
	simulate = false

func rewarded_ready() -> bool:
	if showing: return false
	if backend != null: return backend.is_rewarded_ready()
	return simulate

# Plays a rewarded ad; done(granted) runs once it closes.
func show_rewarded(done: Callable) -> void:
	if not rewarded_ready():
		done.call(false)
		return
	showing = true
	var finish := func(granted: bool):
		showing = false
		if granted: last_rewarded_ms = Time.get_ticks_msec()
		done.call(granted)
	if backend != null: backend.show_rewarded(finish)
	else: finish.call(true)

# A revive is a real rescue only when the landmark is nearly within reach.
static func revive_worth_offering(growth: float) -> bool:
	return growth >= REVIVE_MIN_GROWTH

func round_ended() -> void:
	round_ends += 1

# Called when the player leaves a result screen; returns true if an ad ran.
func maybe_interstitial(level_index: int) -> bool:
	if not interstitial_due(level_index, Time.get_ticks_msec()): return false
	if backend == null or not backend.is_interstitial_ready(): return false
	round_ends = 0
	last_interstitial_ms = Time.get_ticks_msec()
	backend.show_interstitial()
	return true

func interstitial_due(level_index: int, now_ms: int) -> bool:
	return level_index >= INTERSTITIAL_FROM_LEVEL and round_ends >= INTERSTITIAL_EVERY \
		and now_ms - last_interstitial_ms >= INTERSTITIAL_GAP_MS \
		and now_ms - last_rewarded_ms >= REWARDED_QUIET_MS
