extends RefCounted

# Daily mini-game "findcow" (daily_games.gd): a herd of cows spread over the
# farmland (countryside.gd) and one of them, today's named cow, is the one to
# swallow. Clues open one by one: its bell colour from the start, then its coat,
# then the zone it grazes in (one more every CLUE_EVERY seconds, and one after
# each wrong bite). A name tag over the nearest cow turns green when the cow fits
# every open clue. Wrong bites cost time and a chewing pause, so swallowing the whole herd
# never pays; MAX_WRONG of them ends the round. Close to a cow, its name shows.
const I18n = preload("res://scripts/i18n.gd")
const Traffic = preload("res://scripts/traffic.gd")
const COWS := 80
# Under the small hole's reach (0.81), which never grows in the hunt.
const COW_SIZE := 0.7
const SPACING := 3.2
const BELLS := ["e63946", "3a7bd5", "ffd23f", "2fa86b"]
const COATS := [["f4f1ea", "2b2b30"], ["a0623a", "e8d2b4"]]
const NAMES := ["David", "Bella", "Mochi", "Daisy", "Lulu", "Max", "Bông", "Mít", "Luna", "Oscar", "Coco", "Kiki", "Rosa", "Bruno", "Nala", "Tèo"]
const CLUE_EVERY := 15.0
const WRONG_TIME := 3.0
const CHEW := 1.2
const MAX_WRONG := 5
const NAME_RANGE := 3.5
# Cows graze this far inside the hole's reach, so every one can be swallowed.
const EDGE := 1.5

var cows: Array = []
var star: Dictionary = {}
var star_name := ""
var clues := 1
var wrong := 0
var found := false
var chew := 0.0
var clock := 0.0
var label: Label3D
# The zone a spot belongs to: Countryside.zone ("forest"...) or quarter ("north"...).
var zone_of: Callable = func(at: Vector3) -> String: return quarter(at)

# --- setup -----------------------------------------------------------------------

func build(game, rng: RandomNumberGenerator, spot: Callable) -> void:
	cows.clear()
	var taken: Array[Vector3] = []
	var limit := Vector2(game.layout.move_x, game.layout.move_z) - Vector2.ONE*EDGE
	var pick := func() -> Vector3:
		var at: Vector3 = spot.call()
		return Vector3(clampf(at.x, -limit.x, limit.x), at.y, clampf(at.z, -limit.y, limit.y))
	# Roadblocks push a small hole back, so no cow grazes beside one.
	var blocks: Array = game.features.barriers.map(func(barrier): return barrier.origin)
	var clear := func(at: Vector3) -> bool:
		return taken.all(func(other): return other.distance_to(at) >= SPACING) and blocks.all(func(block): return block.distance_to(at) >= SPACING)
	for i in COWS:
		var at: Vector3 = pick.call()
		for attempt in 16:
			if clear.call(at): break
			at = pick.call()
		taken.append(at)
		var bell := rng.randi_range(0, BELLS.size() - 1)
		var coat := rng.randi_range(0, COATS.size() - 1)
		var cow: Dictionary = game.add_item("huntcow", at, COW_SIZE, coat*BELLS.size() + bell, rng.randf_range(0, TAU))
		cow.prey = true
		cow.optional = true
		cow.bell = bell
		cow.coat = coat
		cow.cow_name = NAMES[1 + rng.randi_range(0, NAMES.size() - 2)]
		Traffic.make_walker(cow, Vector2(0.25, 0.15), 0.15, rng.randf_range(0, TAU))
		cows.append(cow)
	# Today's cow, far from the drop point; nobody else matches all three clues.
	var far := cows.filter(func(cow): return cow.origin.distance_to(game.SPAWN) > 12.0)
	star = (far if not far.is_empty() else cows)[rng.randi() % (far if not far.is_empty() else cows).size()]
	star_name = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	star.cow_name = star_name
	for cow in cows:
		if cow == star: continue
		if cow.cow_name == star_name: cow.cow_name = NAMES[(NAMES.find(star_name) + 1) % NAMES.size()]
		if cow.bell == star.bell and cow.coat == star.coat and zone_of.call(cow.origin) == zone_of.call(star.origin):
			cow.bell = (cow.bell + 1) % BELLS.size()
			cow.variant = cow.coat*BELLS.size() + cow.bell
			cow.batch = "huntcow" + str(cow.variant)
	if not is_instance_valid(label):
		label = Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 96
		label.outline_size = 24
		label.pixel_size = 0.012
		label.no_depth_test = true
	if label.get_parent() != game.world: game.world.add_child(label)
	label.visible = false

func reset() -> void:
	clues = 1
	wrong = 0
	found = false
	chew = 0.0
	clock = 0.0
	if is_instance_valid(label): label.visible = false

# The part of town a spot lies in, by its larger offset from the plaza.
static func quarter(at: Vector3) -> String:
	if absf(at.x) >= absf(at.z): return "east" if at.x > 0 else "west"
	return "south" if at.z > 0 else "north"

# --- round -------------------------------------------------------------------------

func update(game, dt: float) -> void:
	clock += dt
	chew = maxf(0.0, chew - dt)
	clues = maxi(clues, mini(3, 1 + int(clock/CLUE_EVERY)))
	# The nearest cow within reach shows its name tag.
	var nearest: Dictionary = {}
	var best: float = NAME_RANGE + game.radius
	for cow in cows:
		if not Traffic.is_active(cow): continue
		var gap := Vector2(cow.position.x - game.hole_position.x, cow.position.z - game.hole_position.z).length()
		if gap < best:
			best = gap
			nearest = cow
	label.visible = not nearest.is_empty()
	if label.visible:
		label.text = nearest.cow_name
		label.position = nearest.position + Vector3(0, 1.6, 0)
		label.modulate = Color("7dff9a") if fits(nearest) else Color("f2f2f2")

# Whether a cow matches every clue open so far.
func fits(cow: Dictionary) -> bool:
	if cow.bell != star.bell: return false
	if clues >= 2 and cow.coat != star.coat: return false
	return clues < 3 or zone_of.call(cow.origin) == zone_of.call(star.origin)

func caught(game, item: Dictionary) -> void:
	if item.kind != "huntcow": return
	if item == star:
		found = true
		game.add_floater(item.position, I18n.t("cow_found", star_name), true)
		game.sfx.play("grow")
		return
	wrong += 1
	chew = CHEW
	clues = mini(3, clues + 1)
	game.remaining = maxf(0.0, game.remaining - WRONG_TIME)
	game.add_floater(item.position, I18n.t("cow_wrong", [item.cow_name, int(WRONG_TIME)]), false)

# Movement while chewing a wrong cow.
func speed_scale() -> float:
	return 0.15 if chew > 0.0 else 1.0

func done() -> bool:
	return found or wrong >= MAX_WRONG

# The open clues, for the HUD's note line.
func note() -> String:
	var parts: Array = [I18n.t("cow_bell_" + str(star.bell))]
	if clues >= 2: parts.append(I18n.t("cow_coat_" + str(star.coat)))
	if clues >= 3: parts.append(I18n.t("cow_" + zone_of.call(star.origin)))
	else: parts.append(I18n.t("cow_next", ceili(CLUE_EVERY*clues - clock)))
	return I18n.t("cow_clues", [star_name, " · ".join(parts)])

func stars() -> int:
	if not found: return 0
	return 3 if wrong <= 1 else 2 if wrong <= 3 else 1

func goal_labels() -> Array:
	return [I18n.t("cow_goal_find", star_name), I18n.t("cow_goal_wrong", 3), I18n.t("cow_goal_wrong", 1)]

func reward(coin_mul: float) -> int:
	return roundi((maxi(30, 120 - wrong*15) if found else wrong*4)*coin_mul)

# --- model ---------------------------------------------------------------------------

# A toy cow facing +z: coat colours and bell by variant (coat*4 + bell).
static func parts(m, variant: int) -> Array:
	var coat: Array = COATS[variant/BELLS.size() % COATS.size()]
	var bell := Color(BELLS[variant % BELLS.size()])
	var main := Color(coat[0])
	var patch := Color(coat[1])
	var parts: Array = []
	parts.append(m.piece("box", Vector3(0, 0.5, 0), Vector3(0.55, 0.42, 0.95), main))
	parts.append(m.piece("box", Vector3(0.18, 0.62, -0.1), Vector3(0.2, 0.2, 0.3), patch))
	parts.append(m.piece("box", Vector3(-0.2, 0.5, 0.22), Vector3(0.18, 0.24, 0.24), patch))
	parts.append(m.piece("box", Vector3(0, 0.7, 0.58), Vector3(0.36, 0.34, 0.34), main))
	parts.append(m.piece("box", Vector3(0, 0.62, 0.77), Vector3(0.3, 0.16, 0.08), Color("f2b8b8")))
	for side in [-1, 1]:
		parts.append(m.piece("box", Vector3(side*0.15, 0.92, 0.55), Vector3(0.06, 0.12, 0.06), Color("e8d9a8")))
		for end in [-0.3, 0.3]:
			parts.append(m.piece("box", Vector3(side*0.18, 0.15, end), Vector3(0.12, 0.3, 0.12), patch.darkened(0.2)))
	parts.append(m.piece("ball", Vector3(0, 0.42, 0.62), Vector3.ONE*0.09, bell))
	return parts
