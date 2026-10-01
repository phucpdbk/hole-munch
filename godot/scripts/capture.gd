extends RefCounted

# Screenshot and performance capture (`--capture` / `--campaign-capture`). Writes
# PNGs and a performance report to test-output/; never writes the player save.
var g
var sample_frames: Array[float] = []

func run(game, campaign_mode: bool) -> void:
	g = game
	DirAccess.make_dir_recursive_absolute("res://test-output")
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
	# Menu shot of every campaign landmark, to review Meshy bakes side by side.
	if "--landmark-gallery" in OS.get_cmdline_user_args():
		for index in g.Campaign.level_count():
			g.load_level(index)
			g.go_menu()
			await frames(20)
			await snapshot("landmark-%02d-%s" % [index+1, g.level.boss])
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
	# Gold district, roadblock and danger zone of a later city, with the minimap.
	if "--map-capture" in OS.get_cmdline_user_args():
		g.load_level(26)
		g.go_menu()
		await frames(40)
		await snapshot("map-menu")
		g.on_play()
		g.started = true
		g.defense.grace = INF
		var spots := {"gold":g.features.gold_blocks[0], "block":Vector2(g.features.barriers[0].position.x, g.features.barriers[0].position.z),
			"danger":g.features.danger_blocks[0], "alley":g.features.shortcut_blocks[0]}
		for name in spots:
			g.hole_position = Vector3(spots[name].x + 4.0, 0, spots[name].y + 4.0)
			await frames(60)
			await snapshot("map-" + name)
		g.get_tree().quit()
		return
	# Guardian mascots up close: idle, winding up and attacking (`--mascot-capture`).
	if "--mascot-capture" in OS.get_cmdline_user_args():
		for index in [8, 0, 1, 3, 6, 10, 26, 46]:
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
		g.get_tree().quit()
		return
	if "--daily-capture" in OS.get_cmdline_user_args():
		await daily_preview()
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
				for i in 8:
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
		g.defense.grace = INF
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
	g.on_play()
	g.started = true
	g.combo = 9
	await frames(40)
	await snapshot("ui-%s-playing" % lang)
	g.finish(true)
	await frames(6)
	await snapshot("ui-%s-result" % lang)

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
