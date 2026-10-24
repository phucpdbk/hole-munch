extends RefCounted

# The beam daily's toy depot (beam_drop.gd), built instead of a city like the
# cow hunt's farmland (countryside.gd): no buildings, traffic, army or
# landmark. The street grid stays as sand paths; the plaza holds the dark
# puzzle deck the pads sit on, and the other blocks are lawns with a sandbox
# and low bushes. Every decoration is baked into the ground, so nothing on
# the map can be eaten, and none of it looks like a toy.
# Slab, path, verge, grass, foliage, light, roof, roof (as Campaign palettes).
const PALETTE := ["6a5f8c", "eadbb2", "a99bd6", "9fd27e", "4f9f3c", "fff4e0", "ff8fb1", "7fc8ff"]
const GROUND := ["9fd27e", "94c872"]
# The deck fits the largest board (4 x 3 pads of beam_drop.PAD).
const DECK := Vector2(10.6, 8.2)

var cells: Array[Vector2] = []

func colors() -> Array:
	return PALETTE

func plan(layout) -> void:
	cells = layout.cells()

# Lawns alternate two shades like a chequerboard.
func ground(x: float, z: float) -> Color:
	var xs: Array = []
	var zs: Array = []
	for cell in cells:
		if not cell.x in xs: xs.append(cell.x)
		if not cell.y in zs: zs.append(cell.y)
	xs.sort()
	zs.sort()
	return Color(GROUND[(xs.find(x) + zs.find(z)) % 2])

func ground_parts(layout, m) -> Array:
	var parts: Array = []
	for cell in cells:
		if cell == Vector2.ZERO:
			parts.append_array(deck(m))
			continue
		var half: Vector2 = (layout.block_size(cell.x, cell.y) - Vector2.ONE*3.4)/2
		parts.append_array(sandbox(m, Vector3(cell.x, 0.16, cell.y)))
		for dx in [-1, 1]:
			for dz in [-1, 1]:
				parts.append(m.piece("hemi", Vector3(cell.x + dx*half.x, 0.16, cell.y + dz*half.y), Vector3(0.9, 0.55, 0.9), Color("3f8a35")))
	return parts

# The puzzle deck: a dark slab with a gold rim and corner lamps.
static func deck(m) -> Array:
	var parts: Array = [m.piece("box", Vector3(0, 0.18, 0), Vector3(DECK.x, 0.05, DECK.y), Color("36406b"))]
	var half := DECK/2
	for side in [-1, 1]:
		parts.append(m.piece("box", Vector3(0, 0.2, side*half.y), Vector3(DECK.x + 0.3, 0.08, 0.15), Color("ffd23f")))
		parts.append(m.piece("box", Vector3(side*half.x, 0.2, 0), Vector3(0.15, 0.08, DECK.y + 0.3), Color("ffd23f")))
	for dx in [-1, 1]:
		for dz in [-1, 1]:
			parts.append(m.piece("cyl", Vector3(dx*half.x, 0.3, dz*half.y), Vector3(0.28, 0.2, 0.28), Color("fff4b0")))
	return parts

static func sandbox(m, at: Vector3) -> Array:
	var parts: Array = [m.piece("box", at + Vector3(0, 0.02, 0), Vector3(4.0, 0.04, 4.0), Color("f2d79a"))]
	for side in [-1, 1]:
		parts.append(m.piece("box", at + Vector3(0, 0.08, side*2.0), Vector3(4.3, 0.16, 0.25), Color("b07a45")))
		parts.append(m.piece("box", at + Vector3(side*2.0, 0.08, 0), Vector3(0.25, 0.16, 4.3), Color("b07a45")))
	return parts

func build(_g, _rng: RandomNumberGenerator) -> void:
	pass
