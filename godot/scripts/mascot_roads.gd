extends RefCounted

# Street routing for the guardian: it may walk along the road centre lines and
# inside the open central plaza around its landmark, never through city blocks.
# Roads are map_layout.gd streets: x = const (north-south) and z = const
# (east-west), limited to the lines the map's move area reaches. A route is a
# Manhattan path: along the current road to a crossing, then along the next one.
# next_point() returns the next corner to walk straight to; callers move toward
# it every frame and ask again, so the route follows a moving target.

# A position this close to a road centre line counts as on that road.
const ON_ROAD := 0.35
# The central plaza block plus the streets around it (they sit at +-9).
const PLAZA := 9.0

static func roads_x(layout) -> Array:
	return layout.streets_x.filter(func(x): return absf(x) <= layout.move_x)

static func roads_z(layout) -> Array:
	return layout.streets_z.filter(func(z): return absf(z) <= layout.move_z)

static func in_plaza(at: Vector3) -> bool:
	return absf(at.x) <= PLAZA and absf(at.z) <= PLAZA

static func line_of(value: float, lines: Array) -> Variant:
	for line in lines:
		if absf(value - line) <= ON_ROAD: return line
	return null

static func on_road(layout, at: Vector3) -> bool:
	return line_of(at.x, roads_x(layout)) != null or line_of(at.z, roads_z(layout)) != null

static func walkable(layout, at: Vector3) -> bool:
	return in_plaza(at) or on_road(layout, at)

# The closest point on any road centre line (the plaza counts as open ground).
static func project(layout, at: Vector3) -> Vector3:
	if in_plaza(at): return Vector3(at.x, at.y, at.z)
	return road_point(layout, at)

static func road_point(layout, at: Vector3) -> Vector3:
	var xs := roads_x(layout)
	var zs := roads_z(layout)
	var best := at
	var best_distance := INF
	for x in xs:
		var point := Vector3(x, at.y, clampf(at.z, -layout.move_z, layout.move_z))
		if absf(point.x - at.x) + absf(point.z - at.z) < best_distance:
			best_distance = absf(point.x - at.x) + absf(point.z - at.z)
			best = point
	for z in zs:
		var point := Vector3(clampf(at.x, -layout.move_x, layout.move_x), at.y, z)
		if absf(point.x - at.x) + absf(point.z - at.z) < best_distance:
			best_distance = absf(point.x - at.x) + absf(point.z - at.z)
			best = point
	return best

static func nearest(value: float, lines: Array) -> float:
	var best: float = lines[0]
	for line in lines:
		if absf(line - value) < absf(best - value): best = line
	return best

# The next point to walk straight to on the way from `from` to `target`.
static func next_point(layout, from: Vector3, target: Vector3) -> Vector3:
	return plan(layout, from, target).next

# Shortest street route from `from` to the walkable point nearest `target`:
# {next, length}. Crossings are the graph's nodes; a point on a road joins the
# crossings at both ends of its block, and the plaza is open ground between all
# the crossings on its rim. Off the network (after a knock) it steps back on first.
static func plan(layout, from: Vector3, target: Vector3) -> Dictionary:
	var goal := project(layout, target)
	if not walkable(layout, from):
		var back := road_point(layout, from)
		return {"next":back, "length":flat_gap(from, back) + flat_gap(back, goal)}
	if shares_stretch(layout, from, goal): return {"next":goal, "length":flat_gap(from, goal)}
	var xs := roads_x(layout)
	var zs := roads_z(layout)
	var starts := exits(layout, from, xs, zs)
	# Standing on a crossing: set off toward one of its neighbours.
	var here := grid_key(from, xs, zs)
	if flat_gap(from, Vector3(xs[here.x], from.y, zs[here.y])) < 0.05:
		starts = neighbours(here, xs, zs).map(func(key): return Vector3(xs[key.x], from.y, zs[key.y]))
	var ends := exits(layout, goal, xs, zs)
	# Dijkstra over crossings keyed by grid index; a few dozen nodes at most.
	var cost := {}
	var first := {}
	var open: Array = []
	for start in starts:
		var key := grid_key(start, xs, zs)
		var value := flat_gap(from, start)
		if value < float(cost.get(key, INF)):
			cost[key] = value
			first[key] = start
			open.append(key)
	var best := INF
	var best_next := goal
	while not open.is_empty():
		open.sort_custom(func(a, b): return cost[a] < cost[b])
		var key: Vector2i = open.pop_front()
		var at := Vector3(xs[key.x], from.y, zs[key.y])
		if cost[key] >= best: break
		for end in ends:
			if end.distance_to(at) < 0.01:
				var total: float = cost[key] + flat_gap(at, goal)
				if total < best:
					best = total
					best_next = first[key]
		for next in neighbours(key, xs, zs):
			var value: float = cost[key] + flat_gap(at, Vector3(xs[next.x], from.y, zs[next.y]))
			if value < float(cost.get(next, INF)):
				cost[next] = value
				first[next] = first[key]
				if next not in open: open.append(next)
	if best == INF: return {"next":road_point(layout, goal), "length":INF}
	return {"next":best_next, "length":best}

static func flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func grid_key(at: Vector3, xs: Array, zs: Array) -> Vector2i:
	return Vector2i(xs.find(nearest(at.x, xs)), zs.find(nearest(at.z, zs)))

# Both ends of one straight stretch with no crossing between, or both in the plaza.
static func shares_stretch(layout, a: Vector3, b: Vector3) -> bool:
	if in_plaza(a) and in_plaza(b): return true
	var xs := roads_x(layout)
	var zs := roads_z(layout)
	var ax = line_of(a.x, xs)
	var bx = line_of(b.x, xs)
	if ax != null and bx != null and is_equal_approx(ax, bx):
		return not zs.any(func(z): return z > minf(a.z, b.z) + 0.05 and z < maxf(a.z, b.z) - 0.05)
	var az = line_of(a.z, zs)
	var bz = line_of(b.z, zs)
	if az != null and bz != null and is_equal_approx(az, bz):
		return not xs.any(func(x): return x > minf(a.x, b.x) + 0.05 and x < maxf(a.x, b.x) - 0.05)
	return false

# Crossings reachable in a straight line: the ends of the road stretch the point
# stands on, or every crossing on the plaza's rim.
static func exits(layout, at: Vector3, xs: Array, zs: Array) -> Array:
	var result: Array = []
	if in_plaza(at):
		for x in xs:
			for z in zs:
				if absf(x) <= PLAZA + 0.01 and absf(z) <= PLAZA + 0.01: result.append(Vector3(x, at.y, z))
	var lx = line_of(at.x, xs)
	if lx != null:
		for z in bracket(at.z, zs): result.append(Vector3(lx, at.y, z))
	var lz = line_of(at.z, zs)
	if lz != null:
		for x in bracket(at.x, xs): result.append(Vector3(x, at.y, lz))
	return result

# The lines just below and above a value (one line when it sits on one).
static func bracket(value: float, lines: Array) -> Array:
	var below := -INF
	var above := INF
	for line in lines:
		if line <= value + 0.05: below = maxf(below, line)
		if line >= value - 0.05: above = minf(above, line)
	var result: Array = []
	if below > -INF: result.append(below)
	if above < INF and not is_equal_approx(above, below): result.append(above)
	return result

static func neighbours(key: Vector2i, xs: Array, zs: Array) -> Array:
	var result: Array = []
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = key + step
		if next.x >= 0 and next.x < xs.size() and next.y >= 0 and next.y < zs.size(): result.append(next)
	# The plaza is open: its rim crossings reach one another straight across.
	var here := Vector3(xs[key.x], 0, zs[key.y])
	if in_plaza(here):
		for i in xs.size():
			for j in zs.size():
				var other := Vector3(xs[i], 0, zs[j])
				if Vector2i(i, j) != key and in_plaza(other): result.append(Vector2i(i, j))
	return result
