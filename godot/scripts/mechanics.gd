extends Node3D

# Arcade twists on the eat-and-grow loop: shield pylons that guard the landmark,
# timed pickups, hunger, bombs, and weather that changes handling. game.gd owns
# the items; this node only adds pylons/bombs, draws the pickup and shield, and
# answers questions such as "may the boss be eaten yet?".
const Traffic = preload("res://scripts/traffic.gd")
const PYLONS := 4
const PYLON_SIZE := 0.9
const PYLON_GAP := 0.9
const BOMBS := 3
const BOMB_SIZE := 0.42
# Below this hole radius a bomb stuns you; from it up, the blast feeds you.
const BOMB_SAFE := 1.7
const BOMB_STUN := 1.0
const BOMB_SECONDS := 3.0
const BLAST_REACH := 2.4
const HUNGER_DELAY := 3.0
const HUNGER_RATE := 0.06
const HUNGER_KEEP := 0.8
const PICKUP_FIRST := 6.0
const PICKUP_GAP := Vector2(7.0, 11.0)
const PICKUP_LIFE := 8.0
const POWER_TIME := 5.0
const TIME_PICKUP := 5.0
const FREEZE_TIME := 4.0
const SPEED_BOOST := 1.4
const MAGNET_BOOST := 3
const I18n = preload("res://scripts/i18n.gd")
# Pickup kind -> [i18n key of its callout, orb colour].
const PICKUPS := {
	"time":["pk_time", Color("ffd35c")], "magnet":["pk_magnet", Color("c69bff")],
	"speed":["pk_speed", Color("62ead3")], "freeze":["pk_freeze", Color("9fdcff")],
}
# Weather handling: grip is how fast the hole reaches the stick direction.
const SLIPPERY := ["rain", "storm", "snow"]
const WINDY := ["wind", "storm"]
const SLIP_GRIP := 3.2
const WIND_PUSH := 0.9
const FOG_VIEW := 0.8
# Weather with a handling note (i18n keys wn_<kind>).
const WEATHER_NOTES := ["rain", "snow", "wind", "storm", "fog"]

var pylons: Array = []
var boss: Dictionary = {}
var weather := "clear"
var rng := RandomNumberGenerator.new()
var pickup := {}
var pickup_timer := PICKUP_FIRST
var powers := {"magnet":0.0, "speed":0.0}
var stun := 0.0
var glide := Vector3.ZERO
var hunger := 0.0
var hungry := false
var peak_radius := 0.0
var shield: MeshInstance3D
var shield_material: StandardMaterial3D
var orb: Node3D
var orb_material: StandardMaterial3D
var orb_label: Label3D

func _ready() -> void:
	shield = MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.is_hemisphere = true
	dome.radius = 1.0
	dome.height = 1.0
	shield.mesh = dome
	shield_material = StandardMaterial3D.new()
	shield_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shield_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield_material.albedo_color = Color(0.45, 0.85, 1.0, 0.18)
	shield.material_override = shield_material
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shield)
	orb = Node3D.new()
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	ball.mesh = sphere
	orb_material = StandardMaterial3D.new()
	orb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball.material_override = orb_material
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(ball)
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.62
	ring.outer_radius = 0.72
	halo.mesh = ring
	halo.material_override = orb_material
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(halo)
	orb_label = Label3D.new()
	orb_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	orb_label.font_size = 64
	orb_label.outline_size = 16
	orb_label.pixel_size = 0.012
	orb_label.position.y = 1.0
	orb_label.no_depth_test = true
	orb.add_child(orb_label)
	add_child(orb)
	orb.visible = false

# --- level setup (called by game.gd after the boss is sized) ---------------------

func setup(game, landmark: bool, seed_value: int) -> void:
	pylons.clear()
	boss = game.items[game.boss_index]
	if landmark: place_pylons(game)
	place_bombs(game, seed_value)

# Shield pylons ring the landmark just outside its footprint, each with a guard.
func place_pylons(game) -> void:
	pylons.clear()
	boss = game.items[game.boss_index]
	var home: Vector3 = boss.origin
	var ring: float = game.boss_radius + PYLON_GAP
	for i in PYLONS:
		var a := PI/4 + i*TAU/PYLONS
		var at := home + Vector3(cos(a)*ring, 0, sin(a)*ring)
		var pylon: Dictionary = game.add_item("pylon", Vector3(at.x, 0.16, at.z), PYLON_SIZE)
		pylon.pylon = true
		pylons.append(pylon)
		var guard: Dictionary = game.add_item("soldier", Vector3(at.x*1.08, 0.16, at.z*1.08 + 0.6), 0.36)
		guard.defender = true
		game.total_points += game.base_points(pylon) + game.base_points(guard)

# Bombs sit on road centre lines, away from the spawn and the landmark.
func place_bombs(game, seed_value: int) -> void:
	var picker := RandomNumberGenerator.new()
	picker.seed = seed_value
	var placed := 0
	var tries := 0
	while placed < BOMBS and tries < 60:
		tries += 1
		var along_x := picker.randf() < 0.5
		var line: float = game.layout.crossings_x[picker.randi()%game.layout.crossings_x.size()] if along_x else game.layout.crossings_z[picker.randi()%game.layout.crossings_z.size()]
		var free := picker.randf_range(-0.8, 0.8)
		var at := Vector3(line, 0.16, free*game.layout.move_z) if along_x else Vector3(free*game.layout.move_x, 0.16, line)
		if at.distance_to(game.SPAWN) < 5.0 or at.distance_to(game.BOSS_HOME) < game.boss_radius + 3.0: continue
		var bomb: Dictionary = game.add_item("bomb", at, BOMB_SIZE)
		bomb.bomb = true
		bomb.optional = true
		placed += 1

func reset(level_weather: String, seed_value: int) -> void:
	weather = level_weather
	rng.seed = seed_value
	pickup = {}
	pickup_timer = PICKUP_FIRST
	powers = {"magnet":0.0, "speed":0.0}
	stun = 0.0
	glide = Vector3.ZERO
	hunger = 0.0
	hungry = false
	peak_radius = 0.0
	orb.visible = false
	if not boss.is_empty(): boss.shielded = not pylons.is_empty()

func weather_note() -> String:
	return I18n.t("wn_" + weather) if weather in WEATHER_NOTES else ""

# --- per-frame rules -----------------------------------------------------------

func shield_up() -> bool:
	return pylons.any(func(pylon): return not pylon.eaten and pylon.fall < 0)

func update(game, dt: float) -> void:
	stun = maxf(0.0, stun-dt)
	for key in powers: powers[key] = maxf(0.0, powers[key]-dt)
	if not boss.is_empty() and boss.get("shielded", false) and not shield_up():
		boss.shielded = false
		game.add_floater(boss.position, I18n.t("shield_down"), true)
		game.fx.ripple(boss.position, game.boss_radius*1.2, Color("9fdcff"))
		game.sfx.play("grow")
	update_hunger(game, dt)
	update_pickup(game, dt)

# Going too long without a bite starves the hole back toward its start size, but
# never below HUNGER_KEEP of its best size this round: a map whose food runs thin
# late must stay winnable.
func update_hunger(game, dt: float) -> void:
	hunger += dt
	peak_radius = maxf(peak_radius, game.target_radius)
	var floor_radius := maxf(float(game.stats.start_radius), peak_radius*HUNGER_KEEP)
	hungry = hunger > HUNGER_DELAY and game.target_radius > floor_radius + 0.01
	if hungry: game.target_radius = maxf(floor_radius, game.target_radius*(1.0-HUNGER_RATE*dt))

func fed() -> void:
	hunger = 0.0

func update_pickup(game, dt: float) -> void:
	if pickup.is_empty():
		pickup_timer -= dt
		if pickup_timer <= 0: spawn_pickup(game)
		return
	pickup.life -= dt
	var bob: float = sin(game.elapsed*3.0)*0.2
	orb.position = pickup.position + Vector3(0, 1.1 + bob, 0)
	orb.rotation.y = game.elapsed*1.5
	# Blink during the last two seconds so the player knows it is leaving.
	orb.visible = pickup.life > 2.0 or fmod(pickup.life, 0.3) > 0.12
	var reach: float = game.radius + 0.45
	if Vector2(pickup.position.x-game.hole_position.x, pickup.position.z-game.hole_position.z).length() < reach:
		collect(game)
	elif pickup.life <= 0:
		clear_pickup()

func spawn_pickup(game) -> void:
	var xs: Array = game.layout.crossings_x
	var zs: Array = game.layout.crossings_z
	var at := Vector3.ZERO
	for attempt in 8:
		at = Vector3(xs[rng.randi()%xs.size()], 0.16, zs[rng.randi()%zs.size()])
		if Vector2(at.x-game.hole_position.x, at.z-game.hole_position.z).length() > 4.0: break
	var kinds: Array = PICKUPS.keys().filter(func(k): return k != "time" or game.clock_can_grow())
	var kind: String = kinds[rng.randi()%kinds.size()]
	pickup = {"kind":kind, "position":at, "life":PICKUP_LIFE}
	var color: Color = PICKUPS[kind][1]
	orb_material.albedo_color = color
	orb_label.text = I18n.t(PICKUPS[kind][0])
	orb_label.modulate = color.lightened(0.3)
	orb.visible = true

func collect(game) -> void:
	var kind: String = pickup.kind
	match kind:
		"time":
			game.remaining += TIME_PICKUP
			game.bonus_seconds += TIME_PICKUP
		"magnet", "speed": powers[kind] = POWER_TIME
		"freeze": game.defense.grace = maxf(game.defense.grace, FREEZE_TIME)
	game.add_floater(pickup.position, I18n.t(PICKUPS[kind][0]) + "!", true)
	game.fx.ripple(pickup.position, 1.2, PICKUPS[kind][1])
	game.sfx.play("grow")
	clear_pickup()

func clear_pickup() -> void:
	pickup = {}
	pickup_timer = rng.randf_range(PICKUP_GAP.x, PICKUP_GAP.y)
	orb.visible = false

# A bomb stuns a small hole; a big one turns the blast into a feeding frenzy.
func explode(game, bomb: Dictionary) -> void:
	game.fx.burst(bomb.position, game.radius)
	game.sfx.play("shot")
	if game.radius < BOMB_SAFE:
		stun = BOMB_STUN
		game.remaining = maxf(0.0, game.remaining-BOMB_SECONDS)
		game.combo = 0
		game.combo_time = 0.0
		game.add_floater(game.hole_position, I18n.t("bomb_stun"), true)
		return
	var reach: float = game.radius*BLAST_REACH
	var blast: Array = game.items.filter(func(item):
		return not item.eaten and item.fall < 0 and Traffic.is_active(item) and not item.get("is_boss", false) \
			and not item.get("bomb", false) and item.radius <= game.radius*game.EAT_RATIO \
			and Vector2(item.position.x-bomb.position.x, item.position.z-bomb.position.z).length() < reach)
	for item in blast: game.swallow(item)
	game.add_floater(game.hole_position, I18n.t("bomb_feast", blast.size()), true)
	game.fx.ripple(bomb.position, reach, Color("ffb347"))

# --- handling ------------------------------------------------------------------

func speed_multiplier() -> float:
	if stun > 0: return 0.0
	return SPEED_BOOST if powers.speed > 0 else 1.0

func magnet_bonus() -> int:
	return MAGNET_BOOST if powers.magnet > 0 else 0

# Slippery weather eases toward the stick; wind adds a slow, turning drift.
# The glide is kept apart from the wind so the drift never accumulates.
func steer(wanted: Vector3, dt: float, clock: float) -> Vector3:
	glide = glide.lerp(wanted, 1.0-exp(-dt*SLIP_GRIP)) if weather in SLIPPERY else wanted
	if weather not in WINDY or stun > 0: return glide
	var angle := clock*0.15
	return glide + Vector3(cos(angle), 0, sin(angle))*WIND_PUSH

func view_scale() -> float:
	return FOG_VIEW if weather == "fog" else 1.0

func sync_shield(game) -> void:
	var up: bool = not boss.is_empty() and boss.get("shielded", false) and not boss.eaten and boss.fall < 0
	shield.visible = up and game.mode in ["playing", "paused", "menu"]
	if not shield.visible: return
	var size: float = game.boss_radius*1.25
	shield.position = Vector3(boss.position.x, 0.1, boss.position.z)
	shield.scale = Vector3(size, size*1.7, size)
	shield_material.albedo_color.a = 0.14 + 0.06*sin(game.elapsed*3.0)
