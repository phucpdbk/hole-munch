extends RefCounted

# Themed maps for the classic dailies (snake, mole, red light), built instead
# of a city like the cow hunt's farmland (countryside.gd): no buildings,
# traffic, army or landmark. The street grid stays as the map's paths (the
# games put their food and holes on them); the blocks are decorated by theme:
#   garden - snake: mown lawns, sand paths, flower beds, hedges, a fountain.
#   veggie - mole: furrowed soil, carrot and cabbage rows, scarecrows, fences.
#   track  - red light: a blue running track with white lanes, striped turf,
#            stands and flags (red_light.gd adds the traffic lights).
# Decorations are items too big for the hole (DECOR), so none is ever eaten.
const THEME := {"snake":"garden", "mole":"veggie", "redlight":"track"}
# Slab, path, verge, grass, foliage, light, roof, roof (as Campaign palettes).
const PALETTES := {
	"garden":["5f8f4a", "eadbb2", "6fb35c", "8fd16f", "4f9f3c", "fff6dc", "e76f8a", "f2c14e"],
	"veggie":["6b4a2b", "c9a46b", "7fb35a", "8a5a36", "5a9a3c", "fff1d6", "b5523b", "d9a441"],
	"track":["3f6e3a", "3b78c4", "eef2f0", "5fb85a", "3f8f3c", "f5f7ff", "3a7bd5", "ffd23f"]}
const GROUND := {"garden":["8fd16f", "84c765"], "veggie":["8a5a36", "7d5131"], "track":["5fb85a", "57ad52"]}
const DECOR := 3.0

var theme := "garden"
var cells: Array[Vector2] = []

func _init(kind: String) -> void:
	theme = THEME.get(kind, "garden")

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

# --- decorations ---------------------------------------------------------------------

func build(g, rng: RandomNumberGenerator) -> void:
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

func garden(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	var half := inner/2
	if cell == Vector2.ZERO:
		decor(g, "theme_garden", Vector3(0, 0.16, 0), 2)
	else:
		g.add_item("farm_tree_oak", Vector3(cell.x, 0.16, cell.y), DECOR, 0, rng.randf_range(0, TAU))
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			decor(g, "theme_garden", Vector3(cell.x + dx*(half.x - 1.2), 0.16, cell.y + dz*(half.y - 1.2)), 0 if (dx + dz) == 0 else 3)
	# Hedges along the north and south edges, broken in the middle.
	for dz in [-half.y, half.y]:
		var x := -half.x + 3.0
		while x <= half.x - 3.0:
			if absf(x) > 2.5: decor(g, "theme_garden", Vector3(cell.x + x, 0.16, cell.y + dz), 1)
			x += 2.0
	for i in 2:
		decor(g, "bench", Vector3(cell.x + rng.randf_range(-half.x/2, half.x/2), 0.16, cell.y + (half.y - 2.4)*(1 if i == 0 else -1)), 0, PI if i == 0 else 0.0)

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
	for along in range(int(-half.x), int(half.x) + 1, 2):
		if absf(along) < 3: continue
		g.add_item("farm_fence_simple", Vector3(cell.x + along, 0.18, cell.y - half.y - 0.6), DECOR)
	for i in 3:
		g.add_item("farm_pumpkin", Vector3(cell.x + rng.randf_range(-half.x, half.x), 0.2, cell.y + half.y + 0.4), DECOR)

func track(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	var half := inner/2
	# A stand along the north edge of every other block, flags at the corners.
	if not odd(cell):
		decor(g, "theme_track", Vector3(cell.x, 0.16, cell.y - half.y + 1.0), 0)
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			decor(g, "theme_track", Vector3(cell.x + dx*half.x, 0.16, cell.y + dz*half.y), 1 + int(rng.randf() < 0.5))
	for i in 3:
		decor(g, "theme_track", Vector3(cell.x + (i - 1)*3.0, 0.16, cell.y + half.y - 2.0), 3)

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
