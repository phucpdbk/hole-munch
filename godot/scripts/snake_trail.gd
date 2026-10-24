extends Node3D

# Daily mini-game "snake" (daily_games.gd), the classic snake in a garden
# (theme_maps.gd): the saucer never stops (steer keeps the last direction).
# Cute animals (critters.gd) roam the garden and bolt from a nearby hole;
# catch one and it joins the line hopping behind the saucer, ORB_GAP apart on
# the hole's own path. Monsters (the Meshy "gobbler", mascot_rig.gd) hunt the
# line: one bites the nearest pet, and every pet behind the bite scatters back
# into the garden; with no pets left they bite BITE_TIME off the clock. More
# monsters join as the round goes on (TIERS). Hedges, beds and ponds block
# the saucer, the animals and the monsters alike. Running into your own line,
# past its first SAFE_ORBS pets, ends the run. The score is the line at the
# end; reaching the target unlocks the next, harder garden for the next run.
const I18n = preload("res://scripts/i18n.gd")
const Critter = preload("res://scripts/critters.gd")
const PetFlock = preload("res://scripts/pet_flock.gd")
const MascotRig = preload("res://scripts/mascot_rig.gd")
const ThemeMaps = preload("res://scripts/theme_maps.gd")
const MONSTER_ID := "gobbler"
# Per garden tier: [monsters at the start, seconds between new ones, most at
# once, animals roaming, monster speed at the start and once the line is long].
const TIERS := [[1, 30.0, 3, 7, 3.2, 4.8], [1, 25.0, 4, 7, 3.4, 5.0], [2, 22.0, 4, 8, 3.5, 5.2], [2, 18.0, 5, 8, 3.6, 5.4]]
const ORB_GAP := 1.1
const MAX_ORBS := 60
const SAFE_ORBS := 4
# The line bites when the hole's centre comes this close (a share of its radius).
const BITE_SHARE := 0.55
const CATCH_SHARE := 0.85
const STEP := 0.15
const ANIMAL_RADIUS := 0.4
# Pets are drawn this much bigger than their toy model, so they read on screen.
const PET_SCALE := 1.5
const WANDER_SPEED := 1.3
const FLEE_SPEED := 4.2
const ALERT := 5.0
const FLEE_TIME := 0.7
const REST := Vector2(0.6, 1.4)
const MONSTER_RADIUS := 0.75
const MONSTER_SCALE := 1.3
const MONSTER_REACH := 1.1
const MONSTER_NAP := 3.0
const CHEW := 1.4
const BITE_TIME := 3.0
# The camera comes in closer than in a city, so the pets and monsters read.
const ZOOM := 0.75

var tier := 0
var roamers: Array = []
var line: Array = []
var pool: Array = []
var monsters: Array = []
var trail: Array[Vector3] = []
var next_monster := 0.0
var made := 0
var chomped := 0
var unlocked := false
var crashed := false
var time := 0.0
var heading := Vector2.ZERO
var rng := RandomNumberGenerator.new()
# The baked Meshy pets drawn as a flipbook crowd (pet_flock.gd), or false for
# the primitive toy animals.
var flipbook := false
var flock: Node3D

func build(game, seed_value: int) -> void:
	rng.seed = seed_value
	flipbook = PetFlock.available()
	if flipbook and not is_instance_valid(flock):
		flock = PetFlock.new()
		add_child(flock)
	tier = game.countryside.tier if game.countryside else 0

func setting(index: int):
	return TIERS[tier][index]

func reset(game) -> void:
	for critter in roamers + line: park(critter)
	roamers.clear()
	line.clear()
	for monster in monsters: monster.holder.queue_free()
	monsters.clear()
	chomped = 0
	unlocked = false
	crashed = false
	heading = Vector2.ZERO
	time = 0.0
	next_monster = setting(1)
	# The round starts at the spawn point (the hole may not be back there yet).
	var start := Vector3(game.spawn.x, 0, game.spawn.z)
	trail = [start]
	for i in setting(3): add_roamer(game, start)
	for i in setting(0): add_monster(game, start, i)

func clear() -> void:
	for critter in roamers + line + pool: critter.visible = false
	if is_instance_valid(flock):
		flock.begin()
		flock.finish()
	for monster in monsters: monster.holder.visible = false

# --- animals ---------------------------------------------------------------------

func take_critter(game) -> Critter:
	if not pool.is_empty(): return pool.pop_back()
	var critter := Critter.new()
	critter.build(game.models, made, flipbook)
	critter.scale = Vector3.ONE*PET_SCALE
	made += 1
	add_child(critter)
	return critter

func park(critter: Node3D) -> void:
	critter.visible = false
	if not critter in pool: pool.append(critter)

# A new animal somewhere free in the garden, away from the saucer.
func add_roamer(game, away_from: Vector3) -> void:
	var critter := take_critter(game)
	var at: Vector3 = game.countryside.free_spot(game, rng, ANIMAL_RADIUS) if game.countryside else game.daily.road_spot(game, 6.0)
	for attempt in 8:
		if flat_gap(at, away_from) > 8.0: break
		at = game.countryside.free_spot(game, rng, ANIMAL_RADIUS) if game.countryside else game.daily.road_spot(game, 6.0)
	critter.position = Vector3(at.x, 0.16, at.z)
	critter.last = Vector3.INF
	critter.visible = true
	roam(critter, "rest", rng.randf_range(REST.x, REST.y), Vector3.ZERO)
	roamers.append(critter)

func roam(critter: Node3D, phase: String, timer: float, heading_value: Vector3) -> void:
	critter.set_meta("phase", phase)
	critter.set_meta("timer", timer)
	critter.set_meta("heading", heading_value if heading_value != Vector3.ZERO else Vector3(cos(rng.randf_range(0, TAU)), 0, sin(rng.randf_range(0, TAU))))

# Roaming animals wander, rest, and bolt from a nearby saucer.
func move_roamer(game, critter: Node3D, dt: float) -> void:
	var phase: String = critter.get_meta("phase")
	var timer: float = critter.get_meta("timer") - dt
	var direction: Vector3 = critter.get_meta("heading")
	var away := Vector3(critter.position.x - game.hole_position.x, 0, critter.position.z - game.hole_position.z)
	var speed := 0.0
	if phase == "flee":
		speed = FLEE_SPEED
		if timer <= 0:
			phase = "rest"
			timer = rng.randf_range(REST.x, REST.y)
	elif away.length() < ALERT + game.radius and timer <= 0:
		phase = "flee"
		timer = FLEE_TIME
		var side := Vector3(-away.z, 0, away.x).normalized()*rng.randf_range(-0.6, 0.6)
		direction = (away.normalized() + side).normalized()
	elif phase == "rest":
		if timer <= 0:
			phase = "wander"
			timer = rng.randf_range(1.5, 3.5)
			direction = direction.rotated(Vector3.UP, rng.randf_range(-1.5, 1.5))
	else:
		speed = WANDER_SPEED
		if rng.randf() < dt*0.6: direction = direction.rotated(Vector3.UP, rng.randf_range(-1.0, 1.0))
		if timer <= 0:
			phase = "rest"
			timer = rng.randf_range(REST.x, REST.y)
	if speed > 0:
		var goal: Vector3 = critter.position + direction*speed*dt
		var moved := keep_in(game, goal, ANIMAL_RADIUS)
		# Blocked by a hedge or the edge: turn and try another way.
		if flat_gap(moved, goal) > 0.01: direction = direction.rotated(Vector3.UP, rng.randf_range(1.2, 2.6) * (1 if rng.randf() < 0.5 else -1))
		critter.position = moved
		critter.rotation.y = atan2(direction.x, direction.z)
	critter.set_meta("phase", phase)
	critter.set_meta("timer", timer)
	critter.set_meta("heading", direction)

func keep_in(game, at: Vector3, radius: float) -> Vector3:
	var clamped := Vector3(clampf(at.x, -game.layout.move_x, game.layout.move_x), at.y, clampf(at.z, -game.layout.move_z, game.layout.move_z))
	return game.countryside.push_out(clamped, radius) if game.countryside else clamped

# A roaming animal under the saucer joins the end of the line.
func catch_roamers(game) -> void:
	for critter in roamers.duplicate():
		if flat_gap(critter.position, game.hole_position) > game.radius*CATCH_SHARE: continue
		roamers.erase(critter)
		if line.size() >= MAX_ORBS:
			park(critter)
		else:
			line.append(critter)
		game.add_floater(critter.position, I18n.t("snake_joined"), true)
		game.sfx.play("grow")
		add_roamer(game, game.hole_position)

# Each pet runs to its place on the path and faces the pet ahead of it.
func move_line(dt: float) -> void:
	for i in line.size():
		var pet: Node3D = line[i]
		var slot := orb_at(i)
		var to := Vector3(slot.x - pet.position.x, 0, slot.z - pet.position.z)
		pet.position += to.limit_length(maxf(9.0, to.length()*10.0)*dt)
		pet.position.y = 0.16
		var ahead := orb_at(i - 1) if i > 0 else trail[-1]
		if flat_gap(ahead, pet.position) > 0.05: pet.rotation.y = atan2(ahead.x - pet.position.x, ahead.z - pet.position.z)

# --- monsters ------------------------------------------------------------------------

func add_monster(game, away_from: Vector3, index: int) -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE*MONSTER_SCALE
	var body
	if MascotRig.model_path(MONSTER_ID) != "":
		body = MascotRig.new()
		body.build(game.models, {"id":MONSTER_ID})
	else:
		body = MeshInstance3D.new()
		body.mesh = game.models.toy("monster")
	holder.add_child(body)
	add_child(holder)
	# Wake far from the saucer: the farthest of a few free spots.
	var best := Vector3.ZERO
	for attempt in 6:
		var spot: Vector3 = game.countryside.free_spot(game, rng, MONSTER_RADIUS) if game.countryside else game.daily.road_spot(game, 10.0)
		if attempt == 0 or flat_gap(spot, away_from) > flat_gap(best, away_from): best = spot
	holder.position = Vector3(best.x, 0.16, best.z)
	monsters.append({"holder":holder, "body":body, "wait":MONSTER_NAP + index*0.8, "speed":0.0, "lunge":0.0})

# Each monster hunts the pet nearest to it, or the saucer when the line is empty.
func move_monster(game, monster: Dictionary, dt: float) -> void:
	var holder: Node3D = monster.holder
	monster.wait = maxf(0.0, monster.wait - dt)
	monster.lunge = maxf(0.0, monster.lunge - dt)
	monster.speed = 0.0
	if monster.wait > 0 or not game.started: return
	var target := -1
	var goal := Vector3(game.hole_position.x, 0, game.hole_position.z)
	var best := INF
	for i in line.size():
		var gap := flat_gap(line[i].position, holder.position)
		if gap < best:
			best = gap
			target = i
	if target >= 0: goal = line[target].position
	var to := Vector3(goal.x - holder.position.x, 0, goal.z - holder.position.z)
	var speed := lerpf(setting(4), setting(5), clampf(line.size()/16.0, 0.0, 1.0))
	if to.length() > 0.01:
		holder.position = keep_in(game, holder.position + to.limit_length(speed*dt), MONSTER_RADIUS)
		holder.position.y = 0.16
		holder.rotation.y = lerp_angle(holder.rotation.y, atan2(to.x, to.z), 1.0 - exp(-dt*10.0))
		monster.speed = speed
	if to.length() < MONSTER_REACH*2.2: monster.lunge = 0.4
	var reach: float = MONSTER_REACH if target >= 0 else MONSTER_REACH + game.radius*0.6
	if to.length() > reach: return
	monster.wait = CHEW
	game.sfx.play("shot", 0.7)
	game.fx.puff(goal, 0.6, 1.0)
	if target >= 0:
		bite(game, target)
		return
	game.remaining = maxf(0.0, game.remaining - BITE_TIME)
	game.add_floater(game.hole_position, I18n.t("snake_bitten", int(BITE_TIME)), false)

# The bitten pet is gone; every pet behind it scatters back into the garden.
func bite(game, index: int) -> void:
	var eaten: Node3D = line[index]
	var behind: Array = line.slice(index + 1)
	line = line.slice(0, index)
	chomped += 1
	park(eaten)
	game.add_floater(eaten.position, I18n.t("snake_chomp"), false)
	for critter in behind:
		var away := Vector3(critter.position.x - eaten.position.x, 0, critter.position.z - eaten.position.z)
		roam(critter, "flee", FLEE_TIME*1.5, away.normalized() if away.length() > 0.01 else Vector3.ZERO)
		roamers.append(critter)
	if not behind.is_empty(): game.add_floater(game.hole_position, I18n.t("snake_scatter", behind.size()), false)

func spread_monsters() -> void:
	for a in monsters.size():
		for b in range(a + 1, monsters.size()):
			var one: Node3D = monsters[a].holder
			var two: Node3D = monsters[b].holder
			var gap := Vector3(two.position.x - one.position.x, 0, two.position.z - one.position.z)
			if gap.length() >= 1.4 or gap.length() < 0.001: continue
			var push := gap.normalized()*(1.4 - gap.length())/2
			one.position -= push
			two.position += push

func animate_monster(monster: Dictionary, dt: float) -> void:
	var body = monster.body
	if body is MascotRig:
		var chewing: bool = monster.wait > 0 and monster.wait < CHEW + 0.01 and time > MONSTER_NAP
		body.animate(dt, {"state":"windup" if monster.lunge > 0 or chewing else "chase", "moving":monster.speed,
			"crouch":0.0, "lunge":0.0, "squash":0.0, "air":0.0, "hurt":0.0})
	else:
		body.position.y = absf(sin(time*11.0))*0.2*clampf(monster.speed, 0.0, 1.0)

# --- round ---------------------------------------------------------------------------

# The saucer keeps gliding the last way it was pushed, like a snake.
func steer(input: Vector2) -> Vector2:
	if input.length() > 0.2: heading = input.normalized()
	return heading

func update(game, dt: float) -> void:
	time += dt
	record(game.hole_position)
	if game.started and not crashed:
		for critter in roamers.duplicate(): move_roamer(game, critter, dt)
		catch_roamers(game)
		for monster in monsters: move_monster(game, monster, dt)
		spread_monsters()
		next_monster -= dt
		if next_monster <= 0 and monsters.size() < setting(2):
			next_monster = setting(1)
			add_monster(game, game.hole_position, 0)
			game.add_floater(game.hole_position, I18n.t("snake_monster"), false)
			game.sfx.play("boss")
		unlock(game)
	move_line(dt)
	for critter in roamers + line: critter.animate(dt)
	draw_flock()
	for monster in monsters: animate_monster(monster, dt)
	if crashed or not game.started: return
	for i in range(SAFE_ORBS, line.size()):
		if flat_gap(orb_at(i), game.hole_position) < game.radius*BITE_SHARE:
			crashed = true
			game.add_floater(game.hole_position, I18n.t("snake_crash"), false)
			game.fx.puff(game.hole_position, 0.8, 1.0)
			game.sfx.play("shot")
			return

# Reaching the target opens the next garden for the next run (kept for good).
func unlock(game) -> void:
	if unlocked or line.size() < game.daily.target() or tier >= ThemeMaps.GARDENS.size() - 1: return
	unlocked = true
	if game.campaign.reach_checkpoint("snake", tier + 1, ThemeMaps.GARDENS.size()): game.persist()
	game.add_floater(game.hole_position, I18n.t("snake_unlock"), true)

# Keeps the hole's path as points STEP apart, as long as the line needs.
func record(at: Vector3) -> void:
	var flat := Vector3(at.x, 0, at.z)
	var last: Vector3 = trail[-1]
	while flat_gap(flat, last) >= STEP:
		last = last + (flat - last).normalized()*STEP
		trail.append(last)
	var keep := int((MAX_ORBS + 1)*ORB_GAP/STEP) + 2
	if trail.size() > keep: trail = trail.slice(trail.size() - keep)

# Pet i sits (i + 1) gaps back along the path, or at its oldest point.
func orb_at(i: int) -> Vector3:
	var back := int(roundf((i + 1)*ORB_GAP/STEP))
	return trail[maxi(0, trail.size() - 1 - back)]

func flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func done() -> bool:
	return crashed

func dots() -> Array:
	return roamers.map(func(critter): return Vector2(critter.position.x, critter.position.z))

func note() -> String:
	return I18n.t("snake_note", [I18n.t("snake_map_" + ThemeMaps.GARDENS[tier]), line.size(), monsters.size()])

# --- fallback model ------------------------------------------------------------------

# The chasing monster facing +z when the Meshy model is missing: a purple
# brute with horns and teeth (models.gd toy "monster").
static func monster_parts(m) -> Array:
	var parts: Array = []
	var fur := Color("5b2a86")
	parts.append(m.piece("ball", Vector3(0, 0.75, 0), Vector3(0.75, 0.7, 0.7), fur))
	parts.append(m.piece("ball", Vector3(0, 0.6, 0.22), Vector3(0.55, 0.45, 0.5), fur.lightened(0.15)))
	for x in [-0.25, 0.25]:
		parts.append(m.piece("ball", Vector3(x, 1.08, 0.5), Vector3.ONE*0.12, Color("ff2b2b")))
		parts.append(m.piece("roof", Vector3(x*1.6, 1.5, 0), Vector3(0.1, 0.35, 0.1), Color("1d1d24"), Vector3(0, 0, -x)))
		parts.append(m.piece("ball", Vector3(x*1.3, 0.1, 0.2), Vector3(0.2, 0.1, 0.26), fur.darkened(0.25)))
	parts.append(m.piece("box", Vector3(0, 0.62, 0.66), Vector3(0.7, 0.24, 0.06), Color("2a0f3c")))
	for i in 4: parts.append(m.piece("roof", Vector3(-0.24 + i*0.16, 0.7, 0.69), Vector3(0.05, 0.1, 0.03), Color("ffffff"), Vector3(PI, 0, 0)))
	return parts

# Every visible pet into its kind, clip and frame batch.
func draw_flock() -> void:
	if not flipbook or not is_instance_valid(flock): return
	flock.begin()
	for critter in roamers + line:
		if critter.visible: flock.add(critter.kind, critter.clip, critter.frame(flock.length(critter.kind, critter.clip)), critter.transform)
	flock.finish()
