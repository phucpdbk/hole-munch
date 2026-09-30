extends RefCounted
# Campaign checks: `--headless --path . -- --campaign-smoke`. Never writes the save.
const Campaign = preload("res://scripts/campaign.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if value: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func run(g) -> void:
	check_progress()
	check_levels(g)
	check_panels(g)
	print("CAMPAIGN CHECKS: ", failures, " failures")
	g.set_process(false)
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	g.get_tree().quit(1 if failures else 0)

func check_progress() -> void:
	var count := Campaign.level_count()
	check(count == 48 and Campaign.REGIONS.size() == 6, "six continents with eight cities each")
	var progress = Campaign.new()
	check(progress.can_select(count-1) and not progress.can_select(count), "playtest allows all valid levels")
	progress.selected = count-1
	progress.complete(3,100)
	check(progress.unlocked == 0 and progress.medals[count-1] == 0 and progress.data().selected == 0, "preview win does not permanently unlock levels or award medals")
	progress.unlock_all_for_testing = false
	check(not progress.can_select(5) and progress.can_select(0), "disabling test flag restores earned locks")
	progress = Campaign.new()
	progress.restore({"version":3, "best":1234, "skin":2, "unlocked":20, "medals":[3,2,0,1]})
	check(progress.best == 1234 and progress.skin == 2 and progress.unlocked == 0 and progress.coins == 150, "old campaign save keeps cosmetics and turns stars into coins")
	progress.complete(0, 2000)
	check(progress.unlocked == 0, "loss does not unlock next level")
	progress.complete(3, 3000)
	progress.complete(1, 100)
	check(progress.unlocked == 1 and progress.medals[0] == 3, "win unlocks next; replay retains best stars")
	# Upgrades: cost growth, coin checks, caps and their effect on stats.
	progress.coins = 80
	check(progress.buy("size") and progress.coins == 0 and progress.upgrades.size == 1, "buying an upgrade spends coins")
	check(not progress.buy("size"), "cannot buy without enough coins")
	check(progress.upgrade_cost("size") == 128, "upgrade cost grows by 1.6x")
	progress.coins = 999999
	for i in 20: progress.buy("magnet")
	check(progress.upgrades.magnet == 5, "upgrades stop at their maximum")
	var stats: Dictionary = progress.stats()
	check(is_equal_approx(stats.start_radius, Campaign.START_RADIUS+0.08) and stats.magnet == 5, "upgrades change round stats")
	check(progress.reward(true, 3, 400) > progress.reward(false, 0, 400), "winning pays more coins than losing")
	progress.skin = 7; progress.effect = 3; progress.trail = 3
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(progress.data())))
	check(restored.data() == progress.data(), "save round trip preserves progress, coins and upgrades")
	restored.restore({"version":4, "selected":999, "unlocked":999, "skin":999, "trail":-3, "effect":"bad", "medals":[null,99], "upgrades":{"size":99, "speed":"x"}})
	check(restored.selected == count-1 and restored.skin == 7 and restored.trail == 0 and restored.medals[1] == 3 and restored.upgrades.size == 8, "malformed save fields are bounded")
	var sizes: Array = []
	for i in count:
		var info := Campaign.level_info(i)
		sizes.append(int(info.cols)*int(info.rows))
	check(sizes[0] == 9 and sizes[count-1] == 35 and sizes[30] == 25 and sizes[23] > sizes[0], "maps grow from 3×3 to 5×7")
	check(sizes[7] > sizes[6], "continent finale uses a bigger map")

func check_levels(g) -> void:
	g.campaign.unlocked = Campaign.level_count()-1
	var route = preload("res://scripts/smoke.gd").new()
	route.g = g
	for i in Campaign.level_count():
		g.load_level(i)
		g.go_menu()
		g.on_play()
		var info: Dictionary = g.level
		check(is_equal_approx(g.remaining, float(info.seconds)) and g.boss_radius >= g.MIN_BOSS and g.boss_radius <= g.MAX_BOSS + g.FINALE_BOSS, "level %d config applied (boss %.1f, %ds)" % [i+1, g.boss_radius, info.seconds])
		check(g.batches.size() <= 30, "level %d render batches bounded (%d)" % [i+1, g.batches.size()])
		var boss_mesh: Mesh = g.batches[g.items[g.boss_index].batch].mesh
		check(boss_mesh.get_surface_count() == 1 and boss_mesh.get_aabb().size.y > 1.5, "level %d boss mesh is built" % (i+1))
		var footprint := 0.0
		for v in boss_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: footprint = maxf(footprint, Vector2(v.x,v.z).length())
		check(footprint <= g.MODEL_BOSS+0.01, "level %d boss footprint matches swallow radius" % (i+1))
		if g.is_landmark():
			var before: Vector3 = g.items[g.boss_index].position
			g.started = true
			g.update_boss(3.0)
			check(g.items[g.boss_index].position == before, "level %d landmark stays put" % (i+1))
		else:
			check(g.minions.size() == g.DuckBoss.MAX_DROPS, "level %d defence boss has minions" % (i+1))
		route.check_growth_route()
		check(route.failures == 0, "level %d estimated travel route wins within timer (%.0fs left)" % [i+1, g.remaining])
		print("PAR %d %d" % [i, ceili(float(info.seconds) - g.remaining)])
		route.failures = 0
		g.reset_round()
		g.mode = "playing"; g.playing = true
		g.toggle_pause()
		var clock: float = g.weather.clock
		g._process(0.2)
		check(g.weather.clock == clock, "level %d pause freezes weather" % (i+1))
		g.on_play()
		var coins_before: int = g.campaign.coins
		g.radius = g.boss_radius/g.EAT_RATIO+0.3
		g.target_radius = g.radius
		g.hole_position = g.items[g.boss_index].position
		g.started = true
		for frame in 60: g.step(0.02,Vector2.ZERO)
		check(g.mode == "result" and g.hud.won and g.campaign.coins > coins_before, "level %d boss can be caught and pays coins" % (i+1))
		if i < Campaign.level_count()-1:
			g.on_play()
			check(g.campaign.selected == i+1 and g.score == 0, "next button loads a fresh level")

func check_panels(g) -> void:
	g.go_menu()
	g.reset_round()
	g.playing = true; g.mode = "playing"; g.started = true
	g.hole_position = Vector3(999,0,-999)
	g.step(0.02,Vector2.ZERO)
	check(absf(g.hole_position.x) <= g.layout.move_x and absf(g.hole_position.z) <= g.layout.move_z, "movement clamps at the map edge")
	g.go_menu()
	g.open_panel("levels")
	check(g.wardrobe.visible and not g.hud.visible, "journey panel opens and blocks game input")
	g.wardrobe.turn_page(-99)
	check(g.wardrobe.page == 0, "journey clamps to the first continent")
	g.wardrobe.turn_page(99)
	check(g.wardrobe.page == 5 and g.wardrobe.controls.size() == 11, "last continent shows eight cities with bounded controls")
	g.wardrobe.choose_level(6)
	check(g.campaign.selected == 6 and g.mode == "menu", "level selection loads chosen map")
	g.campaign.coins = 100
	g.open_panel("shop")
	var speed_before: int = g.campaign.upgrades.speed
	g.wardrobe.buy("speed")
	check(g.campaign.upgrades.speed == speed_before+1 and g.campaign.coins == 30, "shop buys an upgrade")
	g.close_panel()
	check(is_equal_approx(g.stats.speed, 1.0 + g.campaign.upgrades.speed*0.05), "closing the shop applies upgrades")
	for skin in Campaign.SKINS.size():
		g.campaign.skin = skin
		g.campaign.effect = skin%4
		g.campaign.trail = skin%4
		g.apply_style()
		check(g.rim_shader.get_shader_parameter("style") == skin, "skin %d equips" % skin)
	check(g.fx.get_child_count() == 19, "cosmetic changes reuse fixed particle pools")
