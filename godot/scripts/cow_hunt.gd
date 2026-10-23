extends RefCounted

# Daily mini-game "findcow" (daily_games.gd): a herd of cows spread over the
# farmland (countryside.gd), each with a coat, a hat and a bell, and one of
# them, the named cow, is the one to swallow. Each find starts with a card of
# that cow's look (MEMO_TIME, shown again for a moment after a wrong bite);
# then a warm/cold bar and a bell that rings faster tell how close it is. A
# wrong bite costs WRONG_TIME and a short chew; MAX_WRONG of them end the
# round. Every find raises the level: more of the herd joins (8 + HERD_STEP a
# level) and the named cow shares more of its look with the others. The run
# goes on until the clock or the wrong bites run out; the level reached is
# kept (Campaign.checkpoint "findcow") and the next run starts there.
const I18n = preload("res://scripts/i18n.gd")
const Traffic = preload("res://scripts/traffic.gd")
const HERD := 36
const HERD_START := 8
const HERD_STEP := 4
# Under the small hole's reach (0.81), which never grows in the hunt.
const COW_SIZE := 0.7
const SPACING := 3.2
const COATS := [["f4f1ea", "2b2b30"], ["a0623a", "e8d2b4"], ["f2c46b", "a0623a"]]
const HATS := ["none", "straw", "flowers"]
const BELLS := ["e63946", "3a7bd5", "ffd23f"]
const LOOKS := 27
const NAMES := ["David", "Bella", "Mochi", "Daisy", "Lulu", "Max", "Bông", "Mít", "Luna", "Oscar", "Coco", "Kiki", "Rosa", "Bruno", "Nala", "Tèo"]
const MEMO_TIME := 3.0
const MEMO_AGAIN := 1.5
const FOUND_TIME := 10.0
const WRONG_TIME := 3.0
const CHEW := 0.6
const MAX_WRONG := 5
# The level where the named cow is as alike to the herd as it gets.
const HARDEST := 6
const LEVEL_MAX := 30
const RADAR_RANGE := 22.0
const BELL_SLOW := 1.4
const BELL_FAST := 0.18
const STAR_FINDS := [1, 2, 4]
# Cows graze this far inside the hole's reach, so every one can be swallowed.
const EDGE := 1.5

var cows: Array = []
var star: Dictionary = {}
var star_name := ""
var level := 0
var first_level := 0
var finds := 0
var wrong := 0
var chew := 0.0
var memo := 0.0
var bell_clock := 0.0
var rng := RandomNumberGenerator.new()

static func look(coat: int, hat: int, bell: int) -> int:
	return coat*HATS.size()*BELLS.size() + hat*BELLS.size() + bell

# --- setup -----------------------------------------------------------------------

func build(game, seed_rng: RandomNumberGenerator, spot: Callable) -> void:
	cows.clear()
	rng.seed = seed_rng.randi()
	var taken: Array[Vector3] = []
	var limit := Vector2(game.layout.move_x, game.layout.move_z) - Vector2.ONE*EDGE
	var pick := func() -> Vector3:
		var at: Vector3 = spot.call()
		return Vector3(clampf(at.x, -limit.x, limit.x), at.y, clampf(at.z, -limit.y, limit.y))
	# Roadblocks push a small hole back, so no cow grazes beside one.
	var blocks: Array = game.features.barriers.map(func(barrier): return barrier.origin)
	var clear := func(at: Vector3) -> bool:
		return taken.all(func(other): return other.distance_to(at) >= SPACING) and blocks.all(func(block): return block.distance_to(at) >= SPACING)
	for i in HERD:
		var at: Vector3 = pick.call()
		for attempt in 16:
			if clear.call(at): break
			at = pick.call()
		taken.append(at)
		# Every look once before any repeats, in a shuffled order.
		var variant := (i*11 + rng.randi_range(0, 2)) % LOOKS
		var cow: Dictionary = game.add_item("huntcow", at, COW_SIZE, variant, rng.randf_range(0, TAU))
		cow.prey = true
		cow.optional = true
		cow.coat = variant/(HATS.size()*BELLS.size())
		cow.hat = variant/BELLS.size() % HATS.size()
		cow.bell = variant % BELLS.size()
		Traffic.make_walker(cow, Vector2(0.25, 0.15), 0.15, rng.randf_range(0, TAU))
		cows.append(cow)

func reset(game, start_level := 0) -> void:
	first_level = clampi(start_level, 0, LEVEL_MAX)
	finds = 0
	wrong = 0
	chew = 0.0
	bell_clock = 0.0
	for cow in cows:
		cow.hidden = false
		cow.eaten = false
	begin_level(game, first_level)

# Shows the level's share of the herd and picks the named cow: a look nobody
# else on show has, sharing more of it with the others the higher the level.
func begin_level(game, value: int) -> void:
	level = value
	var show := mini(HERD, HERD_START + level*HERD_STEP)
	var standing: Array = cows.filter(func(cow): return not cow.eaten)
	for i in standing.size():
		standing[i].hidden = i >= show
		game.set_item_transform(standing[i])
	var visible: Array = standing.filter(func(cow): return not cow.hidden)
	var far: Array = visible.filter(func(cow): return Vector2(cow.position.x - game.hole_position.x, cow.position.z - game.hole_position.z).length() > 8.0)
	var pool: Array = far if not far.is_empty() else visible
	pool.sort_custom(func(a, b): return alike(a, visible) < alike(b, visible))
	var pick := roundi(float(mini(level, HARDEST))/HARDEST*(pool.size() - 1))
	star = pool[pick]
	for cow in visible:
		if cow != star and cow.variant == star.variant:
			cow.hidden = true
			game.set_item_transform(cow)
	star_name = NAMES[rng.randi_range(0, NAMES.size() - 1)]
	memo = MEMO_TIME

# Cows on show that share two of the three features with this one.
func alike(cow: Dictionary, herd: Array) -> int:
	var total := 0
	for other in herd:
		if other == cow: continue
		var same := int(other.coat == cow.coat) + int(other.hat == cow.hat) + int(other.bell == cow.bell)
		if same >= 2: total += 1
	return total

# --- round -------------------------------------------------------------------------

func update(game, dt: float) -> void:
	chew = maxf(0.0, chew - dt)
	if game.started: memo = maxf(0.0, memo - dt)
	if star.is_empty() or not game.started: return
	# The bell rings faster the warmer the hunt.
	bell_clock -= dt
	if bell_clock <= 0.0:
		bell_clock = lerpf(BELL_SLOW, BELL_FAST, warmth(game))
		game.sfx.play("tick", 0.6 + warmth(game)*0.8)

# 0 far away, 1 right on the named cow.
func warmth(game) -> float:
	if star.is_empty() or star.eaten: return 0.0
	var gap := Vector2(star.position.x - game.hole_position.x, star.position.z - game.hole_position.z).length()
	return clampf(1.0 - gap/RADAR_RANGE, 0.0, 1.0)

func caught(game, item: Dictionary) -> void:
	if item.kind != "huntcow": return
	if item == star:
		finds += 1
		game.add_floater(item.position, I18n.t("cow_found", star_name), true)
		game.sfx.play("grow")
		game.remaining += FOUND_TIME
		if game.campaign.reach_checkpoint("findcow", level + 1, LEVEL_MAX): game.persist()
		begin_level(game, mini(level + 1, LEVEL_MAX))
		return
	wrong += 1
	chew = CHEW
	memo = MEMO_AGAIN
	game.remaining = maxf(0.0, game.remaining - WRONG_TIME)
	game.add_floater(item.position, I18n.t("cow_wrong", int(WRONG_TIME)), false)

# Movement while chewing a wrong cow.
func speed_scale() -> float:
	return 0.3 if chew > 0.0 else 1.0

func done() -> bool:
	return wrong >= MAX_WRONG

# The HUD's line: who to find, at which level.
func note() -> String:
	return I18n.t("cow_hunt_note", [star_name, level + 1])

# The card of the named cow's look, while it shows.
func card() -> Dictionary:
	if memo <= 0.0 or star.is_empty(): return {}
	return {"name":star_name, "coat":star.coat, "hat":star.hat, "bell":star.bell, "fade":minf(1.0, memo/0.3)}

func stars() -> int:
	var total := 0
	for need in STAR_FINDS:
		if finds >= need: total += 1
	return total

func goal_labels() -> Array:
	return STAR_FINDS.map(func(need): return I18n.t("cow_goal_finds", need))

func reward(coin_mul: float) -> int:
	return roundi(maxi(0, finds*40 + level*5 - wrong*5)*coin_mul)

# --- model ---------------------------------------------------------------------------

# A toy cow facing +z: coat, hat and bell by variant (look()).
static func parts(m, variant: int) -> Array:
	var coat: Array = COATS[variant/(HATS.size()*BELLS.size()) % COATS.size()]
	var hat: String = HATS[variant/BELLS.size() % HATS.size()]
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
	# A big bell and hat that read from the camera.
	parts.append(m.piece("ball", Vector3(0, 0.4, 0.66), Vector3.ONE*0.15, bell))
	match hat:
		"straw":
			parts.append(m.piece("cyl", Vector3(0, 0.9, 0.56), Vector3(0.36, 0.04, 0.36), Color("e8c56a")))
			parts.append(m.piece("cyl", Vector3(0, 0.99, 0.56), Vector3(0.18, 0.14, 0.18), Color("e8c56a")))
			parts.append(m.piece("cyl", Vector3(0, 0.95, 0.56), Vector3(0.19, 0.04, 0.19), Color("c0392b")))
		"flowers":
			for i in 5:
				var a := i*TAU/5.0
				parts.append(m.piece("ball", Vector3(cos(a)*0.17, 0.92, 0.56 + sin(a)*0.17), Vector3.ONE*0.09, Color(["ff8fc8", "ffd23f", "ffffff", "c39bff", "ff8fc8"][i])))
	return parts
