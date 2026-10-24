extends Node3D

# Daily mini-game "redlight" (daily_games.gd), red light, green light: snacks
# lie all over the streets and a light ring round the hole says when it may
# move. Green: eat. Yellow (YELLOW seconds): stop now. Red: the saucer must
# stand still; moving faster than STILL after the REACT grace is a strike,
# costing CAUGHT_COST points and a FREEZE. MAX_STRIKES strikes end the run.
# The red light comes sooner and stays longer the more the hole has eaten.
const I18n = preload("res://scripts/i18n.gd")
const SNACKS := 44
const SNACK_SIZE := 0.42
# [variant, value, count]: apples and oranges, and watermelons worth more.
const KINDS := [[0, 1, 20], [1, 1, 16], [2, 3, 8]]
const GREEN := Vector2(2.4, 5.0)
const YELLOW := 0.8
const RED := Vector2(1.5, 3.0)
const REACT := 0.3
const STILL := 0.6
const CAUGHT_COST := 3
const FREEZE := 1.2
const MAX_STRIKES := 3
const COLORS := {"green":Color("3ddc84"), "yellow":Color("ffd23f"), "red":Color("ff4d4d")}

var snacks: Array = []
var phase := "green"
var timer := 0.0
var since := 0.0
var strikes := 0
var freeze := 0.0
var eaten := 0
var ring: MeshInstance3D
var ring_material: StandardMaterial3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.22
	ring.mesh = torus
	ring_material = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)

func build(game, seed_value: int) -> void:
	snacks.clear()
	rng.seed = seed_value
	for entry in KINDS:
		for i in entry[2]:
			var snack: Dictionary = game.add_item("fruit", game.daily.road_spot(game, 4.0), SNACK_SIZE, entry[0], rng.randf_range(0, TAU))
			snack.prey = true
			snack.value = entry[1]
			snacks.append(snack)

func reset() -> void:
	strikes = 0
	freeze = 0.0
	eaten = 0
	set_phase("green", rng.randf_range(GREEN.x, GREEN.y))
	ring.visible = true

func clear() -> void:
	ring.visible = false

func set_phase(value: String, seconds: float) -> void:
	phase = value
	timer = seconds
	since = 0.0
	ring_material.albedo_color = Color(COLORS[phase], 0.85)

# Later lights: greens shorten and reds lengthen as snacks go down.
func pressure() -> float:
	return clampf(eaten/30.0, 0.0, 1.0)

func update(game, dt: float) -> void:
	freeze = maxf(0.0, freeze - dt)
	ring.position = Vector3(game.hole_position.x, 0.25, game.hole_position.z)
	ring.scale = Vector3.ONE*game.radius*(1.0 + (sin(since*14.0)*0.06 if phase != "green" else 0.0))
	if not game.started: return
	timer -= dt
	since += dt
	if timer <= 0: advance(game)
	if phase != "red" or since < REACT or freeze > 0: return
	var speed := Vector2(game.hole_velocity.x, game.hole_velocity.z).length()
	if speed > STILL: strike(game)

func advance(game) -> void:
	match phase:
		"green":
			set_phase("yellow", YELLOW)
			game.sfx.play("tick", 1.2)
		"yellow":
			set_phase("red", rng.randf_range(RED.x, RED.y)*(1.0 + pressure()*0.4))
			game.add_floater(game.hole_position, I18n.t("light_red"), false)
			game.sfx.play("tick", 0.6)
		_:
			set_phase("green", rng.randf_range(GREEN.x, GREEN.y)*(1.0 - pressure()*0.35))
			game.add_floater(game.hole_position, I18n.t("light_green"), true)

func strike(game) -> void:
	strikes += 1
	freeze = FREEZE
	game.daily.count = maxi(0, game.daily.count - CAUGHT_COST)
	game.add_floater(game.hole_position, I18n.t("light_caught", CAUGHT_COST), false)
	game.fx.puff(game.hole_position, 0.8, 1.0)
	game.fx.shake = maxf(game.fx.shake, 0.4)
	game.sfx.play("shot")

func caught(game, item: Dictionary) -> int:
	if not item in snacks: return 0
	eaten += 1
	var value := int(item.get("value", 1))
	game.add_floater(item.position, "+%d" % value, true)
	game.sfx.play("grow")
	return value

# Caught on red, the saucer is frozen for a moment.
func speed_scale() -> float:
	return 0.0 if freeze > 0 else 1.0

func done() -> bool:
	return strikes >= MAX_STRIKES or snacks.all(func(snack): return snack.eaten or snack.fall >= 0)

func note() -> String:
	return I18n.t("light_note_" + phase, [MAX_STRIKES - strikes])
