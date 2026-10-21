extends RefCounted

# Boats on a shaped city's water (map_shapes.gd): they drift on slow loops inside
# their bay, lake or river and rock on the waves. The hole never enters the
# water, so only a hole big enough to reach out from the shore can eat one. They
# are optional food: score, never completion or the landmark's size.
# Kinds (models.gd "boat"): 0 Vietnamese sampan with a woven roof, 1 sailboat,
# 2 little ferry, 3 gondola. Each continent floats its own pair.
const KINDS := {"asia":[0, 2], "europe":[3, 1], "africa":[1, 0], "namerica":[1, 2], "samerica":[0, 1], "oceania":[1, 2]}
const RADIUS := [1.0, 1.2, 1.4, 1.0]
# Water per boat (square units); a pond gets one, a long river several.
const AREA_PER_BOAT := 260.0
const MAX_BOATS := 8
# Boats keep this far inside their water so the hull never crosses the kerb.
const MARGIN := 2.2

static func launch(g, rng: RandomNumberGenerator) -> void:
	var kinds: Array = KINDS.get(g.level.style, [1, 2])
	var count := 0
	for rect in g.layout.water_rects:
		var room: Rect2 = rect.grow(-MARGIN).intersection(Rect2(-g.layout.move_x, -g.layout.move_z, g.layout.move_x*2, g.layout.move_z*2))
		if room.size.x < 2.0 or room.size.y < 2.0: continue
		for i in clampi(int(room.get_area()/AREA_PER_BOAT), 1, 3):
			if count >= MAX_BOATS: return
			var kind: int = kinds[count % kinds.size()]
			var centre := room.position + room.size*Vector2(rng.randf_range(0.3, 0.7), rng.randf_range(0.3, 0.7))
			var boat: Dictionary = g.add_item("boat", Vector3(centre.x, 0.06, centre.y), RADIUS[kind], kind)
			boat.optional = true
			# The loop reaches at most to the water's edge round its centre.
			var reach := Vector2(minf(centre.x - room.position.x, room.end.x - centre.x), minf(centre.y - room.position.y, room.end.y - centre.y))
			Traffic.make_walker(boat, reach*0.9, rng.randf_range(0.6, 1.0), rng.randf_range(0, TAU))
			count += 1

const Traffic = preload("res://scripts/traffic.gd")

# Hull along +z (walkers face their heading on +z).
static func parts(m, variant: int) -> Array:
	var parts: Array = []
	var add := func(shape: String, at: Vector3, size: Vector3, color: String, rotation := Vector3.ZERO):
		parts.append(m.piece(shape, at, size, Color(color), rotation))
	match variant:
		0:
			add.call("box", Vector3(0, 0.18, 0), Vector3(0.7, 0.3, 1.8), "6b4226")
			add.call("prism", Vector3(0, 0.18, 0.95), Vector3(0.36, 0.3, 0.36), "6b4226", Vector3(0, PI/2, 0))
			add.call("hemi", Vector3(0, 0.36, -0.15), Vector3(0.42, 0.42, 0.7), "c9a45a")
			add.call("box", Vector3(0, 0.34, 0.55), Vector3(0.18, 0.08, 0.3), "e63946")
		1:
			add.call("box", Vector3(0, 0.2, 0), Vector3(0.75, 0.32, 2.0), "f4f4f4")
			add.call("box", Vector3(0, 0.38, 0), Vector3(0.78, 0.06, 2.02), "3a7bd5")
			add.call("cylinder", Vector3(0, 1.3, 0.1), Vector3(0.05, 2.0, 0.05), "8a5a3c")
			add.call("prism", Vector3(0.02, 1.25, -0.2), Vector3(0.9, 0.04, 0.9), "fff6e0", Vector3(0, 0, PI/2))
		2:
			add.call("box", Vector3(0, 0.24, 0), Vector3(1.0, 0.4, 2.4), "e8423f")
			add.call("box", Vector3(0, 0.62, -0.2), Vector3(0.8, 0.4, 1.2), "f4f4f4")
			add.call("box", Vector3(0, 0.86, -0.2), Vector3(0.9, 0.08, 1.3), "2b2d42")
			add.call("cylinder", Vector3(0, 1.05, -0.5), Vector3(0.12, 0.35, 0.12), "ffd23f")
		_:
			add.call("box", Vector3(0, 0.14, 0), Vector3(0.5, 0.22, 1.9), "1d1d24")
			add.call("box", Vector3(0, 0.34, 0.95), Vector3(0.12, 0.4, 0.1), "c9a45a", Vector3(0.4, 0, 0))
			add.call("box", Vector3(0, 0.3, 0), Vector3(0.36, 0.08, 0.5), "c0213a")
			add.call("cylinder", Vector3(0.18, 0.7, -0.7), Vector3(0.03, 1.0, 0.03), "8a5a3c", Vector3(0.3, 0, 0))
	return parts
