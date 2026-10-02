extends Node3D

# Landmark guardian: a mascot (mascot_specs.gd) that keeps the landmark's shield
# up until the hole swallows it. It roams the whole city along the streets
# (mascot_roads.gd), never through blocks: patrols between crossings, hunts a
# nearby hole, and runs home when the hole closes in on the landmark. In range it winds up and attacks the saucer (mascot_attacks.gd); once
# the hole can eat it, it runs off in short sprints instead. It takes three bites:
# the first two knock it away, so the fight cannot be skipped by a passing sweep.
# Attacks are telegraphed defence strikes, so hits go through game.take_hit().
# The game sets this node's transform from the guardian item; the look and the
# animation live in mascot_rig.gd.
const MascotRig = preload("res://scripts/mascot_rig.gd")
const MascotAttacks = preload("res://scripts/mascot_attacks.gd")
const Roads = preload("res://scripts/mascot_roads.gd")
const Traffic = preload("res://scripts/traffic.gd")
const ATTACK_COLORS := MascotAttacks.COLORS
const FIRST_COOLDOWN := 4.0
const COOLDOWN := 3.2
const WINDUP := 0.75
const RECOVER := 0.9
const RANGE := 8.0
const HUNT_RANGE := 15.0
const LOSE_RANGE := 22.0
const WALK_SPEED := 2.4
const HUNT_SPEED := 3.4
const HOME_SPEED := 5.2
const FLEE_SPEED := 4.8
const FLEE_DASH := 0.8
const FLEE_REST := 1.5
const ALERT := 8.0
# The guardian heads home when the hole is this far from the landmark's edge.
const GUARD_REACH := 5.0
const HP := 3
const STAGGER := 1.2
const KNOCK_SPEED := 9.0
const KNOCK_TIME := 0.35
const BITE_SHRINK := 0.92
# How far ahead an escape looks for a street to run along.
const FLEE_REACH := 8.0

var spec: Dictionary = {}
var item: Dictionary = {}
var home := Vector3.ZERO
var state := "guard"
var timer := 0.0
var cooldown := FIRST_COOLDOWN
var aim := Vector3.ZERO
var heading := Vector3.ZERO
var waypoint := Vector3.ZERO
var leap_start := Vector3.ZERO
var moving := 0.0
var crouch := 0.0
var lunge := 0.0
var squash := 0.0
var air := 0.0
var hp := HP
var hurt := 0.0
var rig: Node3D
var attacks: Node3D
var rng := RandomNumberGenerator.new()

func build(models, value: Dictionary) -> void:
	spec = value
	rig = MascotRig.new()
	add_child(rig)
	rig.build(models, spec)
	rng.seed = hash(str(spec.get("id", "")))

func reset() -> void:
	state = "guard"
	timer = 0.0
	cooldown = FIRST_COOLDOWN
	heading = Vector3.ZERO
	waypoint = home
	crouch = 0.0
	lunge = 0.0
	squash = 0.0
	moving = 0.0
	air = 0.0
	hp = HP
	hurt = 0.0
	if item.is_empty(): return
	item.position.y = home.y
	if item.has("full_radius"): item.radius = item.full_radius

func attack_color() -> Color:
	return ATTACK_COLORS.get(spec.get("attack", "stomp"), Color("ff7866"))

# --- bites ------------------------------------------------------------------------

# The hole closed over the guardian. Returns true when this bite swallows it;
# otherwise it loses a heart, shrinks a little and is knocked out of reach.
func bite(game) -> bool:
	if hurt > 0.0 or air > 0.3: return false
	hp -= 1
	if hp <= 0: return true
	hurt = STAGGER
	item.full_radius = item.get("full_radius", item.radius)
	item.radius *= BITE_SHRINK
	var away := flat(item.position - game.hole_position)
	heading = Roads.along(game.layout, item.position, inward(game, away.normalized() if away.length() > 0.05 else Vector3.FORWARD))
	state = "knocked"
	timer = KNOCK_TIME
	squash = 1.0
	game.fx.ripple(item.position, item.radius*1.6, attack_color())
	game.fx.shake = maxf(game.fx.shake, 0.4)
	game.add_floater(item.position, game.I18n.t("guardian_hp", [hp, HP]), true)
	game.sfx.play("boss")
	return false

func can_be_bitten() -> bool:
	return hurt <= 0.0 and air <= 0.3

# --- behaviour (during play) ---------------------------------------------------------

func think(game, dt: float) -> void:
	if item.is_empty() or not Traffic.is_active(item): return
	hurt = maxf(0.0, hurt - dt)
	var to_hole := flat(game.hole_position - item.position)
	var distance := to_hole.length()
	moving = 0.0
	var edible: bool = item.radius <= game.radius*game.EAT_RATIO
	var busy := state in ["charge", "leap", "knocked"]
	if edible and not busy and not state.begins_with("flee"):
		state = "flee_rest"
		timer = 0.4
	match state:
		"guard", "patrol", "hunt", "home": roam(game, dt, to_hole, distance)
		"windup":
			timer -= dt
			face(aim - item.position)
			if timer <= 0: release(game)
		"charge":
			timer -= dt
			road_walk(game, aim, MascotAttacks.CHARGE_SPEED, dt)
			if timer <= 0 or flat(aim - item.position).length() < 0.2: land(game)
		"leap": leap(game, dt)
		"recover":
			timer -= dt
			if timer <= 0:
				state = "hunt"
				cooldown = COOLDOWN*game.defense.cooldown_scale
		"knocked":
			timer -= dt
			item.position += heading*KNOCK_SPEED*dt
			if timer <= 0:
				state = "flee_rest" if edible else "hunt"
				timer = 0.3
		"flee_rest":
			if not edible:
				state = "hunt"
				cooldown = 1.0
			timer -= dt
			if timer <= 0 and distance < ALERT + item.radius:
				state = "flee"
				timer = FLEE_DASH
				heading = inward(game, -to_hole/maxf(distance, 0.001))
				waypoint = Roads.project(game.layout, item.position + heading*FLEE_REACH)
		"flee":
			timer -= dt
			road_walk(game, waypoint, FLEE_SPEED, dt)
			if timer <= 0:
				state = "flee_rest"
				timer = FLEE_REST
	stay_on_map(game)
	game.set_item_transform(item)

# Patrol the crossings, hunt a nearby hole, run home to defend the landmark.
func roam(game, dt: float, to_hole: Vector3, distance: float) -> void:
	cooldown -= dt
	var boss: Dictionary = game.items[game.boss_index]
	var threat: float = flat(game.hole_position - boss.position).length() - game.boss_radius
	var away_from_home := flat(home - item.position).length()
	if threat < GUARD_REACH and away_from_home > RANGE*0.5: state = "home"
	elif distance < HUNT_RANGE: state = "hunt"
	elif distance > LOSE_RANGE: state = "patrol"
	match state:
		"home": road_walk(game, home, HOME_SPEED, dt)
		"hunt":
			if distance > RANGE*0.6: road_walk(game, game.hole_position, HUNT_SPEED, dt)
		_:
			if flat(waypoint - item.position).length() < 0.6: waypoint = next_waypoint(game)
			road_walk(game, waypoint, WALK_SPEED, dt)
	if distance < HUNT_RANGE: face(to_hole)
	if cooldown <= 0 and distance < RANGE + item.radius and game.defense.grace <= 0:
		state = "windup"
		timer = WINDUP
		aim = game.hole_position + game.hole_velocity*0.35
		aim.y = 0

func next_waypoint(game) -> Vector3:
	var layout = game.layout
	if layout.crossings_x.is_empty() or layout.crossings_z.is_empty() or rng.randf() < 0.25: return home
	var x: float = layout.crossings_x[rng.randi()%layout.crossings_x.size()]
	var z: float = layout.crossings_z[rng.randi()%layout.crossings_z.size()]
	return Vector3(x, home.y, z)

func release(game) -> void:
	# A charge runs along the street, so it aims at the road point by the hole.
	if spec.get("attack", "") == "charge": aim = Roads.project(game.layout, aim)
	state = MascotAttacks.launch(self, game, aim)
	lunge = 1.0
	match state:
		"charge":
			var path := flat(aim - item.position)
			timer = maxf(0.4, (absf(path.x) + absf(path.z))/MascotAttacks.CHARGE_SPEED) + 0.4
		"leap":
			timer = 0.0
			leap_start = item.position
		_: timer = RECOVER

# A jump up to the saucer's height over the aim point, then a drop back onto
# the closest street (it may fly over a block, but never lands in one).
func leap(game, dt: float) -> void:
	timer += dt
	var t := clampf(timer/MascotAttacks.LEAP_TIME, 0.0, 1.0)
	var target := Vector3(aim.x, home.y, aim.z)
	var landing: Vector3 = Roads.project(game.layout, target)
	if t < 0.5:
		var across := t*2.0
		item.position = leap_start.lerp(target, 1.0 - (1.0 - across)*(1.0 - across))
	else:
		item.position = target.lerp(landing, (t - 0.5)*2.0)
	var peak: float = maxf(1.5, game.saucer.position.y - item.radius*1.2)
	air = sin(t*PI)
	item.position.y = home.y + air*peak
	face(target - leap_start)
	if t >= 1.0: land(game)

func land(game) -> void:
	item.position.y = home.y
	air = 0.0
	state = "recover"
	timer = RECOVER
	squash = 1.0
	game.fx.ripple(item.position, item.radius*1.4, attack_color())

func stay_on_map(game) -> void:
	var position: Vector3 = item.position
	# On the ground it always stands on a street or in the plaza.
	if air <= 0.0 and not Roads.walkable(game.layout, position): position = Roads.road_point(game.layout, position)
	position.x = clampf(position.x, -game.layout.move_x, game.layout.move_x)
	position.z = clampf(position.z, -game.layout.move_z, game.layout.move_z)
	item.position = position

# Near the map edge a knock or an escape bends toward the middle, so the
# guardian is never pinned in a corner where the hole sits on top of it.
const EDGE_MARGIN := 4.0

func inward(game, direction: Vector3) -> Vector3:
	var limit := Vector2(game.layout.move_x, game.layout.move_z) - Vector2.ONE*EDGE_MARGIN
	var bent := direction
	if absf(item.position.x) > limit.x and signf(direction.x) == signf(item.position.x): bent.x = -signf(item.position.x)*absf(direction.x)
	if absf(item.position.z) > limit.y and signf(direction.z) == signf(item.position.z): bent.z = -signf(item.position.z)*absf(direction.z)
	return flat(bent).normalized() if flat(bent).length() > 0.01 else flat(-item.position).normalized()

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

# Walk toward target along the streets (see mascot_roads.gd).
func road_walk(game, target: Vector3, speed: float, dt: float) -> void:
	var corner: Vector3 = Roads.next_point(game.layout, item.position, target)
	var offset := flat(corner - item.position)
	if offset.length() < 0.05: return
	item.position += offset.limit_length(speed*dt)
	moving = speed
	heading = offset.normalized()
	face(offset)

func face(direction: Vector3) -> void:
	if flat(direction).length() > 0.01: item.yaw = atan2(direction.x, direction.z)

# --- animation (every frame, menu included) ----------------------------------------

func animate(dt: float) -> void:
	if rig == null: return
	var crouching := state == "windup"
	crouch = move_toward(crouch, 1.0 if crouching else 0.0, dt*(2.5 if crouching else 6.0))
	lunge = maxf(0.0, lunge - dt*3.0)
	squash = maxf(0.0, squash - dt*4.0)
	rig.animate(dt, {"state":state, "moving":moving, "crouch":crouch, "lunge":lunge,
		"squash":squash, "air":air, "hurt":hurt})
