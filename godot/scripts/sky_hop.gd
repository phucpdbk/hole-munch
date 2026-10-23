extends Node3D

# Daily mini-game "skyhop" (daily_games.gd): a side view high above the city.
# The player's own craft flies right on its own; gravity pulls it down and every
# tap gives it a hop. Gaps open between towers rising from the street and storm
# clouds hanging from the sky, and each gap flown through scores. The gaps narrow
# over the first NARROW_BY, and from SWAY_FROM on some drift up and down.
# Touching a tower, a cloud or the street ends the run. The course is the same
# for every try of a day (seeded), floats ALTITUDE above the city and has its
# own camera, which game.gd makes current for the round.
const ALTITUDE := 400.0
const CEILING := 16.0
const GRAVITY := 30.0
const HOP := 10.5
const FALL_MAX := 15.0
const SPEED := 4.6
# Hit radius of the craft (a little inside the model, to feel fair).
const RADIUS := 0.5
const CRAFT_SCALE := 0.8
const START_Y := 8.0
const FIRST := 10.0
const SPACING := 6.4
const WIDTH := 1.8
# Gap height at the first gate and from NARROW_BY on.
const GAP_START := 5.4
const GAP_END := 4.0
const NARROW_BY := 25
# Gap centres stay between these heights and move at most STEP_MAX per gate.
const GAP_LOW := 4.0
const GAP_HIGH := 12.0
const STEP_MAX := 4.5
const SWAY_FROM := 12
const SWAY_SHARE := 0.4
const SWAY := 1.0
# The cloud puffs hang this far below the cloud column.
const PUFF_DIP := 0.2
const POOL := 8
# The view shows at least this much height (landscape) and width (portrait).
const VIEW_HEIGHT := 18.0
const VIEW_WIDTH := 12.0
const CRASH_TIME := 0.8
const SKYLINE := 16
const SKY_STEP := 3.0
const WALLS := ["c98f6b", "6f8fb0", "d0a35a", "7f9a6a", "a07aa8"]

var rng := RandomNumberGenerator.new()
var seed_value := 0
var gaps: Array[Dictionary] = []
var x := 0.0
var y := START_Y
var vy := 0.0
var running := false
var crashed := false
var crash_clock := 0.0
var passed := 0
var clock := 0.0
var camera: Camera3D
var craft: MeshInstance3D
var ground: MeshInstance3D
var gates: Array[Dictionary] = []
var skyline: Array[MeshInstance3D] = []

# A tap or Space during a round (emulated mouse clicks from touches count once).
static func is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch: return event.pressed
	if event is InputEventMouseButton: return event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION
	return event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]

# --- setup -----------------------------------------------------------------------

func build(game, value: int) -> void:
	seed_value = value
	if not is_instance_valid(camera): make_nodes()
	craft.mesh = game.saucer.mesh
	var palette: Array = game.palette
	ground.material_override = flat(Color(palette[3]).darkened(0.15))
	for i in gates.size():
		gates[i].tower.material_override = flat(Color(WALLS[i % WALLS.size()]))
		gates[i].roof.material_override = flat(Color(palette[6 + i % 2]))
	var haze := Color(palette[5]).lerp(Color("8fa7b8"), 0.5)
	for i in skyline.size():
		skyline[i].material_override = flat(haze.darkened(0.05*(i % 3)))
	visible = false

func make_nodes() -> void:
	position = Vector3(0, ALTITUDE, 0)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 100.0
	add_child(camera)
	craft = MeshInstance3D.new()
	craft.scale = Vector3.ONE*CRAFT_SCALE
	add_child(craft)
	ground = box(Vector3(400, 1, 8))
	var cloud := flat(Color("5d6078"))
	var puff := SphereMesh.new()
	puff.radius = 0.55
	puff.height = 1.1
	for i in POOL:
		var gate := {"tower":box(Vector3.ONE), "roof":box(Vector3.ONE), "cloud":box(Vector3.ONE), "puffs":[]}
		gate.cloud.material_override = cloud
		for p in 3:
			var ball := MeshInstance3D.new()
			ball.mesh = puff
			ball.material_override = cloud
			ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ball)
			gate.puffs.append(ball)
		gates.append(gate)
	var backdrop := RandomNumberGenerator.new()
	backdrop.seed = 911
	for i in SKYLINE:
		var block := box(Vector3(SKY_STEP*0.8, 1, 1))
		block.scale.y = backdrop.randf_range(3.0, 10.0)
		skyline.append(block)

func box(size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func reset() -> void:
	rng.seed = seed_value
	gaps.clear()
	x = 0.0
	y = START_Y
	vy = 0.0
	running = false
	crashed = false
	crash_clock = 0.0
	passed = 0
	clock = 0.0
	place()

# --- course ------------------------------------------------------------------------

# Gate i, made on first use so the course never runs out.
func gap_at(i: int) -> Dictionary:
	while gaps.size() <= i:
		var n := gaps.size()
		var last: float = gaps[n - 1].y if n > 0 else START_Y
		# Drawn inside the band rather than clamped to it, so gaps never sit in a flat row at an edge.
		gaps.append({"x":FIRST + n*SPACING, "y":rng.randf_range(maxf(GAP_LOW, last - STEP_MAX), minf(GAP_HIGH, last + STEP_MAX)),
			"size":lerpf(GAP_START, GAP_END, minf(1.0, float(n)/NARROW_BY)),
			"sway":n >= SWAY_FROM and rng.randf() < SWAY_SHARE, "phase":rng.randf_range(0, TAU)})
	return gaps[i]

func centre(gap: Dictionary) -> float:
	return gap.y + (sin(clock*1.6 + gap.phase)*SWAY if gap.sway else 0.0)

# Whether the craft touches the tower or the cloud of a gate.
func hits(gap: Dictionary) -> bool:
	var dx := maxf(0.0, absf(x - gap.x) - WIDTH*0.5)
	if dx >= RADIUS: return false
	var middle := centre(gap)
	var below := maxf(0.0, y - (middle - gap.size*0.5))
	var above := maxf(0.0, (middle + gap.size*0.5 - PUFF_DIP) - y)
	return dx*dx + below*below < RADIUS*RADIUS or dx*dx + above*above < RADIUS*RADIUS

# --- round -------------------------------------------------------------------------

func flap(game) -> void:
	if crashed: return
	running = true
	vy = HOP
	game.sfx.play("pop5", 1.4)

func update(game, dt: float) -> void:
	if not running:
		clock += dt
		y = START_Y + sin(clock*3.0)*0.3
		place()
		return
	vy = maxf(vy - GRAVITY*dt, -FALL_MAX)
	y += vy*dt
	if crashed:
		crash_clock += dt
		y = maxf(RADIUS*0.5, y)
		craft.rotation.z -= dt*9.0
		place()
		return
	clock += dt
	x += SPEED*dt
	if y > CEILING - RADIUS:
		y = CEILING - RADIUS
		vy = minf(vy, 0.0)
	while x - RADIUS > gap_at(passed).x + WIDTH*0.5:
		passed += 1
		game.score += 10
		game.sfx.play("grow")
	var behind := passed > 0 and hits(gap_at(passed - 1))
	if y - RADIUS <= 0.0 or hits(gap_at(passed)) or behind:
		crashed = true
		vy = minf(vy, 2.0)
		game.sfx.play("shot")
	place()

func done() -> bool:
	return crashed and crash_clock >= CRASH_TIME

# --- view --------------------------------------------------------------------------

func place() -> void:
	if not is_instance_valid(camera): return
	craft.position = Vector3(x, y, 0)
	if not crashed: craft.rotation = Vector3(0, clock*2.0, clampf(vy*0.04, -0.5, 0.35))
	var first := maxi(0, int((x - FIRST)/SPACING) - 2)
	for i in POOL:
		var index := first + i
		var gap := gap_at(index)
		var gate: Dictionary = gates[index % POOL]
		var middle := centre(gap)
		var low: float = middle - gap.size*0.5
		var high: float = middle + gap.size*0.5
		gate.tower.position = Vector3(gap.x, (low - 1.0)*0.5, 0)
		gate.tower.scale = Vector3(WIDTH, low + 1.0, WIDTH)
		gate.roof.position = Vector3(gap.x, low - 0.15, 0)
		gate.roof.scale = Vector3(WIDTH + 0.3, 0.3, WIDTH + 0.3)
		gate.cloud.position = Vector3(gap.x, (high + 0.3 + 30.0)*0.5, 0)
		gate.cloud.scale = Vector3(WIDTH, 30.0 - high - 0.3, WIDTH*0.8)
		for p in 3:
			gate.puffs[p].position = Vector3(gap.x + (p - 1)*0.6, high + 0.55 - PUFF_DIP, 0.1)
	ground.position = Vector3(x, -0.5, 0)
	var span := SKYLINE*SKY_STEP
	for i in skyline.size():
		var block := skyline[i]
		block.position = Vector3(x + wrapf(i*SKY_STEP - x*0.5, -span*0.4, span*0.6), block.scale.y*0.5, -10.0)

# Shows the course and makes its camera current, or hands the view back.
func show_view(on: bool) -> void:
	visible = on
	if not on or not is_instance_valid(camera): return
	var screen := get_viewport().get_visible_rect().size
	var aspect := screen.x/maxf(1.0, screen.y)
	camera.size = maxf(VIEW_HEIGHT, VIEW_WIDTH/aspect)
	camera.position = Vector3(x + camera.size*aspect*0.22, CEILING*0.5, 30.0)
	if not camera.current: camera.make_current()
