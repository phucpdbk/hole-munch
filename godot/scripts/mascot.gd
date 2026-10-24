extends Node3D

# Landmark guardian: a mascot (mascot_specs.gd) that keeps the landmark's shield
# up until the hole swallows it. It roams the whole city along the streets
# (mascot_roads.gd, shortest routes round the blocks), never through them: patrols
# between crossings, hunts the hole from across the city, and runs home when the
# hole closes in on the landmark. A long detour round a block makes it hop over
# the roofs to land beside the hole and strike at once. It keeps circling at its
# style's range, leads a moving saucer, and winds up and attacks (mascot_attacks.gd); once
# the hole can eat it, it runs off in short sprints and strikes back between them. It takes three bites:
# the first two throw it out of the hole, so the fight cannot be skipped by a passing sweep.
# Attacks are telegraphed defence strikes, so hits go through game.take_hit().
# The game sets this node's transform from the guardian item; the look and the
# animation live in mascot_rig.gd.
const MascotRig = preload("res://scripts/mascot_rig.gd")
const MascotAttacks = preload("res://scripts/mascot_attacks.gd")
const Roads = preload("res://scripts/mascot_roads.gd")
const Traffic = preload("res://scripts/traffic.gd")
const ATTACK_COLORS := MascotAttacks.COLORS
const FIRST_COOLDOWN := 2.5
const COOLDOWN := 2.3
const WINDUP := 0.75
const RECOVER := 0.6
const RANGE := 10.0
const HUNT_RANGE := 22.0
const LOSE_RANGE := 32.0
const WALK_SPEED := 2.4
const HUNT_SPEED := 4.4
# The aim follows the hole through the wind-up and leads it by this share of the
# strike's warning, so a hole that keeps going straight is hit and one that turns
# or stops dodges. The lead never reaches further than MAX_LEAD.
const LEAD := 0.85
const MAX_LEAD := 6.0
# Distance each style likes to fight from; it circles the hole at about that range.
const STANDOFF := {"fire":5.5, "water":5.5, "lightning":6.0, "stomp":1.0, "charge":6.5, "leap":6.5}
const CIRCLE_SPEED := 0.7
const CIRCLE_SWING := 0.9
# Over the roofs when the street route is this many times the straight distance.
const HOP_DETOUR := 1.6
const HOP_REACH := 18.0
const HOP_TIME := 0.75
const HOP_HEIGHT := 3.5
const HOP_COOLDOWN := 3.0
# A landing from a hop strikes this soon.
const HOP_STRIKE := 0.35
const HOME_SPEED := 5.2
const FLEE_SPEED := 4.8
const FLEE_DASH := 0.8
const FLEE_REST := 1.5
const ALERT := 8.0
# The guardian heads home when the hole is this far from the landmark's edge.
const GUARD_REACH := 5.0
const HP := 3
const STAGGER := 1.2
# A bite throws the guardian up and out over the rim: it lands on a street at
# least THROW_GAP beyond the hole's edge and stays unbiteable for STAGGER after.
const THROW_TIME := 0.7
const THROW_HEIGHT := 3.0
const THROW_GAP := 2.5
const BITE_SHRINK := 0.92
# How far ahead an escape looks for a street to run along.
const FLEE_REACH := 8.0
# The last bite leaves it hanging on the far rim (when showtime is on): taps pull
# it loose, and it lets go by itself after CLING_MAX.
const CLING_TAPS := 6
const CLING_MAX := 3.2

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
var hop_cooldown := 0.0
var circle := 0.0
var taps := 0
var flail := 0.0
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
	hop_cooldown = 0.0
	circle = 0.0
	taps = 0
	flail = 0.0
	if item.is_empty(): return
	item.position.y = home.y
	if item.has("full_radius"): item.radius = item.full_radius

func attack_color() -> Color:
	return ATTACK_COLORS.get(spec.get("attack", "stomp"), Color("ff7866"))

# --- bites ------------------------------------------------------------------------

# The hole closed over the guardian. Returns true when this bite swallows it;
# otherwise it loses a heart, shrinks a little and is thrown out of the hole.
func bite(game) -> bool:
	if hurt > 0.0 or air > 0.3 or state == "cling": return false
	hp -= 1
	if hp <= 0:
		if not game.showtime.enabled: return true
		start_cling(game)
		return false
	hurt = STAGGER + THROW_TIME
	item.full_radius = item.get("full_radius", item.radius)
	item.radius *= BITE_SHRINK
	leap_start = item.position
	aim = throw_landing(game)
	state = "thrown"
	timer = 0.0
	squash = 1.0
	game.fx.ripple(item.position, item.radius*1.6, attack_color())
	game.fx.shake = maxf(game.fx.shake, 0.4)
	game.add_floater(item.position, game.I18n.t("guardian_hp", [hp, HP]), true)
	game.sfx.play("boss")
	return false

# A street (or plaza) spot clear of the hole's rim: straight away from the hole
# first, then turning further round, bent toward the middle near the map edge.
func throw_landing(game) -> Vector3:
	var away := flat(item.position - game.hole_position)
	var direction := inward(game, away.normalized() if away.length() > 0.05 else Vector3.FORWARD)
	var clear: float = game.radius + item.radius + THROW_GAP
	var best: Vector3 = item.position
	var best_gap := -1.0
	for reach in [clear, clear + 3.0, clear + 6.0]:
		for turn in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, PI]:
			var spot: Vector3 = game.hole_position + direction.rotated(Vector3.UP, turn)*reach
			spot.x = clampf(spot.x, -game.layout.move_x, game.layout.move_x)
			spot.z = clampf(spot.z, -game.layout.move_z, game.layout.move_z)
			spot = Roads.project(game.layout, Vector3(spot.x, home.y, spot.z))
			var gap := flat(spot - game.hole_position).length()
			if gap >= clear: return spot
			if gap > best_gap:
				best = spot
				best_gap = gap
	return best

# The throw arc; the landing squashes it and it runs (or hunts) from there.
func thrown(game, dt: float) -> void:
	timer += dt
	var t := clampf(timer/THROW_TIME, 0.0, 1.0)
	item.position = leap_start.lerp(aim, t*t*(3.0 - 2.0*t))
	air = sin(t*PI)
	item.position.y = home.y + air*maxf(THROW_HEIGHT, item.radius*2.0)
	if t < 1.0: return
	item.position.y = home.y
	air = 0.0
	squash = 1.0
	game.fx.ripple(item.position, item.radius*1.4, attack_color())
	var edible: bool = item.radius <= game.radius*game.EAT_RATIO
	state = "flee_rest" if edible else "hunt"
	timer = 0.3

func can_be_bitten() -> bool:
	return hurt <= 0.0 and air <= 0.3 and state != "cling"

# --- hanging on the rim ----------------------------------------------------------------

# It grabs the rim on the side away from the camera, so it hangs facing the player.
func start_cling(game) -> void:
	state = "cling"
	timer = 0.0
	taps = 0
	var back := flat(game.hole_position - game.camera.global_position)
	heading = back.normalized() if back.length() > 0.01 else Vector3.FORWARD
	squash = 1.0
	game.fx.shake = maxf(game.fx.shake, 0.5)
	game.add_floater(item.position, game.I18n.t("guardian_cling"), true)
	game.sfx.play("boss")

func tug(game) -> void:
	if state != "cling": return
	taps += 1
	squash = 1.0
	flail = 1.0
	game.pulse = 1.0
	game.fx.puff(item.position, item.radius*0.5, game.radius)
	game.sfx.play("click", 0.9 + taps*0.08)

# Hangs at the far rim, sinking a little more with every tap, kicking its legs.
func cling(game, dt: float) -> void:
	timer += dt
	flail = maxf(0.4, flail - dt*2.0)
	# The hole holds still and nothing shoots while the player taps.
	game.mechanics.stun = maxf(game.mechanics.stun, 0.1)
	game.defense.grace = maxf(game.defense.grace, 0.5)
	if taps >= CLING_TAPS or timer >= CLING_MAX:
		state = "dropped"
		flail = 0.0
		game.add_floater(item.position, game.I18n.t("guardian_drop"), true)
		game.swallow(item)
		return
	var grip: float = float(taps)/CLING_TAPS
	var rim: Vector3 = game.hole_position + heading*maxf(0.2, game.radius - item.radius*0.35)
	var shiver := Vector3(sin(timer*31.0), 0, cos(timer*27.0))*0.04*(1.0 + grip)
	item.position = rim + shiver
	item.position.y = home.y - item.radius*(0.9 + grip*0.7) + absf(sin(timer*9.0))*0.06
	# Facing the camera with its back to the far rim, leaning out over the hole.
	var facing := atan2(-heading.x, -heading.z)
	var lean := Basis(Vector3.UP.cross(-heading).normalized(), 0.28 + sin(timer*8.0)*0.06)
	var basis := (lean*Basis(Vector3.UP, facing + sin(timer*6.0)*0.15)).scaled(Vector3.ONE*game.model_scale(item))
	game.set_item_basis(item, basis)

# --- behaviour (during play) ---------------------------------------------------------

func think(game, dt: float) -> void:
	if item.is_empty() or not Traffic.is_active(item): return
	hurt = maxf(0.0, hurt - dt)
	var to_hole := flat(game.hole_position - item.position)
	var distance := to_hole.length()
	moving = 0.0
	var edible: bool = item.radius <= game.radius*game.EAT_RATIO
	var busy := state in ["windup", "recover", "charge", "leap", "thrown", "cling", "dropped", "hop"]
	if edible and not busy and not state.begins_with("flee"):
		state = "flee_rest"
		timer = 0.4
	match state:
		"guard", "patrol", "hunt", "home": roam(game, dt, to_hole, distance)
		"windup":
			timer -= dt
			aim = predict(game)
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
				state = "flee_rest" if edible else "hunt"
				cooldown = COOLDOWN*game.defense.cooldown_scale
		"thrown": thrown(game, dt)
		"hop": hop(game, dt)
		"cling":
			cling(game, dt)
			return
		"dropped": return
		"flee_rest":
			if not edible:
				state = "hunt"
				cooldown = 1.0
			timer -= dt
			# Cornered, it still fights back between its sprints.
			cooldown -= dt
			if strike_ready(game, distance):
				face(to_hole)
				wind_up(game)
			elif timer <= 0 and distance < ALERT + item.radius:
				state = "flee"
				timer = FLEE_DASH
				heading = inward(game, -to_hole/maxf(distance, 0.001))
				waypoint = Roads.project(game.layout, item.position + heading*FLEE_REACH)
		"flee":
			timer -= dt
			cooldown -= dt
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
	# Once the opening grace is over it hunts the hole wherever it is in the city.
	if threat < GUARD_REACH and away_from_home > RANGE*0.5: state = "home"
	elif distance < HUNT_RANGE or game.defense.grace <= 0: state = "hunt"
	elif distance > LOSE_RANGE: state = "patrol"
	hop_cooldown -= dt
	match state:
		"home": road_walk(game, home, HOME_SPEED, dt)
		"hunt": hunt(game, dt, to_hole, distance)
		_:
			if flat(waypoint - item.position).length() < 0.6: waypoint = next_waypoint(game)
			road_walk(game, waypoint, WALK_SPEED, dt)
	if state == "hop": return
	if distance < HUNT_RANGE: face(to_hole)
	if strike_ready(game, distance): wind_up(game)

func strike_ready(game, distance: float) -> bool:
	return cooldown <= 0 and distance < RANGE + item.radius and game.defense.grace <= 0

func wind_up(game) -> void:
	state = "windup"
	timer = WINDUP
	aim = predict(game)

# Where the hole will be when the strike lands, if it keeps its course.
func predict(game) -> Vector3:
	var warning: float = MascotAttacks.WARNING*game.defense.warning_scale
	var ahead: Vector3 = flat(game.hole_velocity*warning*LEAD).limit_length(MAX_LEAD)
	var target: Vector3 = flat(game.hole_position) + ahead
	target.x = clampf(target.x, -game.layout.move_x, game.layout.move_x)
	target.z = clampf(target.z, -game.layout.move_z, game.layout.move_z)
	return target

# Circle the hole at the style's range along the shortest street route, or hop
# over the roofs when the streets go the long way round.
func hunt(game, dt: float, to_hole: Vector3, distance: float) -> void:
	circle += dt*CIRCLE_SPEED
	var standoff: float = maxf(float(STANDOFF.get(spec.get("attack", "stomp"), 5.0)), game.radius + item.radius*0.5)
	var back := -to_hole/distance if distance > 0.01 else Vector3.BACK
	var spot: Vector3 = game.hole_position + back.rotated(Vector3.UP, sin(circle)*CIRCLE_SWING)*standoff
	spot.y = home.y
	# A hole far across the city is closed on with long hops over the roofs.
	if hop_cooldown <= 0.0 and distance >= HOP_REACH:
		start_hop(game, item.position + to_hole/distance*minf(HOP_REACH, distance - standoff))
		return
	if hop_cooldown <= 0.0 and distance < HOP_REACH and distance > standoff + 2.0 \
			and Roads.plan(game.layout, item.position, game.hole_position).length > distance*HOP_DETOUR:
		start_hop(game, spot)
		return
	var route: Dictionary = Roads.plan(game.layout, item.position, spot)
	var goal: Vector3 = Roads.project(game.layout, spot)
	if flat(goal - item.position).length() > 0.3: step_to(route.next, HUNT_SPEED, dt)

func start_hop(game, spot: Vector3) -> void:
	state = "hop"
	timer = 0.0
	leap_start = item.position
	aim = Roads.project(game.layout, spot)
	squash = 1.0
	game.fx.puff(item.position, item.radius*0.6, 1.0)

# Over a block in one arc, landing on the street beside the hole, then a quick strike.
func hop(game, dt: float) -> void:
	timer += dt
	var t := clampf(timer/HOP_TIME, 0.0, 1.0)
	item.position = leap_start.lerp(aim, t)
	air = sin(t*PI)
	item.position.y = home.y + air*maxf(HOP_HEIGHT, item.radius*2.0)
	face(aim - leap_start)
	if t < 1.0: return
	item.position.y = home.y
	air = 0.0
	squash = 1.0
	state = "hunt"
	hop_cooldown = HOP_COOLDOWN
	cooldown = minf(cooldown, HOP_STRIKE)
	game.fx.ripple(item.position, item.radius*1.4, attack_color())
	game.fx.shake = maxf(game.fx.shake, 0.25)

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

# Near the map edge a throw or an escape bends toward the middle, so the
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
	step_to(Roads.next_point(game.layout, item.position, target), speed, dt)

func step_to(corner: Vector3, speed: float, dt: float) -> void:
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
		"squash":squash, "air":air, "hurt":hurt, "flail":flail if state == "cling" else 0.0})
