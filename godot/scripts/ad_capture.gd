extends RefCounted

# Scripted clips for ads (`--capture --ad-capture --ad=<preset> --levels=<city>`),
# in English unless --lang= says otherwise. tools/make-ads.ps1 records them with
# Godot's movie maker in a portrait window (the project's own window is landscape,
# so the script swaps in a temporary override.cfg). Presets:
#   conquer  big hole rolls into the landmark: tremble, vacuum, burp, banner
#   cling    last bite on the guardian: it hangs on the rim and is tapped loose
#   growth   the whole city from the first cone, on autopilot, sped up, ending
#            with the guardian and the conquest
#   rushhour the jam rolls in next to the hole, which then eats its way through
#   gates    through a green ×1.5 gate, then (oops) a red −30% one
#   boss     the hole feeds inside a block; the guardian hunts it over the roofs
# The HUD is hidden (add --ad-hud to keep it); the showtime overlay stays. Key
# frames are also saved as PNGs (test-output/ads/<preset>-<city>-*.png) for store
# art and thumbnails. Never writes the player's save (capture mode).
const TAP_GAP := 0.16
# Let the hang read on camera before the first tap.
const TAP_WAIT := 0.9
const TAIL := 1.6
const TIMEOUT := 120.0

var g
var cap
var preset := "conquer"
var level := 8
var speed := 1.0
var clip := ""
var tap_clock := 0.0
var was_clinging := false

func run(game, capture) -> void:
	g = game
	cap = capture
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ad="): preset = arg.trim_prefix("--ad=")
		if arg.begins_with("--levels="): level = int(arg.trim_prefix("--levels=").split(",")[0])
		if arg.begins_with("--ad-speed="): speed = float(arg.trim_prefix("--ad-speed="))
	if preset == "growth" and speed == 1.0: speed = 1.6
	# Ads target international stores: English unless --lang= asks for another.
	if not Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--lang=")): g.I18n.set_lang("en")
	DirAccess.make_dir_recursive_absolute("res://test-output/ads")
	clip = "%s-%02d" % [preset, level + 1]
	g.load_level(level)
	g.on_play()
	g.hud.visible = "--ad-hud" in OS.get_cmdline_user_args()
	g.showtime.show_floaters = not g.hud.visible
	g.started = true
	g.rival.active = false
	g.defense.grace = INF
	match preset:
		"cling": await cling()
		"growth": await growth()
		"rushhour": await rush_hour()
		"gates": await gates()
		"boss": await boss_hunt()
		_: await conquer()
	Engine.time_scale = 1.0
	await hold(TAIL)
	await shot("end")
	print("AD CLIP: %s" % clip)

# Hole one size short of the landmark across the plaza; the guardian is already
# gone, so the drive in triggers the conquest.
func conquer() -> void:
	clear_guardian()
	var boss: Dictionary = g.items[g.boss_index]
	g.target_radius = g.boss_radius/g.EAT_RATIO + 0.25
	g.radius = g.target_radius*0.85
	g.hole_position = Vector3(boss.position.x + 9.0, 0, boss.position.z + 10.0)
	g.camera_target = g.hole_position
	await hold(0.8)
	await shot("approach")
	await drive(func(): return g.items[g.boss_index], func(): return g.showtime.busy())
	await hold(0.5)
	await shot("tremble")
	await until(func(): return g.showtime.phase == "banner")
	await hold(0.4)
	await shot("banner")
	await until(func(): return g.mode == "result")

# The guardian down to its last heart and a hole big enough to bite it.
func cling() -> void:
	var guardian: Dictionary = g.mechanics.guardian
	if guardian.is_empty():
		await conquer()
		return
	var mascot = g.mechanics.mascot
	mascot.hp = 1
	g.target_radius = guardian.radius/g.EAT_RATIO + 0.6
	g.radius = g.target_radius
	g.hole_position = Vector3(guardian.position.x + 7.0, 0, guardian.position.z + 6.0)
	g.camera_target = g.hole_position
	await hold(0.6)
	await drive(func(): return guardian, func(): return mascot.state == "cling")
	await hold(0.5)
	await shot("cling")
	await until(func(): return mascot.state != "cling")
	await hold(0.8)
	await shot("dropped")

# The whole city on autopilot: greedy food route, the guardian, then the landmark.
func growth() -> void:
	Engine.time_scale = speed
	g.remaining = 999.0
	await hold(0.4)
	await shot("start")
	var halfway := false
	var clock := 0.0
	while g.mode == "playing" and not g.showtime.busy() and clock < TIMEOUT:
		var target: Dictionary = g.Rival.best_target(g.items, g.items[g.boss_index], g.hole_position, g.radius)
		steer(target.position if not target.is_empty() else Vector3.ZERO)
		auto_tap(g.get_process_delta_time())
		if not halfway and g.growth() >= 0.5:
			halfway = true
			await shot("half")
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()
	g.bot_input = Vector2.ZERO
	Engine.time_scale = 1.0
	await hold(0.6)
	await shot("tremble")
	await until(func(): return g.mode == "result")

# The jam arrives right away; the hole then eats the nearest vehicle each time.
func rush_hour() -> void:
	g.target_radius = 1.45
	g.radius = g.target_radius
	await hold(0.5)
	g.events.round_time = g.events.JAM_AFTER
	await until(func(): return g.events.jam_state != "wait")
	await hold(0.6)
	await shot("jam")
	var clock := 0.0
	var feasted := false
	while clock < 9.0:
		var left: Array = g.events.jam.filter(func(car): return g.Traffic.is_active(car) and car.radius <= g.radius*g.EAT_RATIO)
		if left.is_empty(): break
		left.sort_custom(func(a, b): return a.position.distance_to(g.hole_position) < b.position.distance_to(g.hole_position))
		steer(left[0].position)
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()
		if not feasted and clock > 2.5:
			feasted = true
			await shot("feast")
	g.bot_input = Vector2.ZERO

# Two runs, each starting a little before its gate pair: through the green half
# of the first, then (oops) the red half of the next. No rush hour here.
func gates() -> void:
	var pairs: Array = g.events.gates.filter(func(gate): return gate.side > 0)
	if pairs.size() < 2:
		await conquer()
		return
	g.events.jam_state = "none"
	g.target_radius = 1.1
	g.radius = 1.1
	for i in 2:
		var pair: Dictionary = pairs[i]
		var pick: Dictionary = g.events.gates.filter(func(gate): return gate.pair == pair.pair and gate.good == (i == 0))[0]
		var lane: Vector3 = pick.across*pick.side*0.8
		var way: float = signf((g.hole_position - pick.at).dot(pick.along))
		if way == 0.0: way = -1.0
		g.hole_position = pick.at + pick.along*way*7.0 + lane
		g.hole_position.y = 0
		g.events.last_hole = g.hole_position
		g.camera_target = g.hole_position
		await hold(0.5)
		await drive_to(pick.at + pick.along*way*2.5 + lane)
		await shot("gate%d-before" % (i + 1))
		await drive_to(pick.at - pick.along*way*2.0 + lane)
		await hold(0.4)
		await shot("gate%d-after" % (i + 1))

# The hole feeds across a block from the guardian, which hops the roofs and
# attacks. Defence squads stay quiet; only the guardian fights.
func boss_hunt() -> void:
	var guardian: Dictionary = g.mechanics.guardian
	if guardian.is_empty():
		await conquer()
		return
	var mascot = g.mechanics.mascot
	var Roads = mascot.Roads
	g.events.jam_state = "none"
	g.target_radius = 1.6
	g.radius = 1.6
	var best := Vector3(guardian.position.x + 12.0, 0, guardian.position.z)
	var best_ratio := 0.0
	for x in range(-int(g.layout.move_x), int(g.layout.move_x), 2):
		for z in range(-int(g.layout.move_z), int(g.layout.move_z), 2):
			var spot := Vector3(x, 0, z)
			var gap: float = Vector2(spot.x - guardian.position.x, spot.z - guardian.position.z).length()
			if gap < 10.0 or gap > 14.0 or Roads.walkable(g.layout, spot): continue
			var ratio: float = Roads.plan(g.layout, guardian.position, spot).length/gap
			if ratio > best_ratio:
				best_ratio = ratio
				best = spot
	g.hole_position = best
	g.camera_target = best.lerp(Vector3(guardian.position.x, 0, guardian.position.z), 0.35)
	for unit in g.defense.units: unit.cooldown = INF
	g.defense.grace = 0.0
	mascot.cooldown = 1.0
	var clock := 0.0
	var hopped := false
	var struck := false
	while clock < 8.0:
		var food: Dictionary = g.Rival.best_target(g.items.filter(func(item): return not item.get("guardian", false)), g.items[g.boss_index], g.hole_position, g.radius)
		if not food.is_empty() and food.position.distance_to(best) < 6.0: steer(food.position)
		else: steer(best)
		if not hopped and mascot.state == "hop" and mascot.air > 0.6:
			hopped = true
			await shot("hop")
		if not struck and g.saucer_wobble > 0.6:
			struck = true
			await shot("hit")
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()
	g.bot_input = Vector2.ZERO

# --- helpers ------------------------------------------------------------------------

func clear_guardian() -> void:
	var guardian: Dictionary = g.mechanics.guardian
	if guardian.is_empty(): return
	guardian.eaten = true
	g.set_item_transform(guardian)

# Steer at whatever target() returns until done() holds (or a timeout).
func drive(target: Callable, done: Callable) -> void:
	var clock := 0.0
	while not done.call() and clock < 20.0 and g.mode == "playing":
		var item: Dictionary = target.call()
		steer(item.position)
		auto_tap(g.get_process_delta_time())
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()
	g.bot_input = Vector2.ZERO

func drive_to(at: Vector3) -> void:
	var clock := 0.0
	while Vector2(at.x - g.hole_position.x, at.z - g.hole_position.z).length() > 0.4 and clock < 8.0:
		steer(at)
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()
	g.bot_input = Vector2.ZERO

# Stick input toward a world point, in the camera's frame like a finger drag.
func steer(at: Vector3) -> void:
	var offset := Vector3(at.x - g.hole_position.x, 0, at.z - g.hole_position.z)
	var right: Vector3 = g.camera.global_basis.x
	var down: Vector3 = g.camera.global_basis.z
	right.y = 0
	down.y = 0
	var stick := Vector2(offset.dot(right.normalized()), offset.dot(down.normalized()))
	g.bot_input = stick.normalized() if stick.length() > 0.4 else stick/0.4 + Vector2(0.001, 0)

# A quick but human tap rhythm on a clinging guardian.
func auto_tap(dt: float) -> void:
	var clinging: bool = g.mechanics.guardian_clinging()
	if clinging and not was_clinging: tap_clock = -TAP_WAIT
	was_clinging = clinging
	if not clinging: return
	tap_clock += dt
	if tap_clock < TAP_GAP: return
	tap_clock = 0.0
	g.tap_guardian()

func hold(seconds: float) -> void:
	var clock := 0.0
	while clock < seconds:
		auto_tap(g.get_process_delta_time())
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()

func until(done: Callable) -> void:
	var clock := 0.0
	while not done.call() and clock < TIMEOUT:
		auto_tap(g.get_process_delta_time())
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()

func shot(moment: String) -> void:
	await cap.snapshot("ads/%s-%s" % [clip, moment])
