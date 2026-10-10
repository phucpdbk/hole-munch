extends Node3D

# Street events for campaign and endless rounds, built to read in a short clip:
# - RUSH HOUR: once the hole can eat a cab, a jam of local vehicles (yellow cabs,
#   London cabs and double-deckers, tuk-tuks, school buses) rolls onto a street
#   near it, bumper to bumper and honking. Bonus food: score and growth, never
#   completion or the landmark's size.
# - Gates: pairs across inner streets, a green ×1.5 and a red −30% side by side.
#   The first one the hole's centre drives through fires and the pair folds away;
#   once the hole is wider than the road it has to aim. The ×1.5 never takes the
#   hole past GATE_CAP of the size the landmark needs.
# Smoke runs switch both off (enabled = false), like showtime.gd.
const I18n = preload("res://scripts/i18n.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Traffic = preload("res://scripts/traffic.gd")
const JAM_CARS := 16
const JAM_AFTER := 10.0
const JAM_DRIVE := 1.1
const JAM_GAP := 0.05
const JAM_RUN := 14.0
# Vehicles models.gd "jamcar" draws, per continent (two kinds keep batches low).
const JAM_MIX := [[0, 3], [1, 2], [0, 3], [0, 4], [0, 2], [0, 2]]
const JAM_RADIUS := [0.8, 0.8, 1.3, 0.6, 1.3]
const LANE := 0.85
# The jam rolls onto the street whose middle is nearest this far from the hole.
const JAM_VIEW := 10.0
const GATE_PAIRS := 2
const GATE_GROW := 1.5
const GATE_SHRINK := 0.7
const GATE_CAP := 0.9
const ROAD_HALF := 1.6
const GATE_HEIGHT := 2.4
const GATE_FOLD := 0.3
const GOOD := Color("3ddc84")
const BAD := Color("ff5a5f")

var enabled := true
var active := false
var jam: Array = []
var jam_state := "wait"
var jam_clock := 0.0
var round_time := 0.0
var gates: Array = []
var last_hole := Vector3.ZERO
var rng := RandomNumberGenerator.new()

# Hidden jam vehicles, made with the city so they share its batches.
func build(game) -> void:
	jam.clear()
	if game.run_kind == "daily": return
	var mix: Array = JAM_MIX[int(game.level.region) % JAM_MIX.size()]
	for i in JAM_CARS:
		var variant: int = mix[i % mix.size()]
		var car: Dictionary = game.add_item("jamcar", Vector3(0, 0.08, 0), JAM_RADIUS[variant], variant)
		car.bonus = true
		car.hidden = true
		car.jam = true
		jam.append(car)

func reset(game) -> void:
	active = enabled and game.run_kind != "daily"
	jam_state = "wait"
	jam_clock = 0.0
	round_time = 0.0
	last_hole = game.hole_position
	for car in jam:
		for key in ["jam_lane", "jam_target", "jam_start", "jam_delay"]: car.erase(key)
	if game.capture_mode: rng.seed = 991 + game.campaign.selected
	else: rng.randomize()
	for gate in gates: gate.node.queue_free()
	gates.clear()
	if active: place_gates(game)

func update(game, dt: float) -> void:
	if not active: return
	round_time += dt
	if jam_state == "wait" and round_time >= JAM_AFTER and game.target_radius*game.EAT_RATIO >= JAM_RADIUS[0] + 0.05:
		start_jam(game)
	if jam_state == "rolling": roll(game, dt)
	check_gates(game)
	fold_gates(dt)
	last_hole = game.hole_position

# --- rush hour ----------------------------------------------------------------------

func start_jam(game) -> void:
	jam_state = "rolling"
	jam_clock = 0.0
	var street := pick_street(game)
	if street.is_empty():
		jam_state = "none"
		return
	var along: Vector3 = street.along
	var across := Vector3(along.z, 0, -along.x)
	var placed := 0
	for lane in [1, -1]:
		var at: float = -street.length/2.0
		for car in jam:
			if car.has("jam_lane") or placed >= JAM_CARS: continue
			if at + car.radius*2.0 > street.length/2.0: break
			at += car.radius
			car.jam_lane = lane
			car.jam_target = street.centre + along*at + across*LANE*lane
			car.jam_start = car.jam_target - along*JAM_RUN*lane
			car.jam_delay = placed*JAM_GAP
			car.yaw = atan2(-along.z*lane, along.x*lane)
			car.origin_yaw = car.yaw
			at += car.radius + 0.25
			placed += 1
	for car in jam:
		if not car.has("jam_lane"): continue
		car.hidden = false
		car.position = car.jam_start
		game.set_item_transform(car)
	game.showtime.callout(I18n.t("rush_hour"), Color("ffc928"))
	game.sfx.play("honk")
	for i in mini(3, placed): game.showtime.shout_at(jam[rng.randi() % placed], "shout_jam")

# Cars drive in from both ends and stop bumper to bumper.
func roll(game, dt: float) -> void:
	jam_clock += dt
	var moving := false
	for car in jam:
		if not car.has("jam_lane") or not Traffic.is_active(car): continue
		var t := clampf((jam_clock - float(car.jam_delay))/JAM_DRIVE, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - t, 3.0)
		car.position = car.jam_start.lerp(car.jam_target, ease)
		car.origin = car.jam_target
		game.set_item_transform(car)
		if t < 1.0: moving = true
	if not moving: jam_state = "parked"

# An inner street segment (between two crossings) whose middle is near JAM_VIEW
# from the hole, so the jam rolls in on screen.
func pick_street(game) -> Dictionary:
	var layout = game.layout
	var best: Dictionary = {}
	var best_score := INF
	for road in layout.crossings_x:
		for j in layout.blocks_z.size():
			var length: float = layout.streets_z[j+1] - layout.streets_z[j] - 3.2
			best_score = consider(game, {"centre":Vector3(road, 0.08, layout.blocks_z[j]), "along":Vector3(0, 0, 1), "length":length}, best_score, best)
	for road in layout.crossings_z:
		for i in layout.blocks_x.size():
			var length: float = layout.streets_x[i+1] - layout.streets_x[i] - 3.2
			best_score = consider(game, {"centre":Vector3(layout.blocks_x[i], 0.08, road), "along":Vector3(1, 0, 0), "length":length}, best_score, best)
	return best

func consider(game, street: Dictionary, best_score: float, best: Dictionary) -> float:
	var gap := Vector2(street.centre.x - game.hole_position.x, street.centre.z - game.hole_position.z).length()
	if gap < game.radius + 3.0: return best_score
	var score := absf(gap - JAM_VIEW)
	if score >= best_score: return best_score
	best.merge(street, true)
	return score

# --- gates --------------------------------------------------------------------------

# Pairs across inner streets mid-block, away from the drop point and each other.
func place_gates(game) -> void:
	var layout = game.layout
	var spots: Array = []
	for road in layout.crossings_x:
		for z in layout.blocks_z: spots.append({"at":Vector3(road, 0, z), "along":Vector3(0, 0, 1)})
	for road in layout.crossings_z:
		for x in layout.blocks_x: spots.append({"at":Vector3(x, 0, road), "along":Vector3(1, 0, 0)})
	spots.shuffle()
	for spot in spots:
		if gates.size() >= GATE_PAIRS*2: break
		if spot.at.distance_to(Vector3(game.hole_position.x, 0, game.hole_position.z)) < 8.0: continue
		if gates.any(func(gate): return gate.at.distance_to(spot.at) < 12.0): continue
		var good_side := 1.0 if rng.randf() < 0.5 else -1.0
		var pair := gates.size()/2
		for side in [1.0, -1.0]:
			gates.append(make_gate(spot.at, spot.along, side, side == good_side, pair))

func make_gate(at: Vector3, along: Vector3, side: float, good: bool, pair: int) -> Dictionary:
	var across := Vector3(along.z, 0, -along.x)
	var node := Node3D.new()
	node.position = at + across*side*ROAD_HALF/2.0
	# Local x (the gate's width) runs across the road.
	node.basis = Basis(Vector3.UP, atan2(-across.z, across.x))
	add_child(node)
	var color := GOOD if good else BAD
	var frame := StandardMaterial3D.new()
	frame.albedo_color = color.darkened(0.25)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color(color, 0.38)
	var width := ROAD_HALF - 0.1
	for x in [-width/2.0, width/2.0]: node.add_child(block(Vector3(x, GATE_HEIGHT/2.0, 0), Vector3(0.14, GATE_HEIGHT, 0.14), frame))
	node.add_child(block(Vector3(0, GATE_HEIGHT, 0), Vector3(width + 0.14, 0.16, 0.16), frame))
	node.add_child(block(Vector3(0, GATE_HEIGHT/2.0, 0), Vector3(width, GATE_HEIGHT, 0.04), glow))
	var label := Label3D.new()
	label.text = "×%s" % str(GATE_GROW) if good else "−%d%%" % roundi((1.0 - GATE_SHRINK)*100)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = UiStyle.font(800)
	label.font_size = 110
	label.outline_size = 28
	label.pixel_size = 0.01
	label.modulate = color.lightened(0.35)
	label.outline_modulate = Color("1d1530")
	label.position = Vector3(0, GATE_HEIGHT + 0.9, 0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(label)
	return {"node":node, "at":at, "along":along, "across":across, "side":side, "good":good, "pair":pair, "used":false, "fold":0.0}

func block(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

# The hole's centre crossed a pair's line within the road: the gate on its side fires.
func check_gates(game) -> void:
	for gate in gates:
		if gate.used or gate.side < 0: continue
		var before: float = (last_hole - gate.at).dot(gate.along)
		var after: float = (game.hole_position - gate.at).dot(gate.along)
		if signf(before) == signf(after) or before == 0.0: continue
		var lateral: float = (game.hole_position - gate.at).dot(gate.across)
		if absf(lateral) > ROAD_HALF + 0.3: continue
		var hit_side := 1.0 if lateral >= 0.0 else -1.0
		for other in gates:
			if other.pair != gate.pair: continue
			other.used = true
			if other.side == hit_side: fire(game, other)

func fire(game, gate: Dictionary) -> void:
	if gate.good:
		var cap: float = game.boss_radius/game.EAT_RATIO*GATE_CAP
		game.target_radius = maxf(game.target_radius, minf(game.target_radius*GATE_GROW, cap))
		game.pulse = 1.0
		game.fx.ripple(game.hole_position, game.target_radius*1.3, GOOD)
		game.showtime.callout(I18n.t("gate_big"), GOOD)
		game.sfx.play("grow")
	else:
		game.target_radius = maxf(float(game.stats.start_radius), game.target_radius*GATE_SHRINK)
		game.fx.shake = maxf(game.fx.shake, 0.5)
		game.fx.ripple(game.hole_position, game.radius, BAD)
		game.showtime.callout(I18n.t("gate_small"), BAD)
		game.sfx.play("shot")

# Used gates sink into the road.
func fold_gates(dt: float) -> void:
	for gate in gates:
		if not gate.used or gate.fold >= 1.0: continue
		gate.fold = minf(1.0, gate.fold + dt/GATE_FOLD)
		gate.node.scale = Vector3(1.0, maxf(0.001, 1.0 - gate.fold), 1.0)
		gate.node.visible = gate.fold < 1.0
