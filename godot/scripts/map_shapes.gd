extends RefCounted

# Shaped city maps: some grid cells become water (a bay, a lake, a river), so a
# city is no longer a plain rectangle and the hole, the rival and the guardian
# go round it or over a bridge. map_layout.gd draws the shore and keeps the hole
# off the water; this file only picks the cells.
#
# Shapes are written for each grid size with the plaza (the centre cell) kept as
# land. A bridge is [cell, step]: the street between a water cell and its
# neighbour in that direction stays as a road over the water. Each city mirrors
# its shape by its own seed, so the same shape looks different from city to city.
# The first cities stay plain rectangles while the player learns to steer.
const PLAIN_UNTIL := 3

const N := Vector2i(0, -1)
const S := Vector2i(0, 1)
const W := Vector2i(-1, 0)
const E := Vector2i(1, 0)

# grid "cols x rows" -> shape id -> {"water": cells, "bridges": [[cell, step]]}
const SHAPES := {
	"3x3": {
		"bay": {"water":[Vector2i(0, 0)]},
		"strait": {"water":[Vector2i(0, 0), Vector2i(2, 2)]},
		"inlet": {"water":[Vector2i(1, 0), Vector2i(0, 0)]},
		"plus": {"water":[Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]},
	},
	"5x3": {
		"bay": {"water":[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]},
		"river": {"water":[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)], "bridges":[[Vector2i(1, 0), S], [Vector2i(1, 1), S]]},
		"lakes": {"water":[Vector2i(1, 0), Vector2i(3, 2)]},
		"coast": {"water":[Vector2i(0, 0), Vector2i(0, 1), Vector2i(4, 1), Vector2i(4, 2)]},
		# Hoi An (Mid-Autumn): the Thu Bon along the south-west and a channel with
		# two bridges to the islet on the east.
		"hoian": {"water":[Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(0, 2), Vector2i(1, 2)],
			"bridges":[[Vector2i(3, 0), S], [Vector2i(3, 1), S]], "festival":true},
	},
	"5x5": {
		"river": {"water":[Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4)],
			"bridges":[[Vector2i(1, 0), S], [Vector2i(1, 2), S], [Vector2i(1, 3), S]]},
		"lakes": {"water":[Vector2i(1, 1), Vector2i(3, 3), Vector2i(4, 0)]},
		"harbour": {"water":[Vector2i(2, 0), Vector2i(1, 0), Vector2i(3, 0), Vector2i(2, 1)], "bridges":[[Vector2i(2, 0), S]]},
		"capes": {"water":[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(4, 4), Vector2i(3, 4), Vector2i(4, 3)]},
		"canal": {"water":[Vector2i(0, 3), Vector2i(1, 3), Vector2i(3, 1), Vector2i(4, 1)], "bridges":[[Vector2i(1, 3), N], [Vector2i(3, 1), S]]},
		# Verona (Valentine's): the Adige right across the north of the old town,
		# three bridges to the far bank.
		"verona": {"water":[Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1)],
			"bridges":[[Vector2i(0, 1), E], [Vector2i(1, 1), E], [Vector2i(3, 1), E]], "festival":true},
	},
	"5x7": {
		"river": {"water":[Vector2i(3, 0), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6)],
			"bridges":[[Vector2i(3, 0), S], [Vector2i(3, 1), S], [Vector2i(4, 3), S], [Vector2i(3, 5), S]]},
		"delta": {"water":[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(4, 5), Vector2i(4, 6), Vector2i(3, 6), Vector2i(1, 4)]},
		"isles": {"water":[Vector2i(1, 1), Vector2i(1, 2), Vector2i(3, 4), Vector2i(3, 5), Vector2i(0, 6), Vector2i(4, 0)],
			"bridges":[[Vector2i(1, 1), S], [Vector2i(3, 4), S]]},
	},
}

# Plain cities, then a rotation through the grid's shapes; holiday cities pick
# their own (campaign.gd HOLIDAYS "shape").
static func for_level(level: Dictionary) -> Dictionary:
	var grid := "%dx%d" % [int(level.cols), int(level.rows)]
	if not SHAPES.has(grid): return {}
	var id: String = level.get("shape", "")
	if id == "":
		if int(level.index) < PLAIN_UNTIL: return {}
		var ids: Array = SHAPES[grid].keys().filter(func(key): return not SHAPES[grid][key].get("festival", false))
		id = ids[(int(level.index)*7 + int(level.region)) % ids.size()]
	if not SHAPES[grid].has(id): return {}
	var seed_value := int(level.index)*31 + 5
	return mirrored(SHAPES[grid][id], int(level.cols), int(level.rows), seed_value % 2 == 1, (seed_value/2) % 2 == 1)

static func mirrored(shape: Dictionary, cols: int, rows: int, flip_x: bool, flip_z: bool) -> Dictionary:
	var flip := func(cell: Vector2i) -> Vector2i:
		return Vector2i(cols - 1 - cell.x if flip_x else cell.x, rows - 1 - cell.y if flip_z else cell.y)
	var turn := func(step: Vector2i) -> Vector2i:
		return Vector2i(-step.x if flip_x else step.x, -step.y if flip_z else step.y)
	var water: Array = shape.water.map(func(cell): return flip.call(cell))
	var bridges: Array = shape.get("bridges", []).map(func(pair): return [flip.call(pair[0]), turn.call(pair[1])])
	return {"water":water, "bridges":bridges}

# Turns the cells into the layout's water and bridged streets.
static func apply(layout, shape: Dictionary) -> void:
	if shape.is_empty(): return
	var keys: Array = shape.bridges.map(func(pair): return layout.street_key(pair[0], pair[1]))
	layout.shape(shape.water, keys)

# Every land block's centre reachable from the plaza by the hole itself: a
# flood fill over the area it may stand on, one unit apart (bridges included).
static func connected(layout) -> bool:
	var size := Vector2i(int(layout.move_x)*2 + 1, int(layout.move_z)*2 + 1)
	var origin := Vector2(-int(layout.move_x), -int(layout.move_z))
	var seen := {}
	var start := Vector2i(int(layout.move_x), int(layout.move_z))
	seen[start] = true
	var open: Array[Vector2i] = [start]
	while not open.is_empty():
		var at: Vector2i = open.pop_back()
		for step in [N, S, W, E]:
			var next: Vector2i = at + step
			if seen.has(next) or next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y: continue
			if not layout.inside(Vector3(origin.x + next.x, 0, origin.y + next.y)): continue
			seen[next] = true
			open.append(next)
	for cell in layout.cells():
		if not seen.has(Vector2i(roundi(cell.x - origin.x), roundi(cell.y - origin.y))): return false
	return true
