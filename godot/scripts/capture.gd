extends RefCounted

# Screenshot and performance capture (`--capture` / `--campaign-capture`). Writes
# PNGs and a performance report to test-output/; never writes the player save.
var g
var sample_frames: Array[float] = []

func run(game, campaign_mode: bool) -> void:
	g = game
	DirAccess.make_dir_recursive_absolute("res://test-output")
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
	g.wardrobe.equip(7)
	await frames(65)
	await snapshot("wardrobe")
	g.close_panel()
	print("CAMPAIGN CAPTURE COMPLETE")
