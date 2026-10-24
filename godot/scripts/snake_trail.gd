extends Node3D

# Daily mini-game "snake" (daily_games.gd), the classic snake on city streets:
# the saucer never stops (steer keeps the last direction), FRUITS sit on the
# roads, and each one eaten adds a glowing orb to the saucer's tail, which
# follows the hole's own path ORB_GAP apart. Running the hole into its tail,
# past the first SAFE_ORBS, ends the run. A fruit eaten comes back elsewhere,
# farther from the hole the longer the tail.
const I18n = preload("res://scripts/i18n.gd")
const Traffic = preload("res://scripts/traffic.gd")
const FRUITS := 3
const FRUIT_SIZE := 0.42
const ORB_GAP := 0.9
const ORB_SIZE := 0.3
const MAX_ORBS := 60
const SAFE_ORBS := 4
# The tail bites when the hole's centre comes this close (a share of its radius).
const BITE_SHARE := 0.55
const STEP := 0.15
const NEAR := 6.0
const FAR := Vector2(12.0, 22.0)

var fruits: Array = []
var orbs: Array[MeshInstance3D] = []
var trail: Array[Vector3] = []
var length := 0
var crashed := false
var time := 0.0
var heading := Vector2.ZERO
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	var ball := SphereMesh.new()
	ball.radius = ORB_SIZE
	ball.height = ORB_SIZE*2
	ball.radial_segments = 12
	ball.rings = 6
	for i in MAX_ORBS:
		var orb := MeshInstance3D.new()
		orb.mesh = ball
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# The tail fades from the saucer's violet to cyan at its end.
		material.albedo_color = Color("b98cff").lerp(Color("5ce1e6"), float(i % 12)/11.0)
		orb.material_override = material
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.visible = false
		add_child(orb)
		orbs.append(orb)

func build(game, seed_value: int) -> void:
	fruits.clear()
	rng.seed = seed_value
	for i in FRUITS:
		var fruit: Dictionary = game.add_item("fruit", game.SPAWN, FRUIT_SIZE, i % 3, rng.randf_range(0, TAU))
		fruit.prey = true
		fruits.append(fruit)

func reset(game) -> void:
	length = 0
	crashed = false
	heading = Vector2.ZERO
	time = 0.0
	# The round starts at the spawn point (the hole may not be back there yet).
	trail = [Vector3(game.spawn.x, 0, game.spawn.z)]
	for fruit in fruits: place(game, fruit, game.spawn)
	for orb in orbs: orb.visible = false

func clear() -> void:
	for orb in orbs: orb.visible = false

# A fruit on a road: near the hole at first, farther as the tail grows.
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
	for i in MAX_ORBS:
		orbs[i].visible = i < length
		if i < length: orbs[i].position = orb_at(i) + Vector3(0, 0.35 + sin(time*6.0 - i*0.6)*0.06, 0)
	if crashed or not game.started: return
	for i in range(SAFE_ORBS, length):
		if flat_gap(orb_at(i), game.hole_position) < game.radius*BITE_SHARE:
			crashed = true
			game.add_floater(game.hole_position, I18n.t("snake_crash"), false)
			game.fx.puff(game.hole_position, 0.8, 1.0)
			game.sfx.play("shot")
			return

# Keeps the hole's path as points STEP apart, as long as the tail needs.
func record(at: Vector3) -> void:
	var flat := Vector3(at.x, 0, at.z)
	var last: Vector3 = trail[-1]
	while flat_gap(flat, last) >= STEP:
		last = last + (flat - last).normalized()*STEP
		trail.append(last)
	var keep := int((MAX_ORBS + 1)*ORB_GAP/STEP) + 2
	if trail.size() > keep: trail = trail.slice(trail.size() - keep)

# Orb i sits (i + 1) gaps back along the path, or at its oldest point.
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
	game.add_floater(item.position, "+1", true)
	game.sfx.play("grow")
	return true

func done() -> bool:
	return crashed

func note() -> String:
	return I18n.t("snake_note", length)
