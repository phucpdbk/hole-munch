extends Node3D

# Daily mini-game "slide" (daily_games.gd): a turn-based puzzle on a small city
# block high above the city. A swipe sends the hole sliding in a straight line
# until a building, the edge or something too big stops it, swallowing every
# snack small enough on the way. The hole grows a size at GROW_AT points eaten;
# the landmark only fits a size-3 hole, so the order of the slides matters.
# Every day's board comes from the date's seed and a breadth-first solver keeps
# only boards with a known shortest solution (par). Stars: solved, within
# PAR_SLACK of par, and par itself. The board has its own camera.
const ALTITUDE := 800.0
const SIZE := 7
const CELL := 2.0
const WALLS := 9
# Snacks: [size, count]; the landmark comes on top and needs a size-3 hole.
const SNACKS := [[1, 5], [2, 3]]
const LANDMARK := 3
const GROW_AT := [3, 8]
const PAR_MIN := 6
const PAR_MAX := 14
const PAR_SLACK := 3
const TRIES := 300
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const SLIDE_SPEED := 9.0
const FINISH_TIME := 0.8
# The board's screen height is foreshortened by the camera tilt, plus roofs.
const TILT_SHARE := 0.95
const BORDER := 1.2
const WALL_COLORS := ["c98f6b", "6f8fb0", "d0a35a", "7f9a6a", "a07aa8"]
const SNACK_COLORS := {1:"ffb34c", 2:"62b6ff", 3:"ffd84a"}

var rng := RandomNumberGenerator.new()
var walls := {}
# [{cell, size, landmark}], the landmark last.
var items: Array[Dictionary] = []
var item_at := {}
var start := Vector2i.ZERO
var par := 0
var cell := Vector2i.ZERO
var mask := 0
var moves := 0
var history: Array = []
var solved := false
var finish_clock := 0.0
var camera: Camera3D
var hole: MeshInstance3D
var hole_label: Label3D
var board_nodes: Array[Node3D] = []
var item_nodes: Array[Node3D] = []
var hole_at := Vector3.ZERO

# --- board -------------------------------------------------------------------------

static func level_of(value: int) -> int:
	var level := 1
	for need in GROW_AT:
		if value >= need: level += 1
	return level

func value_of(eaten: int) -> int:
	var total := 0
	for i in items.size():
		if eaten & (1 << i): total += int(items[i].size)
	return total

func landmark_bit() -> int:
	return 1 << (items.size() - 1)

func inside(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < SIZE and at.y < SIZE

# One swipe from `from` with `eaten` swallowed: [stop cell, eaten after].
func slide(from: Vector2i, eaten: int, dir: Vector2i) -> Array:
	var at := from
	var level := level_of(value_of(eaten))
	while true:
		var next := at + dir
		if not inside(next) or walls.has(next): break
		var k: int = item_at.get(next, -1)
		if k >= 0 and eaten & (1 << k) == 0:
			if int(items[k].size) > level: break
			eaten |= 1 << k
			level = level_of(value_of(eaten))
		at = next
	return [at, eaten]

# Fewest swipes to swallow the landmark from the start, or -1.
func solve() -> int:
	var path := solution()
	return path.size() if not path.is_empty() else -1

# One shortest list of swipes (breadth first), empty when there is none.
func solution() -> Array:
	var goal := landmark_bit()
	# key -> [parent key, swipe]
	var parent := {key(start, 0):[-1, Vector2i.ZERO]}
	var frontier: Array = [[start, 0]]
	var depth := 0
	while not frontier.is_empty() and depth < PAR_MAX + 4:
		depth += 1
		var next_frontier: Array = []
		for state in frontier:
			var from := key(state[0], state[1])
			for dir in DIRS:
				var after := slide(state[0], state[1], dir)
				if after[0] == state[0]: continue
				var k := key(after[0], after[1])
				if parent.has(k): continue
				parent[k] = [from, dir]
				if after[1] & goal: return path_to(parent, k)
				next_frontier.append(after)
		frontier = next_frontier
	return []

func path_to(parent: Dictionary, k: int) -> Array:
	var path: Array = []
	while parent[k][0] >= 0:
		path.push_front(parent[k][1])
		k = parent[k][0]
	return path

func key(at: Vector2i, eaten: int) -> int:
	return eaten*64 + at.y*SIZE + at.x

# Seeded boards until one has a par in range (the last solvable one otherwise).
func generate(value: int) -> void:
	rng.seed = value
	var fallback := {}
	for attempt in TRIES:
		lay_out()
		var shortest := solve()
		if shortest < 0: continue
		fallback = {"walls":walls.duplicate(), "items":items.duplicate(true), "start":start, "par":shortest}
		if shortest >= PAR_MIN and shortest <= PAR_MAX: break
	walls = fallback.get("walls", {})
	items.assign(fallback.get("items", []))
	start = fallback.get("start", Vector2i.ZERO)
	par = int(fallback.get("par", 0))
	item_at.clear()
	for i in items.size(): item_at[items[i].cell] = i

func lay_out() -> void:
	walls.clear()
	items.clear()
	item_at.clear()
	var free: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE: free.append(Vector2i(x, y))
	for i in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := free[i]
		free[i] = free[j]
		free[j] = swap
	start = free.pop_back()
	for i in WALLS: walls[free.pop_back()] = true
	for snack in SNACKS:
		for i in snack[1]: items.append({"cell":free.pop_back(), "size":snack[0], "landmark":false})
	items.append({"cell":free.pop_back(), "size":LANDMARK, "landmark":true})
	for i in items.size(): item_at[items[i].cell] = i

# --- round -------------------------------------------------------------------------

func build(game, value: int) -> void:
	generate(value)
	if not is_instance_valid(camera): make_camera()
	dress(game)
	reset()
	visible = false

func reset() -> void:
	cell = start
	mask = 0
	moves = 0
	history.clear()
	solved = false
	finish_clock = 0.0
	hole_at = world(start)
	sync_items(true)
	place()

# A swipe; false when it would not move the hole.
func move(game, dir: Vector2i) -> bool:
	if solved: return false
	var after := slide(cell, mask, dir)
	if after[0] == cell: return false
	history.append([cell, mask])
	var bites := bit_count(after[1] & ~mask)
	cell = after[0]
	mask = after[1]
	moves += 1
	game.sfx.play("pop5" if bites == 0 else "grow")
	if mask & landmark_bit():
		solved = true
		game.sfx.play("boss")
	return true

static func bit_count(bits: int) -> int:
	var total := 0
	while bits:
		total += bits & 1
		bits >>= 1
	return total

func undo() -> void:
	if solved or history.is_empty(): return
	var last: Array = history.pop_back()
	cell = last[0]
	mask = last[1]
	moves -= 1
	hole_at = world(cell)
	sync_items(true)

func restart() -> void:
	if solved: return
	cell = start
	mask = 0
	moves = 0
	history.clear()
	hole_at = world(start)
	sync_items(true)

func level() -> int:
	return level_of(value_of(mask))

func stars() -> int:
	if not solved: return 0
	return 3 if moves <= par else 2 if moves <= par + PAR_SLACK else 1

func update(dt: float) -> void:
	var target := world(cell)
	hole_at = hole_at.move_toward(target, SLIDE_SPEED*CELL*dt)
	if solved and hole_at == target: finish_clock += dt
	place()

func done() -> bool:
	return solved and finish_clock >= FINISH_TIME

# --- view --------------------------------------------------------------------------

func world(at: Vector2i) -> Vector3:
	var half := (SIZE - 1)*CELL*0.5
	return Vector3(at.x*CELL - half, 0, at.y*CELL - half)

func make_camera() -> void:
	position = Vector3(0, ALTITUDE, 0)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.far = 200.0
	# Tilted a little so buildings read as buildings; screen right stays +x.
	camera.rotation = Vector3(-deg_to_rad(68.0), 0, 0)
	camera.position = Vector3(0, 40.0, 16.0)
	add_child(camera)

func dress(game) -> void:
	for node in board_nodes + item_nodes: node.queue_free()
	board_nodes.clear()
	item_nodes.clear()
	var palette: Array = game.palette
	var span := SIZE*CELL
	board_nodes.append(box(Vector3(span + 1.2, 0.6, span + 1.2), Vector3(0, -0.4, 0), Color(palette[1]).darkened(0.2)))
	for y in SIZE:
		for x in SIZE:
			var shade := Color(palette[3]) if (x + y)%2 == 0 else Color(palette[3]).darkened(0.08)
			board_nodes.append(box(Vector3(CELL*0.96, 0.1, CELL*0.96), world(Vector2i(x, y)) + Vector3(0, -0.05, 0), shade))
	var heights := RandomNumberGenerator.new()
	heights.seed = rng.seed + 5
	var n := 0
	for at in walls:
		var tall := heights.randf_range(1.6, 3.2)
		board_nodes.append(box(Vector3(CELL*0.86, tall, CELL*0.86), world(at) + Vector3(0, tall*0.5, 0), Color(WALL_COLORS[n%WALL_COLORS.size()])))
		board_nodes.append(box(Vector3(CELL*0.92, 0.2, CELL*0.92), world(at) + Vector3(0, tall + 0.1, 0), Color(palette[6 + n%2])))
		n += 1
	for item in items: item_nodes.append(snack_node(item))
	if not is_instance_valid(hole):
		hole = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.06
		hole.mesh = disc
		hole.material_override = flat(Color("120a1f"))
		var rim := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.92
		ring.outer_radius = 1.08
		rim.mesh = ring
		rim.material_override = flat(Color("b7a2f1"))
		hole.add_child(rim)
		add_child(hole)
		hole_label = label3d(Color("ffffff"))
		add_child(hole_label)

func snack_node(item: Dictionary) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var size: int = item.size
	var color := Color(SNACK_COLORS[size])
	if item.landmark:
		for k in 3:
			var piece := box(Vector3(1.3 - k*0.35, 0.9, 1.3 - k*0.35), Vector3(0, 0.45 + k*0.9, 0), color.darkened(k*0.08))
			piece.reparent(root, false)
	elif size == 1:
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.38
		sphere.height = 0.76
		ball.mesh = sphere
		ball.material_override = flat(color)
		ball.position.y = 0.38
		root.add_child(ball)
	else:
		box(Vector3(1.3, 0.55, 0.8), Vector3(0, 0.35, 0), color).reparent(root, false)
		box(Vector3(0.7, 0.35, 0.7), Vector3(0, 0.75, 0), color.lightened(0.3)).reparent(root, false)
	var tag := label3d(Color(SNACK_COLORS[size]).lightened(0.4))
	tag.text = str(size)
	tag.position.y = 3.2 if item.landmark else 1.6
	root.add_child(tag)
	root.position = world(item.cell)
	return root

func label3d(color: Color) -> Label3D:
	var tag := Label3D.new()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 96
	tag.outline_size = 24
	tag.pixel_size = 0.008
	tag.modulate = color
	tag.no_depth_test = true
	return tag

func box(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = flat(color)
	node.position = at
	add_child(node)
	return node

func flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

# Shows eaten snacks as gone; `instant` skips the shrink (start, restart, undo).
func sync_items(instant: bool) -> void:
	for i in mini(items.size(), item_nodes.size()):
		var gone := mask & (1 << i) != 0
		if instant or not gone: item_nodes[i].scale = Vector3.ZERO if gone else Vector3.ONE

func place() -> void:
	if not is_instance_valid(hole): return
	var radius := 0.42 + level()*0.18
	hole.position = hole_at + Vector3(0, 0.04, 0)
	hole.scale = Vector3(radius, 1, radius)
	hole_label.text = str(level())
	hole_label.position = hole_at + Vector3(0, 1.2, 0)
	# A snack shrinks into the hole once the sliding hole reaches it.
	for i in mini(items.size(), item_nodes.size()):
		if mask & (1 << i) == 0: continue
		var node := item_nodes[i]
		if node.position.distance_to(hole_at) < CELL*0.6 or hole_at == world(cell):
			node.scale = node.scale.move_toward(Vector3.ZERO, 0.25)

# Shows the board fitted into `frame` (screen pixels, from the HUD layout), or
# hands the view back.
func show_view(on: bool, frame := Rect2()) -> void:
	visible = on
	if not on or not is_instance_valid(camera): return
	var screen := get_viewport().get_visible_rect().size
	if frame.size.x <= 0.0: frame = Rect2(Vector2.ZERO, screen)
	var span := SIZE*CELL + BORDER
	camera.size = maxf(span*TILT_SHARE*screen.y/frame.size.y, span*screen.y/frame.size.x)
	var per_pixel := camera.size/screen.y
	var centre := frame.get_center() - screen/2
	camera.h_offset = -centre.x*per_pixel
	camera.v_offset = centre.y*per_pixel
	if not camera.current: camera.make_current()
