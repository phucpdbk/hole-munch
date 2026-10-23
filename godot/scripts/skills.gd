extends RefCounted

# Saucer skills. Eating fills an energy bar; once it is full the player fires
# the skill of the saucer they fly (SKILL_OF follows Fleet.NAMES). Campaign and
# endless rounds only: daily mini-games, the bonus run and the cow hunt keep
# their own rules.
const I18n = preload("res://scripts/i18n.gd")

const KINDS := ["dash", "vacuum", "blink", "gulp", "freeze", "shield"]
const SKILL_OF := ["dash", "vacuum", "blink", "gulp", "freeze", "dash", "blink", "shield", "gulp", "vacuum", "shield", "gulp", "freeze"]
const COLORS := {
	"dash":Color("62ead3"), "vacuum":Color("c69bff"), "blink":Color("7cbcff"),
	"gulp":Color("ffb34c"), "freeze":Color("9fdcff"), "shield":Color("ffd35c"),
}
# HUD icon per skill (UiStyle.icon names).
const ICONS := {"dash":"bolt", "vacuum":"magnet", "blink":"next", "gulp":"food", "freeze":"snow", "shield":"shield"}
# The bar fills this many times over a whole map's food; a round eats about
# half the map, so two or three skills a round. Long combos charge faster and
# every hit drains a quarter.
const CHARGE_PER_MAP := 5.0
const COMBO_CHARGE_FROM := 8
const COMBO_CHARGE := 1.5
const HIT_DRAIN := 0.25
const DURATION := {"dash":1.6, "vacuum":4.0, "blink":0.0, "gulp":3.0, "freeze":4.0, "shield":5.0}
const DASH_SPEED := 2.0
# Magnet levels the vacuum adds on top of the upgrade.
const VACUUM_MAGNET := 8
# Gulp lets the hole eat one size up, never the landmark or boss.
const GULP_SCALE := 1.25
const BLINK_BASE := 6.0
const BLINK_PER_RADIUS := 1.5

var kind := "dash"
var energy := 0.0
# Seconds left of the running skill.
var active := 0.0
var enabled := false
var used := 0

static func skill_of(craft: int) -> String:
	return SKILL_OF[clampi(craft, 0, SKILL_OF.size()-1)]

func reset(craft: int, on: bool) -> void:
	kind = skill_of(craft)
	energy = 0.0
	active = 0.0
	used = 0
	enabled = on

# share: the bite's part of the whole map's food points. True on the bite
# that fills the bar.
func charge(share: float, combo: int) -> bool:
	if not enabled or energy >= 1.0: return false
	var rate := COMBO_CHARGE if combo >= COMBO_CHARGE_FROM else 1.0
	energy = minf(1.0, energy + share*CHARGE_PER_MAP*rate)
	return energy >= 1.0

func can_use() -> bool:
	return enabled and energy >= 1.0 and active <= 0.0

func running(name: String) -> bool:
	return active > 0.0 and kind == name

func update(dt: float) -> void:
	active = maxf(0.0, active - dt)

# A hit while the shield is up is absorbed (true); otherwise it drains energy.
func absorbs_hit() -> bool:
	if running("shield"): return true
	energy = maxf(0.0, energy - HIT_DRAIN)
	return false

func speed_multiplier() -> float:
	return DASH_SPEED if running("dash") else 1.0

func magnet_bonus() -> int:
	return VACUUM_MAGNET if running("vacuum") else 0

func eat_scale(item: Dictionary) -> float:
	return GULP_SCALE if running("gulp") and not item.get("is_boss", false) else 1.0

func frozen() -> bool:
	return running("freeze")

# Share of the running skill still left (HUD ring), 0 when none runs.
func active_share() -> float:
	var full: float = DURATION[kind]
	return active/full if full > 0.0 else 0.0

func use(game) -> bool:
	if not can_use(): return false
	energy = 0.0
	active = DURATION[kind]
	used += 1
	match kind:
		"blink": blink(game)
		"freeze": game.defense.grace = maxf(game.defense.grace, DURATION.freeze)
	game.add_floater(game.hole_position, I18n.t("skill_" + kind), true)
	game.fx.ripple(game.hole_position, game.radius*1.4, COLORS[kind])
	game.sfx.play("grow")
	return true

# Jumps ahead along the way the hole moves (or toward the camera's top when
# still); the map's own clamp keeps it on land and inside the city.
func blink(game) -> void:
	var direction := Vector3(game.hole_velocity.x, 0, game.hole_velocity.z)
	if direction.length() < 0.1:
		var forward: Vector3 = -game.camera.global_basis.z
		direction = Vector3(forward.x, 0, forward.z)
	if direction.length() < 0.01: direction = Vector3.FORWARD
	game.fx.puff(game.hole_position, game.radius, 1.0)
	var target: Vector3 = game.hole_position + direction.normalized()*(BLINK_BASE + game.radius*BLINK_PER_RADIUS)
	game.hole_position = game.layout.clamp_point(target)
