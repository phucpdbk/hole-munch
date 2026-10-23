extends Node3D

# Daily mini-game "siege" (daily_games.gd): the army sends its air force after
# the saucer over today's city. The saucer fires on its own at the nearest
# enemy in RANGE; the player only steers. Holding still beside a helicopter
# reels it up in the tractor beam (CAPTURE_TIME) and it flies as an escort
# that fires too, for ESCORT_TIME. Three stages (STAGES): helicopters (circle
# and shoot), then jets join (a warned strafing line), then flak guns (warned
# blasts on the ground) and the command blimp, which fires rings and ends the
# run when it falls. A stage clears at its goal of enemy points, gives a life
# back and a breather. Three hits end the run. Every enemy downed scores its
# value; some drop a spread or rapid-fire power. Meshy models
# (assets/aircraft, tools/bake_aircraft.gd) replace the block models when baked.
const I18n = preload("res://scripts/i18n.gd")
const LIVES := 3
const HIT_GRACE := 1.2
const PLAYER_RADIUS := 0.8
const FLY_Y := 4.3
# Planes are drawn bigger than life so they read at the city's zoom.
const MODEL_SCALE := 1.6
# Inside the screen, so the player sees what the saucer shoots at.
const RANGE := 8.0
const FIRE_EVERY := 0.24
const RAPID_EVERY := 0.12
const SPREAD := 0.22
const SHOT_SPEED := 24.0
const SHOT_LIFE := 0.6
const FOE_SHOT_SPEED := 6.5
const FOE_SHOT_LIFE := 4.0
const CAPTURE_REACH := 3.2
const CAPTURE_TIME := 0.6
const ESCORT_TIME := 8.0
const ESCORT_FIRE := 0.35
const ESCORT_ORBIT := 2.2
const POWER_TIME := 5.0
const POWER_LIFE := 7.0
const DROP_SHARE := 0.18
const MAX_FOES := 8
# Helicopters circle this far out, inside the screen.
const HELI_ORBIT := 5.5
# Main rotor turn rate, radians per second.
const ROTOR_SPIN := 18.0
const SPAWN_DISTANCE := 15.0
# goal: enemy points to clear the stage (0: down the blimp); gap: seconds
# between spawns.
const STAGES := [
	{"goal":10, "kinds":["heli"], "gap":1.5},
	{"goal":14, "kinds":["heli", "heli", "jet"], "gap":1.4},
	{"goal":0, "kinds":["heli", "jet", "flak"], "gap":1.8, "boss":"blimp"},
]
const BREATHER := 2.5
const MODEL_DIR := "res://assets/aircraft/"
const FOES := {
	"heli":{"hp":3, "value":1, "radius":0.8, "speed":4.0, "fire":2.2},
	"jet":{"hp":3, "value":2, "radius":0.9, "speed":16.0, "warn":1.0},
	"flak":{"hp":3, "value":2, "radius":0.9, "fire":2.6, "life":18.0},
	"blimp":{"hp":24, "value":6, "radius":2.0, "speed":1.6, "fire":3.0},
}
const BLAST_WARN := 1.2
const BLAST_RADIUS := 1.5
const RING_SHOTS := 10
const POWERS := {"spread":Color("62ead3"), "rapid":Color("ffb34c")}

var rng := RandomNumberGenerator.new()
var seed_value := 0
var foes: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var foe_shots: Array[Dictionary] = []
var blasts: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var escort := {}
var lives := LIVES
var grace := 0.0
var fire_timer := 0.0
var spawn_timer := 1.0
var capture_progress := 0.0
var capture_target := {}
var power := ""
var power_time := 0.0
var stage := 0
var stage_points := 0
var boss_down := false
# Baked Meshy meshes per kind (null where there is none).
var baked := {}
var clock := 0.0
var count := 0
var downed := 0
var beam: MeshInstance3D
var meshes := {}
var materials := {}

# --- setup -----------------------------------------------------------------------

func build(value: int) -> void:
	seed_value = value
	if meshes.is_empty(): make_meshes()
	reset()

func reset() -> void:
	clear()
	rng.seed = seed_value
	lives = LIVES
	grace = 0.0
	fire_timer = 0.0
	spawn_timer = 1.0
	capture_progress = 0.0
	capture_target = {}
	power = ""
	power_time = 0.0
	clock = 0.0
	count = 0
	downed = 0
	stage = 0
	stage_points = 0
	boss_down = false

func clear() -> void:
	for list in [foes, shots, foe_shots, blasts, pickups]:
		for entry in list: entry.node.queue_free()
		list.clear()
	if not escort.is_empty(): escort.node.queue_free()
	escort = {}
	if is_instance_valid(beam): beam.visible = false

func make_meshes() -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	meshes.shot = ball
	var orb := SphereMesh.new()
	orb.radius = 0.45
	orb.height = 0.9
	meshes.orb = orb
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.04
	meshes.disc = disc
	materials.shot = glow(Color("8ff7ff"))
	materials.foe_shot = glow(Color("ff7a4d"))
	materials.warn = glow(Color(1.0, 0.2, 0.15, 0.35))
	materials.beam = glow(Color(0.7, 1.0, 0.9, 0.35))
	beam = MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.35
	tube.bottom_radius = 0.6
	tube.height = 1.0
	beam.mesh = tube
	beam.material_override = materials.beam
	beam.visible = false
	add_child(beam)

func glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if color.a < 1.0: material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func flat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material

func part(root: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = flat(color)
	node.position = at
	root.add_child(node)
	return node

# The baked Meshy model of a kind, textured like the saucers, or null.
# The rotor ("heli_rotor") shares the helicopter's texture.
func baked_mesh(game, kind: String) -> ArrayMesh:
	if baked.has(kind): return baked[kind]
	var path := MODEL_DIR + kind + ".res"
	var texture := MODEL_DIR + kind.trim_suffix("_rotor") + "_albedo.res"
	var mesh: ArrayMesh = null
	if ResourceLoader.exists(path) and ResourceLoader.exists(texture):
		mesh = load(path).duplicate()
		var material: ShaderMaterial = game.models.landmark_material.duplicate()
		material.set_shader_parameter("albedo_tex", load(texture))
		mesh.surface_set_material(0, material)
	baked[kind] = mesh
	return mesh

# The Meshy model at its baked size, else simple block models (army green
# with the defence's red markings) drawn MODEL_SCALE up.
func foe_model(game, kind: String) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var mesh := baked_mesh(game, kind)
	if mesh:
		var body := MeshInstance3D.new()
		body.mesh = mesh
		root.add_child(body)
		root.set_meta("scale", 1.0)
		# The baked helicopter's main rotor spins on its hub (tools/bake_aircraft.gd).
		var blades := baked_mesh(game, kind + "_rotor") if kind == "heli" else null
		if blades:
			var rotor := MeshInstance3D.new()
			rotor.name = "Rotor"
			rotor.mesh = blades
			rotor.position = blades.get_meta("hub", Vector3.ZERO)
			root.add_child(rotor)
		return root
	root.set_meta("scale", MODEL_SCALE)
	match kind:
		"heli":
			part(root, Vector3(0.9, 0.6, 1.4), Vector3.ZERO, Color("5b6b3a"))
			part(root, Vector3(0.2, 0.2, 1.3), Vector3(0, 0.1, 1.2), Color("4a5830"))
			var rotor := part(root, Vector3(2.4, 0.05, 0.18), Vector3(0, 0.42, 0), Color("2b2b2b"))
			rotor.name = "Rotor"
			part(root, Vector3(0.5, 0.3, 0.3), Vector3(0, 0.05, -0.75), Color("9fd0ff"))
		"jet":
			part(root, Vector3(0.5, 0.35, 2.4), Vector3.ZERO, Color("7a8592"))
			part(root, Vector3(2.4, 0.08, 0.8), Vector3(0, 0, 0.2), Color("66717d"))
			part(root, Vector3(0.08, 0.6, 0.5), Vector3(0, 0.35, 1.0), Color("c0392b"))
		"flak":
			part(root, Vector3(1.4, 0.5, 1.4), Vector3(0, 0.25, 0), Color("4f5b34"))
			part(root, Vector3(0.25, 0.25, 1.3), Vector3(0, 0.8, -0.3), Color("2f3522")).rotation.x = 0.7
		"blimp":
			var hull := MeshInstance3D.new()
			var capsule := CapsuleMesh.new()
			capsule.radius = 1.3
			capsule.height = 5.0
			hull.mesh = capsule
			hull.rotation.x = PI/2
			hull.material_override = flat(Color("8a8f98"))
			root.add_child(hull)
			part(root, Vector3(1.0, 0.6, 1.6), Vector3(0, -1.4, 0), Color("4a5059"))
			part(root, Vector3(0.1, 1.4, 1.0), Vector3(0, 0.9, 2.2), Color("c0392b"))
	return root

# --- round -------------------------------------------------------------------------

# player: the saucer's ground point; still: no steering this frame.
func update(game, dt: float, player: Vector3, still: bool) -> void:
	clock += dt
	grace = maxf(0.0, grace - dt)
	power_time = maxf(0.0, power_time - dt)
	if power_time <= 0.0: power = ""
	spawn(game, dt, player)
	for foe in foes.duplicate(): move_foe(game, foe, dt, player)
	if stage_goal() > 0 and stage_points >= stage_goal() and stage < STAGES.size() - 1: advance_stage(game, player)
	fire(game, dt, player)
	move_shots(game, dt, player)
	update_blasts(game, dt, player)
	update_capture(game, dt, player, still)
	update_escort(game, dt, player)
	update_pickups(game, dt, player)

func stage_goal() -> int:
	return int(STAGES[stage].goal)

func won() -> bool:
	return boss_down

# Stages fully cleared (a star each).
func stages_cleared() -> int:
	return STAGES.size() if boss_down else stage

func spawn(game, dt: float, player: Vector3) -> void:
	if boss_down: return
	spawn_timer -= dt
	if spawn_timer > 0.0 or foes.size() >= MAX_FOES: return
	var current: Dictionary = STAGES[stage]
	spawn_timer = float(current.gap)
	var kinds: Array = current.kinds
	add_foe(game, kinds[rng.randi_range(0, kinds.size() - 1)], player)

# A stage's goal met: a life back, a breather and the next stage (whose boss,
# if any, arrives at once).
func advance_stage(game, player: Vector3) -> void:
	stage += 1
	stage_points = 0
	lives = mini(LIVES, lives + 1)
	spawn_timer = BREATHER
	for shot in foe_shots.duplicate(): drop_shot(foe_shots, shot)
	game.add_floater(game.hole_position, I18n.t("siege_stage", stage + 1), true)
	game.fx.ripple(player, 3.0, POWERS.spread)
	game.sfx.play("grow")
	var boss: String = STAGES[stage].get("boss", "")
	if boss != "": add_foe(game, boss, player)

func edge_point(game, player: Vector3, distance: float) -> Vector3:
	var angle := rng.randf_range(0, TAU)
	var at := player + Vector3(cos(angle), 0, sin(angle))*distance
	at.x = clampf(at.x, -game.layout.move_x - 4.0, game.layout.move_x + 4.0)
	at.z = clampf(at.z, -game.layout.move_z - 4.0, game.layout.move_z + 4.0)
	return at

func add_foe(game, kind: String, player: Vector3) -> void:
	var stats: Dictionary = FOES[kind]
	var foe := {"kind":kind, "hp":int(stats.hp), "radius":float(stats.radius), "value":int(stats.value),
		"timer":float(stats.get("fire", 0.0))*0.7, "angle":rng.randf_range(0, TAU), "flash":0.0, "life":0.0}
	match kind:
		"jet":
			# A strafing pass through a point near the saucer, warned by a red lane.
			var aim := player + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
			var dir := Vector3(cos(foe.angle), 0, sin(foe.angle))
			foe.pos = aim - dir*22.0
			foe.dir = dir
			foe.warn = float(stats.warn)
			var lane := MeshInstance3D.new()
			var strip := BoxMesh.new()
			strip.size = Vector3(1.6, 0.04, 44.0)
			lane.mesh = strip
			lane.material_override = materials.warn
			lane.position = Vector3(aim.x, 0.08, aim.z)
			lane.rotation.y = atan2(dir.x, dir.z)
			add_child(lane)
			foe.lane = lane
		"flak":
			var angle := rng.randf_range(0, TAU)
			foe.pos = game.layout.clamp_point(player + Vector3(cos(angle), 0, sin(angle))*rng.randf_range(6.0, 9.0))
		_:
			foe.pos = edge_point(game, player, SPAWN_DISTANCE)
	foe.node = foe_model(game, kind)
	foes.append(foe)
	place_foe(foe)

func move_foe(game, foe: Dictionary, dt: float, player: Vector3) -> void:
	var stats: Dictionary = FOES[foe.kind]
	foe.flash = maxf(0.0, foe.flash - dt)
	foe.life += dt
	foe.timer -= dt
	match foe.kind:
		"heli":
			# Nose on the saucer while it circles; one in the beam stops
			# circling and is reeled in.
			foe.face = player - foe.pos
			if foe != capture_target:
				foe.angle += dt*0.5
				var orbit: Vector3 = player + Vector3(cos(foe.angle), 0, sin(foe.angle))*HELI_ORBIT
				foe.pos = foe.pos.move_toward(orbit, float(stats.speed)*dt)
			if foe.timer <= 0.0 and foe != capture_target:
				foe.timer = float(stats.fire)
				shoot_at(foe.pos, player)
		"jet":
			if foe.warn > 0.0:
				foe.warn -= dt
				foe.node.visible = false
			else:
				foe.node.visible = true
				foe.pos += foe.dir*float(stats.speed)*dt
				if flat_distance(foe.pos, player) < foe.radius + PLAYER_RADIUS: hit(game)
				if foe.life > float(stats.warn) + 44.0/float(stats.speed): remove_foe(foe)
		"flak":
			if foe.timer <= 0.0:
				foe.timer = float(stats.fire)
				add_blast(player)
			if foe.life > float(stats.life): remove_foe(foe)
		"blimp":
			var away: Vector3 = foe.pos - player
			if away.length() > 6.0: foe.pos = foe.pos.move_toward(player, float(stats.speed)*dt)
			if foe.timer <= 0.0:
				foe.timer = float(stats.fire)
				for i in RING_SHOTS:
					var angle := TAU*i/RING_SHOTS + clock
					shoot_at(foe.pos, foe.pos + Vector3(cos(angle), 0, sin(angle)))
	place_foe(foe)

func place_foe(foe: Dictionary) -> void:
	if not foes.has(foe) and foe != escort: return
	var node: Node3D = foe.node
	var height := 0.0 if foe.kind == "flak" else FLY_Y + (1.2 if foe.kind == "blimp" else 0.0)
	node.position = Vector3(foe.pos.x, height, foe.pos.z)
	match foe.kind:
		"jet": node.rotation.y = atan2(foe.dir.x, foe.dir.z)
		"heli":
			# Nose toward foe.face (+z on the Meshy model, -z on the blocks).
			var face: Vector3 = foe.get("face", Vector3.FORWARD)
			if Vector2(face.x, face.z).length() > 0.01:
				node.rotation.y = atan2(face.x, face.z) + (0.0 if node.get_meta("scale", MODEL_SCALE) == 1.0 else PI)
			var rotor := node.get_node_or_null("Rotor")
			if rotor: rotor.rotation.y = clock*ROTOR_SPIN
		"blimp": node.rotation.y = clock*0.2
	node.scale = Vector3.ONE*float(node.get_meta("scale", MODEL_SCALE))*(1.15 if foe.flash > 0.0 else 1.0)

func remove_foe(foe: Dictionary) -> void:
	if foe.has("lane"): foe.lane.queue_free()
	foe.node.queue_free()
	foes.erase(foe)
	if foe == capture_target:
		capture_target = {}
		capture_progress = 0.0

func damage(game, foe: Dictionary, amount: int) -> void:
	if not foes.has(foe): return
	foe.hp -= amount
	foe.flash = 0.1
	if foe.hp > 0: return
	down(game, foe)
	game.fx.burst(Vector3(foe.pos.x, 0, foe.pos.z), foe.radius)
	game.sfx.play("boss" if foe.kind == "blimp" else "shot", 0.7)
	if rng.randf() < DROP_SHARE: add_pickup(foe.pos)
	remove_foe(foe)

# An enemy downed (or captured) scores its value.
func down(game, foe: Dictionary) -> void:
	count += int(foe.value)
	stage_points += int(foe.value)
	downed += 1
	if foe.kind == STAGES[stage].get("boss", ""): boss_down = true
	game.score += int(foe.value)*10
	game.add_floater(Vector3(foe.pos.x, 0, foe.pos.z), "+%d" % int(foe.value), true)

# --- weapons -----------------------------------------------------------------------

func nearest(from: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_distance := reach
	for foe in foes:
		if foe.kind == "jet" and foe.warn > 0.0: continue
		if foe == capture_target: continue
		var distance := flat_distance(foe.pos, from)
		if distance < best_distance:
			best = foe
			best_distance = distance
	return best

func fire(game, dt: float, player: Vector3) -> void:
	fire_timer -= dt
	if fire_timer > 0.0: return
	var target := nearest(player, RANGE)
	if target.is_empty(): return
	fire_timer = RAPID_EVERY if power == "rapid" else FIRE_EVERY
	var aim: Vector3 = (target.pos - player).normalized()
	var spread := [0.0, -SPREAD, SPREAD] if power == "spread" else [0.0]
	for angle in spread: add_shot(shots, player, aim.rotated(Vector3.UP, angle)*SHOT_SPEED, SHOT_LIFE, materials.shot)
	game.sfx.play("pop5", 1.8)

func shoot_at(from: Vector3, to: Vector3) -> void:
	var dir := Vector3(to.x - from.x, 0, to.z - from.z)
	if dir.length() < 0.01: return
	add_shot(foe_shots, from, dir.normalized()*FOE_SHOT_SPEED, FOE_SHOT_LIFE, materials.foe_shot)

func add_shot(list: Array[Dictionary], from: Vector3, velocity: Vector3, life: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.mesh = meshes.shot
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var shot := {"pos":Vector3(from.x, 0, from.z), "vel":velocity, "life":life, "node":node}
	list.append(shot)
	node.position = shot.pos + Vector3(0, FLY_Y, 0)

func move_shots(game, dt: float, player: Vector3) -> void:
	for shot in shots.duplicate():
		shot.pos += shot.vel*dt
		shot.life -= dt
		var struck := {}
		for foe in foes:
			if foe.kind == "jet" and foe.warn > 0.0: continue
			if flat_distance(shot.pos, foe.pos) < foe.radius:
				struck = foe
				break
		if not struck.is_empty(): damage(game, struck, 1)
		if shot.life <= 0.0 or not struck.is_empty(): drop_shot(shots, shot)
		else: shot.node.position = shot.pos + Vector3(0, FLY_Y, 0)
	for shot in foe_shots.duplicate():
		shot.pos += shot.vel*dt
		shot.life -= dt
		var touched := flat_distance(shot.pos, player) < PLAYER_RADIUS
		if touched: hit(game)
		if shot.life <= 0.0 or touched: drop_shot(foe_shots, shot)
		else: shot.node.position = shot.pos + Vector3(0, FLY_Y, 0)

func drop_shot(list: Array[Dictionary], shot: Dictionary) -> void:
	shot.node.queue_free()
	list.erase(shot)

# A flak burst: a red ring on the ground where the saucer is, then the blast.
func add_blast(player: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = meshes.disc
	node.material_override = materials.warn
	node.position = Vector3(player.x, 0.1, player.z)
	add_child(node)
	blasts.append({"pos":Vector3(player.x, 0, player.z), "time":BLAST_WARN, "node":node})

func update_blasts(game, dt: float, player: Vector3) -> void:
	for blast in blasts.duplicate():
		blast.time -= dt
		var grow: float = 1.0 - blast.time/BLAST_WARN
		blast.node.scale = Vector3(BLAST_RADIUS*grow, 1, BLAST_RADIUS*grow)
		if blast.time > 0.0: continue
		game.fx.puff(blast.pos, BLAST_RADIUS, 1.0)
		if flat_distance(blast.pos, player) < BLAST_RADIUS + PLAYER_RADIUS*0.5: hit(game)
		blast.node.queue_free()
		blasts.erase(blast)

func hit(game) -> void:
	if grace > 0.0 or lives <= 0: return
	lives -= 1
	grace = HIT_GRACE
	game.saucer_wobble = 1.0
	game.fx.shake = maxf(game.fx.shake, 0.55)
	game.add_floater(game.hole_position, I18n.t("hit"), true)
	game.sfx.play("tick")

# --- tractor beam and escort -------------------------------------------------------

func update_capture(game, dt: float, player: Vector3, still: bool) -> void:
	var target := {}
	if still and escort.is_empty():
		for foe in foes:
			if foe.kind == "heli" and flat_distance(foe.pos, player) < CAPTURE_REACH:
				target = foe
				break
	if target.is_empty() or (not capture_target.is_empty() and target != capture_target):
		capture_progress = maxf(0.0, capture_progress - dt*2.0)
		if capture_progress <= 0.0: capture_target = {}
	if not target.is_empty() and (capture_target.is_empty() or target == capture_target):
		capture_target = target
		capture_progress += dt/CAPTURE_TIME
		# The beam reels the helicopter in over the saucer.
		target.pos = target.pos.move_toward(player, dt*2.0)
	beam.visible = not capture_target.is_empty()
	if beam.visible:
		var from: Vector3 = player + Vector3(0, FLY_Y + 0.4, 0)
		var to: Vector3 = capture_target.pos + Vector3(0, FLY_Y, 0)
		beam.position = (from + to)*0.5
		beam.scale = Vector3(1, maxf(0.1, from.distance_to(to)), 1)
		beam.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD)
		beam.rotate_object_local(Vector3.RIGHT, PI/2)
	if capture_progress < 1.0 or capture_target.is_empty(): return
	var heli := capture_target
	capture_target = {}
	capture_progress = 0.0
	beam.visible = false
	foes.erase(heli)
	down(game, heli)
	game.sfx.play("grow")
	game.fx.ripple(player, 2.0, POWERS.spread)
	escort = {"kind":"heli", "pos":heli.pos, "node":heli.node, "time":ESCORT_TIME, "timer":0.0, "angle":0.0, "flash":0.0, "face":heli.pos - player}
	for node in heli.node.get_children():
		if node is MeshInstance3D and node.name != "Rotor": node.material_override = flat(Color("62ead3"))

func update_escort(game, dt: float, player: Vector3) -> void:
	if escort.is_empty(): return
	escort.time -= dt
	escort.angle += dt*1.6
	escort.pos = player + Vector3(cos(escort.angle), 0, sin(escort.angle))*ESCORT_ORBIT
	escort.timer -= dt
	if escort.timer <= 0.0:
		var target := nearest(escort.pos, RANGE)
		if not target.is_empty():
			escort.timer = ESCORT_FIRE
			# The escort turns its nose on what it shoots.
			escort.face = target.pos - escort.pos
			add_shot(shots, escort.pos, (target.pos - escort.pos).normalized()*SHOT_SPEED, SHOT_LIFE, materials.shot)
	place_foe(escort)
	if escort.time <= 0.0:
		game.fx.puff(escort.pos, 0.8, 1.0)
		escort.node.queue_free()
		escort = {}

# --- powers ------------------------------------------------------------------------

func add_pickup(at: Vector3) -> void:
	var kind: String = POWERS.keys()[rng.randi_range(0, POWERS.size() - 1)]
	var node := MeshInstance3D.new()
	node.mesh = meshes.orb
	node.material_override = glow(POWERS[kind])
	add_child(node)
	pickups.append({"pos":Vector3(at.x, 0, at.z), "kind":kind, "life":POWER_LIFE, "node":node})

func update_pickups(game, dt: float, player: Vector3) -> void:
	for pickup in pickups.duplicate():
		pickup.life -= dt
		pickup.node.position = pickup.pos + Vector3(0, FLY_Y - 0.6 + sin(clock*4.0)*0.2, 0)
		var taken := flat_distance(pickup.pos, player) < PLAYER_RADIUS + 0.6
		if taken:
			power = pickup.kind
			power_time = POWER_TIME
			game.add_floater(game.hole_position, I18n.t("siege_" + power), true)
			game.sfx.play("grow")
		if taken or pickup.life <= 0.0:
			pickup.node.queue_free()
			pickups.erase(pickup)

# --- state -------------------------------------------------------------------------

func done() -> bool:
	return lives <= 0 or boss_down

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# Minimap dots for the enemies in the air.
func dots() -> Array:
	var list: Array = []
	for foe in foes:
		if foe.kind != "jet" or foe.warn <= 0.0: list.append(Vector2(foe.pos.x, foe.pos.z))
	return list
