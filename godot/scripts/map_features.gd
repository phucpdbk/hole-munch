extends RefCounted

# Route-planning features on top of the street grid, seeded per city and growing
# with the campaign:
#   gold districts - every bite there scores double and feeds 1.5× growth;
#   roadblocks     - barriers on some crossings that a small hole cannot pass;
#   shortcuts      - an alley cut through a block, lined with small snacks;
#   danger zone    - a block held by a guard squad with bombs, but twice the food.
# plan() runs before the ground is built (it tints districts); build() adds the
# items while the city is filled, before the landmark is sized.
const Traffic = preload("res://scripts/traffic.gd")
const GOLD_POINTS := 2
const GOLD_GROWTH := 1.5
const BARRIER_SIZE := 1.9
const LANE_HALF := 1.4
const SNACK_STEP := 0.9
const SAFE_SPAWN := 6.0
const GOLD_TINT := Color("eccf6e")
const DANGER_TINT := Color("d98a72")

var gold_blocks: Array[Vector2] = []
var danger_blocks: Array[Vector2] = []
var shortcut_blocks: Array[Vector2] = []
var barrier_spots: Array[Vector2] = []
var barriers: Array = []
# Minimap lines of the alleys: [from, to] pairs in world x/z.
var shortcuts: Array = []

# How many of each feature a campaign city gets.
static func counts(index: int) -> Dictionary:
	return {"gold":0 if index < 2 else 1 if index < 16 else 2,
		"barriers":0 if index < 3 else 1 if index < 12 else 2 if index < 24 else 3,
		"shortcuts":0 if index < 5 else 1 if index < 20 else 2,
		"danger":0 if index < 6 else 1}

func plan(layout, districts: Dictionary, index: int, seed_value: int, spawn: Vector3) -> void:
	gold_blocks.clear()
	danger_blocks.clear()
	shortcut_blocks.clear()
	barrier_spots.clear()
	barriers.clear()
	shortcuts.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wanted := counts(index)
	var free: Array[Vector2] = []
	for key in districts:
		if districts[key] not in ["plaza", "farm"]: free.append(key)
	free.sort()
	shuffle(free, rng)
	for i in wanted.gold:
		if not free.is_empty(): gold_blocks.append(free.pop_back())
	for i in wanted.danger:
		if not free.is_empty():
			var key: Vector2 = free.pop_back()
			danger_blocks.append(key)
			# Guards hold an open square, so the extra food has room.
			districts[key] = "commercial"
	for i in wanted.shortcuts:
		if not free.is_empty(): shortcut_blocks.append(free.pop_back())
	var crossings: Array[Vector2] = []
	for x in layout.crossings_x:
		for z in layout.crossings_z:
			if Vector2(x - spawn.x, z - spawn.z).length() > SAFE_SPAWN: crossings.append(Vector2(x, z))
	shuffle(crossings, rng)
	for i in mini(wanted.barriers, crossings.size()): barrier_spots.append(crossings[i])

static func shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap

func zone(x: float, z: float) -> String:
	var key := Vector2(x, z)
	if key in gold_blocks: return "gold"
	if key in danger_blocks: return "danger"
	return ""

# --- city build (game.gd make_city) ------------------------------------------------

func build(g, rng: RandomNumberGenerator) -> void:
	for key in shortcut_blocks: cut_shortcut(g, key, rng)
	for key in danger_blocks: fill_danger(g, key, rng)
	for spot in barrier_spots:
		var barrier: Dictionary = g.add_item("barrier", Vector3(spot.x, 0.16, spot.y), BARRIER_SIZE, 0, PI/2 if rng.randf() < 0.5 else 0.0)
		barrier.barrier = true
		barrier.optional = true
		barriers.append(barrier)
		block_traffic(g, spot, barrier)
	for key in gold_blocks:
		var area := block_rect(g.layout, key)
		for item in g.items:
			if item.get("move", "") == "" and not item.get("defender", false) and area.has_point(Vector2(item.position.x, item.position.z)):
				item.gold = true

# Cars on both roads through the blocked crossing queue up in front of it.
func block_traffic(g, spot: Vector2, barrier: Dictionary) -> void:
	for car in g.items:
		if car.get("move", "") != "car": continue
		if absf(car.lateral - (spot.y if car.axis == "h" else spot.x)) < 1.0:
			car.blocks = car.get("blocks", []) + [{"at":spot.x if car.axis == "h" else spot.y, "item":barrier}]

func block_rect(layout, key: Vector2) -> Rect2:
	var size: Vector2 = layout.block_size(key.x, key.y)
	return Rect2(key - size/2, size)

# A north-south alley through the block: buildings in the lane give way to a
# line of cones and benches, a quick snack trail for a small hole.
func cut_shortcut(g, key: Vector2, rng: RandomNumberGenerator) -> void:
	var area := block_rect(g.layout, key)
	var lane := Rect2(key.x - LANE_HALF, area.position.y - 1.6, LANE_HALF*2, area.size.y + 3.2)
	g.items.assign(g.items.filter(func(item): return item.get("move", "") == "car" or not lane.has_point(Vector2(item.position.x, item.position.z))))
	var z := area.position.y + 0.8
	var i := 0
	while z < area.end.y - 0.8:
		if i % 4 == 3: g.add_item("bench", Vector3(key.x + 0.6, 0.16, z), 0.55, 0, PI/2)
		else: g.add_item("cone", Vector3(key.x + (0.35 if i % 2 == 0 else -0.35), 0.07, z), 0.2)
		z += SNACK_STEP
		i += 1
	shortcuts.append([Vector2(key.x, area.position.y), Vector2(key.x, area.end.y)])

# Twice the food, held by a squad that stays put and two bombs on the ground.
func fill_danger(g, key: Vector2, rng: RandomNumberGenerator) -> void:
	var area := block_rect(g.layout, key)
	var inner := area.grow(-3.2)
	for row in 4:
		for col in 5:
			var at := Vector3(inner.position.x + inner.size.x*(col + 0.5)/5.0, 0.16, inner.position.y + inner.size.y*(row + 0.5)/4.0)
			match (row + col) % 3:
				0: g.add_item("bench", at, 0.55, 0, rng.randf_range(0, TAU))
				1:
					var walker: Dictionary = g.add_item("person", at, 0.22, (row + col) % 4)
					Traffic.make_walker(walker, Vector2(0.3, 0.2), 0.3, rng.randf_range(0, TAU))
				_: g.add_item("tree", at, 0.68, col % 2)
	var corners := [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1)]
	for i in corners.size():
		var at: Vector2 = key + corners[i]*(inner.size/2 - Vector2(0.6, 0.6))
		var tank := i == 0
		var guard: Dictionary = g.add_item("patrol_tank" if tank else "soldier", Vector3(at.x, 0.16, at.y), 1.5 if tank else 0.36)
		guard.defender = true
		guard.stay = true
	for side in [-1.0, 1.0]:
		var bomb: Dictionary = g.add_item("bomb", Vector3(key.x + side*inner.size.x*0.3, 0.16, key.y - side*1.2), g.Mechanics.BOMB_SIZE)
		bomb.bomb = true
		bomb.optional = true

# --- per frame ----------------------------------------------------------------------

# Keeps a hole that is too small to eat a barrier outside it. A push straight into
# one slides around it, so neither the player nor the rival gets stuck.
func collide(position: Vector3, hole_radius: float, eat_ratio: float, motion: Vector3) -> Vector3:
	for barrier in barriers:
		if not Traffic.is_active(barrier) or barrier.radius <= hole_radius*eat_ratio: continue
		var offset := Vector3(position.x - barrier.position.x, 0, position.z - barrier.position.z)
		var reach: float = barrier.radius*0.75 + hole_radius*0.5
		var distance := offset.length()
		if distance >= reach: continue
		var normal := offset/distance if distance > 0.001 else Vector3.BACK
		var tangent := Vector3(-normal.z, 0, normal.x)
		if tangent.dot(motion) < 0: tangent = -tangent
		var depth := reach - distance
		position.x = barrier.position.x + normal.x*reach + tangent.x*minf(depth, 0.12)
		position.z = barrier.position.z + normal.z*reach + tangent.z*minf(depth, 0.12)
	return position

# --- minimap ------------------------------------------------------------------------

func minimap(layout) -> Dictionary:
	var zones: Array = []
	for key in gold_blocks: zones.append({"rect":block_rect(layout, key), "color":GOLD_TINT})
	for key in danger_blocks: zones.append({"rect":block_rect(layout, key), "color":DANGER_TINT})
	var blocks: Array = []
	for barrier in barriers:
		if Traffic.is_active(barrier): blocks.append(Vector2(barrier.position.x, barrier.position.z))
	return {"zones":zones, "shortcuts":shortcuts, "barriers":blocks}
