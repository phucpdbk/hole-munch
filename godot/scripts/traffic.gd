extends RefCounted

# Lane traffic with signalled crossings, and pedestrians strolling around a home spot.
# Cars keep a single "along" coordinate on their lane and wrap at the map edge, like
# the 2D game. Signals alternate between the two road directions with an all-red
# clearing phase long enough for a committed car to leave the crossing.
# Each car carries its lane length ("wrap") and the crossings on its road, so the
# same rules work for every map size.
const BOX := 2.35
const FOLLOW_GAP := 2.5
const ACCEL := 2.4
const BRAKE := 4.0
const STOP_SLACK := 0.05
const EDGE_FADE := 1.2
const GREEN := 5.0
const CLEAR := 2.6
const CYCLE := (GREEN + CLEAR) * 2.0

var clock := 0.0

# "h" when horizontal lanes may enter crossings, "v" for vertical, "" while clearing.
func green_axis() -> String:
	var t := fmod(clock, CYCLE)
	if t < GREEN: return "h"
	if t >= GREEN + CLEAR and t < GREEN * 2.0 + CLEAR: return "v"
	return ""

static func make_car(item: Dictionary, axis: String, road: float, lane: int, along: float, speed: float, wrap: float, crossings: Array[float]) -> void:
	item.move = "car"
	item.wrap = wrap
	item.crossings = crossings
	item.axis = axis
	item.direction = lane
	item.lane_id = "%s%.0f%+d" % [axis, road, lane]
	item.start_along = along
	item.along = along
	item.speed = speed
	item.velocity = speed
	# Right-hand traffic: eastbound cars use the south lane, southbound the west lane.
	item.lateral = road + lane * 0.85 if axis == "h" else road - lane * 0.85
	item.yaw = (0.0 if lane > 0 else PI) if axis == "h" else (-PI / 2 if lane > 0 else PI / 2)
	item.origin_yaw = item.yaw
	place_car(item)
	item.origin = item.position

static func make_walker(item: Dictionary, amplitude: Vector2, walk_speed: float, phase: float) -> void:
	item.move = "walk"
	item.home = item.origin
	item.amplitude = amplitude
	item.walk_speed = walk_speed
	item.phase = phase

static func place_car(item: Dictionary) -> void:
	var y: float = item.origin.y
	item.position = Vector3(item.along, y, item.lateral) if item.axis == "h" else Vector3(item.lateral, y, item.along)

# Cars shrink out of view at the map edge before wrapping to the other side.
static func edge_scale(item: Dictionary) -> float:
	if item.get("move", "") != "car": return 1.0
	return clampf((item.wrap - absf(item.along)) / EDGE_FADE, 0.0, 1.0)

static func is_active(item: Dictionary) -> bool:
	return not item.eaten and item.fall < 0 and not item.get("hidden", false)

func update(items: Array, dt: float) -> void:
	clock += dt
	var lanes := {}
	for item in items:
		if item.get("move", "") == "car" and is_active(item):
			if not lanes.has(item.lane_id): lanes[item.lane_id] = []
			lanes[item.lane_id].append(item)
	var green := green_axis()
	for lane_id in lanes:
		var lane: Array = lanes[lane_id]
		var moves: Array[float] = []
		for car in lane: moves.append(allowed_move(car, lane, green, dt))
		for i in lane.size():
			var car: Dictionary = lane[i]
			car.along = wrapf(car.along + car.direction * moves[i], -car.wrap, car.wrap)
			place_car(car)
	for item in items:
		if item.get("move", "") == "walk" and is_active(item): place_walker(item)

# Cars ease off toward the car ahead or a red stop line and pull away smoothly.
func allowed_move(car: Dictionary, lane: Array, green: String, dt: float) -> float:
	var room := INF
	for other in lane:
		if other != car:
			var gap := wrapf((other.along - car.along) * car.direction, 0.0, car.wrap * 2.0)
			room = minf(room, maxf(0.0, gap - FOLLOW_GAP))
	if green != car.axis:
		for crossing in car.crossings:
			var ahead: float = (crossing - car.along) * car.direction
			# Only cars that have not yet entered the crossing wait at the stop line.
			if ahead > BOX - STOP_SLACK: room = minf(room, maxf(0.0, ahead - BOX))
	var target: float = minf(car.speed, sqrt(2.0 * BRAKE * room))
	car.velocity = target if target < car.velocity else move_toward(car.velocity, target, ACCEL * dt)
	return minf(car.velocity * dt, room)

# Lamp colour for signals facing one axis: green, amber while clearing, or red.
func lamp_color(axis: String) -> Color:
	var green := green_axis()
	if green == axis: return Color("63e08a")
	var t := fmod(clock, CYCLE)
	var clearing_mine := (axis == "h" and t >= GREEN and t < GREEN + CLEAR) or (axis == "v" and t >= GREEN * 2.0 + CLEAR)
	return Color("ffc14d") if clearing_mine else Color("ff5a4f")

# Stroll on a small figure-eight around home, facing the walking direction.
func place_walker(item: Dictionary) -> void:
	var amplitude: Vector2 = item.amplitude
	var rate: float = item.walk_speed / maxf(0.05, amplitude.x)
	var t: float = clock * rate + item.phase
	var z_phase: float = t * 0.63 + item.phase * 1.7
	var velocity := Vector2(cos(t) * amplitude.x, cos(z_phase) * amplitude.y * 0.63)
	item.position = item.home + Vector3(sin(t) * amplitude.x, 0, sin(z_phase) * amplitude.y)
	item.position.y = item.home.y + absf(sin(t * 5.0)) * 0.05
	if velocity.length() > 0.001: item.yaw = atan2(velocity.x, velocity.y)
	item.roll = sin(t * 5.0) * 0.08
