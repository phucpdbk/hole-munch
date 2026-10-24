extends RefCounted

# The find-the-cow daily (cow_hunt.gd) plays in the countryside instead of a
# city: no buildings, traffic, army or landmark, only farmland split into four
# zones the third clue can name. Each block takes the zone of its side of the
# map (forest north, cornfield east, farmyard south, wheat west, meadow in the
# middle), and a big floating sign names every zone.
const I18n = preload("res://scripts/i18n.gd")
const Models = preload("res://scripts/models.gd")
const Traffic = preload("res://scripts/traffic.gd")
const UiStyle = preload("res://scripts/ui_style.gd")

# Slab, dirt track, verge, grass, foliage, light, roof, roof (as Campaign palettes).
const PALETTE := ["6f8a4a", "a68a5f", "8fb062", "9cc26a", "4f8f3c", "f3ead0", "b5523b", "d9a441"]
const GROUND := {"forest":"7fae58", "corn":"b8c46a", "farm":"b59c6b", "wheat":"d2c27a", "meadow":"9cc26a"}
const ZONE_BY_SIDE := {"north":"forest", "east":"corn", "south":"farm", "west":"wheat"}
# Cows keep this far from props (more from trees, tents and fences), so they
# stand in aisles, clearings and on tracks instead of hiding inside the crops.
const BIG := 0.6
const MARGIN := 0.35
const BIG_MARGIN := 0.9

var cells: Dictionary = {}  # Vector2 cell centre -> zone
var blockers: Array = []    # [position, clearance] of every prop

# --- zones -----------------------------------------------------------------------

static func side(at: Vector3) -> String:
	if absf(at.x) >= absf(at.z): return "east" if at.x > 0 else "west"
	return "south" if at.z > 0 else "north"

func plan(layout) -> void:
	cells.clear()
	for cell in layout.cells():
		cells[cell] = "meadow" if cell == Vector2.ZERO else ZONE_BY_SIDE[side(Vector3(cell.x, 0, cell.y))]

# The zone of the block nearest to a spot (a cow on a track counts for the field beside it).
func zone(at: Vector3) -> String:
	var best := INF
	var found := "meadow"
	for cell in cells:
		var gap: float = Vector2(at.x, at.z).distance_squared_to(cell)
		if gap < best:
			best = gap
			found = cells[cell]
	return found

func ground(x: float, z: float) -> Color:
	return Color(GROUND[cells.get(Vector2(x, z), "meadow")])

func colors() -> Array:
	return PALETTE

# The fields need no ground details (theme_maps.gd draws its own).
func ground_parts(_layout, _models) -> Array:
	return []

# --- build -----------------------------------------------------------------------

func build(g, rng: RandomNumberGenerator) -> void:
	blockers.clear()
	for cell in cells:
		var inner: Vector2 = g.layout.block_size(cell.x, cell.y) - Vector2.ONE*2.6
		match cells[cell]:
			"forest": forest(g, rng, cell, inner)
			"corn": rows(g, cell, inner, "crops_cornStageD", Vector2(1.1, 1.5))
			"wheat": wheat(g, rng, cell, inner)
			"farm": farmyard(g, rng, cell, inner)
			_: meadow(g, rng, cell, inner)
	signs(g)

func prop(g, id: String, at: Vector3, yaw := 0.0) -> Dictionary:
	var radius: float = Models.FARM_RADIUS[id]
	blockers.append([at, radius + (BIG_MARGIN if radius >= BIG else MARGIN)])
	return g.add_item("farm_" + id, at, radius, 0, yaw)

func forest(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	for gx in range(int(-inner.x/2), int(inner.x/2) + 1, 2):
		for gz in range(int(-inner.y/2), int(inner.y/2) + 1, 2):
			if rng.randf() < 0.22: continue  # clearings where the cows graze
			var at := Vector3(cell.x + gx + rng.randf_range(-0.5, 0.5), 0.16, cell.y + gz + rng.randf_range(-0.5, 0.5))
			if rng.randf() < 0.5: prop(g, "tree_oak", at, rng.randf_range(0, TAU))
			else:
				g.add_item("tree", at, 0.68, rng.randi_range(0, 1))
				blockers.append([at, 0.68 + BIG_MARGIN])

# Crop rows with an open aisle down the middle.
func rows(g, cell: Vector2, inner: Vector2, id: String, step: Vector2) -> void:
	var x := -inner.x/2
	while x <= inner.x/2:
		var z := -inner.y/2
		while z <= inner.y/2:
			if absf(z) > 1.2: prop(g, id, Vector3(cell.x + x, 0.2, cell.y + z))
			z += step.y
		x += step.x

func wheat(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	rows(g, cell, inner, "crops_wheatStageB", Vector2(1.2, 1.3))
	for i in 6:
		prop(g, "pumpkin", Vector3(cell.x + rng.randf_range(-inner.x/2, inner.x/2), 0.2, cell.y + rng.randf_range(-0.8, 0.8)))

# A tent for a barn, a fence round the yard with a gate, pigs and chickens.
func farmyard(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	prop(g, "tent_smallOpen", Vector3(cell.x - inner.x/4, 0.18, cell.y - inner.y/4), PI/4)
	var half := inner/2
	var along := -half.x
	while along <= half.x:
		if absf(along) > 1.5:
			prop(g, "fence_simple", Vector3(cell.x + along, 0.18, cell.y - half.y))
			prop(g, "fence_simple", Vector3(cell.x + along, 0.18, cell.y + half.y))
		along += 1.3
	along = -half.y + 1.3
	while along < half.y:
		prop(g, "fence_simple", Vector3(cell.x - half.x, 0.18, cell.y + along), PI/2)
		prop(g, "fence_simple", Vector3(cell.x + half.x, 0.18, cell.y + along), PI/2)
		along += 1.3
	for i in 8:
		var id := "pig" if i < 3 else "chicken"
		var animal := prop(g, id, Vector3(cell.x + rng.randf_range(0, half.x - 1.0), 0.18, cell.y + rng.randf_range(-half.y + 1.0, half.y - 1.0)), rng.randf_range(0, TAU))
		Traffic.make_walker(animal, Vector2(0.45, 0.35), 0.3, rng.randf_range(0, TAU))

func meadow(g, rng: RandomNumberGenerator, cell: Vector2, inner: Vector2) -> void:
	for dx in [-inner.x/2, inner.x/2]:
		for dz in [-inner.y/2, inner.y/2]:
			prop(g, "tree_oak", Vector3(cell.x + dx, 0.16, cell.y + dz), rng.randf_range(0, TAU))
	for i in 10:
		prop(g, "pumpkin", Vector3(cell.x + rng.randf_range(-inner.x/2, inner.x/2), 0.2, cell.y + rng.randf_range(-inner.y/2, inner.y/2)))

# One sign per zone, over the middle of its blocks.
func signs(g) -> void:
	var centres: Dictionary = {}
	for cell in cells:
		if cells[cell] == "meadow": continue
		if not centres.has(cells[cell]): centres[cells[cell]] = []
		centres[cells[cell]].append(cell)
	for key in centres:
		var middle := Vector2.ZERO
		for cell in centres[key]: middle += cell
		middle /= centres[key].size()
		var label := Label3D.new()
		label.text = I18n.t("zone_" + key)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font = UiStyle.font(800)
		label.font_size = 140
		label.outline_size = 32
		label.pixel_size = 0.012
		label.modulate = Color("fff4d6", 0.9)
		label.outline_modulate = Color("4a3a1c")
		# High above the fields, so it never covers the name tag over a cow.
		label.position = Vector3(middle.x, 10.0, middle.y)
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.world.add_child(label)

# --- cows ----------------------------------------------------------------------------

# A grazing spot anywhere on the map, clear of every prop, away from the drop point.
func spot(g, rng: RandomNumberGenerator, clear: float) -> Vector3:
	var at := Vector3.ZERO
	for attempt in 60:
		at = Vector3(rng.randf_range(-g.layout.move_x, g.layout.move_x), 0.16, rng.randf_range(-g.layout.move_z, g.layout.move_z))
		if at.distance_to(g.SPAWN) < clear: continue
		if blockers.all(func(entry): return Vector2(at.x - entry[0].x, at.z - entry[0].z).length() > entry[1]): break
	return at
