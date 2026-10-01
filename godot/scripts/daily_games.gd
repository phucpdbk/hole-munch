extends Node3D

# Daily mini-games, one per day (campaign.gd picks the type from the date):
#   stampede - fast ducks scatter from the hole; catch as many as you can.
#   coinrain - coins rain down near the hole, with a few bombs mixed in.
#   goldrush - only golden treasure scores, raced by the rival hole.
# The landmark, its guardian and the defence squads sit the round out. game.gd
# owns the items; this node adds the game's own items when the city is built,
# moves them, counts catches and draws the shadows of falling coins.
const Traffic = preload("res://scripts/traffic.gd")
const I18n = preload("res://scripts/i18n.gd")
const SECONDS := {"stampede":45.0, "coinrain":45.0, "goldrush":60.0}
const TARGET := {"stampede":15, "coinrain":24, "goldrush":30}
# Coins paid per catch (gold pays per value point).
const COIN_RATE := {"stampede":6, "coinrain":4, "goldrush":4}
const ICON := {"stampede":"target", "coinrain":"coin", "goldrush":"chest"}
const STAR_SHARES := [0.5, 1.0, 1.5]
# Ducks rest, then sprint away from a nearby hole; a sprint is faster than the
# hole but short, so cornering a duck pays off.
const DUCKS := 24
const DUCK_SIZE := 0.46
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
# Gold rush treasure: [variant, radius, value, count].
const GOLD := [[0, 0.32, 1, 20], [1, 0.95, 3, 7], [2, 1.7, 8, 3]]

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

static func title(type: String) -> String:
	return I18n.t("dg_" + type)

static func goal_line(type: String) -> String:
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
			for i in DUCKS:
				var duck: Dictionary = game.add_item("duck", road_spot(game, 6.0), DUCK_SIZE, 0, rng.randf_range(0, TAU))
				duck.prey = true
				prey.append(duck)
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

# The landmark, its guardian and every defender sit out the mini-game.
func reset(game) -> void:
	count = 0
	clock = 0.0
	rng.seed = seed_value + 1
	next_coin = 1.0
	next_bomb = BOMB_EVERY
	for item in game.items:
		if item.get("is_boss", false) or item.get("defender", false) or item.get("guardian", false) or item.get("pylon", false):
			item.hidden = true
			game.set_item_transform(item)
	for duck in prey:
		duck.phase = "rest"
		duck.timer = rng.randf_range(0.0, DUCK_REST.y)
		duck.heading = Vector3.ZERO
	for drop in sky: park(game, drop)
	for marker in markers: marker.visible = false

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
		for duck in prey: move_duck(game, duck, dt)
	elif kind == "coinrain":
		update_rain(game, dt)

func move_duck(game, duck: Dictionary, dt: float) -> void:
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
		duck.position += duck.heading*DUCK_SPEED*dt
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
	if not item.get("prey", false): return
	var value := int(item.get("value", 1))
	count += value
	game.add_floater(item.position, "+%d" % value if value > 1 else "+1", true)
	game.sfx.play("grow")

func done() -> bool:
	return kind == "stampede" and prey.all(func(duck): return not Traffic.is_active(duck))

func reached() -> bool:
	return count >= target()

func stars() -> int:
	var total := 0
	for share in STAR_SHARES:
		if count >= ceili(target()*share): total += 1
	return total

func goal_labels() -> Array:
	return STAR_SHARES.map(func(share): return I18n.t("dg_count_" + kind, ceili(target()*share)))

func reward(coin_mul: float) -> int:
	return roundi(count*COIN_RATE.get(kind, 1)*coin_mul)

# Minimap dots for what still scores.
func dots() -> Array:
	var list: Array = []
	for item in prey + sky:
		if item.get("prey", false) and Traffic.is_active(item) and item.get("falling", 0.0) <= 0:
			list.append(Vector2(item.position.x, item.position.z))
	return list
