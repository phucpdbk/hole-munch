extends RefCounted

# Where the saucer drops in: a random inner street each round, so every run of a
# city opens differently. Candidates are the midpoints of inner street segments
# (at least half a block from any crossing, so barriers never sit on the drop),
# kept clear of the landmark, its guardian, the rival's corner and the bombs.
# The designed opening street (game.SPAWN) is always a candidate. The opening
# cones follow the saucer as a row along the new street's centre line.
const BOSS_GAP := 3.0
const GUARDIAN_GAP := 8.0
const RIVAL_GAP := 14.0
const BOMB_GAP := 6.0
# Cones stop this far short of the crossings at either end of the segment.
const CONE_MARGIN := 2.5
const CONE_STEP := 0.82

# Each candidate: {"at": Vector3, "axis": Vector3 along the street, "length": float}.
static func candidates(g) -> Array:
	var layout = g.layout
	var list: Array = [{"at":g.SPAWN, "axis":Vector3.RIGHT, "length":18.0}]
	for z in layout.crossings_z: list.append_array(segments(layout.streets_x, z, true))
	for x in layout.crossings_x: list.append_array(segments(layout.streets_z, x, false))
	return list.filter(func(spot): return spot.at.is_equal_approx(g.SPAWN) or clear(g, spot.at))

static func segments(streets: Array, line: float, horizontal: bool) -> Array:
	var list: Array = []
	for i in streets.size() - 1:
		var mid: float = (streets[i] + streets[i+1])*0.5
		list.append({"at":Vector3(mid, 0, line) if horizontal else Vector3(line, 0, mid),
			"axis":Vector3.RIGHT if horizontal else Vector3.BACK, "length":float(streets[i+1] - streets[i])})
	return list

static func clear(g, at: Vector3) -> bool:
	if flat(at, g.BOSS_HOME) < g.boss_radius + BOSS_GAP: return false
	var guardian: Dictionary = g.mechanics.guardian
	if not guardian.is_empty() and flat(at, guardian.origin) < GUARDIAN_GAP: return false
	if g.level.get("rival", false) and flat(at, Vector3(g.layout.move_x*0.8, 0, -g.layout.move_z*0.8)) < RIVAL_GAP: return false
	for bomb in g.mechanics.bombs:
		if flat(at, bomb.origin) < BOMB_GAP: return false
	return true

static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

static func pick(g, rng: RandomNumberGenerator) -> Dictionary:
	var list := candidates(g)
	return list[rng.randi()%list.size()]

# The designed opening stays on its own street; elsewhere the cones line up
# along the new street, centred on the drop point.
static func place_opening(g, spot: Dictionary) -> void:
	var cones: Array = g.items.filter(func(item): return item.has("opening_origin"))
	if cones.is_empty(): return
	var designed: bool = spot.at.is_equal_approx(g.SPAWN)
	var span := maxf(0.0, spot.length*0.5 - CONE_MARGIN)
	var step := minf(CONE_STEP, 2.0*span/maxf(1.0, cones.size() - 1))
	for i in cones.size():
		var cone: Dictionary = cones[i]
		if designed:
			cone.origin = cone.opening_origin
			continue
		var offset := (i - (cones.size() - 1)*0.5)*step
		cone.origin = Vector3(spot.at.x, cone.opening_origin.y, spot.at.z) + spot.axis*offset
