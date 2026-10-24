extends Node3D

# Daily mini-games, one per day (campaign.gd picks the type from the date):
#   stampede - mother ducks lead lines of ducklings; eat a line from its tail.
#   coinrain - coins rain down near the hole, with a few bombs mixed in.
#   goldrush - carry golden treasure to the bank ring, raced by a thieving rival.
#   findcow  - memorise a cow's look, then find it in the herd (cow_hunt.gd).
#   skyhop   - one-tap flight through gaps high above the city (sky_hop.gd).
#   slide    - a turn-based sliding puzzle on a block above the city (slide_puzzle.gd).
#   siege    - the saucer shoots down the army's air force (sky_siege.gd).
#   snake    - catch roaming pets to grow a line; monsters bite it (snake_trail.gd).
#   mole     - moles pop out of manholes for a moment: whack-a-mole (mole_patch.gd).
#   redlight - red light, green light: eat on green, stand still on red (red_light.gd).
#   beam     - beam toys up and drop each on the pad that wants it (beam_drop.gd).
# The landmark, its guardian and the defence squads sit the round out. game.gd
# owns the items; this node adds the game's own items when the city is built,
# moves them, counts catches and draws the shadows of falling coins.
const Traffic = preload("res://scripts/traffic.gd")
const I18n = preload("res://scripts/i18n.gd")
const CowHunt = preload("res://scripts/cow_hunt.gd")
const SkyHop = preload("res://scripts/sky_hop.gd")
const SlidePuzzle = preload("res://scripts/slide_puzzle.gd")
const SkySiege = preload("res://scripts/sky_siege.gd")
const SnakeTrail = preload("res://scripts/snake_trail.gd")
const MolePatch = preload("res://scripts/mole_patch.gd")
const RedLight = preload("res://scripts/red_light.gd")
const BeamDrop = preload("res://scripts/beam_drop.gd")
const SECONDS := {"stampede":45.0, "coinrain":45.0, "goldrush":60.0, "findcow":75.0, "skyhop":120.0, "slide":30.0, "siege":90.0, "snake":90.0, "mole":60.0, "redlight":75.0, "beam":90.0}
# The slide puzzle counts boards solved (its first star at 5); the siege counts
# its stages, so its target is clearing the first one. The puzzle's own board
# clock replaces SECONDS once a board is up.
const TARGET := {"stampede":30, "coinrain":24, "goldrush":30, "findcow":1, "skyhop":20, "slide":1, "siege":1, "snake":12, "mole":25, "redlight":30, "beam":12}
# Coins paid per catch (gold pays per value point, the sky hop per gap, the
# siege per enemy point plus a stage bonus); the slide puzzle pays a base,
# this per board solved and SLIDE_PAR_COINS per board solved in par.
const COIN_RATE := {"stampede":3, "coinrain":4, "goldrush":4, "findcow":1, "skyhop":5, "slide":6, "siege":3, "snake":5, "mole":3, "redlight":3, "beam":5}
const SLIDE_BASE_COINS := 15
const SLIDE_PAR_COINS := 4
const SIEGE_STAGE_COINS := 15
const ICON := {"stampede":"target", "coinrain":"coin", "goldrush":"chest", "findcow":"target", "skyhop":"star", "slide":"gem", "siege":"fire", "snake":"food", "mole":"bolt", "redlight":"clock", "beam":"magnet"}
const STAR_SHARES := [0.5, 1.0, 1.5]
# Duck families: a mother leads a line of ducklings. Each duckling eaten from
# the tail of an unbroken line scores one more than the last (1..5); a mother
# eaten after all her ducklings scores FAMILY_POINTS, one eaten early scores
# MOTHER_POINTS and scatters the line. Scattered ducklings and resting
# mothers sprint away from a nearby hole; a sprint is faster than the hole but
# short, so cornering a duck pays off.
const FAMILIES := 4
const CHICKS := 5
const MOTHER_SIZE := 0.6
const CHICK_SIZE := 0.32
const CHICK_GAP := 0.75
const CHICK_SPEED := 9.0
const WANDER_SPEED := 1.3
const MOTHER_DASH := 0.7
const MOTHER_POINTS := 2
const FAMILY_POINTS := 5
const DUCK_ALERT := 7.0
const DUCK_DASH := 0.55
const DUCK_REST := Vector2(0.8, 1.6)
const DUCK_SPEED := 8.0
# Coin rain: a pool of coins and bombs recycled as they are caught or expire.
const COINS := 16
const SKY_BOMBS := 4
const COIN_SIZE := 0.34
const COIN_EVERY := 0.5
const BOMB_EVERY := 3.5
const COIN_LIFE := 6.0
const DROP_HEIGHT := 14.0
const DROP_TIME := 1.0
const DROP_RANGE := 10.0
# Gold rush treasure: [variant, radius, value, count]. Swallowed gold is
# carried, slowing the hole (CARRY_SLOW a point, down to CARRY_FLOOR), until
# it is banked in the BANK_RADIUS ring on the plaza; the rival hole touching
# the player takes everything carried (a STEAL_COOLDOWN apart).
const GOLD := [[0, 0.32, 1, 20], [1, 0.55, 3, 7], [2, 0.75, 8, 3]]
# Mini-games whose hole (and the gold rival's) never grows; every prey above
# fits a starting hole (Campaign.START_RADIUS*EAT_RATIO ~ 0.8).
const FIXED_HOLE := ["stampede", "coinrain", "goldrush", "snake", "mole", "redlight", "beam"]
const BANK_RADIUS := 2.6
const CARRY_SLOW := 0.04
const CARRY_FLOOR := 0.5
const STEAL_COOLDOWN := 2.0

var kind := ""
var count := 0
var clock := 0.0
var rng := RandomNumberGenerator.new()
var seed_value := 0
var prey: Array = []
var sky: Array = []
var next_coin := 0.0
var next_bomb := 0.0
var markers: Array[MeshInstance3D] = []
var hunt := CowHunt.new()
# Duck families: [{mother, chicks (in line order), chain, scattered}].
var families: Array = []
# Gold carried but not banked yet, and the bank ring's nodes.
var carried := 0
var steal_wait := 0.0
var bank: Node3D
var hop := SkyHop.new()
var puzzle := SlidePuzzle.new()
var siege := SkySiege.new()
var snake := SnakeTrail.new()
var moles := MolePatch.new()
var light := RedLight.new()
var beam := BeamDrop.new()

func _ready() -> void:
	var shadow := StandardMaterial3D.new()
	shadow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow.albedo_color = Color(0.05, 0.03, 0.12, 0.4)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	disc.radial_segments = 20
	for i in COINS + SKY_BOMBS:
		var marker := MeshInstance3D.new()
		marker.mesh = disc
		marker.material_override = shadow
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.visible = false
		add_child(marker)
		markers.append(marker)
	add_child(hop)
	hop.visible = false
	add_child(puzzle)
	puzzle.visible = false
	add_child(siege)
	add_child(snake)
	add_child(moles)
	add_child(light)
	add_child(beam)

static func title(type: String) -> String:
	return I18n.t("dg_" + type)

static func goal_line(type: String) -> String:
	if type in ["findcow", "slide", "siege"]: return I18n.t("dgoal_" + type)
	return I18n.t("dgoal_" + type, TARGET[type])

func target() -> int:
	return TARGET.get(kind, 1)

# --- city setup (game.gd load_level, before the batches are built) ---------------

func build(game, type: String, value: int) -> void:
	kind = type
	seed_value = value
	prey.clear()
	sky.clear()
	rng.seed = value
	match kind:
		"stampede":
			families.clear()
			for f in FAMILIES:
				var at := road_spot(game, 6.0)
				var mother: Dictionary = game.add_item("duck", at, MOTHER_SIZE, 0, rng.randf_range(0, TAU))
				mother.prey = true
				mother.family = f
				prey.append(mother)
				var family := {"mother":mother, "chicks":[], "chain":0, "scattered":false}
				for c in CHICKS:
					var chick: Dictionary = game.add_item("duck", at + Vector3(0, 0, (c + 1)*CHICK_GAP), CHICK_SIZE, 0, mother.yaw)
					chick.prey = true
					chick.family = f
					chick.chick = true
					prey.append(chick)
					family.chicks.append(chick)
				families.append(family)
		"coinrain":
			for i in COINS + SKY_BOMBS:
				var bomb := i >= COINS
				var drop: Dictionary = game.add_item("bomb" if bomb else "coin", game.SPAWN, game.Mechanics.BOMB_SIZE if bomb else COIN_SIZE)
				if bomb: drop.bomb = true
				else: drop.prey = true
				sky.append(drop)
		"goldrush":
			for entry in GOLD:
				for i in entry[3]:
					var treasure: Dictionary = game.add_item("gold", road_spot(game, 5.0), entry[1], entry[0], rng.randf_range(0, TAU))
					treasure.prey = true
					treasure.value = entry[2]
					treasure.gold = true
					prey.append(treasure)
		"findcow":
			var farm = game.countryside
			# Cows graze in the open: the forest's canopy would hide their looks.
			if farm: hunt.build(game, rng, func(): return open_spot(game, farm))
			else: hunt.build(game, rng, func(): return road_spot(game, 6.0))
		"skyhop":
			# One course for everyone, by lap, not by day.
			hop.build(game, SkyHop.course_seed(game.campaign.lap("skyhop")))
		"slide":
			# The ladder is the same for everyone, by lap, not by day.
			puzzle.build(game, SlidePuzzle.ladder_seed(game.campaign.lap("slide")))
		"siege":
			siege.build(value)
		"snake":
			snake.build(game, value)
		"mole":
			moles.build(game, value)
			prey.append_array(moles.moles)
			sky.append_array(moles.bombs)
		"redlight":
			light.build(game, value)
			prey.append_array(light.snacks)
		"beam":
			beam.build(game, value)
	for item in prey + sky: item.optional = true

# A spot on a road, away from the spawn point.
func road_spot(game, clear: float) -> Vector3:
	var at := Vector3.ZERO
	for attempt in 12:
		var free := rng.randf_range(-0.92, 0.92)
		if rng.randf() < 0.5:
			at = Vector3(game.layout.streets_x[rng.randi()%game.layout.streets_x.size()], 0.16, free*game.layout.move_z)
		else:
			at = Vector3(free*game.layout.move_x, 0.16, game.layout.streets_z[rng.randi()%game.layout.streets_z.size()])
		at.x = clampf(at.x, -game.layout.move_x, game.layout.move_x)
		at.z = clampf(at.z, -game.layout.move_z, game.layout.move_z)
		if at.distance_to(game.SPAWN) > clear: break
	return at

# --- round -------------------------------------------------------------------------

# Back in a city: the classic games' own nodes (pets, mole hills, lights) go.
func clear() -> void:
	siege.clear()
	snake.clear()
	moles.clear()
	light.clear()
	beam.clear()

# The landmark, its guardian and every defender sit out the mini-game.
func reset(game) -> void:
	count = 0
	clock = 0.0
	rng.seed = seed_value + 1
	next_coin = 1.0
	next_bomb = BOMB_EVERY
	for item in game.items:
		if item.get("is_boss", false) or item.get("defender", false) or item.get("guardian", false):
			item.hidden = true
			game.set_item_transform(item)
	for duck in prey:
		duck.phase = "rest"
		duck.timer = rng.randf_range(0.0, DUCK_REST.y)
		duck.heading = Vector3.ZERO
	for family in families:
		family.chain = 0
		family.scattered = false
		family.mother.heading = Vector3(cos(rng.randf_range(0, TAU)), 0, sin(rng.randf_range(0, TAU)))
	carried = 0
	steal_wait = 0.0
	if kind == "goldrush": show_bank(game)
	elif is_instance_valid(bank): bank.visible = false
	for drop in sky: park(game, drop)
	for marker in markers: marker.visible = false
	if kind == "findcow": hunt.reset(game, game.campaign.checkpoint("findcow"))
	if kind == "skyhop": hop.reset(game.campaign.checkpoint("skyhop"))
	if kind == "slide": puzzle.reset(game)
	# The siege's planes and shots are its own nodes: clear them in other games.
	if kind == "siege": siege.reset(game.campaign.checkpoint("siege"))
	else: siege.clear()
	# So are the snake's animals and monsters, the mole hills and the lights.
	if kind == "snake": snake.reset(game)
	else: snake.clear()
	if kind == "mole": moles.reset(game)
	else: moles.clear()
	if kind == "redlight": light.reset()
	else: light.clear()
	if kind == "beam": beam.reset(game)
	else: beam.clear()

func park(game, drop: Dictionary) -> void:
	drop.hidden = true
	drop.eaten = false
	drop.fall = -1.0
	drop.falling = 0.0
	drop.life = 0.0
	game.set_item_transform(drop)

func update(game, dt: float) -> void:
	clock += dt
	if kind == "stampede":
		for family in families: move_family(game, family, dt)
	elif kind == "goldrush":
		update_gold(game, dt)
	elif kind == "coinrain":
		update_rain(game, dt)
	elif kind == "findcow":
		hunt.update(game, dt)
	elif kind == "skyhop":
		hop.update(game, dt)
		count = hop.run_gaps()
	elif kind == "slide":
		puzzle.update(game, dt)
		count = puzzle.cleared
	elif kind == "siege":
		siege.update(game, dt, game.hole_position, game.move_direction().length() < 0.1)
		count = siege.run_cleared()
	elif kind == "snake":
		snake.update(game, dt)
		count = snake.line.size()
	elif kind == "mole":
		moles.update(game, dt)
	elif kind == "redlight":
		light.update(game, dt)
	elif kind == "beam":
		beam.update(game, dt)
		count = beam.placed

# The snake never stops: an idle stick keeps the saucer's last direction.
func steer(input: Vector2) -> Vector2:
	return snake.steer(input) if kind == "snake" else input

# The mother wanders (and sprints from a near hole); her line follows her.
func move_family(game, family: Dictionary, dt: float) -> void:
	var mother: Dictionary = family.mother
	if Traffic.is_active(mother):
		if mother.phase == "rest":
			mother.timer -= dt
			if rng.randf() < dt*0.4: mother.heading = mother.heading.rotated(Vector3.UP, rng.randf_range(-1.2, 1.2))
			mother.position += mother.heading*WANDER_SPEED*dt
			bounce(game, mother)
			mother.yaw = atan2(mother.heading.x, mother.heading.z)
			game.set_item_transform(mother)
		move_duck(game, mother, dt, MOTHER_DASH)
	var leader: Dictionary = mother
	for chick in family.chicks:
		if not Traffic.is_active(chick): continue
		if family.scattered or not Traffic.is_active(leader):
			move_duck(game, chick, dt)
			continue
		var ahead: Vector3 = Vector3(sin(leader.yaw), 0, cos(leader.yaw))
		var spot: Vector3 = leader.position - ahead*CHICK_GAP
		var to := Vector3(spot.x - chick.position.x, 0, spot.z - chick.position.z)
		if to.length() > 0.02:
			chick.position += to.limit_length(CHICK_SPEED*dt)
			chick.yaw = atan2(to.x, to.z)
		chick.roll = sin(clock*18.0 + chick.position.x)*0.1
		game.set_item_transform(chick)
		leader = chick

# Keeps a duck inside the map, turning it back at the edge.
func bounce(game, duck: Dictionary) -> void:
	if absf(duck.position.x) > game.layout.move_x: duck.heading.x = -duck.heading.x
	if absf(duck.position.z) > game.layout.move_z: duck.heading.z = -duck.heading.z
	duck.position.x = clampf(duck.position.x, -game.layout.move_x, game.layout.move_x)
	duck.position.z = clampf(duck.position.z, -game.layout.move_z, game.layout.move_z)

# The last duckling still in the family's line; `eating` (already falling into
# the hole) still counts as in it.
func tail_of(family: Dictionary, eating: Dictionary) -> Dictionary:
	for i in range(family.chicks.size() - 1, -1, -1):
		var chick: Dictionary = family.chicks[i]
		if chick == eating or Traffic.is_active(chick): return chick
	return {}

# Points for a duck by where it was in its family.
func duck_points(item: Dictionary) -> int:
	var family: Dictionary = families[int(item.family)]
	if item.get("chick", false):
		if family.scattered: return 1
		if item == tail_of(family, item):
			family.chain += 1
			return family.chain
		family.chain = 0
		return 1
	var left: Array = family.chicks.filter(func(chick): return Traffic.is_active(chick) and chick.fall < 0 and not chick.eaten)
	if left.is_empty(): return FAMILY_POINTS
	family.scattered = true
	for chick in left:
		chick.phase = "rest"
		chick.timer = 0.0
	return MOTHER_POINTS

func open_spot(game, farm) -> Vector3:
	var at: Vector3 = farm.spot(game, rng, 6.0)
	for attempt in 12:
		if farm.zone(at) != "forest": break
		at = farm.spot(game, rng, 6.0)
	return at

# --- gold rush bank ------------------------------------------------------------------

func show_bank(game) -> void:
	if not is_instance_valid(bank):
		bank = Node3D.new()
		var ring := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = BANK_RADIUS
		disc.bottom_radius = BANK_RADIUS
		disc.height = 0.05
		ring.mesh = disc
		ring.material_override = glow(Color(1.0, 0.84, 0.3, 0.45))
		bank.add_child(ring)
		var rim := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = BANK_RADIUS - 0.15
		torus.outer_radius = BANK_RADIUS + 0.1
		rim.mesh = torus
		rim.material_override = glow(Color(1.0, 0.85, 0.25, 0.95))
		bank.add_child(rim)
		var beam := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.top_radius = BANK_RADIUS*0.6
		column.bottom_radius = BANK_RADIUS
		column.height = 9.0
		beam.mesh = column
		beam.position.y = 4.5
		beam.material_override = glow(Color(1.0, 0.9, 0.5, 0.2))
		bank.add_child(beam)
		add_child(bank)
	# Above the plaza paving, which sits a little over the ground.
	bank.position = bank_at() + Vector3(0, 0.3, 0)
	bank.visible = true

func glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func bank_at() -> Vector3:
	return Vector3.ZERO

func flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Banks the gold carried into the ring; the rival takes it on a touch.
func update_gold(game, dt: float) -> void:
	steal_wait = maxf(0.0, steal_wait - dt)
	if carried <= 0: return
	if flat_gap(game.hole_position, bank_at()) < BANK_RADIUS:
		count += carried
		game.add_floater(game.hole_position, I18n.t("gold_banked", carried), true)
		game.fx.ripple(bank_at(), BANK_RADIUS, Color("ffd84a"))
		game.sfx.play("grow")
		carried = 0
		return
	if game.rival.active and steal_wait <= 0.0 and flat_gap(game.rival.position, game.hole_position) < game.rival.radius + game.radius + 0.4:
		game.add_floater(game.hole_position, I18n.t("gold_stolen", carried), false)
		game.sfx.play("shot")
		carried = 0
		steal_wait = STEAL_COOLDOWN

func move_duck(game, duck: Dictionary, dt: float, dash_scale := 1.0) -> void:
	if not Traffic.is_active(duck): return
	duck.timer -= dt
	var away := Vector3(duck.position.x - game.hole_position.x, 0, duck.position.z - game.hole_position.z)
	var distance := away.length()
	if duck.phase == "rest":
		duck.roll = 0.0
		if duck.timer <= 0 and distance < DUCK_ALERT + game.radius:
			duck.phase = "dash"
			duck.timer = DUCK_DASH
			# Scatter away from the hole with a little sideways jink.
			var side := Vector3(-away.z, 0, away.x).normalized()*rng.randf_range(-0.6, 0.6)
			duck.heading = ((away/maxf(distance, 0.001)) + side).normalized()
	else:
		duck.position += duck.heading*DUCK_SPEED*dash_scale*dt
		duck.yaw = atan2(duck.heading.x, duck.heading.z)
		duck.roll = sin(duck.timer*30.0)*0.12
		# Bounce off the map edge instead of piling up in a corner.
		if absf(duck.position.x) > game.layout.move_x: duck.heading.x = -duck.heading.x
		if absf(duck.position.z) > game.layout.move_z: duck.heading.z = -duck.heading.z
		duck.position.x = clampf(duck.position.x, -game.layout.move_x, game.layout.move_x)
		duck.position.z = clampf(duck.position.z, -game.layout.move_z, game.layout.move_z)
		if duck.timer <= 0:
			duck.phase = "rest"
			duck.timer = rng.randf_range(DUCK_REST.x, DUCK_REST.y)
	game.set_item_transform(duck)

func update_rain(game, dt: float) -> void:
	next_coin -= dt
	next_bomb -= dt
	if next_coin <= 0:
		next_coin = COIN_EVERY
		drop_next(game, sky.slice(0, COINS), DROP_RANGE)
	if next_bomb <= 0:
		next_bomb = BOMB_EVERY
		drop_next(game, sky.slice(COINS), DROP_RANGE*0.6)
	for i in sky.size():
		var drop: Dictionary = sky[i]
		if drop.eaten:
			park(game, drop)
			markers[i].visible = false
			continue
		if drop.hidden or drop.fall >= 0: continue
		if drop.falling > 0:
			drop.falling = maxf(0.0, drop.falling - dt)
			var k: float = drop.falling/DROP_TIME
			drop.position = drop.origin + Vector3(0, DROP_HEIGHT*k*k, 0)
			drop.yaw += dt*6.0
			markers[i].visible = true
			markers[i].position = Vector3(drop.origin.x, 0.15, drop.origin.z)
			markers[i].scale = Vector3.ONE*drop.radius*1.6*lerpf(1.0, 0.35, k)
			if drop.falling <= 0:
				markers[i].visible = false
				game.fx.puff(drop.origin, drop.radius, 1.0)
		else:
			drop.life -= dt
			drop.yaw += dt*2.5
			if drop.life <= 0:
				park(game, drop)
				continue
		game.set_item_transform(drop)

# Drops the first parked coin (or bomb) somewhere around the hole, on a road.
func drop_next(game, pool: Array, reach: float) -> void:
	for drop in pool:
		if not drop.hidden: continue
		var angle := rng.randf_range(0, TAU)
		var at: Vector3 = game.hole_position + Vector3(cos(angle), 0, sin(angle))*rng.randf_range(2.5, reach)
		at = snap_to_road(game, at)
		drop.origin = Vector3(at.x, 0.16, at.z)
		drop.position = drop.origin + Vector3(0, DROP_HEIGHT, 0)
		drop.hidden = false
		drop.falling = DROP_TIME
		drop.life = COIN_LIFE
		return

func snap_to_road(game, at: Vector3) -> Vector3:
	var best_x: float = game.layout.streets_x[0]
	var best_z: float = game.layout.streets_z[0]
	for x in game.layout.streets_x:
		if absf(x - at.x) < absf(best_x - at.x): best_x = x
	for z in game.layout.streets_z:
		if absf(z - at.z) < absf(best_z - at.z): best_z = z
	if absf(best_x - at.x) < absf(best_z - at.z): at.x = best_x
	else: at.z = best_z
	at.x = clampf(at.x, -game.layout.move_x, game.layout.move_x)
	at.z = clampf(at.z, -game.layout.move_z, game.layout.move_z)
	return at

# Called by game.swallow for every bite during a daily round.
func caught(game, item: Dictionary) -> void:
	if kind == "findcow":
		hunt.caught(game, item)
		count = hunt.finds
		return
	if not item.get("prey", false): return
	if kind == "mole":
		count += moles.caught(game, item)
		return
	if kind == "redlight":
		count += light.caught(game, item)
		return
	if kind == "stampede":
		var points := duck_points(item)
		count += points
		game.add_floater(item.position, I18n.t("duck_family") if points == FAMILY_POINTS and not item.get("chick", false) else "+%d" % points, true)
		game.sfx.play("grow")
		return
	var value := int(item.get("value", 1))
	if kind == "goldrush":
		carried += value
		game.add_floater(item.position, I18n.t("gold_carried", value), true)
		game.sfx.play("grow")
		return
	count += value
	game.add_floater(item.position, "+%d" % value if value > 1 else "+1", true)
	game.sfx.play("grow")

func done() -> bool:
	if kind == "findcow": return hunt.done()
	if kind == "skyhop": return hop.done()
	if kind == "slide": return puzzle.done()
	if kind == "siege": return siege.done()
	if kind == "snake": return snake.done()
	if kind == "redlight": return light.done()
	return kind == "stampede" and prey.all(func(duck): return not Traffic.is_active(duck))

func reached() -> bool:
	return count >= target()

func stars() -> int:
	if kind == "findcow": return hunt.stars()
	if kind == "slide": return puzzle.stars()
	if kind == "siege": return siege.stages_cleared()
	var total := 0
	for share in STAR_SHARES:
		if count >= ceili(target()*share): total += 1
	return total

func goal_labels() -> Array:
	if kind == "findcow": return hunt.goal_labels()
	if kind == "slide": return SlidePuzzle.STAR_BOARDS.map(func(need): return I18n.t("slide_goal", need))
	if kind == "siege": return [I18n.t("siege_g1"), I18n.t("siege_g2"), I18n.t("siege_g3")]
	return STAR_SHARES.map(func(share): return I18n.t("dg_count_" + kind, ceili(target()*share)))

func reward(coin_mul: float) -> int:
	if kind == "findcow": return hunt.reward(coin_mul)
	if kind == "slide": return roundi((SLIDE_BASE_COINS + puzzle.cleared*COIN_RATE.slide + puzzle.in_par*SLIDE_PAR_COINS)*coin_mul) if puzzle.cleared > 0 else 0
	if kind == "siege": return roundi((siege.count*COIN_RATE.siege + siege.run_cleared()*SIEGE_STAGE_COINS)*coin_mul)
	return roundi(count*COIN_RATE.get(kind, 1)*coin_mul)

# Minimap dots for what still scores.
func dots() -> Array:
	var list: Array = []
	# No minimap help in the cow hunt: the clues are the whole game.
	if kind == "findcow" or kind == "slide": return list
	if kind == "siege": return siege.dots()
	if kind == "mole": return moles.dots()
	if kind == "beam": return beam.dots()
	if kind == "snake": return snake.dots()
	for item in prey + sky:
		if item.get("prey", false) and Traffic.is_active(item) and item.get("falling", 0.0) <= 0:
			list.append(Vector2(item.position.x, item.position.z))
	return list

# The HUD's note line: the cow hunt's open clues, the puzzle's moves and size.
func note() -> String:
	if kind == "skyhop": return I18n.t("hop_note", [I18n.t("hop_map_" + SkyHop.map_of(hop.passed).id), hop.next_checkpoint()])
	if kind == "slide": return I18n.t("slide_note", [puzzle.board + 1, SlidePuzzle.BOARD_COUNT, puzzle.moves, puzzle.par, puzzle.level()])
	if kind == "siege" and not siege.won(): return I18n.t("siege_boss_note") if siege.stage_goal() == 0 else I18n.t("siege_note", [siege.stage + 1, siege.stage_points, siege.stage_goal()])
	if kind == "goldrush" and carried > 0: return I18n.t("gold_note", carried)
	if kind == "snake": return snake.note()
	if kind == "redlight": return light.note()
	if kind == "beam": return beam.note()
	return hunt.note() if kind == "findcow" else ""

# Camera zoom: the snake garden is seen closer up.
func zoom_scale() -> float:
	return SnakeTrail.ZOOM if kind == "snake" else 1.0

# Movement scale: a wrong cow is chewed slowly; carried gold weighs the hole down.
func speed_scale() -> float:
	if kind == "goldrush": return maxf(CARRY_FLOOR, 1.0/(1.0 + carried*CARRY_SLOW))
	if kind == "redlight": return light.speed_scale()
	if kind == "beam": return beam.speed_scale()
	return hunt.speed_scale() if kind == "findcow" else 1.0
