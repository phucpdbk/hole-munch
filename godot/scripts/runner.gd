extends Node3D

# Bonus run, offered after every BONUS_EVERY-th campaign city on its first win.
# The hole rolls forward on its own down one long avenue (the middle column of a
# COLS×ROWS map, the side columns are scenery) and the
# player only steers left and right: food on both halves of the road, a gate
# pair on every other cross street (a choice of size changes), and the city's
# landmark, oversized, waiting at the far end. Big enough by then swallows it.
# game.gd owns the items, the hole and the result; this node builds the course,
# drives the hole and fires the gates.
const I18n = preload("res://scripts/i18n.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const BONUS_EVERY := 5
const COLS := 3
const ROWS := 9
const SPEED := 7.0
const STEER := 9.0
# How far either side of the centre line the hole may roll.
const LANE := 6.6
# The last stretch eases the hole onto the landmark's line.
const FUNNEL := 14.0
const GATE_HEIGHT := 2.6
const GATE_FOLD := 0.3
const GOOD := Color("3ddc84")
const BAD := Color("ff5a5f")
const FAIR := Color("ffd166")
# Gate pairs as [left, right] size multipliers before the side is shuffled; one
# pair in two offers two gains, so the better gain also rewards a sharp eye.
const PAIRS := [[1.5, 0.7], [1.3, 1.1], [1.4, 0.75], [1.2, 1.5], [1.25, 0.8], [1.6, 0.6]]
# Food ladder by progress along the course: [kind, radius, variants].
const FOOD := [
	[["cone", 0.2, 1], ["person", 0.22, 4]],
	[["person", 0.22, 4], ["bench", 0.55, 1]],
	[["bench", 0.55, 1], ["tree", 0.68, 2]],
	[["tree", 0.68, 2], ["car", 0.82, 4]],
	[["car", 0.82, 4], ["house", 1.5, 2]],
	[["house", 1.5, 2], ["tower", 2.0, 1]],
	[["house", 1.5, 2], ["tower", 2.4, 1]],
]
# A player who eats this share of what fits and takes the better gate makes the
# landmark with some room; always the worse gate falls short.
const EAT_SHARE := 0.55
const BOSS_MARGIN := 0.92

var rng := RandomNumberGenerator.new()
var gates: Array = []
var start := Vector3.ZERO
var finish_z := 0.0
# Seconds the hole has sat at the landmark too small to eat it.
var stuck := 0.0
var last_z := 0.0

static func due(index: int) -> bool:
	return (index + 1) % BONUS_EVERY == 0

func clear() -> void:
	for gate in gates: gate.node.queue_free()
	gates.clear()

# Course: food rows in each block, gates on the cross streets, the boss beyond
# the last one. Called instead of make_city().
func build(game, seed_value: int) -> void:
	rng.seed = seed_value
	clear()
	var layout = game.layout
	start = Vector3(0, 0, layout.move_z - 3.0)
	finish_z = -layout.move_z + 6.0
	# Blocks run from the start (largest z) to the finish; the last one is the plaza.
	var blocks: Array = layout.blocks_z.duplicate()
	blocks.reverse()
	for i in blocks.size() - 1:
		var t := float(i)/float(blocks.size() - 2)
		var tier: Array = FOOD[mini(int(t*FOOD.size()), FOOD.size() - 1)]
		fill_block(game, float(blocks[i]), tier, i == 0)
	for x in [-LANE - 1.2, LANE + 1.2]:
		for z in range(int(start.z), int(finish_z), -4):
			var tree: Dictionary = game.add_item("tree", Vector3(x, 0.16, z), 0.68, rng.randi_range(0, 1))
			tree.scenery = true
	for x in layout.blocks_x:
		if x != 0.0:
			for z in layout.blocks_z: fill_scenery(game, x, z)
	var streets: Array = layout.crossings_z.duplicate()
	streets.reverse()
	for i in range(1, streets.size(), 2):
		var pair: Array = PAIRS[(i/2 + rng.randi_range(0, PAIRS.size() - 1)) % PAIRS.size()].duplicate()
		if rng.randf() < 0.5: pair.reverse()
		for side in [-1.0, 1.0]:
			gates.append(make_gate(float(streets[i]), side, pair[0 if side < 0 else 1], i))
	game.make_boss()
	var boss: Dictionary = game.items[game.boss_index]
	game.boss_radius = landmark_radius(game)
	boss.radius = game.boss_radius
	boss.origin = Vector3(0, game.BOSS_HOME.y, finish_z - game.boss_radius*0.4)
	boss.position = boss.origin
	game.mechanics.setup(game, false, seed_value, false)

# Two lanes of loose rows: each half of the road gets its own mix, so steering
# is a choice.
func fill_block(game, z: float, tier: Array, first: bool) -> void:
	var depth: float = 18.0 - 3.6
	for side in [-1.0, 1.0]:
		var pick: Array = tier[rng.randi_range(0, tier.size() - 1)]
		if first: pick = tier[0]
		var size: float = pick[1]
		var gap := maxf(1.6, size*2.6)
		var cols := maxi(1, int((LANE - 0.4)/gap))
		var rows := maxi(1, int(depth/gap))
		for r in rows:
			for c in cols:
				if rng.randf() < 0.22: continue
				# Now and then a smaller snack from the tier sits in the row.
				var kind_pick: Array = tier[0] if rng.randf() < 0.25 else pick
				var x: float = side*(0.6 + gap*0.5 + c*gap) + rng.randf_range(-0.25, 0.25)*gap
				var at := Vector3(clampf(x, -LANE, LANE), 0.16, z - depth/2.0 + gap*0.5 + r*gap + rng.randf_range(-0.2, 0.2)*gap)
				var kind: String = kind_pick[0]
				game.add_item(kind, at, kind_pick[1], rng.randi_range(0, int(kind_pick[2]) - 1), rng.randf_range(0, TAU) if kind != "tower" else 0.0)

# The side columns: houses and towers behind a row of trees, out of the lane.
func fill_scenery(game, x: float, z: float) -> void:
	var inner := x - signf(x)*5.0
	for dz in [-5.0, 0.0, 5.0]:
		var item: Dictionary = game.add_item("house", Vector3(inner, 0.16, z + dz), 1.5, rng.randi_range(0, 1), PI/2 if x > 0 else -PI/2)
		item.scenery = true
	for dz in [-3.5, 3.5]:
		var tower: Dictionary = game.add_item("tower", Vector3(x + signf(x)*2.5, 0.16, z + dz), 2.0, 0)
		tower.scenery = true

# The landmark's size from a simulated good run: rows in course order, a share
# of what fits eaten, the better gate at each cross street.
func landmark_radius(game) -> float:
	var food: Array = game.items.filter(func(item): return not item.get("is_boss", false) and not item.get("bonus", false) and not item.get("scenery", false))
	food.sort_custom(func(a, b): return a.position.z > b.position.z)
	var r: float = float(game.stats.start_radius)
	var next := 0
	var ordered := gates.filter(func(gate): return gate.side < 0)
	ordered.sort_custom(func(a, b): return a.at > b.at)
	for item in food:
		while next < ordered.size() and item.position.z < ordered[next].at:
			r = minf(game.MAX_RADIUS, r*best_gain(ordered[next].pair))
			next += 1
		if item.radius <= r*game.EAT_RATIO: r = sqrt(r*r + EAT_SHARE*item.radius*item.radius*game.GROWTH)
	return clampf(r*game.EAT_RATIO*BOSS_MARGIN, game.MIN_BOSS, game.MAX_RADIUS*game.EAT_RATIO)

func best_gain(pair: int) -> float:
	var best := 0.0
	for gate in gates:
		if gate.pair == pair: best = maxf(best, gate.gain)
	return best

func make_gate(z: float, side: float, gain: float, pair: int) -> Dictionary:
	var node := Node3D.new()
	var width := LANE + 0.4
	node.position = Vector3(side*width/2.0, 0, z)
	add_child(node)
	var color := BAD if gain < 1.0 else GOOD if gain >= 1.4 else FAIR
	var frame := StandardMaterial3D.new()
	frame.albedo_color = color.darkened(0.25)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color(color, 0.32)
	for x in [-width/2.0, width/2.0]: node.add_child(block(Vector3(x, GATE_HEIGHT/2.0, 0), Vector3(0.18, GATE_HEIGHT, 0.18), frame))
	node.add_child(block(Vector3(0, GATE_HEIGHT, 0), Vector3(width + 0.18, 0.2, 0.2), frame))
	node.add_child(block(Vector3(0, GATE_HEIGHT/2.0, 0), Vector3(width, GATE_HEIGHT, 0.04), glow))
	var label := Label3D.new()
	label.text = gain_text(gain)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = UiStyle.font(800)
	label.font_size = 150
	label.outline_size = 34
	label.pixel_size = 0.012
	label.modulate = color.lightened(0.35)
	label.outline_modulate = Color("1d1530")
	label.position = Vector3(0, GATE_HEIGHT + 1.1, 0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(label)
	return {"node":node, "at":z, "side":side, "gain":gain, "pair":pair, "used":false, "fold":0.0, "color":color}

static func gain_text(gain: float) -> String:
	if gain >= 1.0: return "×%s" % str(snappedf(gain, 0.01))
	return "−%d%%" % roundi((1.0 - gain)*100)

func block(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func reset(game) -> void:
	stuck = 0.0
	last_z = start.z
	for gate in gates:
		gate.used = false
		gate.fold = 0.0
		gate.node.scale = Vector3.ONE
		gate.node.visible = true
	game.remaining = time_left(game.hole_position)

func time_left(at: Vector3) -> float:
	return maxf(0.0, (at.z - finish_z)/SPEED)

# Forward on its own, sideways from the stick; the last stretch lines the hole
# up with the landmark. Returns true once the round is over.
func drive(game, dt: float, input: Vector2) -> bool:
	var boss: Dictionary = game.items[game.boss_index]
	var stop: float = boss.position.z + (boss.radius*0.4 if boss.radius <= game.radius*game.EAT_RATIO else boss.radius + game.radius*0.6)
	# A small slack so a hole still settling in size does not creep forward forever.
	var forward := SPEED*float(game.stats.speed) if game.hole_position.z > stop + 0.1 else 0.0
	var lane := LANE
	if game.hole_position.z - finish_z < FUNNEL:
		lane = lerpf(0.0, LANE, clampf((game.hole_position.z - finish_z)/FUNNEL, 0, 1))
	var side := input.x*STEER
	game.hole_velocity = Vector3(side, 0, -forward)
	last_z = game.hole_position.z
	game.hole_position += game.hole_velocity*dt
	game.hole_position.z = maxf(game.hole_position.z, stop)
	game.hole_position.x = clampf(game.hole_position.x, -lane, lane)
	game.remaining = time_left(game.hole_position)
	check_gates(game)
	fold_gates(dt)
	if forward > 0.0 or game.boss_down or boss.fall >= 0: return false
	# Too small at the landmark: a beat to see it, then the round ends.
	if stuck == 0.0:
		game.add_floater(boss.position, I18n.t("run_too_small"), true)
		game.fx.shake = maxf(game.fx.shake, 0.4)
		game.sfx.play("shot")
	stuck += dt
	return stuck > 1.2

# The hole's centre crossed a gate line: the gate on its side fires, the pair folds.
func check_gates(game) -> void:
	for gate in gates:
		if gate.used or gate.side > 0: continue
		if not (last_z > gate.at and game.hole_position.z <= gate.at): continue
		var hit := -1.0 if game.hole_position.x < 0.0 else 1.0
		for other in gates:
			if other.pair != gate.pair: continue
			other.used = true
			if other.side == hit: fire(game, other)

func fire(game, gate: Dictionary) -> void:
	var gain: float = gate.gain
	game.target_radius = clampf(game.target_radius*gain, float(game.stats.start_radius), game.MAX_RADIUS)
	game.fx.ripple(game.hole_position, game.target_radius*1.3, gate.color)
	game.showtime.callout(gain_text(gain), gate.color)
	if gain >= 1.0:
		game.pulse = 1.0
		game.sfx.play("grow")
	else:
		game.fx.shake = maxf(game.fx.shake, 0.5)
		game.sfx.play("shot")

func fold_gates(dt: float) -> void:
	for gate in gates:
		if not gate.used or gate.fold >= 1.0: continue
		gate.fold = minf(1.0, gate.fold + dt/GATE_FOLD)
		gate.node.scale = Vector3(1.0, maxf(0.001, 1.0 - gate.fold), 1.0)
		gate.node.visible = gate.fold < 1.0

# Coins: a share of the food eaten, more for the landmark.
func reward(eaten_points: int, won: bool, coin_mul: float) -> int:
	return roundi((eaten_points/20.0 + (60.0 if won else 0.0))*coin_mul)
