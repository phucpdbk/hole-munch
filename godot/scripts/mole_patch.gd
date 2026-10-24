extends Node3D

# Daily mini-game "mole" (daily_games.gd), whack-a-mole in a vegetable patch
# (theme_maps.gd): HILLS mole hills dot the dirt paths, and moles pop out of
# the ones near the hole for a moment, then duck back down. Swallow one while it is up: a brown mole is
# worth 1, a golden one GOLD_POINTS (up for less time). Now and then a gas
# bomb pops up instead (mechanics.gd stuns the hole on a bite). Each catch
# shortens how long the next moles stay up, and more pop up at once.
const I18n = preload("res://scripts/i18n.gd")
const HILLS := 16
const MOLES := 4
const BOMBS := 2
const MOLE_SIZE := 0.55
const GOLD_POINTS := 3
const GOLD_CHANCE := 0.15
const BOMB_CHANCE := 0.12
const UP_TIME := Vector2(3.0, 1.3)
const UP_STEP := 0.08
const RISE := 0.2
const GOLD_UP := 0.7
const POP_GAP := Vector2(0.5, 1.1)
# Moles pop out of mole hills this far from the hole, so one is always in reach.
const REACH := Vector2(3.5, 14.0)
const SPACING := 5.0

var spots: Array[Vector3] = []
var lids: Array[MeshInstance3D] = []
var moles: Array = []
var bombs: Array = []
var catches := 0
var missed := 0
var next_pop := 0.0
var rng := RandomNumberGenerator.new()

func build(game, seed_value: int) -> void:
	moles.clear()
	bombs.clear()
	spots.clear()
	rng.seed = seed_value
	for i in HILLS:
		var at: Vector3 = game.daily.road_spot(game, 4.0)
		for attempt in 16:
			if spots.all(func(other): return other.distance_to(at) >= SPACING): break
			at = game.daily.road_spot(game, 4.0)
		spots.append(at)
	for i in MOLES:
		var mole: Dictionary = game.add_item("mole", game.SPAWN, MOLE_SIZE, 0)
		mole.prey = true
		moles.append(mole)
	# Golden moles are their own items: a variant has its own model batch.
	var gold: Dictionary = game.add_item("mole", game.SPAWN, MOLE_SIZE, 1)
	gold.prey = true
	gold.value = GOLD_POINTS
	moles.append(gold)
	for i in BOMBS:
		var bomb: Dictionary = game.add_item("bomb", game.SPAWN, game.Mechanics.BOMB_SIZE)
		bomb.bomb = true
		bombs.append(bomb)
	make_lids()

# A mole hill on every spot: a mound of fresh dirt round a dark burrow.
func make_lids() -> void:
	for lid in lids: lid.queue_free()
	lids.clear()
	var mound := CylinderMesh.new()
	mound.top_radius = 0.62
	mound.bottom_radius = 1.0
	mound.height = 0.28
	mound.radial_segments = 14
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("a8784a")
	var hole := CylinderMesh.new()
	hole.top_radius = 0.5
	hole.bottom_radius = 0.5
	hole.height = 0.02
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2b1d14")
	var clod := SphereMesh.new()
	clod.radius = 0.12
	clod.height = 0.2
	for at in spots:
		var lid := MeshInstance3D.new()
		lid.mesh = mound
		lid.material_override = dirt
		lid.position = Vector3(at.x, 0.3, at.z)
		var burrow := MeshInstance3D.new()
		burrow.mesh = hole
		burrow.material_override = dark
		burrow.position.y = 0.15
		lid.add_child(burrow)
		for i in 3:
			var lump := MeshInstance3D.new()
			lump.mesh = clod
			lump.material_override = dirt
			var angle := i*2.1 + at.x
			lump.position = Vector3(cos(angle)*1.15, -0.1, sin(angle)*1.15)
			lid.add_child(lump)
		add_child(lid)
		lids.append(lid)

func reset(game) -> void:
	catches = 0
	missed = 0
	next_pop = 0.6
	for lid in lids: lid.visible = true
	for item in moles + bombs: park(game, item)

func clear() -> void:
	for lid in lids: lid.visible = false

func park(game, item: Dictionary) -> void:
	item.hidden = true
	item.eaten = false
	item.fall = -1.0
	item.up = 0.0
	item.spot = -1
	game.set_item_transform(item)

func up_time() -> float:
	return maxf(UP_TIME.y, UP_TIME.x - catches*UP_STEP)

# How many may be up at once: two, and a third after 10 catches.
func crowd() -> int:
	return mini(3, 2 + catches/10)

func update(game, dt: float) -> void:
	next_pop -= dt
	var showing := 0
	for item in moles + bombs:
		if item.eaten:
			park(game, item)
			continue
		if item.hidden or item.fall >= 0: continue
		showing += 1
		item.up -= dt
		var left: float = item.up
		var at: Vector3 = spots[item.spot]
		# Pops up over RISE, bobs, and sinks back down over the last part.
		var lift := clampf((item.total - left)/RISE, 0.0, 1.0)*clampf(left/0.25, 0.0, 1.0)
		item.position = Vector3(at.x, lerpf(-0.6, 0.34, lift) + sin(left*9.0)*0.03, at.z)
		item.yaw += dt*(2.5 if item.get("bomb", false) else 0.8)
		if left <= 0:
			if item.get("prey", false):
				missed += 1
				game.add_floater(at, I18n.t("mole_missed"), false)
			park(game, item)
			continue
		game.set_item_transform(item)
	if next_pop > 0 or showing >= crowd() or not game.started: return
	next_pop = rng.randf_range(POP_GAP.x, POP_GAP.y)
	var roll := rng.randf()
	var pool: Array = bombs if roll < BOMB_CHANCE else [moles[-1]] if roll < BOMB_CHANCE + GOLD_CHANCE else moles.slice(0, MOLES)
	pop(game, pool)

# Pops the first parked item of the pool out of a free manhole near the hole.
func pop(game, pool: Array) -> void:
	var item: Dictionary = {}
	for candidate in pool:
		if candidate.hidden and candidate.fall < 0: item = candidate
	if item.is_empty(): return
	var used: Array = (moles + bombs).filter(func(other): return not other.hidden).map(func(other): return other.spot)
	var free: Array = []
	for i in spots.size():
		var gap := Vector2(spots[i].x - game.hole_position.x, spots[i].z - game.hole_position.z).length()
		if not i in used and gap >= REACH.x and gap <= REACH.y: free.append(i)
	if free.is_empty():
		for i in spots.size():
			if not i in used: free.append(i)
	if free.is_empty(): return
	item.spot = free[rng.randi() % free.size()]
	var time := up_time()*(GOLD_UP if item.get("value", 1) > 1 else 1.0)
	item.up = time
	item.total = time
	item.hidden = false
	item.position = Vector3(spots[item.spot].x, -0.6, spots[item.spot].z)
	game.fx.puff(Vector3(spots[item.spot].x, 0.2, spots[item.spot].z), 0.5, 1.0)
	game.set_item_transform(item)

func caught(game, item: Dictionary) -> int:
	if not item in moles: return 0
	catches += 1
	var value := int(item.get("value", 1))
	game.add_floater(item.position, I18n.t("mole_gold", value) if value > 1 else "+1", true)
	game.sfx.play("grow")
	return value

func dots() -> Array:
	var list: Array = []
	for mole in moles:
		if not mole.hidden and mole.fall < 0 and not mole.eaten: list.append(Vector2(mole.position.x, mole.position.z))
	return list
