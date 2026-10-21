extends RefCounted

# Per-level city grid. Blocks are 18 units apart with roads between them; the
# boss plaza is always the centre block, so both counts must be odd.
const BLOCK_STEP := 18.0
const BLOCK_SIZE := 14.8
# Street-to-street widths of the blocks around the plaza. Wide blocks with
# sparse buildings (city_blocks.gd) leave the hole room to steer between bites.
const DISTRICT_WIDTHS: Array[float] = [24.0, 31.0, 38.0]
# Half a road: blocks and water stop this far from a street's centre line.
const ROAD_HALF := 1.6
# The hole's centre stays this far off the water's edge.
const SHORE := 0.6
# Steering corners sit this far out from each corner of the water.
const NODE_PAD := 0.4

var cols := 3
var rows := 3
var blocks_x: Array[float] = []
var blocks_z: Array[float] = []
var streets_x: Array[float] = []
var streets_z: Array[float] = []
# Inner streets carry traffic and meet at signalled crossings.
var crossings_x: Array[float] = []
var crossings_z: Array[float] = []
var half_x := 28.0
var half_z := 28.0
var move_x := 26.0
var move_z := 26.0

# --- Shaped maps (map_shapes.gd) -------------------------------------------------
# Grid cells turned into water: Vector2i(column, row) -> true. Streets between two
# water cells disappear unless bridged; a street with land on either side stays.
var water := {}
# Bridged street segments: "h:<z line>:<column>" or "v:<x line>:<row>" -> true.
var bridges := {}
# Water drawn on the ground, and the (slightly larger) areas the hole's centre
# cannot enter; both are rebuilt by shape().
var water_rects: Array[Rect2] = []
var forbidden: Array[Rect2] = []
# Corners round the water and which of them see one another, for steer().
var nodes: Array[Vector2] = []
var links: Array = []
# street_spans() results by "axis:line" (the guardian asks every frame).
var span_cache := {}

static func make(cols_value: int, rows_value: int) -> RefCounted:
	var layout = load("res://scripts/map_layout.gd").new()
	layout.cols = cols_value
	layout.rows = rows_value
	layout.blocks_x = axis_blocks(cols_value)
	layout.blocks_z = axis_blocks(rows_value)
	layout.streets_x = axis_streets(cols_value)
	layout.streets_z = axis_streets(rows_value)
	layout.crossings_x.assign(layout.streets_x.slice(1, layout.streets_x.size()-1))
	layout.crossings_z.assign(layout.streets_z.slice(1, layout.streets_z.size()-1))
	layout.half_x = cols_value*BLOCK_STEP/2.0 + 1.0
	layout.half_z = rows_value*BLOCK_STEP/2.0 + 1.0
	layout.move_x = layout.half_x - 2.0
	layout.move_z = layout.half_z - 2.0
	return layout

# Unequal city blocks, with the central plaza/spawn streets kept at ±9.
# Traffic and defence share these exact road coordinates.
func vary_districts(seed_value: int) -> void:
	streets_x = district_streets(cols,seed_value)
	streets_z = district_streets(rows,seed_value+3)
	blocks_x.clear()
	blocks_z.clear()
	for i in cols: blocks_x.append((streets_x[i]+streets_x[i+1])*0.5)
	for i in rows: blocks_z.append((streets_z[i]+streets_z[i+1])*0.5)
	crossings_x.assign(streets_x.slice(1,streets_x.size()-1))
	crossings_z.assign(streets_z.slice(1,streets_z.size()-1))
	half_x = maxf(absf(streets_x[0]),streets_x[-1])+1.0
	half_z = maxf(absf(streets_z[0]),streets_z[-1])+1.0
	move_x = half_x-2
	move_z = half_z-2
	span_cache.clear()

static func district_streets(count: int, seed_value: int) -> Array[float]:
	var result: Array[float] = [-9.0,9.0]
	for i in count/2:
		result.push_front(result[0]-DISTRICT_WIDTHS[(seed_value+i)%3])
		result.append(result[-1]+DISTRICT_WIDTHS[(seed_value+i+1)%3])
	return result

func block_size(x: float, z: float) -> Vector2:
	var ix := blocks_x.find(x)
	var iz := blocks_z.find(z)
	return Vector2(streets_x[ix+1]-streets_x[ix]-3.2,streets_z[iz+1]-streets_z[iz]-3.2)

static func axis_blocks(count: int) -> Array[float]:
	var result: Array[float] = []
	for i in count: result.append((i - (count-1)/2.0) * BLOCK_STEP)
	return result

static func axis_streets(count: int) -> Array[float]:
	var result: Array[float] = []
	for i in count+1: result.append((i - count/2.0) * BLOCK_STEP)
	return result

func block_count() -> int:
	return cols*rows - water.size()

func is_edge_block(x: float, z: float) -> bool:
	return x == blocks_x[0] or x == blocks_x[-1] or z == blocks_z[0] or z == blocks_z[-1]

# --- Land and water ----------------------------------------------------------------

func shaped() -> bool:
	return not water.is_empty()

# Land blocks only: a cell outside the grid or under water is not land.
func land(i: int, j: int) -> bool:
	return i >= 0 and i < cols and j >= 0 and j < rows and not water.has(Vector2i(i, j))

func is_land(x: float, z: float) -> bool:
	return land(blocks_x.find(x), blocks_z.find(z))

# Centres of every land block, row by row.
func cells() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for x in blocks_x:
		for z in blocks_z:
			if is_land(x, z): result.append(Vector2(x, z))
	return result

# Water cells, and the street segments that cross water. Rebuilds the shore,
# the hole's no-go areas and the steering corners.
func shape(water_cells: Array, bridge_keys: Array = []) -> void:
	water.clear()
	bridges.clear()
	span_cache.clear()
	for cell in water_cells: water[Vector2i(cell)] = true
	for key in bridge_keys: bridges[str(key)] = true
	water_rects.clear()
	forbidden.clear()
	for cell in water: water_rects.append(water_rect(cell))
	for rect in water_rects: forbidden.append(rect.grow(SHORE))
	build_nodes()

# A water cell reaches the street centre line where more water continues past
# it, the map edge where the grid ends, and stops at the kerb where land or a
# bridge runs along that side.
func water_rect(cell: Vector2i) -> Rect2:
	var left := water_side(cell, Vector2i(-1, 0), streets_x[cell.x], -half_x, 1.0)
	var right := water_side(cell, Vector2i(1, 0), streets_x[cell.x+1], half_x, -1.0)
	var top := water_side(cell, Vector2i(0, -1), streets_z[cell.y], -half_z, 1.0)
	var bottom := water_side(cell, Vector2i(0, 1), streets_z[cell.y+1], half_z, -1.0)
	return Rect2(left, top, right - left, bottom - top)

func water_side(cell: Vector2i, step: Vector2i, line: float, edge: float, inward: float) -> float:
	var next := cell + step
	if next.x < 0 or next.x >= cols or next.y < 0 or next.y >= rows: return edge
	if water.has(next) and not bridges.has(street_key(cell, step)): return line
	return line + inward*ROAD_HALF

# The street segment between a cell and its neighbour in direction `step`.
func street_key(cell: Vector2i, step: Vector2i) -> String:
	if step.x != 0: return "v:%d:%d" % [cell.x + maxi(step.x, 0), cell.y]
	return "h:%d:%d" % [cell.y + maxi(step.y, 0), cell.x]

# --- Streets -----------------------------------------------------------------------

# A street segment exists where land runs along either side or a bridge crosses.
# `line` indexes streets_z for "h" and streets_x for "v"; `cell` is the column
# ("h") or row ("v") the segment spans.
func street_open(axis: String, line: int, cell: int) -> bool:
	if axis == "h": return land(cell, line - 1) or land(cell, line) or bridges.has("h:%d:%d" % [line, cell])
	return land(line - 1, cell) or land(line, cell) or bridges.has("v:%d:%d" % [line, cell])

# Whether the street (or open ground) under a point is there at all: a point on
# a street centre line checks that segment, anything else checks the hole's area.
func segment_open(at: Vector3) -> bool:
	if water.is_empty(): return true
	var lx := line_index(at.x, streets_x)
	var lz := line_index(at.z, streets_z)
	if lx >= 0 and lz >= 0: return junction_open(lx, lz)
	if lx >= 0: return street_open("v", lx, cell_index(at.z, streets_z))
	if lz >= 0: return street_open("h", lz, cell_index(at.x, streets_x))
	return inside(at)

func junction_open(lx: int, lz: int) -> bool:
	return street_open("v", lx, lz - 1) or street_open("v", lx, lz) or street_open("h", lz, lx - 1) or street_open("h", lz, lx)

# All four arms of an inner crossing exist (a full crossing with signals).
func junction_full(x: float, z: float) -> bool:
	var lx := streets_x.find(x)
	var lz := streets_z.find(z)
	return street_open("v", lx, lz - 1) and street_open("v", lx, lz) and street_open("h", lz, lx - 1) and street_open("h", lz, lx)

# Inner crossings with all four arms: signals, squads and roadblocks stand here.
func junctions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for x in crossings_x:
		for z in crossings_z:
			if junction_full(x, z): result.append(Vector2(x, z))
	return result

# Crossings at neither end of a bridge: a roadblock there never cuts an island off.
func land_junctions() -> Array[Vector2]:
	return junctions().filter(func(spot: Vector2):
		var lx := streets_x.find(spot.x)
		var lz := streets_z.find(spot.y)
		for key in ["h:%d:%d" % [lz, lx-1], "h:%d:%d" % [lz, lx], "v:%d:%d" % [lx, lz-1], "v:%d:%d" % [lx, lz]]:
			if bridges.has(key): return false
		return true)

# A spot just off a crossing's corner that stands on land: the given corner, or
# the next one round when water fills that corner.
func land_corner(centre: Vector2, offset: Vector2) -> Vector2:
	for turn in [offset, Vector2(-offset.x, offset.y), Vector2(offset.x, -offset.y), -offset]:
		var spot: Vector2 = centre + turn
		if inside(Vector3(spot.x, 0, spot.y)) and not water_rects.any(func(rect: Rect2): return rect.grow(0.4).has_point(spot)): return spot
	return centre + offset

static func line_index(value: float, lines: Array[float]) -> int:
	for i in lines.size():
		if absf(value - lines[i]) <= 0.35: return i
	return -1

# The block (column or row) a coordinate falls in, clamped to the grid.
static func cell_index(value: float, lines: Array[float]) -> int:
	for i in lines.size() - 1:
		if value < lines[i+1]: return i
	return lines.size() - 2

# Stretches of one street line that exist, as [from, to] pairs along it. A
# stretch that reaches the grid's edge runs on to the map edge (cars fade there).
func street_spans(axis: String, line_value: float) -> Array[Vector2]:
	var key := "%s:%.2f" % [axis, line_value]
	if not span_cache.has(key): span_cache[key] = find_spans(axis, line_value)
	return span_cache[key]

func find_spans(axis: String, line_value: float) -> Array[Vector2]:
	var lines: Array[float] = streets_z if axis == "h" else streets_x
	var across: Array[float] = streets_x if axis == "h" else streets_z
	var edge := half_x if axis == "h" else half_z
	var line := lines.find(line_value)
	var result: Array[Vector2] = []
	var start := -1
	for cell in across.size():
		var open := cell < across.size() - 1 and street_open(axis, line, cell)
		if open and start < 0: start = cell
		if not open and start >= 0:
			result.append(Vector2(-edge if start == 0 else across[start], edge if cell == across.size() - 1 else across[cell]))
			start = -1
	return result

# --- The hole's area ----------------------------------------------------------------

func inside(at: Vector3) -> bool:
	if absf(at.x) > move_x + 0.001 or absf(at.z) > move_z + 0.001: return false
	var flat := Vector2(at.x, at.z)
	for rect in forbidden:
		if rect.has_point(flat) and flat.x > rect.position.x and flat.y > rect.position.y: return false
	return true

# The nearest point the hole's centre may stand on: inside the map edge and off
# the water. Pushing out the short way lets the hole slide along a shore.
func clamp_point(at: Vector3) -> Vector3:
	var point := Vector3(clampf(at.x, -move_x, move_x), at.y, clampf(at.z, -move_z, move_z))
	for attempt in 4:
		var rect := forbidden_at(point)
		if rect.size == Vector2.ZERO: return point
		point = push_out(point, rect)
	return point

func forbidden_at(at: Vector3) -> Rect2:
	var flat := Vector2(at.x, at.z)
	for rect in forbidden:
		if flat.x > rect.position.x and flat.x < rect.end.x and flat.y > rect.position.y and flat.y < rect.end.y: return rect
	return Rect2()

# Out of one no-go rect through its nearest side that leads somewhere open
# (a side on the map edge is no way out).
func push_out(at: Vector3, rect: Rect2) -> Vector3:
	var exits := [Vector3(rect.position.x, at.y, at.z), Vector3(rect.end.x, at.y, at.z),
		Vector3(at.x, at.y, rect.position.y), Vector3(at.x, at.y, rect.end.y)].map(func(point: Vector3):
			return Vector3(clampf(point.x, -move_x, move_x), point.y, clampf(point.z, -move_z, move_z)))
	exits.sort_custom(func(a, b): return a.distance_squared_to(at) < b.distance_squared_to(at))
	for point in exits:
		if inside(point): return point
	for point in exits:
		if forbidden_at(point) != rect: return point
	return exits[0]

# --- Steering round the water ---------------------------------------------------

# Where to head next on the way from `from` to `to`: straight there when the
# water allows, else the first corner of the shortest way round. Shared by the
# rival, the par route and the autopilot.
func steer(from: Vector3, to: Vector3) -> Vector3:
	if forbidden.is_empty() or clear_line(Vector2(from.x, from.z), Vector2(to.x, to.z)): return to
	var start := Vector2(from.x, from.z)
	var goal := Vector2(to.x, to.z)
	var cost: Array[float] = []
	var first: Array[int] = []
	cost.resize(nodes.size())
	cost.fill(INF)
	first.resize(nodes.size())
	var open: Array[int] = []
	for i in nodes.size():
		if clear_line(start, nodes[i]):
			cost[i] = start.distance_to(nodes[i])
			first[i] = i
			open.append(i)
	var best := INF
	var best_first := -1
	while not open.is_empty():
		open.sort_custom(func(a, b): return cost[a] < cost[b])
		var here: int = open.pop_front()
		if cost[here] >= best: break
		if clear_line(nodes[here], goal) and cost[here] + nodes[here].distance_to(goal) < best:
			best = cost[here] + nodes[here].distance_to(goal)
			best_first = first[here]
		for next in links[here]:
			var value: float = cost[here] + nodes[here].distance_to(nodes[next])
			if value < cost[next]:
				cost[next] = value
				first[next] = first[here]
				if next not in open: open.append(next)
	if best_first < 0: return to
	return Vector3(nodes[best_first].x, to.y, nodes[best_first].y)

# The shortest way round the water, in units (straight-line length on open maps).
func route_length(from: Vector3, to: Vector3) -> float:
	var length := 0.0
	var at := from
	for hop in 12:
		var next := steer(at, to)
		length += Vector2(next.x - at.x, next.z - at.z).length()
		if next.is_equal_approx(to): return length
		at = next
	return length + Vector2(to.x - at.x, to.z - at.z).length()

func build_nodes() -> void:
	nodes.clear()
	links.clear()
	for rect in forbidden:
		for corner in [rect.position + Vector2(-NODE_PAD, -NODE_PAD), Vector2(rect.end.x + NODE_PAD, rect.position.y - NODE_PAD),
				Vector2(rect.position.x - NODE_PAD, rect.end.y + NODE_PAD), rect.end + Vector2(NODE_PAD, NODE_PAD)]:
			if inside(Vector3(corner.x, 0, corner.y)) and nodes.all(func(n): return n.distance_to(corner) > 0.2): nodes.append(corner)
	for i in nodes.size():
		var seen: Array[int] = []
		for j in nodes.size():
			if i != j and clear_line(nodes[i], nodes[j]): seen.append(j)
		links.append(seen)

# True when a straight move from a to b never enters the water's no-go areas.
func clear_line(a: Vector2, b: Vector2) -> bool:
	for rect in forbidden:
		if crosses(a, b, rect.grow(-0.05)): return false
	return true

# Slab test: does the segment a-b pass through the rectangle's interior?
static func crosses(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var delta := b - a
	for axis in 2:
		var from: float = a[axis]
		var step: float = delta[axis]
		var low: float = rect.position[axis]
		var high: float = rect.end[axis]
		if absf(step) < 0.000001:
			if from <= low or from >= high: return false
			continue
		var enter := (low - from)/step
		var leave := (high - from)/step
		if enter > leave:
			var swap := enter
			enter = leave
			leave = swap
		t0 = maxf(t0, enter)
		t1 = minf(t1, leave)
		if t0 >= t1: return false
	return true
