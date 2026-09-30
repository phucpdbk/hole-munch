extends RefCounted

# Street-front city blocks. Each block becomes a district: shophouses touching
# side by side along the pavement, with high-rise towers (downtown), a green
# courtyard (commercial) or detached houses (residential) behind them.
# The district mix comes from the landmark city's profile (city_profiles.gd).
const StreetModels = preload("res://scripts/street_models.gd")
const PAVEMENT := 1.05
const ALLEY_CHANCE := 0.08
const STREET_TREE_STEP := 6.0
const TOWER_GAP := 0.4

var profile: Dictionary
var districts: Dictionary = {}

# Decide every block's district up front so the ground can pave downtown blocks.
func plan(layout, city_profile: Dictionary, farms: bool, seed_value: int) -> void:
	profile = city_profile
	districts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var towers: float = profile.towers
	var nearest := Vector2.INF
	for x in layout.blocks_x:
		for z in layout.blocks_z:
			var key := Vector2(x, z)
			if x == 0 and z == 0:
				districts[key] = "plaza"
				continue
			if farms and layout.is_edge_block(x, z) and rng.randf() < 0.5:
				districts[key] = "farm"
				continue
			var spread := Vector2(x/layout.half_x, z/layout.half_z).length()/sqrt(2.0)
			var roll := rng.randf()
			if roll < towers*(1.15 - spread*0.6): districts[key] = "downtown"
			elif roll > 0.72 + towers*0.2: districts[key] = "residential"
			else: districts[key] = "commercial"
			if key.length() < nearest.length(): nearest = key
	# Any city with a skyline shows at least one high-rise block near the landmark.
	if towers > 0 and nearest != Vector2.INF and not districts.values().has("downtown"):
		districts[nearest] = "downtown"

func district(x: float, z: float) -> String:
	return districts.get(Vector2(x, z), "commercial")

func fill(g, rng: RandomNumberGenerator, x: float, z: float, size: Vector2) -> void:
	var inner := size/2 - Vector2(PAVEMENT, PAVEMENT)
	match district(x, z):
		"downtown":
			street_front(g, rng, x, z, inner, true)
			towers(g, rng, x, z, inner)
		"commercial":
			street_front(g, rng, x, z, inner, true)
			for dx in [-inner.x*0.3, inner.x*0.3]:
				g.add_item("tree", Vector3(x + dx, 0.16, z + rng.randf_range(-1.0, 1.0)), 0.68, rng.randi_range(0, 1))
		_:
			street_front(g, rng, x, z, inner, false)
			for dx in [-size.x*0.26, size.x*0.26]:
				for dz in [-size.y*0.26, size.y*0.12]:
					g.add_item("house", Vector3(x + dx + rng.randf_range(-0.6, 0.6), 0.16, z + dz), 1.5, rng.randi_range(0, 1), PI if dx > 0 else 0.0)
			for dx in [-inner.x + 0.65, inner.x - 0.65]:
				g.add_item("tree", Vector3(x + dx, 0.16, z - inner.y + 0.65), 0.68, int(dx > 0))
	street_trees(g, x, z, size, inner)

# Shop rows face all four streets (or only the south street for residential
# blocks). The north/south rows run the full width and own the corners.
func street_front(g, rng: RandomNumberGenerator, x: float, z: float, inner: Vector2, all_sides: bool) -> void:
	var depth := StreetModels.DEPTH
	row(g, rng, Vector3(x - inner.x, 0.16, z + inner.y - depth/2), Vector3.RIGHT, inner.x*2, 0.0)
	if not all_sides: return
	row(g, rng, Vector3(x - inner.x, 0.16, z - inner.y + depth/2), Vector3.RIGHT, inner.x*2, PI)
	row(g, rng, Vector3(x + inner.x - depth/2, 0.16, z - inner.y + depth), Vector3.BACK, inner.y*2 - depth*2, PI/2)
	row(g, rng, Vector3(x - inner.x + depth/2, 0.16, z - inner.y + depth), Vector3.BACK, inner.y*2 - depth*2, -PI/2)

func row(g, rng: RandomNumberGenerator, start: Vector3, direction: Vector3, length: float, yaw: float) -> void:
	var width: float = StreetModels.style_of(profile).w
	var count := int(length/width)
	var offset := (length - count*width)/2 + width/2
	var previous := rng.randi_range(0, 2)
	for i in count:
		if rng.randf() < ALLEY_CHANCE: continue
		# Neighbouring shops never repeat, so every row mixes heights and colours.
		var variant := (previous + 1 + rng.randi_range(0, 1)) % 3
		previous = variant
		g.add_item("shop", start + direction*(offset + i*width), StreetModels.shop_radius(profile, variant), variant, yaw)

func towers(g, rng: RandomNumberGenerator, x: float, z: float, inner: Vector2) -> void:
	var room := inner - Vector2.ONE*(StreetModels.DEPTH + TOWER_GAP)
	if room.x < StreetModels.TOWER_SIZE/2 or room.y < StreetModels.TOWER_SIZE/2: return
	var span := StreetModels.TOWER_SIZE*2 + 0.6
	var xs: Array = [-room.x*0.5, room.x*0.5] if room.x*2 >= span else [0.0]
	var zs: Array = [-room.y*0.5, room.y*0.5] if room.y*2 >= span else [0.0]
	var spread := Vector2(x, z).length()/40.0
	var slots := xs.size()*zs.size()
	# Big blocks keep one tower slot as a small tree park.
	var park := rng.randi_range(0, slots - 1) if slots == 4 else -1
	var slot := 0
	for dx in xs:
		for dz in zs:
			if slot == park:
				g.add_item("tree", Vector3(x + dx - 0.7, 0.16, z + dz), 0.68, 0)
				g.add_item("tree", Vector3(x + dx + 0.7, 0.16, z + dz + 0.5), 0.68, 1)
			else:
				var high := rng.randf() < float(profile.towers)*(1.0 - minf(spread, 0.8))
				var variant := 1 if high else 0
				g.add_item("tower", Vector3(x + dx, 0.16, z + dz), StreetModels.tower_radius(variant), variant)
			slot += 1

# Trees along the east, west and north pavements; the south one keeps benches.
func street_trees(g, x: float, z: float, size: Vector2, inner: Vector2) -> void:
	var edge := size/2 - Vector2(0.5, 0.5)
	for along in range(int(-inner.y/STREET_TREE_STEP), int(inner.y/STREET_TREE_STEP) + 1):
		var dz := along*STREET_TREE_STEP
		if absf(dz) > inner.y - 1.0: continue
		for dx in [-edge.x, edge.x]: g.add_item("tree", Vector3(x + dx, 0.16, z + dz), 0.68, int(dx > 0))
	for along in range(int(-inner.x/STREET_TREE_STEP) - 1, int(inner.x/STREET_TREE_STEP) + 1):
		var dx := along*STREET_TREE_STEP + STREET_TREE_STEP/2
		if absf(dx) > inner.x - 1.0: continue
		g.add_item("tree", Vector3(x + dx, 0.16, z - edge.y), 0.68, along & 1)
