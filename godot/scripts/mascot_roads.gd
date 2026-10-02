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
	var goal := project(layout, target)
	if in_plaza(from) and in_plaza(goal): return goal
	# Off the network (e.g. after a knock): step straight back onto the closest road.
	if not walkable(layout, from): return road_point(layout, from)
	if not on_road(layout, from): return road_point(layout, from)
	# The goal is in the plaza: reach the road beside it, then walk in.
	var entry := road_point(layout, goal) if in_plaza(goal) and not on_road(layout, goal) else goal
	return route(layout, from, entry)

static func route(layout, from: Vector3, to: Vector3) -> Vector3:
	var xs := roads_x(layout)
	var zs := roads_z(layout)
	var from_x = line_of(from.x, xs)
	var from_z = line_of(from.z, zs)
	var to_x = line_of(to.x, xs)
	var to_z = line_of(to.z, zs)
	if from_x != null and to_x != null and is_equal_approx(from_x, to_x): return Vector3(from_x, to.y, to.z)
	if from_z != null and to_z != null and is_equal_approx(from_z, to_z): return Vector3(to.x, to.y, from_z)
	if from_x != null and to_z != null: return Vector3(from_x, to.y, to_z)
	if from_z != null and to_x != null: return Vector3(to_x, to.y, from_z)
	if from_x != null and to_x != null: return Vector3(from_x, to.y, nearest((from.z + to.z)*0.5, zs))
	if from_z != null and to_z != null: return Vector3(nearest((from.x + to.x)*0.5, xs), to.y, from_z)
	return to

# A push or an escape keeps to the road: only the part along the current road
# counts (the plaza is open in every direction).
static func along(layout, at: Vector3, direction: Vector3) -> Vector3:
	if in_plaza(at): return direction
	var on_x := line_of(at.x, roads_x(layout)) != null
	var on_z := line_of(at.z, roads_z(layout)) != null
	if on_x and on_z: return Vector3(0, 0, signf(direction.z)) if absf(direction.z) >= absf(direction.x) else Vector3(signf(direction.x), 0, 0)
	if on_x: return Vector3(0, 0, signf(direction.z) if direction.z != 0.0 else 1.0)
	if on_z: return Vector3(signf(direction.x) if direction.x != 0.0 else 1.0, 0, 0)
	return direction
