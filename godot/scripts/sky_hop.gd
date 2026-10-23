extends Node3D

# Daily mini-game "skyhop" (daily_games.gd): a side view high above the city.
# The default saucer flies right on its own, whatever craft is equipped (the
# others are bigger than the gaps and RADIUS are tuned for). Gravity pulls it
# down and every tap gives it a hop. Gaps open between towers rising from the street and storm
# clouds hanging from the sky, and each gap flown through scores. The gaps narrow
# over the first NARROW_BY, and from SWAY_FROM on some drift up and down.
# Touching a tower, a cloud or the street ends the run.
# The course is one long flight the same for everyone (seeded by its lap),
# MAP_GAPS gaps per map through the MAPS in turn, each with its own hazard on
# every other gap from its third: sand gusts that push the saucer up or down
# (desert), icicles that drop into a gap as the saucer nears (snow),
# searchlights sweeping from the tower roofs (night) and gulls bobbing between
# the gates (harbour). A run starts at the player's checkpoint
# (Campaign.checkpoint "skyhop", every CHECKPOINT_EVERY gaps); the full COURSE
# starts a new lap. It floats ALTITUDE above the city and has its own camera,
# which game.gd makes current for the round.
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
# The course: maps, checkpoints and laps.
const MAP_GAPS := 20
const CHECKPOINT_EVERY := 10
const COURSE := 100
const COURSE_SEED := 4049
const LAP_SEED_STEP := 7919
const HAZARD_FROM := 2
# Each map's colours and hazard.
const MAPS := [
	{"id":"rooftops", "hazard":"", "walls":["c98f6b", "6f8fb0", "d0a35a", "7f9a6a", "a07aa8"], "roof":"c0392b", "cloud":"5d6078", "ground":"7f9a6a", "haze":"9fb0bd"},
	{"id":"desert", "hazard":"wind", "walls":["d9a066", "c98a52", "e0b27a", "b8774a", "d9b98a"], "roof":"8c5a3a", "cloud":"b89a72", "ground":"e0c08a", "haze":"e8cfa0"},
	{"id":"snow", "hazard":"icicle", "walls":["dfe9f2", "b8cde0", "c9d6df", "a9bcd0", "eef3f7"], "roof":"5b7ea0", "cloud":"8fa3b8", "ground":"f4f8fb", "haze":"cfdbe6"},
	{"id":"night", "hazard":"beam", "walls":["3b3f6b", "4a3f6b", "2f3a5a", "553a6b", "3a4f6b"], "roof":"ff4fd8", "cloud":"2a2540", "ground":"20243a", "haze":"3a3f66"},
	{"id":"harbour", "hazard":"gull", "walls":["c0392b", "2a7ab0", "e9c46a", "2e8b57", "f4f1e6"], "roof":"f4f1e6", "cloud":"6c7a8a", "ground":"2f8fb8", "haze":"9fc5d8"},
]
# Desert gusts push up or down between the gates (units per second squared).
const WIND := 14.0
# Snow: an icicle drops this far into the gap once the saucer is ICICLE_RANGE away.
const ICICLE_DROP := 1.2
const ICICLE_RANGE := 4.5
const ICICLE_RATE := 4.0
# Night: a searchlight on the tower roof swings round BEAM_TILT by BEAM_SWING.
const BEAM_LENGTH := 7.0
const BEAM_TILT := -0.6
const BEAM_SWING := 0.9
const BEAM_SPEED := 1.2
# Harbour: a gull bobs between the gates.
const GULL_RADIUS := 0.35
const GULL_RANGE := 1.8
const GULL_SPEED := 2.0

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
# The gap this run started at (the checkpoint).
var first := 0
var clock := 0.0
var camera: Camera3D
var craft: MeshInstance3D
var ground: MeshInstance3D
var gates: Array[Dictionary] = []
var skyline: Array[MeshInstance3D] = []
var materials := {}

# A tap or Space during a round (emulated mouse clicks from touches count once).
static func is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch: return event.pressed
	if event is InputEventMouseButton: return event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION
	return event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]

static func course_seed(lap: int) -> int:
	return COURSE_SEED + lap*LAP_SEED_STEP

static func map_of(index: int) -> Dictionary:
	return MAPS[(index/MAP_GAPS) % MAPS.size()]

# --- setup -----------------------------------------------------------------------

func build(game, value: int) -> void:
	seed_value = value
	if not is_instance_valid(camera): make_nodes()
	if not game.craft_meshes.has(0): game.craft_meshes[0] = preload("res://scripts/fleet.gd").new().build(game.models, 0)
	craft.mesh = game.craft_meshes[0]
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
	var puff := SphereMesh.new()
	puff.radius = 0.55
	puff.height = 1.1
	var icicle := CylinderMesh.new()
	icicle.top_radius = 0.4
	icicle.bottom_radius = 0.0
	icicle.height = 1.0
	var gull_body := SphereMesh.new()
	gull_body.radius = GULL_RADIUS
	gull_body.height = GULL_RADIUS*1.6
	for i in POOL:
		var gate := {"tower":box(Vector3.ONE), "roof":box(Vector3.ONE), "cloud":box(Vector3.ONE), "puffs":[],
			"band":box(Vector3.ONE), "icicle":mesh_node(icicle), "beam":box(Vector3.ONE), "lamp":box(Vector3(0.5, 0.35, 0.5)),
			"gull":mesh_node(gull_body), "wings":[box(Vector3(0.7, 0.06, 0.25)), box(Vector3(0.7, 0.06, 0.25))],
			"streaks":[box(Vector3(0.12, 1.1, 0.1)), box(Vector3(0.12, 1.1, 0.1)), box(Vector3(0.12, 1.1, 0.1)), box(Vector3(0.12, 1.1, 0.1))]}
		for p in 3:
			var ball := mesh_node(puff)
			gate.puffs.append(ball)
		gate.band.material_override = glow(Color(0.7, 0.48, 0.22, 0.4))
		for streak in gate.streaks: streak.material_override = glow(Color(1.0, 0.95, 0.8, 0.8))
		gate.beam.material_override = glow(Color(1.0, 0.95, 0.55, 0.55))
		gate.lamp.material_override = flat(Color("ffd84a"))
		gate.icicle.material_override = flat(Color("d6f0ff"))
		gate.gull.material_override = flat(Color("f4f4f4"))
		for wing in gate.wings: wing.material_override = flat(Color("dfe6ea"))
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
	return mesh_node(mesh)

func mesh_node(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func flat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if materials.has(key): return materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	materials[key] = material
	return material

func glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

# Back to the checkpoint gap, hovering before the first tap.
func reset(start := 0) -> void:
	rng.seed = seed_value
	gaps.clear()
	first = maxi(0, start)
	passed = first
	x = gap_at(first).x - FIRST
	y = START_Y
	vy = 0.0
	running = false
	crashed = false
	crash_clock = 0.0
	clock = 0.0
	place()

# --- course ------------------------------------------------------------------------

# Gate i, made on first use so the course never runs out.
func gap_at(i: int) -> Dictionary:
	while gaps.size() <= i:
		var n := gaps.size()
		var last: float = gaps[n - 1].y if n > 0 else START_Y
		# Drawn inside the band rather than clamped to it, so gaps never sit in a flat row at an edge.
		var gap := {"x":FIRST + n*SPACING, "y":rng.randf_range(maxf(GAP_LOW, last - STEP_MAX), minf(GAP_HIGH, last + STEP_MAX)),
			"size":lerpf(GAP_START, GAP_END, minf(1.0, float(n)/NARROW_BY)),
			"sway":n >= SWAY_FROM and rng.randf() < SWAY_SHARE, "phase":rng.randf_range(0, TAU), "drop":0.0}
		var map := map_of(n)
		gap.hazard = map.hazard if n % MAP_GAPS >= HAZARD_FROM and n % 2 == 1 else ""
		gap.wind = WIND if rng.randf() < 0.5 else -WIND
		gaps.append(gap)
	return gaps[i]

func centre(gap: Dictionary) -> float:
	return gap.y + (sin(clock*1.6 + gap.phase)*SWAY if gap.sway else 0.0)

# Whether the craft touches the tower or the cloud of a gate (an icicle lowers the cloud).
func hits(gap: Dictionary) -> bool:
	var dx := maxf(0.0, absf(x - gap.x) - WIDTH*0.5)
	if dx >= RADIUS: return false
	var middle := centre(gap)
	var below := maxf(0.0, y - (middle - gap.size*0.5))
	var above := maxf(0.0, (middle + gap.size*0.5 - PUFF_DIP - float(gap.drop)) - y)
	return dx*dx + below*below < RADIUS*RADIUS or dx*dx + above*above < RADIUS*RADIUS

# The searchlight's beam: from the tower roof, at its swing angle (0 = straight up).
func beam_angle(gap: Dictionary) -> float:
	return BEAM_TILT + sin(clock*BEAM_SPEED + gap.phase)*BEAM_SWING

func beam_ends(gap: Dictionary) -> Array:
	var from := Vector2(gap.x, centre(gap) - gap.size*0.5)
	var angle := beam_angle(gap)
	return [from, from + Vector2(sin(angle), cos(angle))*BEAM_LENGTH]

func gull_at(gap: Dictionary) -> Vector2:
	return Vector2(gap.x - SPACING*0.5, centre(gap) + sin(clock*GULL_SPEED + gap.phase)*GULL_RANGE)

# Whether the gap's hazard catches the craft.
func hazard_hits(gap: Dictionary) -> bool:
	var at := Vector2(x, y)
	match gap.hazard:
		"beam":
			var ends := beam_ends(gap)
			return Geometry2D.get_closest_point_to_segment(at, ends[0], ends[1]).distance_to(at) < RADIUS*0.8
		"gull": return gull_at(gap).distance_to(at) < RADIUS + GULL_RADIUS
	return false

# Sand gusts blow between the previous gate and this one.
func in_wind(gap: Dictionary) -> bool:
	return gap.hazard == "wind" and x > gap.x - SPACING + WIDTH*0.5 + RADIUS and x < gap.x - WIDTH*0.5 - RADIUS

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
	if not crashed and in_wind(gap_at(passed)): vy += float(gap_at(passed).wind)*dt
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
	for k in range(passed, passed + 2):
		var gap := gap_at(k)
		if gap.hazard == "icicle":
			var due: float = ICICLE_DROP if x > gap.x - ICICLE_RANGE else 0.0
			gap.drop = move_toward(float(gap.drop), due, ICICLE_RATE*dt)
	while x - RADIUS > gap_at(passed).x + WIDTH*0.5:
		passed += 1
		game.score += 10
		game.sfx.play("grow")
		if passed % CHECKPOINT_EVERY == 0 and game.campaign.reach_checkpoint("skyhop", passed, COURSE): game.persist()
	var current := gap_at(passed)
	var behind := passed > 0 and hits(gap_at(passed - 1))
	if y - RADIUS <= 0.0 or hits(current) or behind or hazard_hits(current):
		crashed = true
		vy = minf(vy, 2.0)
		game.sfx.play("shot")
	place()

func done() -> bool:
	return crashed and crash_clock >= CRASH_TIME

# Gaps flown through in this run.
func run_gaps() -> int:
	return passed - first

# The next checkpoint ahead of the craft.
func next_checkpoint() -> int:
	return (passed/CHECKPOINT_EVERY + 1)*CHECKPOINT_EVERY

# --- view --------------------------------------------------------------------------

func place() -> void:
	if not is_instance_valid(camera): return
	craft.position = Vector3(x, y, 0)
	if not crashed: craft.rotation = Vector3(0, clock*2.0, clampf(vy*0.04, -0.5, 0.35))
	var start := maxi(0, int((x - FIRST)/SPACING) - 2)
	for i in POOL:
		var index := start + i
		var gap := gap_at(index)
		var gate: Dictionary = gates[index % POOL]
		var map := map_of(index)
		var middle := centre(gap)
		var low: float = middle - gap.size*0.5
		var high: float = middle + gap.size*0.5
		gate.tower.material_override = flat(Color(map.walls[index % map.walls.size()]))
		gate.roof.material_override = flat(Color(map.roof))
		gate.cloud.material_override = flat(Color(map.cloud))
		gate.tower.position = Vector3(gap.x, (low - 1.0)*0.5, 0)
		gate.tower.scale = Vector3(WIDTH, low + 1.0, WIDTH)
		gate.roof.position = Vector3(gap.x, low - 0.15, 0)
		gate.roof.scale = Vector3(WIDTH + 0.3, 0.3, WIDTH + 0.3)
		gate.cloud.position = Vector3(gap.x, (high + 0.3 + 30.0)*0.5, 0)
		gate.cloud.scale = Vector3(WIDTH, 30.0 - high - 0.3, WIDTH*0.8)
		for p in 3:
			gate.puffs[p].material_override = gate.cloud.material_override
			gate.puffs[p].position = Vector3(gap.x + (p - 1)*0.6, high + 0.55 - PUFF_DIP, 0.1)
		place_hazard(gate, gap)
	var here := map_of(maxi(0, int((x - FIRST)/SPACING)))
	ground.material_override = flat(Color(here.ground))
	ground.position = Vector3(x, -0.5, 0)
	var span := SKYLINE*SKY_STEP
	for i in skyline.size():
		var block := skyline[i]
		block.material_override = flat(Color(here.haze).darkened(0.05*(i % 3)))
		block.position = Vector3(x + wrapf(i*SKY_STEP - x*0.5, -span*0.4, span*0.6), block.scale.y*0.5, -10.0)

func place_hazard(gate: Dictionary, gap: Dictionary) -> void:
	var middle := centre(gap)
	var low: float = middle - gap.size*0.5
	var high: float = middle + gap.size*0.5
	gate.band.visible = gap.hazard == "wind"
	for streak in gate.streaks: streak.visible = gate.band.visible
	if gate.band.visible:
		gate.band.position = Vector3(gap.x - SPACING*0.5, CEILING*0.5, -0.5)
		gate.band.scale = Vector3(SPACING - WIDTH, CEILING, 0.2)
		# Streaks race the way the gust blows (up or down).
		var rise: float = sign(float(gap.wind))
		for k in gate.streaks.size():
			var height := wrapf(clock*6.0*rise + k*CEILING/gate.streaks.size(), 0.0, CEILING)
			gate.streaks[k].position = Vector3(gap.x - SPACING*0.5 + (k - 1.5)*0.9, height, -0.3)
	gate.icicle.visible = gap.hazard == "icicle"
	if gate.icicle.visible:
		var length := 0.4 + float(gap.drop)
		gate.icicle.position = Vector3(gap.x, high - PUFF_DIP - length*0.5, 0.3)
		gate.icicle.scale = Vector3(1, length, 1)
	gate.beam.visible = gap.hazard == "beam"
	gate.lamp.visible = gate.beam.visible
	if gate.beam.visible:
		var ends := beam_ends(gap)
		var mid: Vector2 = (ends[0] + ends[1])*0.5
		gate.beam.position = Vector3(mid.x, mid.y, 0.4)
		gate.beam.scale = Vector3(0.22, BEAM_LENGTH, 0.1)
		gate.beam.rotation = Vector3(0, 0, -beam_angle(gap))
		gate.lamp.position = Vector3(gap.x, low + 0.15, 0.3)
	gate.gull.visible = gap.hazard == "gull"
	for wing in gate.wings: wing.visible = gate.gull.visible
	if gate.gull.visible:
		var at := gull_at(gap)
		gate.gull.position = Vector3(at.x, at.y, 0.3)
		var flap_angle := sin(clock*14.0 + gap.phase)*0.6
		for side in 2:
			var wing: MeshInstance3D = gate.wings[side]
			var sign := -1.0 if side == 0 else 1.0
			wing.position = Vector3(at.x + sign*0.4, at.y + 0.05, 0.3)
			wing.rotation = Vector3(0, 0, sign*flap_angle)

# Shows the course and makes its camera current, or hands the view back.
func show_view(on: bool) -> void:
	visible = on
	if not on or not is_instance_valid(camera): return
	var screen := get_viewport().get_visible_rect().size
	var aspect := screen.x/maxf(1.0, screen.y)
	camera.size = maxf(VIEW_HEIGHT, VIEW_WIDTH/aspect)
	camera.position = Vector3(x + camera.size*aspect*0.22, CEILING*0.5, 30.0)
	if not camera.current: camera.make_current()
