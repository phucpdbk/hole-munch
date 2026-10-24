extends Node3D

# Daily mini-game "snake" (daily_games.gd), the classic snake in a flower
# garden (theme_maps.gd): the saucer never stops (steer keeps the last
# direction), FRUITS sit on the paths, and each one eaten brings a cute pet
# (chick, bunny, piglet, kitten) to hop along behind it, ORB_GAP apart on the
# hole's own path. A monster chases the line and chomps its last pet (then
# chews for CHEW); with no pets left it bites the saucer for BITE_TIME
# seconds. It speeds up as the line grows. Running into your own line, past
# its first SAFE_ORBS pets, ends the run. The score is the line at the end.
const I18n = preload("res://scripts/i18n.gd")
const FRUITS := 3
const FRUIT_SIZE := 0.42
const ORB_GAP := 0.9
const MAX_ORBS := 60
const SAFE_ORBS := 4
const PETS := 4
# Pets are drawn this much bigger than their toy model, so they read on screen.
const PET_SCALE := 1.7
# The line bites when the hole's centre comes this close (a share of its radius).
const BITE_SHARE := 0.55
const STEP := 0.15
const NEAR := 6.0
const FAR := Vector2(12.0, 22.0)
const MONSTER_SPEED := Vector2(3.4, 5.6)
const MONSTER_REACH := 0.9
const MONSTER_NAP := 3.0
const CHEW := 1.4
const BITE_TIME := 3.0

var fruits: Array = []
var pets: Array[MeshInstance3D] = []
var monster: MeshInstance3D
var monster_at := Vector3.ZERO
var monster_wait := 0.0
var trail: Array[Vector3] = []
var length := 0
var chomped := 0
var crashed := false
var time := 0.0
var heading := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func build(game, seed_value: int) -> void:
	fruits.clear()
	rng.seed = seed_value
	for i in FRUITS:
		var fruit: Dictionary = game.add_item("fruit", game.SPAWN, FRUIT_SIZE, i % 3, rng.randf_range(0, TAU))
		fruit.prey = true
		fruits.append(fruit)
	if pets.is_empty():
		for i in MAX_ORBS:
			var pet := MeshInstance3D.new()
			pet.mesh = game.models.toy("pet", i % PETS)
			pet.scale = Vector3.ONE*PET_SCALE
			pet.visible = false
			add_child(pet)
			pets.append(pet)
		monster = MeshInstance3D.new()
		monster.mesh = game.models.toy("monster")
		monster.scale = Vector3.ONE*1.3
		monster.visible = false
		add_child(monster)

func reset(game) -> void:
	length = 0
	chomped = 0
	crashed = false
	heading = Vector2.ZERO
	time = 0.0
	# The round starts at the spawn point (the hole may not be back there yet).
	var start := Vector3(game.spawn.x, 0, game.spawn.z)
	trail = [start]
	for fruit in fruits: place(game, fruit, start)
	for pet in pets: pet.visible = false
	# The monster naps in the far corner for a moment before the chase.
	monster_at = Vector3(-signf(start.x + 0.1)*game.layout.move_x*0.8, 0.16, -signf(start.z + 0.1)*game.layout.move_z*0.8)
	monster_wait = MONSTER_NAP
	monster.visible = true
	place_monster(0.0)

func clear() -> void:
	for pet in pets: pet.visible = false
	if is_instance_valid(monster): monster.visible = false

# A fruit on a path: near the hole at first, farther as the line grows.
func place(game, fruit: Dictionary, from: Vector3) -> void:
	var reach := lerpf(FAR.x, FAR.y, clampf(length/30.0, 0.0, 1.0))
	var at := from
	for attempt in 12:
		var angle := rng.randf_range(0, TAU)
		at = game.daily.snap_to_road(game, from + Vector3(cos(angle), 0, sin(angle))*rng.randf_range(NEAR, reach))
		if flat_gap(at, from) > NEAR*0.6 and not touches_tail(at, 1.2): break
	fruit.position = Vector3(at.x, 0.16, at.z)
	fruit.origin = fruit.position
	fruit.hidden = false
	fruit.eaten = false
	fruit.fall = -1.0
	game.set_item_transform(fruit)

# The saucer keeps gliding the last way it was pushed, like a snake.
func steer(input: Vector2) -> Vector2:
	if input.length() > 0.2: heading = input.normalized()
	return heading

func update(game, dt: float) -> void:
	time += dt
	for fruit in fruits:
		if fruit.eaten: place(game, fruit, game.hole_position)
		elif not fruit.hidden and fruit.fall < 0:
			fruit.yaw += dt*1.5
			game.set_item_transform(fruit)
	record(game.hole_position)
	draw_pets()
	if crashed or not game.started:
		place_monster(dt)
		return
	update_monster(game, dt)
	for i in range(SAFE_ORBS, length):
		if flat_gap(orb_at(i), game.hole_position) < game.radius*BITE_SHARE:
			crashed = true
			game.add_floater(game.hole_position, I18n.t("snake_crash"), false)
			game.fx.puff(game.hole_position, 0.8, 1.0)
			game.sfx.play("shot")
			return

# Each pet hops along the path, facing the pet ahead of it.
func draw_pets() -> void:
	for i in MAX_ORBS:
		var pet := pets[i]
		pet.visible = i < length
		if i >= length: continue
		var at := orb_at(i)
		var ahead := orb_at(i - 1) if i > 0 else trail[-1]
		var hop := absf(sin(time*9.0 - i*0.7))*0.18
		pet.position = at + Vector3(0, 0.16 + hop, 0)
		if flat_gap(ahead, at) > 0.01: pet.rotation.y = atan2(ahead.x - at.x, ahead.z - at.z)

# The monster runs for the last pet (or the saucer when there is none).
func update_monster(game, dt: float) -> void:
	monster_wait = maxf(0.0, monster_wait - dt)
	if monster_wait > 0:
		place_monster(dt)
		return
	var target: Vector3 = orb_at(length - 1) if length > 0 else Vector3(game.hole_position.x, 0, game.hole_position.z)
	var to := Vector3(target.x - monster_at.x, 0, target.z - monster_at.z)
	var speed := lerpf(MONSTER_SPEED.x, MONSTER_SPEED.y, clampf(length/20.0, 0.0, 1.0))
	if to.length() > 0.01:
		monster_at += to.limit_length(speed*dt)
		monster.rotation.y = atan2(to.x, to.z)
	place_monster(dt)
	if to.length() > MONSTER_REACH: return
	monster_wait = CHEW
	game.sfx.play("shot", 0.7)
	game.fx.puff(target, 0.6, 1.0)
	if length > 0:
		length -= 1
		chomped += 1
		game.add_floater(target, I18n.t("snake_chomp"), false)
		return
	game.remaining = maxf(0.0, game.remaining - BITE_TIME)
	game.add_floater(game.hole_position, I18n.t("snake_bitten", int(BITE_TIME)), false)

func place_monster(dt: float) -> void:
	if not is_instance_valid(monster): return
	var chewing := monster_wait > 0
	var bob := absf(sin(time*(4.0 if chewing else 11.0)))*(0.08 if chewing else 0.25)
	monster.position = Vector3(monster_at.x, 0.16 + bob, monster_at.z)
	monster.scale = Vector3(1.3, 1.3*(1.0 + (sin(time*16.0)*0.08 if chewing else 0.0)), 1.3)

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

func touches_tail(at: Vector3, gap: float) -> bool:
	for i in length:
		if flat_gap(orb_at(i), at) < gap: return true
	return false

func flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func caught(game, item: Dictionary) -> bool:
	if not item in fruits: return false
	length = mini(MAX_ORBS, length + 1)
	game.add_floater(item.position, I18n.t("snake_joined"), true)
	game.sfx.play("grow")
	return true

func done() -> bool:
	return crashed

func note() -> String:
	return I18n.t("snake_note", length)

# --- models --------------------------------------------------------------------------

# A pet facing +z, about the size of a small fruit: chick, bunny, piglet, kitten.
static func pet_parts(m, variant: int) -> Array:
	var parts: Array = []
	var eye := Color("1d2430")
	match variant % PETS:
		0:
			parts.append(m.piece("ball", Vector3(0, 0.24, 0), Vector3(0.24, 0.22, 0.26), Color("ffe066")))
			parts.append(m.piece("ball", Vector3(0, 0.46, 0.1), Vector3.ONE*0.15, Color("ffe680")))
			parts.append(m.piece("roof", Vector3(0, 0.45, 0.27), Vector3(0.06, 0.1, 0.06), Color("ff9a3c"), Vector3(PI/2, 0, 0)))
			for x in [-0.07, 0.07]: parts.append(m.piece("ball", Vector3(x, 0.5, 0.22), Vector3.ONE*0.03, eye))
		1:
			parts.append(m.piece("ball", Vector3(0, 0.24, 0), Vector3(0.24, 0.22, 0.28), Color("f7f4ee")))
			parts.append(m.piece("ball", Vector3(0, 0.44, 0.14), Vector3.ONE*0.15, Color("ffffff")))
			for x in [-0.07, 0.07]:
				parts.append(m.piece("ball", Vector3(x, 0.68, 0.1), Vector3(0.04, 0.16, 0.05), Color("ffffff")))
				parts.append(m.piece("ball", Vector3(x, 0.68, 0.13), Vector3(0.02, 0.11, 0.02), Color("ffb3c1")))
				parts.append(m.piece("ball", Vector3(x, 0.47, 0.27), Vector3.ONE*0.03, eye))
			parts.append(m.piece("ball", Vector3(0, 0.26, -0.28), Vector3.ONE*0.08, Color("ffffff")))
		2:
			parts.append(m.piece("ball", Vector3(0, 0.24, 0), Vector3(0.25, 0.22, 0.3), Color("ffb3c1")))
			parts.append(m.piece("ball", Vector3(0, 0.36, 0.24), Vector3.ONE*0.15, Color("ffc2cd")))
			parts.append(m.piece("cyl", Vector3(0, 0.34, 0.38), Vector3(0.08, 0.05, 0.08), Color("ff8fa8"), Vector3(PI/2, 0, 0)))
			for x in [-0.08, 0.08]:
				parts.append(m.piece("roof", Vector3(x, 0.5, 0.2), Vector3(0.05, 0.08, 0.05), Color("ff8fa8")))
				parts.append(m.piece("ball", Vector3(x*0.8, 0.42, 0.35), Vector3.ONE*0.03, eye))
		_:
			parts.append(m.piece("ball", Vector3(0, 0.24, 0), Vector3(0.22, 0.21, 0.28), Color("ffa94d")))
			parts.append(m.piece("ball", Vector3(0, 0.44, 0.14), Vector3.ONE*0.16, Color("ffb366")))
			for x in [-0.09, 0.09]:
				parts.append(m.piece("roof", Vector3(x, 0.62, 0.12), Vector3(0.06, 0.1, 0.06), Color("ff922b")))
				parts.append(m.piece("ball", Vector3(x*0.8, 0.47, 0.28), Vector3.ONE*0.035, Color("2f9e44")))
			parts.append(m.piece("box", Vector3(0, 0.42, -0.3), Vector3(0.05, 0.36, 0.05), Color("ff922b"), Vector3(-0.5, 0, 0)))
	return parts

# The chasing monster facing +z: a round purple fuzzball with horns and teeth.
static func monster_parts(m) -> Array:
	var parts: Array = []
	var fur := Color("8a4fd8")
	parts.append(m.piece("ball", Vector3(0, 0.75, 0), Vector3(0.75, 0.7, 0.7), fur))
	parts.append(m.piece("ball", Vector3(0, 0.6, 0.22), Vector3(0.55, 0.45, 0.5), fur.lightened(0.15)))
	for x in [-0.25, 0.25]:
		parts.append(m.piece("ball", Vector3(x, 1.08, 0.5), Vector3.ONE*0.17, Color("ffffff")))
		parts.append(m.piece("ball", Vector3(x, 1.08, 0.64), Vector3.ONE*0.08, Color("1d2430")))
		parts.append(m.piece("roof", Vector3(x*1.6, 1.5, 0), Vector3(0.1, 0.35, 0.1), Color("ffe066"), Vector3(0, 0, -x)))
		parts.append(m.piece("ball", Vector3(x*1.3, 0.1, 0.2), Vector3(0.2, 0.1, 0.26), fur.darkened(0.25)))
	parts.append(m.piece("box", Vector3(0, 0.62, 0.66), Vector3(0.7, 0.24, 0.06), Color("3a1a5c")))
	for i in 4: parts.append(m.piece("roof", Vector3(-0.24 + i*0.16, 0.7, 0.69), Vector3(0.05, 0.1, 0.03), Color("ffffff"), Vector3(PI, 0, 0)))
	return parts
