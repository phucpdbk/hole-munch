extends RefCounted

# Screenshot and performance capture (`--capture` / `--campaign-capture`). Writes
# PNGs and a performance report to test-output/; never writes the player save.
var g
var sample_frames: Array[float] = []

func run(game, campaign_mode: bool) -> void:
	g = game
	DirAccess.make_dir_recursive_absolute("res://test-output")
	if "--privacy-capture" in OS.get_cmdline_user_args():
		g.go_menu()
		await frames(20)
		await snapshot("privacy-menu")
		g.hud.privacy_requested.emit()
		await frames(10)
		await snapshot("privacy-dialog")
		g.get_tree().quit()
		return
	if "--perf-large" in OS.get_cmdline_user_args():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		g.load_level(47)
	if "--city-assets" in OS.get_cmdline_user_args():
		for index in [6,13,47]:
			g.load_level(index)
			g.go_menu()
			await frames(70)
			await snapshot("city-assets-%d" % index)
		g.get_tree().quit()
		return
	# Decorated hole skins, the black-hole shaft, the guardian and a pickup.
	if "--mechanics-capture" in OS.get_cmdline_user_args():
		g.load_level(0)
		for skin in [8, 9, 10, 11]:
			g.campaign.skin = skin
			g.apply_style()
			g.reset_round()
			g.playing = true; g.mode = "playing"; g.started = true
			g.defense.grace = INF
			g.target_radius = 1.8; g.radius = 1.8
			g.hole_position = Vector3(3.5, 0, 3.0)
			g.mechanics.spawn_pickup(g)
			g.mechanics.pickup.position = g.hole_position + Vector3(3.0, 0.16, -1.0)
			for i in 40: g.step(0.02, Vector2(0.3, -0.2) if i < 20 else Vector2.ZERO)
			await frames(20)
			await snapshot("skin-%d" % skin)
		g.get_tree().quit()
		return
	# The slide puzzle at the start and halfway along the solver's path
	# (test-output/slide-start.png, slide-play.png).
	if "--slide-capture" in OS.get_cmdline_user_args():
		g.campaign.daily = {}
		g.campaign.test_mode = true
		g.play_daily("slide")
		await frames(30)
		await snapshot("slide-start")
		var path: Array = g.daily.puzzle.solution()
		for i in path.size()/2: g.slide(path[i])
		await frames(60)
		await snapshot("slide-play")
		g.get_tree().quit()
		return
	# The siege a few seconds in, then with a helicopter in the tractor beam
	# (test-output/siege-play.png, siege-beam.png).
	if "--siege-capture" in OS.get_cmdline_user_args():
		g.campaign.daily = {}
		g.campaign.test_mode = true
		g.play_daily("siege")
		var siege = g.daily.siege
		g.started = true
		for frame in 1000:
			g.step(0.02, Vector2(0.4, 0.2) if frame%120 < 60 else Vector2(-0.4, -0.1))
			siege.grace = 1.0
		await frames(5)
		await snapshot("siege-play")
		for frame in 1250:
			g.step(0.02, Vector2(0.3, -0.3) if frame%160 < 80 else Vector2(-0.3, 0.3))
			siege.grace = 1.0
		await frames(5)
		await snapshot("siege-late")
		siege.add_foe(g, "heli", g.hole_position)
		siege.foes[-1].pos = g.hole_position + Vector3(2.0, 0, 0)
		siege.foes[-1].hp = 99
		for frame in 12: g.step(0.02, Vector2.ZERO)
		await frames(3)
		await snapshot("siege-beam")
		# A jet strafing left to right, to check it flies nose first.
		siege.add_foe(g, "jet", g.hole_position)
		var jet: Dictionary = siege.foes[-1]
		jet.dir = Vector3.RIGHT
		jet.pos = g.hole_position + Vector3(-4.0, 0, 2.0)
		jet.warn = 0.0
		jet.life = 1.0
		siege.grace = 9.0
		g.step(0.02, Vector2.ZERO)
		await frames(3)
		await snapshot("siege-jet")
		g.get_tree().quit()
		return
	# The test-mode list of daily games (daily_picker.gd), the sky hop before the
	# first tap, then mid-flight past a few gaps (test-output/hop-menu.png,
	# hop-start.png, hop-play.png).
	if "--hop-capture" in OS.get_cmdline_user_args():
		# A big saucer equipped: the hop must still fly the default one.
		g.campaign.craft = 5
		g.apply_style()
		g.campaign.daily = {}
		g.campaign.test_mode = true
		g.campaign.unlock_all_for_testing = true
		g.hud.daily_requested.emit()
		await frames(10)
		await snapshot("hop-menu")
		g.play_daily("skyhop")
		await frames(30)
		await snapshot("hop-start")
		var hop = g.daily.hop
		for frame in 900:
			if hop.passed >= 6: break
			if hop.y < hop.centre(hop.gap_at(hop.passed)) - 0.6 and hop.vy < 1.0: hop.flap(g)
			g.step(0.02, Vector2.ZERO)
		await frames(10)
		await snapshot("hop-play")
		g.get_tree().quit()
		return
	# The cow hunt's farmland from above, then the hole beside today's cow with
	# every clue open (test-output/cow-overview.png, cow-play.png).
	# The cow hunt's card before the first move, then the radar beside the
	# named cow (test-output/cow-card.png, cow-play.png).
	if "--cow-capture" in OS.get_cmdline_user_args():
		g.campaign.daily = {}
		g.campaign.checkpoints = {"findcow":{"at":2, "lap":0}}
		g.daily_override = "findcow"
		g.start_daily()
		await frames(40)
		await snapshot("cow-card")
		g.started = true
		g.daily.hunt.memo = 0.0
		var star: Dictionary = g.daily.hunt.star
		g.hole_position = star.position + Vector3(2.4, 0, 1.6)
		g.hole_position.y = 0
		await frames(60)
		await snapshot("cow-play")
		g.get_tree().quit()
		return
	# Duck families in their lines and the gold rush's bank ring
	# (test-output/duck-families.png, gold-bank.png).
	if "--duckgold-capture" in OS.get_cmdline_user_args():
		g.campaign.daily = {}
		g.daily_override = "stampede"
		g.start_daily()
		g.started = true
		var mother: Dictionary = g.daily.families[0].mother
		g.hole_position = mother.position + Vector3(7, 0, 5)
		g.hole_position.y = 0
		await frames(90)
		await snapshot("duck-families")
		g.go_menu()
		g.campaign.daily = {}
		g.daily_override = "goldrush"
		g.start_daily()
		g.started = true
		g.daily.carried = 11
		g.hole_position = g.daily.bank_at() + Vector3(4.5, 0, 3.0)
		await frames(60)
		await snapshot("gold-bank")
		g.get_tree().quit()
		return
	# The beam daily's depot with a toy in the beam over its pad
	# (test-output/beam-carry.png) and a board part filled (beam-board.png).
	if "--beam-capture" in OS.get_cmdline_user_args():
		g.campaign.daily = {}
		g.daily_override = "beam"
		g.start_daily()
		g.started = true
		var beam = g.daily.beam
		for pad in beam.pads.slice(0, 2):
			var pile: Dictionary = beam.piles.filter(func(p): return beam.fits(pad, p.stack[-1]))[0]
			for at in [pile.at, pad.at]:
				g.hole_position = at
				beam.tap(g)
				await frames(30)
		var last: Dictionary = beam.pads[2]
		g.hole_position = beam.piles.filter(func(p): return beam.fits(last, p.stack[-1]))[0].at
		beam.tap(g)
		await frames(30)
		g.hole_position = last.at + Vector3(0.6, 0, 1.4)
		await frames(20)
		await snapshot("beam-carry")
		g.hole_position = last.at
		beam.tap(g)
		await frames(30)
		g.hole_position = Vector3(0, 0, 6.5)
		await frames(20)
		await snapshot("beam-board")
		g.get_tree().quit()
		return
	# The classic dailies on their themed maps (test-output/classic-snake.png,
	# classic-mole.png, classic-green.png, classic-red.png).
	if "--classic-capture" in OS.get_cmdline_user_args():
		g.campaign.daily = {}
		g.daily_override = "snake"
		g.start_daily()
		g.started = true
		g.bot_input = Vector2(1, 0.3)
		await frames(50)
		# A line of eight pets with a monster closing in on it.
		var snake = g.daily.snake
		for i in 8:
			var pet = snake.take_critter(g)
			pet.visible = true
			pet.position = snake.orb_at(snake.line.size())
			snake.line.append(pet)
		var monster: Dictionary = snake.monsters[0]
		monster.wait = 0.0
		monster.holder.position = snake.orb_at(7) + Vector3(-3.0, 0.16, 1.5)
		await frames(20)
		await snapshot("classic-snake")
		# What a long line costs: draw calls and triangles with 40 pets in it.
		var before_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var before_tris := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		for i in 32:
			var pet = snake.take_critter(g)
			pet.visible = true
			pet.position = snake.orb_at(snake.line.size())
			snake.line.append(pet)
		await frames(10)
		print("PERF 40 pets: draw calls %d -> %d, primitives %d -> %d" % [before_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			before_tris, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		# Pets roaming and running, close up (classic-pets.png).
		g.bot_input = Vector2.ZERO
		monster.wait = 99.0
		var near = snake.roamers[0]
		for i in snake.roamers.size():
			var roamer = snake.roamers[i]
			roamer.position = near.position + Vector3((i % 4)*1.3 - 2.0, 0, (i/4)*1.3)
			snake.roam(roamer, "wander", 9.0, Vector3(1, 0, 0.4).normalized())
		# The saucer parks just out of their alert range while the camera settles.
		snake.heading = Vector2.ZERO
		g.hole_position = near.position + Vector3(0, 0, 6.5)
		g.hole_position.y = 0
		await frames(60)
		await snapshot("classic-pets")
		# Each harder garden (classic-garden-1.png ... classic-garden-3.png).
		for garden in [1, 2, 3]:
			g.go_menu()
			g.campaign.daily = {}
			g.campaign.checkpoints = {"snake":{"at":garden, "lap":0}}
			g.start_daily()
			g.started = true
			g.bot_input = Vector2(0, -1)
			await frames(40)
			await snapshot("classic-garden-%d" % garden)
		g.campaign.checkpoints = {}
		g.bot_input = Vector2.ZERO
		g.go_menu()
		g.campaign.daily = {}
		g.daily_override = "mole"
		g.start_daily()
		g.started = true
		await frames(150)
		await snapshot("classic-mole")
		g.go_menu()
		g.campaign.daily = {}
		g.daily_override = "redlight"
		g.start_daily()
		g.started = true
		await frames(30)
		await snapshot("classic-green")
		g.daily.light.set_phase("red", 99.0)
		await frames(10)
		await snapshot("classic-red")
		g.get_tree().quit()
		return
	# Each sky hop map a few gaps in (test-output/hop-map-0.png ... hop-map-4.png).
	if "--hopmaps-capture" in OS.get_cmdline_user_args():
		var hop = g.daily.hop
		for m in hop.MAPS.size():
			g.go_menu()
			g.campaign.daily = {}
			g.campaign.checkpoints = {"skyhop":{"at":m*hop.MAP_GAPS, "lap":0}}
			g.daily_override = "skyhop"
			g.start_daily()
			var index: int = m*hop.MAP_GAPS + 3
			var gap: Dictionary = hop.gap_at(index)
			hop.running = true
			hop.passed = index
			hop.clock = 2.0
			hop.x = gap.x - 3.0
			hop.y = hop.centre(gap)
			if gap.hazard == "icicle": gap.drop = hop.ICICLE_DROP
			hop.place()
			await frames(20)
			await snapshot("hop-map-%d" % m)
		g.get_tree().quit()
		return
	# A grown hole parked on the map edge: shaft and rim stop at the slab (test-output/edge-*.png).
	if "--edge-capture" in OS.get_cmdline_user_args():
		g.load_level(1)
		g.on_play()
		g.started = true
		g.defense.grace = INF
		for side in [["east", Vector3(1, 0, 0)], ["south", Vector3(0, 0, 1)]]:
			g.target_radius = 2.6; g.radius = 2.6
			g.hole_position = Vector3(side[1].x*g.layout.move_x, 0, side[1].z*g.layout.move_z)
			for i in 30: g.step(0.02, Vector2.ZERO)
			await frames(30)
			await snapshot("edge-" + side[0])
		g.get_tree().quit()
		return
	# Bonus run: the start, a gate pair coming up, the landmark ahead, the result.
	if "--run-capture" in OS.get_cmdline_user_args():
		g.load_level(4)
		g.start_run()
		await frames(30)
		await snapshot("run-start")
		g.started = true
		# Steered through bot_input so the camera and HUD run frame by frame;
		# shots are taken by distance, since capture frames are uncapped.
		var shots := [[215.0, "run-gates"], [100.0, "run-boost"], [20.0, "run-mid"], [-110.0, "run-swap"], [-245.0, "run-end"]]
		for i in 20000:
			if g.mode != "playing": break
			# The better gate of the next pair, round any roadblock before it.
			var next: Dictionary = {}
			for gate in g.runner.gates:
				if gate.used or gate.at > g.hole_position.z: continue
				if next.is_empty() or gate.at > next.at or (gate.at == next.at and gate.gain > next.gain): next = gate
			var aim: float = next.side*3.3 if not next.is_empty() else 0.0
			for block in g.runner.props.blocks:
				if block.used or block.at > g.hole_position.z or (not next.is_empty() and block.at < next.at): continue
				var x: float = g.runner.props.block_x(block, g.runner.props.clock + (g.hole_position.z - block.at)/12.0)
				if absf(aim - x) < 4.5: aim = -signf(x if x != 0.0 else 1.0)*6.6
			g.bot_input = Vector2(clampf((aim - g.hole_position.x)*0.5, -1, 1), 0)
			if not shots.is_empty() and g.hole_position.z < shots[0][0]: await snapshot(shots.pop_front()[1])
			else: await frames(1)
		g.bot_input = Vector2.ZERO
		await frames(40)
		await snapshot("run-result")
		g.get_tree().quit()
		return
	# Each guardian attack style mid-shot at the saucer, then a hit wobble.
	if "--guardian-capture" in OS.get_cmdline_user_args():
		await guardian_preview()
		g.get_tree().quit()
		return
	# Every trail mid-run, the ground-painted fire and rainbow included.
	if "--trail-capture" in OS.get_cmdline_user_args():
		g.load_level(0)
		for trail in range(1, preload("res://scripts/cosmetics.gd").count("trails")):
			g.campaign.trail = trail
			g.apply_style()
			g.reset_round()
			g.playing = true; g.mode = "playing"; g.started = true
			g.defense.grace = INF
			g.hole_position = Vector3(-12.0, 0, 9.0)
			# Capture has no drag, so the run steers the hole and feeds the trail itself.
			for i in 80:
				g.hole_position += (Vector3(1, 0, 0) if i < 45 else Vector3(0.6, 0, -0.8))*0.12
				g.fx.move_trail(g.hole_position, true, g.radius)
				await frames(1)
			await snapshot("trail-%d" % trail)
		g.get_tree().quit()
		return
	# Portrait ad clips under the movie maker (ad_capture.gd, tools/make-ads.ps1).
	if "--ad-capture" in OS.get_cmdline_user_args():
		await preload("res://scripts/ad_capture.gd").new().run(g, self)
		g.get_tree().quit()
		return
	# Review page of every city: shots plus landmark, guardian and weather data.
	if "--catalog" in OS.get_cmdline_user_args():
		await preload("res://scripts/catalog_capture.gd").new().run(g, self)
		g.get_tree().quit()
		return
	# Menu shot of every campaign landmark, to review Meshy bakes side by side.
	if "--landmark-gallery" in OS.get_cmdline_user_args():
		for index in g.Campaign.level_count():
			g.load_level(index)
			g.go_menu()
			await frames(20)
			await snapshot("landmark-%02d-%s" % [index+1, g.level.boss])
		g.get_tree().quit()
		return
	# Conquest album: the menu button, a few continents with mixed progress, a
	# landmark card, test mode, then the same in portrait (test-output/album-*.png,
	# add --lang=en etc.).
	if "--album-capture" in OS.get_cmdline_user_args():
		await album_preview()
		g.get_tree().quit()
		return
	# Menus, journey maps, intro/tip cards and panels (add --lang=en etc.).
	if "--ui-capture" in OS.get_cmdline_user_args():
		await ui_preview()
		g.get_tree().quit()
		return
	if "--street-capture" in OS.get_cmdline_user_args():
		await street_preview()
		g.get_tree().quit()
		return
	if "--challenge-capture" in OS.get_cmdline_user_args():
		await challenge_preview()
		g.get_tree().quit()
		return
	# Each power-up dropping in and floating (`--pickup-capture`): test-output/pickup-<kind>.png.
	if "--pickup-capture" in OS.get_cmdline_user_args():
		g.load_level(4)
		g.on_play()
		g.started = true
		g.defense.grace = INF
		for kind in g.Mechanics.PICKUPS:
			g.hole_position = g.SPAWN
			g.mechanics.spawn_pickup(g, kind)
			# Park it beside the hole so it floats in the middle of the shot.
			g.mechanics.pickup.position = g.SPAWN + Vector3(2.5, 0, -1.5)
			g.mechanics.pickup.drop = 0.0
			await frames(70)
			await snapshot("pickup-" + kind)
			# A 3x close-up around the floating model as well.
			var image: Image = g.get_viewport().get_texture().get_image()
			var centre: Vector2 = g.camera.unproject_position(g.mechanics.orb.global_position)
			var box := Rect2i(Vector2i(centre) - Vector2i(80, 80), Vector2i(160, 160)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
			var close := image.get_region(box)
			close.resize(box.size.x*3, box.size.y*3, Image.INTERPOLATE_LANCZOS)
			close.save_png("res://test-output/pickup-%s-close.png" % kind)
			g.mechanics.clear_pickup()
		g.get_tree().quit()
		return
	# Whole shaped cities from above (bays, lakes, rivers, festival dress):
	# test-output/shape-XX.png, `--levels=4,48` picks cities (0-based).
	if "--shape-capture" in OS.get_cmdline_user_args():
		var picks: Array = [4, 13, 24, 32, 47, 48, 49, 50, 51, 52, 53]
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--levels="): picks = Array(arg.trim_prefix("--levels=").split(",")).map(func(value): return int(value))
		for index in picks:
			g.load_level(index)
			g.on_play()
			g.started = true
			g.defense.grace = INF
			g.overview_size = maxf(g.layout.half_x, g.layout.half_z)*2.3
			g.camera.far = 600
			await frames(90)
			await snapshot("shape-%02d" % (index + 1))
			g.overview_size = 0.0
			g.camera.far = 200
			g.hole_position = g.SPAWN
			await frames(60)
			await snapshot("shape-%02d-street" % (index + 1))
		g.get_tree().quit()
		return
	# Gold district, roadblock and danger zone of a later city, with the minimap.
	if "--map-capture" in OS.get_cmdline_user_args():
		g.load_level(26)
		g.go_menu()
		await frames(40)
		await snapshot("map-menu")
		g.on_play()
		g.started = true
		var spots := {"gold":g.features.gold_blocks[0], "block":Vector2(g.features.barriers[0].position.x, g.features.barriers[0].position.z),
			"danger":g.features.danger_blocks[0], "alley":g.features.shortcut_blocks[0]}
		for name in spots:
			g.hole_position = Vector3(spots[name].x + 4.0, 0, spots[name].y + 4.0)
			await frames(60)
			await snapshot("map-" + name)
		g.get_tree().quit()
		return
	# Guardian mascots up close: idle, winding up and attacking (`--mascot-capture`).
	# `--levels=0,4` picks other cities (0-based).
	if "--mascot-capture" in OS.get_cmdline_user_args():
		var picks: Array = [8, 0, 1, 3, 6, 10, 26, 46]
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--levels="): picks = Array(arg.trim_prefix("--levels=").split(",")).map(func(value): return int(value))
		for index in picks:
			g.load_level(index)
			g.on_play()
			g.started = true
			g.defense.grace = INF
			var guardian: Dictionary = g.mechanics.guardian
			g.hole_position = guardian.position + Vector3(1.0, 0, guardian.radius + 3.0)
			g.hole_position.y = 0
			await frames(50)
			await snapshot("mascot-%02d-%s-idle" % [index+1, g.level.boss])
			g.defense.grace = 0.0
			g.mechanics.mascot.cooldown = 0.0
			await frames(30)
			await snapshot("mascot-%02d-%s-windup" % [index+1, g.level.boss])
			await frames(28)
			await snapshot("mascot-%02d-%s-attack" % [index+1, g.level.boss])
			# Fire, water and lightning: wait for the beam to reach the saucer.
			for i in 90:
				if g.defense.strikes.any(func(s): return s.source == guardian and s.get("style", "") != "" and s.time < s.flight*0.6): break
				await frames(1)
			await snapshot("mascot-%02d-%s-beam" % [index+1, g.level.boss])
		g.get_tree().quit()
		return
	# Rain, fog (veil and hidden minimap), snow and storm mid-round (`--weather-capture`).
	if "--weather-capture" in OS.get_cmdline_user_args():
		for index in [1, 2, 6, 7]:
			g.load_level(index)
			g.on_play()
			g.started = true
			g.defense.grace = INF
			for i in 30: g.step(0.02, Vector2(0.4, -0.3))
			await frames(60)
			await snapshot("weather-%02d-%s" % [index+1, g.level.weather])
		g.get_tree().quit()
		return
	if "--daily-capture" in OS.get_cmdline_user_args():
		await daily_preview()
		g.get_tree().quit()
		return
	if "--army-capture" in OS.get_cmdline_user_args():
		await army_preview()
		g.get_tree().quit()
		return
	if "--defense-capture" in OS.get_cmdline_user_args():
		await defense_preview()
		g.get_tree().quit()
		return
	if "--landscape-ui" in OS.get_cmdline_user_args():
		await frames(30)
		for panel in ["levels","shop","skins","crafts"]:
			g.open_panel(panel)
			await frames(40)
			await snapshot("landscape-"+panel)
			if panel == "crafts":
				var crafts: int = preload("res://scripts/fleet.gd").NAMES.size()
				g.campaign.owned.crafts = range(crafts)
				for i in crafts:
					g.wardrobe.equip(i)
					await frames(15)
					await snapshot("craft-%d" % i)
			g.close_panel()
	if campaign_mode: await campaign()
	else: await single()
	g.get_tree().quit()

func frames(count: int) -> void:
	for i in count: await g.get_tree().process_frame

# Menu goals, the rival mid-race, the landmark counter-attack and the result.
func challenge_preview() -> void:
	g.load_level(12)
	g.go_menu()
	await frames(60)
	await snapshot("challenge-menu")
	g.on_play()
	g.started = true
	g.rival.position = g.hole_position + Vector3(5, 0, -3)
	g.rival.target_radius = 1.8
	for i in 90:
		g.hole_position.x = lerpf(g.hole_position.x, -3.0, 0.03)
		await g.get_tree().process_frame
	await snapshot("challenge-rival")
	g.defense.grace = 0.0
	g.target_radius = g.boss_radius/g.EAT_RATIO*g.COUNTER_AT + 0.1
	g.radius = g.target_radius
	g.hole_position = g.items[g.boss_index].position + Vector3(0, 0, 7)
	g.hole_position.y = 0
	await frames(100)
	await snapshot("challenge-counter")
	g.remaining = 0.05
	while g.mode != "result": await g.get_tree().process_frame
	await frames(3)
	await snapshot("challenge-result")
	g.go_menu()
	await frames(20)
	await snapshot("challenge-menu-after")

# Each daily mini-game mid-round, then a result (`--capture --daily-capture`).
func daily_preview() -> void:
	g.go_menu()
	await frames(30)
	await snapshot("daily-menu")
	for type in g.Campaign.DAILY_TYPES:
		g.campaign.daily = {}
		g.daily_override = type
		g.start_daily()
		g.started = true
		g.target_radius = 1.6
		for i in 150:
			g.hole_position.x = lerpf(g.hole_position.x, -6.0, 0.02)
			await g.get_tree().process_frame
		await snapshot("daily-" + type)
		g.go_menu()
	g.daily.count = 99
	g.campaign.daily = {}
	g.daily_override = "stampede"
	g.start_daily()
	g.daily.count = 18
	g.started = true
	g.remaining = 0.05
	while g.mode != "result": await g.get_tree().process_frame
	await frames(3)
	await snapshot("daily-result")
	g.go_menu()
	await frames(20)
	await snapshot("daily-menu-after")

func defense_preview() -> void:
	g.load_level(1)
	g.on_play()
	g.set_process(false)
	g.started = true
	g.hole_position = Vector3(0,0,9)
	g.defense.grace = 0
	for unit in g.defense.units: unit.cooldown = 0
	g.step(0.01,Vector2.ZERO)
	g.update_view(1.0)
	g.update_hud()
	await snapshot("defense-warning")
	for i in 9: g.step(0.1,Vector2.ZERO)
	g.update_view(0.1)
	g.update_hud()
	assert(g.defense.strikes.any(func(s): return s.time < s.flight),"Projectiles should be in flight")
	await snapshot("defense-projectiles")
	for i in 8: g.step(0.1,Vector2.ZERO)
	g.update_view(0.1)
	g.update_hud()
	assert(g.defense.hits == 1,"Standing in boss warning should hit exactly once")
	assert(g.remaining < float(g.level.seconds)-3.5,"Hit must remove two seconds")
	await snapshot("defense-hit")
	g.reset_round()
	assert(g.defense.hits == 0 and g.defense.strikes.is_empty())
	print("DEFENSE INTEGRATION: telegraph, damage and retry passed")

# National forces (army.gd) round a still saucer: a volley, the missile lock
# reticle closing and the missile in flight, per city (`--levels=0,8` to pick).
func army_preview() -> void:
	var levels: Array = [0, 2, 8, 17, 24, 33, 40]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="): levels = Array(arg.trim_prefix("--levels=").split(",")).map(func(v): return int(v))
	for index in levels:
		g.load_level(index)
		g.reset_round()
		g.playing = true; g.mode = "playing"; g.started = true; g.remaining = 99.0
		g.rival.active = false
		g.defense.grace = 0.0
		if g.mechanics.mascot: g.mechanics.mascot.cooldown = INF
		var anchors: Array = g.items.filter(func(item): return item.get("unit", "") == "missile")
		if anchors.is_empty(): anchors = g.items.filter(func(item): return item.get("unit", "") == "car")
		g.hole_position = Vector3(anchors[0].position.x + 4.5, 0, anchors[0].position.z)
		for gunner in g.army.gunners: gunner.cooldown = randf_range(0.0, 0.8)
		for frame in 30: await g.get_tree().process_frame
		await snapshot("army-%02d-volley" % index)
		if g.army.trucks.is_empty(): continue
		# Guns quiet so the knock-backs do not keep breaking the lock.
		for gunner in g.army.gunners: gunner.cooldown = INF
		for unit in g.defense.units: unit.cooldown = INF
		for frame in 90: await g.get_tree().process_frame
		for frame in 300:
			await g.get_tree().process_frame
			if g.army.lock.progress > 0.55: break
		await snapshot("army-%02d-lock" % index)
		for frame in 200:
			await g.get_tree().process_frame
			if g.army.shots.any(func(s): return s.kind == "missile" and s.time > 0.45): break
		await snapshot("army-%02d-missile" % index)
		print("ARMY CAPTURE %d %s: units=%d hits=%d" % [index, g.ArmyForces.country(g.level), g.army.active_count(), g.army.hits])

# Gameplay-zoom street views of several landmark cities, hole on a crossing.
func street_preview() -> void:
	for index in [0, 5, 8, 10, 16, 21, 24, 26, 32, 35, 40, 45]:
		g.load_level(index)
		g.on_play()
		g.hole_position = Vector3(g.layout.crossings_x[-1], 0, g.layout.crossings_z[-1])
		g.radius = 1.6
		await frames(60)
		await snapshot("street-%02d" % (index+1))

func ui_preview() -> void:
	var lang: String = g.I18n.lang
	# A running streak, so the menu shows it beside today's mini-game.
	g.campaign.streak = {"count":3, "last":g.Campaign.today()}
	await frames(40)
	await snapshot("ui-%s-menu" % lang)
	g.intro.open(g.Intro.story_pages(), Callable(), true)
	await frames(20)
	await snapshot("ui-%s-story1" % lang)
	g.intro.advance()
	await frames(20)
	await snapshot("ui-%s-story2" % lang)
	g.intro.close()
	g.intro.open([g.Intro.tip_page("weather_rain"), g.Intro.tip_page("rival")])
	await frames(20)
	await snapshot("ui-%s-tip" % lang)
	g.intro.close()
	g.intro.open([g.Intro.tip_page("lm_onepillar")])
	await frames(20)
	await snapshot("ui-%s-landmark" % lang)
	g.intro.close()
	g.open_panel("levels")
	for region in g.Campaign.REGIONS.size():
		g.wardrobe.turn_page(region - g.wardrobe.page)
		await frames(12)
		await snapshot("ui-%s-journey-%d" % [lang, region+1])
	g.close_panel()
	g.open_panel("language")
	await frames(4)
	await snapshot("ui-%s-language" % lang)
	g.close_panel()
	g.campaign.coins = 640
	g.open_panel("shop")
	await frames(4)
	await snapshot("ui-%s-shop" % lang)
	g.close_panel()
	g.open_panel("crafts")
	await frames(20)
	await snapshot("ui-%s-wardrobe" % lang)
	g.close_panel()
	g.open_panel("trails")
	await frames(20)
	await snapshot("ui-%s-trails" % lang)
	g.close_panel()
	g.on_play()
	g.started = true
	g.combo = 9
	await frames(40)
	await snapshot("ui-%s-playing" % lang)
	g.finish(true)
	await frames(6)
	await snapshot("ui-%s-result" % lang)

func album_preview() -> void:
	var lang: String = g.I18n.lang
	var campaign = g.campaign
	# Captures never save, so this made-up progress is harmless.
	campaign.unlock_all_for_testing = false
	campaign.unlocked = 11
	for i in 11: campaign.goals[i] = [7, 3, 1, 7, 5, 3, 7, 1, 3, 7, 1][i]
	campaign.goals[g.Campaign.regular_count()] = 7
	for i in campaign.goals.size(): campaign.medals[i] = g.Challenges.count(campaign.goals[i])
	for shape in ["landscape", "portrait"]:
		if shape == "portrait":
			g.get_window().size = Vector2i(450, 966)
			await frames(20)
		g.go_menu()
		await frames(30)
		await snapshot("album-%s-%s-menu" % [lang, shape])
		g.hud.album_requested.emit()
		for region in [0, 1, 5]:
			g.wardrobe.album.pick(region)
			await frames(6)
			await snapshot("album-%s-%s-%d" % [lang, shape, region+1])
		g.wardrobe.album.pick(0)
		g.wardrobe.album.tap_card(4)
		await frames(20)
		await snapshot("album-%s-%s-card" % [lang, shape])
		g.intro.close()
		campaign.unlock_all_for_testing = true
		g.wardrobe.album.pick(3)
		await frames(6)
		await snapshot("album-%s-%s-test" % [lang, shape])
		campaign.unlock_all_for_testing = false
		g.close_panel()

func guardian_preview() -> void:
	var specs: Dictionary = g.Mechanics.MascotSpecs.MASCOTS
	var shown := {}
	for index in g.Campaign.level_count():
		var id: String = g.Campaign.level_info(index).boss
		var style: String = specs.get(id, ["", "", "", "", "", ""])[5]
		if style == "" or shown.has(style): continue
		shown[style] = true
		g.load_level(index)
		g.reset_round()
		g.playing = true; g.mode = "playing"; g.started = true; g.remaining = 99.0
		g.rival.active = false
		g.defense.grace = 0.0
		var mascot = g.mechanics.mascot
		var guardian: Dictionary = g.mechanics.guardian
		mascot.cooldown = 0.0
		g.hole_position = guardian.position + Vector3(-3.0, 0, guardian.radius + 3.5)
		g.hole_position.y = 0
		# Run real frames until the attack is in the air, then shoot it.
		for frame in 240:
			await g.get_tree().process_frame
			var flying: bool = g.defense.strikes.any(func(s): return s.source == guardian and s.time <= s.flight*0.5)
			if flying or (style == "leap" and mascot.air > 0.8): break
		await snapshot("guardian-%s-%s" % [style, id])
		for frame in 40:
			await g.get_tree().process_frame
			if g.saucer_wobble > 0.6: break
		await snapshot("guardian-%s-hit" % style)
	# Hunting a hole that sits inside a block: the guardian comes by the streets.
	g.load_level(1)
	g.reset_round()
	g.playing = true; g.mode = "playing"; g.started = true; g.remaining = 99.0
	g.rival.active = false
	g.defense.grace = INF
	g.hole_position = Vector3(14.0, 0, 13.0)
	for frame in [60, 90, 90]:
		for i in frame: await g.get_tree().process_frame
		await snapshot("guardian-street-%d" % frame)

func snapshot(name: String) -> void:
	await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_png("res://test-output/" + name + ".png")

func single() -> void:
	await frames(45)
	await snapshot("menu")
	g.on_play()
	var last_tick := Time.get_ticks_usec()
	for i in range(130):
		await g.get_tree().process_frame
		var current_tick := Time.get_ticks_usec()
		if i >= 10: sample_frames.append((current_tick-last_tick)/1000.0)
		last_tick = current_tick
	await snapshot("game")
	# Eat along the cone line to show combo, popups and pedestrians mid-round.
	g.started = true
	for cone in g.items.filter(func(item): return item.kind == "cone").slice(0, 10):
		g.hole_position = Vector3(cone.position.x, 0, cone.position.z)
		await frames(3)
	await snapshot("combo")
	# A full skill bar glows on its button, bottom right.
	g.skills.energy = 1.0
	await frames(3)
	await snapshot("skill-ready")
	# Catch the boss to show the celebration, then the result screen.
	g.eaten_points = int(g.total_points*0.8)
	g.target_radius = g.boss_radius/g.EAT_RATIO + 0.2
	g.radius = g.target_radius
	var boss: Dictionary = g.items[g.boss_index]
	g.hole_position = Vector3(boss.position.x, 0, boss.position.z)
	await frames(24)
	await snapshot("boss")
	while g.mode != "result": await g.get_tree().process_frame
	await frames(3)
	await snapshot("result")
	sample_frames.sort()
	var report := {"renderer":RenderingServer.get_current_rendering_method(),
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects":g.items.size(), "batches":g.batches.size(),
		"frame_median_ms":sample_frames[sample_frames.size()/2],
		"frame_p95_ms":sample_frames[int(sample_frames.size()*0.95)]}
	var file := FileAccess.open("res://test-output/performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("CAPTURE: ", JSON.stringify(report))

func campaign() -> void:
	await frames(30)
	g.open_panel("levels")
	await snapshot("journey-1")
	g.wardrobe.turn_page(2)
	await snapshot("journey-3")
	g.close_panel()
	g.campaign.coins = 640
	g.open_panel("shop")
	await snapshot("shop")
	g.close_panel()
	# Every city's menu view, to review regional buildings, landmarks and bosses.
	for index in g.Campaign.level_count():
		g.load_level(index)
		g.go_menu()
		await frames(70)
		await snapshot("level-%02d" % (index+1))
	g.load_level(0)
	g.go_menu()
	g.open_panel("skins")
	# Captures never save, so owning the shown skin here is harmless.
	g.campaign.owned.skins = g.campaign.owned.skins + [7]
	g.wardrobe.equip(7)
	await frames(65)
	await snapshot("wardrobe")
	g.close_panel()
	print("CAMPAIGN CAPTURE COMPLETE")
