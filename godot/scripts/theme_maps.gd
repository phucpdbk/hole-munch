extends RefCounted

# Themed maps for the classic dailies (snake, mole, red light), built instead
# of a city like the cow hunt's farmland (countryside.gd): no buildings,
# traffic, army or landmark. The street grid stays as the map's paths (the
# games put their food and holes on them); the blocks are decorated by theme:
#   garden - snake: mown lawns, sand paths, flower beds, hedges, a fountain,
#            in GARDENS tiers that get harder (snake_trail.gd picks the tier).
#   veggie - mole: furrowed soil, carrot and cabbage rows, scarecrows, fences.
#   track  - red light: a blue running track with white lanes, striped turf,
#            stands and flags (red_light.gd adds the traffic lights).
# Decorations are items too big for the hole (DECOR), so none is ever eaten.
# The solid ones (hedges, beds, ponds, trees, fences, stands) block the hole,
# the snake's animals and its monsters: push_out() slides a circle out of them.
const THEME := {"snake":"garden", "mole":"veggie", "redlight":"track"}
# Garden tiers, easiest first: open lawns; hedged rooms with a gap on each
# side; hedged rooms round a pond; hedge mazes.
const GARDENS := ["open", "hedges", "ponds", "maze"]
# Slab, path, verge, grass, foliage, light, roof, roof (as Campaign palettes).
const PALETTES := {
	"garden":["5f8f4a", "eadbb2", "6fb35c", "8fd16f", "4f9f3c", "fff6dc", "e76f8a", "f2c14e"],
	"veggie":["6b4a2b", "c9a46b", "7fb35a", "8a5a36", "5a9a3c", "fff1d6", "b5523b", "d9a441"],
	"track":["3f6e3a", "3b78c4", "eef2f0", "5fb85a", "3f8f3c", "f5f7ff", "3a7bd5", "ffd23f"]}
const GROUND := {"garden":["8fd16f", "84c765"], "veggie":["8a5a36", "7d5131"], "track":["5fb85a", "57ad52"]}
const DECOR := 3.0
const HEDGE := 2.0
const MAZE_CELL := 5.0
const BUCKET := 4.0
# Solids are listed in every bucket they come within this far of, so a query
# circle up to this radius only needs its own bucket.
const REACH := 1.2

var theme := "garden"
var tier := 0
var cells: Array[Vector2] = []
# {c: Vector2 centre, h: Vector2 half size} for boxes, {c, r} for circles.
var solids: Array = []
var buckets := {}

func _init(kind: String, level := 0) -> void:
	theme = THEME.get(kind, "garden")
	tier = clampi(level, 0, GARDENS.size() - 1)

static func themed(kind: String) -> bool:
	return THEME.has(kind)

func colors() -> Array:
	return PALETTES[theme]

func plan(layout) -> void:
	cells = layout.cells()

# Blocks alternate two shades like a chequerboard: a mown lawn, soil beds, turf.
func ground(x: float, z: float) -> Color:
	return Color(GROUND[theme][1 if odd(Vector2(x, z)) else 0])

func odd(cell: Vector2) -> bool:
	var xs: Array = []
	var zs: Array = []
	for other in cells:
		if not other.x in xs: xs.append(other.x)
		if not other.y in zs: zs.append(other.y)
	xs.sort()
	zs.sort()
	return (xs.find(cell.x) + zs.find(cell.y)) % 2 != 0

# Ground details baked with the ground: furrows, lane lines and turf stripes.
func ground_parts(layout, m) -> Array:
	var parts: Array = []
	match theme:
		"veggie":
			for cell in cells:
				var inner: Vector2 = layout.block_size(cell.x, cell.y) - Vector2.ONE*2.6
				var z := -inner.y/2
				while z <= inner.y/2:
					parts.append(m.piece("box", Vector3(cell.x, 0.165, cell.y + z), Vector3(inner.x, 0.02, 0.35), Color("6e4527")))
					z += 1.6
		"track":
			for street in layout.streets_x:
				for side in [-0.75, 0.75]:
					parts.append(m.piece("box", Vector3(street + side, 0.04, 0), Vector3(0.08, 0.015, layout.half_z*2 - 2), Color("f4efe6")))
			for street in layout.streets_z:
				for side in [-0.75, 0.75]:
					parts.append(m.piece("box", Vector3(0, 0.04, street + side), Vector3(layout.half_x*2 - 2, 0.015, 0.08), Color("f4efe6")))
			for cell in cells:
				var inner: Vector2 = layout.block_size(cell.x, cell.y) - Vector2.ONE*2.2
				var x := -inner.x/2 + 1.5
				var stripe := 0
				while x < inner.x/2:
					if stripe % 2 == 0: parts.append(m.piece("box", Vector3(cell.x + x, 0.165, cell.y), Vector3(3.0, 0.01, inner.y), Color("6cc566")))
					x += 3.0
					stripe += 1
	return parts

# --- solids ------------------------------------------------------------------------

func add_box(centre: Vector2, half: Vector2) -> void:
	add_solid({"c":centre, "h":half}, half)

func add_circle(centre: Vector2, radius: float) -> void:
	add_solid({"c":centre, "r":radius}, Vector2.ONE*radius)

func add_solid(solid: Dictionary, half: Vector2) -> void:
	solids.append(solid)
	var low: Vector2 = solid.c - half - Vector2.ONE*REACH
	var high: Vector2 = solid.c + half + Vector2.ONE*REACH
	for bx in range(floori(low.x/BUCKET), floori(high.x/BUCKET) + 1):
		for bz in range(floori(low.y/BUCKET), floori(high.y/BUCKET) + 1):
			var key := Vector2i(bx, bz)
			if not buckets.has(key): buckets[key] = []
			buckets[key].append(solid)

# Slides a circle of `radius` (up to REACH) at `at` out of every solid.
func push_out(at: Vector3, radius: float) -> Vector3:
	var p := Vector2(at.x, at.z)
	var near: Array = buckets.get(Vector2i(floori(p.x/BUCKET), floori(p.y/BUCKET)), [])
	for pass_index in 2:
		for solid in near:
			if solid.has("r"):
				var away: Vector2 = p - solid.c
				var reach: float = solid.r + radius
				if away.length() < reach: p = solid.c + (away.normalized() if away.length() > 0.001 else Vector2.RIGHT)*reach
				continue
			var low: Vector2 = solid.c - solid.h
			var high: Vector2 = solid.c + solid.h
			var closest := Vector2(clampf(p.x, low.x, high.x), clampf(p.y, low.y, high.y))
			var gap := p - closest
			if gap.length() >= radius: continue
			if gap.length() > 0.001:
				p = closest + gap.normalized()*radius
				continue
			# Inside the box: out by the shortest side.
			var exits := [p.x - low.x, high.x - p.x, p.y - low.y, high.y - p.y]
			match exits.find(exits.min()):
				0: p.x = low.x - radius
				1: p.x = high.x + radius
				2: p.y = low.y - radius
				_: p.y = high.y + radius
	return Vector3(p.x, at.y, p.y)

func is_free(at: Vector3, radius: float) -> bool:
	var moved := push_out(at, radius)
	return Vector2(moved.x - at.x, moved.z - at.z).length() < 0.01

# A free spot anywhere on the map for an animal of `radius`.
func free_spot(g, rng: RandomNumberGenerator, radius: float) -> Vector3:
	var at := Vector3.ZERO
	for attempt in 40:
		at = Vector3(rng.randf_range(-g.layout.move_x, g.layout.move_x), 0.16, rng.randf_range(-g.layout.move_z, g.layout.move_z))
		if is_free(at, radius): return at
	return g.daily.snap_to_road(g, at)

# --- decorations ---------------------------------------------------------------------

func build(g, rng: RandomNumberGenerator) -> void:
	solids.clear()
	buckets.clear()
	for cell in cells:
		var inner: Vector2 = g.layout.block_size(cell.x, cell.y) - Vector2.ONE*3.4
		match theme:
			"garden": garden(g, rng, cell, inner)
			"veggie": veggie(g, rng, cell, inner)
			_: track(g, rng, cell, inner)

func decor(g, kind: String, at: Vector3, variant := 0, yaw := 0.0) -> Dictionary:
	var item: Dictionary = g.add_item(kind, at, DECOR, variant, yaw)
	item.optional = true
	return item

# A straight hedge from `a` to `b` (along x or z), one solid box.
func hedge(g, a: Vector2, b: Vector2) -> void:
	var length := a.distance_to(b)
	if length < 0.5: return
	var along_x := absf(b.x - a.x) >= absf(b.y - a.y)
	var count := maxi(1, roundi(length/HEDGE))
	for i in count:
		var at := a.lerp(b, (i + 0.5)/count)
		decor(g, "theme_garden", Vector3(at.x, 0.16, at.y), 1, 0.0 if along_x else PI/2)
	var centre := (a + b)/2
	add_box(centre, Vector2(length/2, 0.38) if along_x else Vector2(0.38, length/2))

# A hedge round the block's edge with a `gap` wide opening in the middle of each side.
func hedge_ring(g, cell: Vector2, half: Vector2, gap: float) -> void:
	for side in [-1, 1]:
		hedge(g, cell + Vector2(-half.x, side*half.y), cell + Vector2(-gap/2, side*half.y))
		hedge(g, cell + Vector2(gap/2, side*half.y), cell + Vector2(half.x, side*half.y))
		hedge(g, cell + Vector2(side*half.x, -half.y), cell + Vector2(side*half.x, -gap/2))
		hedge(g, cell + Vector2(side*half.x, gap/2), cell + Vector2(side*half.x, half.y))

func bed(g, at: Vector2, variant: int) -> void:
	decor(g, "theme_garden", Vector3(at.x, 0.16, at.y), variant)
	add_circle(at, 1.1)

func garden(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	var half := inner/2
	var style: String = GARDENS[tier]
	if style == "maze":
		hedge_ring(g, cell, half, MAZE_CELL - 1.0)
		maze(g, rng, cell, half)
		return
	if style == "ponds":
		decor(g, "theme_garden", Vector3(cell.x, 0.16, cell.y), 4)
		add_circle(cell, 2.8)
	elif cell == Vector2.ZERO:
		decor(g, "theme_garden", Vector3(0, 0.16, 0), 2)
		add_circle(cell, 2.6)
	else:
		g.add_item("farm_tree_oak", Vector3(cell.x, 0.16, cell.y), DECOR, 0, rng.randf_range(0, TAU))
		add_circle(cell, 0.6)
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			bed(g, cell + Vector2(dx*(half.x - 2.2), dz*(half.y - 2.2)), 0 if (dx + dz) == 0 else 3)
	if style == "open":
		# Hedges along the north and south edges only, broken in the middle.
		for dz in [-half.y, half.y]:
			hedge(g, cell + Vector2(-half.x + 2.0, dz), cell + Vector2(-2.5, dz))
			hedge(g, cell + Vector2(2.5, dz), cell + Vector2(half.x - 2.0, dz))
		for i in 2:
			decor(g, "bench", Vector3(cell.x + rng.randf_range(-half.x/2, half.x/2), 0.16, cell.y + (half.y - 2.4)*(1 if i == 0 else -1)), 0, PI if i == 0 else 0.0)
		return
	hedge_ring(g, cell, half, 4.0 if style == "hedges" else 3.0)

# A perfect maze of MAZE_CELL rooms inside the block's hedge ring: every room
# reachable, the ring's gaps opening onto the middle rooms of each side.
func maze(g, rng: RandomNumberGenerator, cell: Vector2, half: Vector2) -> void:
	var cols := maxi(2, floori(half.x*2/MAZE_CELL))
	var rows := maxi(2, floori(half.y*2/MAZE_CELL))
	var size := Vector2(half.x*2/cols, half.y*2/rows)
	var open := {}
	var seen := {Vector2i(0, 0):true}
	var stack: Array[Vector2i] = [Vector2i(0, 0)]
	while not stack.is_empty():
		var here: Vector2i = stack[-1]
		var next: Array[Vector2i] = []
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var there: Vector2i = here + step
			if there.x >= 0 and there.y >= 0 and there.x < cols and there.y < rows and not seen.has(there): next.append(there)
		if next.is_empty():
			stack.pop_back()
			continue
		var pick: Vector2i = next[rng.randi() % next.size()]
		open[[here, pick]] = true
		open[[pick, here]] = true
		seen[pick] = true
		stack.append(pick)
	var corner := cell - half
	for x in cols:
		for z in rows:
			var room := Vector2i(x, z)
			# The wall east of the room and the wall south of it, unless carved.
			if x + 1 < cols and not open.has([room, room + Vector2i(1, 0)]):
				var wall_x := corner.x + (x + 1)*size.x
				hedge(g, Vector2(wall_x, corner.y + z*size.y + 0.4), Vector2(wall_x, corner.y + (z + 1)*size.y - 0.4))
			if z + 1 < rows and not open.has([room, room + Vector2i(0, 1)]):
				var wall_z := corner.y + (z + 1)*size.y
				hedge(g, Vector2(corner.x + x*size.x + 0.4, wall_z), Vector2(corner.x + (x + 1)*size.x - 0.4, wall_z))

func veggie(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	var half := inner/2
	var z := -half.y + 0.8
	var row := 0
	while z <= half.y - 0.8:
		var x := -half.x + 0.8
		while x <= half.x - 0.8:
			if absf(x) > 1.6: decor(g, "theme_veggie", Vector3(cell.x + x, 0.16, cell.y + z), row % 2, rng.randf_range(0, TAU))
			x += 1.4
		z += 1.6
		row += 1
	if rng.randf() < 0.6 or cell == Vector2.ZERO:
		decor(g, "theme_veggie", Vector3(cell.x, 0.16, cell.y), 2, rng.randf_range(-0.4, 0.4))
		add_circle(cell, 0.4)
	var fence_z := cell.y - half.y - 0.6
	for along in range(int(-half.x), int(half.x) + 1, 2):
		if absf(along) < 3: continue
		g.add_item("farm_fence_simple", Vector3(cell.x + along, 0.18, fence_z), DECOR)
	for side in [-1, 1]:
		add_box(Vector2(cell.x + side*(half.x + 3.0)/2, fence_z), Vector2((half.x - 3.0)/2 + 0.6, 0.15))
	for i in 3:
		var at := Vector2(cell.x + rng.randf_range(-half.x, half.x), cell.y + half.y + 0.4)
		g.add_item("farm_pumpkin", Vector3(at.x, 0.2, at.y), DECOR)
		add_circle(at, 0.35)

func track(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	var half := inner/2
	# A stand along the north edge of every other block, flags at the corners.
	if not odd(cell):
		decor(g, "theme_track", Vector3(cell.x, 0.16, cell.y - half.y + 1.0), 0)
		add_box(Vector2(cell.x, cell.y - half.y + 0.4), Vector2(3.0, 0.95))
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			decor(g, "theme_track", Vector3(cell.x + dx*half.x, 0.16, cell.y + dz*half.y), 1 + int(rng.randf() < 0.5))
			add_circle(cell + Vector2(dx*half.x, dz*half.y), 0.15)
	for i in 3:
		decor(g, "theme_track", Vector3(cell.x + (i - 1)*3.0, 0.16, cell.y + half.y - 2.0), 3)
		add_box(Vector2(cell.x + (i - 1)*3.0, cell.y + half.y - 2.0), Vector2(0.65, 0.15))

# --- models --------------------------------------------------------------------------

# Toy decorations facing +z, by theme and variant (models.gd toy "theme_*").
static func parts(m, theme_name: String, variant: int) -> Array:
	match theme_name:
		"garden": return garden_parts(m, variant)
		"veggie": return veggie_parts(m, variant)
	return track_parts(m, variant)

static func garden_parts(m, variant: int) -> Array:
	var parts: Array = []
	match variant:
		0, 3:
			# A round flower bed: a stone rim, soil and a ring of blooms.
			var blooms: Array = ["ff8fc8", "ffd23f", "ffffff", "c39bff"] if variant == 0 else ["ff6b6b", "ffa94d", "ffe066", "ff8fc8"]
			parts.append(m.piece("cyl", Vector3(0, 0.12, 0), Vector3(1.1, 0.24, 1.1), Color("d8d2c4")))
			parts.append(m.piece("cyl", Vector3(0, 0.22, 0), Vector3(0.95, 0.06, 0.95), Color("6e4527")))
			for i in 10:
				var a := i*TAU/10.0
				parts.append(m.piece("ball", Vector3(cos(a)*0.65, 0.36, sin(a)*0.65), Vector3.ONE*0.17, Color(blooms[i % blooms.size()])))
			parts.append(m.piece("ball", Vector3(0, 0.5, 0), Vector3(0.35, 0.35, 0.35), Color("5aa64a")))
		1:
			parts.append(m.piece("box", Vector3(0, 0.4, 0), Vector3(1.9, 0.8, 0.7), Color("4f9f3c")))
			parts.append(m.piece("box", Vector3(0, 0.82, 0), Vector3(1.8, 0.08, 0.6), Color("62b64d")))
		4:
			# A pond with a stone edge, lily pads and reeds.
			parts.append(m.piece("cyl", Vector3(0, 0.1, 0), Vector3(2.8, 0.2, 2.8), Color("cfc8b8")))
			parts.append(m.piece("cyl", Vector3(0, 0.16, 0), Vector3(2.55, 0.1, 2.55), Color("4fb3e0")))
			parts.append(m.piece("cyl", Vector3(0, 0.17, 0), Vector3(1.6, 0.1, 1.6), Color("62c2ea")))
			for i in 6:
				var a := i*TAU/6.0 + 0.4
				var at := Vector3(cos(a)*1.7, 0.23, sin(a)*1.5)
				parts.append(m.piece("cyl", at, Vector3(0.32, 0.02, 0.32), Color("4caf50")))
				if i % 2 == 0: parts.append(m.piece("ball", at + Vector3(0.08, 0.06, 0), Vector3.ONE*0.09, Color("ff8fc8")))
			for i in 5:
				var a := i*0.35 + 3.6
				parts.append(m.piece("cyl", Vector3(cos(a)*2.35, 0.55, sin(a)*2.35), Vector3(0.04, 0.8, 0.04), Color("5a8f3a")))
				parts.append(m.piece("ball", Vector3(cos(a)*2.35, 0.95, sin(a)*2.35), Vector3(0.06, 0.14, 0.06), Color("8a5a2b")))
		_:
			# The fountain in the middle of the garden.
			parts.append(m.piece("cyl", Vector3(0, 0.2, 0), Vector3(2.6, 0.4, 2.6), Color("d8d2c4")))
			parts.append(m.piece("cyl", Vector3(0, 0.34, 0), Vector3(2.35, 0.1, 2.35), Color("6ec6f0")))
			parts.append(m.piece("cyl", Vector3(0, 0.9, 0), Vector3(0.3, 1.2, 0.3), Color("e6e0d2")))
			parts.append(m.piece("cyl", Vector3(0, 1.5, 0), Vector3(1.0, 0.14, 1.0), Color("d8d2c4")))
			parts.append(m.piece("ball", Vector3(0, 1.85, 0), Vector3(0.35, 0.5, 0.35), Color("9fe2ff")))
	return parts

static func veggie_parts(m, variant: int) -> Array:
	var parts: Array = []
	match variant:
		0:
			# Carrot tops poking out of the soil.
			parts.append(m.piece("roof", Vector3(0, 0.2, 0), Vector3(0.14, 0.3, 0.14), Color("ff8c1a"), Vector3(PI, 0, 0)))
			for i in 3: parts.append(m.piece("box", Vector3((i - 1)*0.06, 0.48, 0), Vector3(0.05, 0.36, 0.05), Color("4caf50"), Vector3(0, 0, (i - 1)*0.4)))
		1:
			parts.append(m.piece("ball", Vector3(0, 0.3, 0), Vector3(0.38, 0.3, 0.38), Color("8fd16f")))
			parts.append(m.piece("ball", Vector3(0, 0.36, 0), Vector3(0.26, 0.24, 0.26), Color("c6ef9a")))
		_:
			# A scarecrow with a straw hat.
			parts.append(m.piece("box", Vector3(0, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color("8a5a2b")))
			parts.append(m.piece("box", Vector3(0, 1.35, 0), Vector3(1.4, 0.1, 0.1), Color("8a5a2b")))
			parts.append(m.piece("box", Vector3(0, 1.2, 0), Vector3(0.6, 0.6, 0.3), Color("3a7bd5")))
			parts.append(m.piece("ball", Vector3(0, 1.75, 0), Vector3.ONE*0.22, Color("f2d39a")))
			parts.append(m.piece("cyl", Vector3(0, 1.95, 0), Vector3(0.5, 0.05, 0.5), Color("e8c56a")))
			parts.append(m.piece("cyl", Vector3(0, 2.05, 0), Vector3(0.24, 0.2, 0.24), Color("e8c56a")))
			for x in [-0.7, 0.7]: parts.append(m.piece("ball", Vector3(x, 1.35, 0), Vector3(0.12, 0.08, 0.12), Color("e8c56a")))
	return parts

static func track_parts(m, variant: int) -> Array:
	var parts: Array = []
	match variant:
		0:
			# A three-step stand with coloured seats.
			for step in 3:
				parts.append(m.piece("box", Vector3(0, 0.25 + step*0.45, -step*0.6), Vector3(6.0, 0.5 + step*0.9, 0.6), Color("c9d2dc")))
				for i in 10: parts.append(m.piece("box", Vector3(-2.7 + i*0.6, 0.6 + step*0.9, -step*0.6), Vector3(0.45, 0.18, 0.4), Color(["3a7bd5", "ffd23f", "ff6b6b"][(i + step) % 3])))
		1, 2:
			parts.append(m.piece("cylinder", Vector3(0, 1.3, 0), Vector3(0.05, 2.6, 0.05), Color("dfe4ea")))
			parts.append(m.piece("box", Vector3(0.45, 2.3, 0), Vector3(0.8, 0.5, 0.04), Color("ff6b6b") if variant == 1 else Color("3a7bd5")))
		_:
			# A hurdle.
			for x in [-0.6, 0.6]: parts.append(m.piece("box", Vector3(x, 0.35, 0), Vector3(0.06, 0.7, 0.3), Color("dfe4ea")))
			parts.append(m.piece("box", Vector3(0, 0.66, 0), Vector3(1.3, 0.12, 0.05), Color("ff6b6b")))
			parts.append(m.piece("box", Vector3(0, 0.66, 0.01), Vector3(0.3, 0.12, 0.05), Color("ffffff")))
	return parts
