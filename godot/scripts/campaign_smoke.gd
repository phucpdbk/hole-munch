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
	if "--rival-bench" in OS.get_cmdline_user_args():
		bench_rival(g)
		g.get_tree().quit()
		return
	check_progress()
	check_goals_and_modes()
	check_levels(g)
	check_challenge_systems(g)
	check_rival(g)
	check_special_runs(g)
	check_panels(g)
	check_language_and_intro(g)
	print("CAMPAIGN CHECKS: ", failures, " failures")
	g.set_process(false)
	await g.get_tree().process_frame
	await g.get_tree().process_frame
	g.get_tree().quit(1 if failures else 0)

func check_language_and_intro(g) -> void:
	var I18n = g.I18n
	var rows_complete := true
	for key in I18n.Strings.S:
		var row: Array = I18n.Strings.S[key]
		if row.size() != I18n.LANGS.size() or row.any(func(cell): return str(cell) == ""):
			rows_complete = false
			push_error("incomplete translation: " + key)
	check(rows_complete, "every translation row has all %d languages" % I18n.LANGS.size())
	var names_complete := true
	for id in Campaign.LANDMARKS: names_complete = names_complete and I18n.has("lm_" + id)
	for region in Campaign.REGIONS: names_complete = names_complete and I18n.has("reg_" + str(region.id))
	for kind in Campaign.WEATHER_NAMES: names_complete = names_complete and I18n.has("w_" + kind)
	check(names_complete, "every landmark, continent and weather has a translated name")
	I18n.set_lang("en")
	check(Campaign.boss_name("eiffel") == "Eiffel Tower" and Campaign.level_info(0).city == "Hanoi" and I18n.t("combo", 5) == "COMBO 5", "English names and formatting")
	I18n.set_lang("xx")
	check(I18n.lang == I18n.FALLBACK and I18n.t("no_such_key") == "no_such_key", "unknown language and key fall back safely")
	I18n.set_lang("vi")
	var saved = Campaign.new()
	saved.lang = "pt"
	saved.seen.append_array(["story", "weather_rain"])
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(saved.data())))
	check(restored.lang == "pt" and restored.seen == saved.seen, "language and seen tips survive a save")
	restored.restore({"version":5, "lang":"klingon", "seen":[3, "x".repeat(99)]})
	check(restored.lang == "pt" and restored.seen.size() == 2, "bad language and seen entries are ignored")
	var Intro = g.Intro
	check(Intro.pending_tips(Campaign.level_info(0), []).is_empty(), "the first city needs no tips")
	check(Intro.pending_tips(Campaign.level_info(1), []) == ["weather_rain", "pickup"], "city 2 introduces rain and power orbs")
	var seen: Array = ["weather_rain", "pickup"]
	check(Intro.pending_tips(Campaign.level_info(1), seen).is_empty(), "seen tips are not repeated")
	check(Intro.pending_tips(Campaign.level_info(8), seen)[0] == "region_europe", "a new continent gets a welcome card first")
	check(Intro.pending_tips(Campaign.level_info(40), []).size() == Intro.MAX_TIPS, "tips per start are capped")
	check(Intro.story_pages().size() == 4 and Intro.tip_page("weather_storm").icon == "storm", "story and tip pages are built")

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
	progress.coins = 160
	check(progress.buy("size") and progress.coins == 0 and progress.upgrades.size == 1, "buying an upgrade spends coins")
	check(not progress.buy("size"), "cannot buy without enough coins")
	check(progress.upgrade_cost("size") == 280, "upgrade cost grows by 1.75x")
	progress.coins = 999999
	for i in 20: progress.buy("magnet")
	check(progress.upgrades.magnet == 5, "upgrades stop at their maximum")
	var stats: Dictionary = progress.stats()
	check(is_equal_approx(stats.start_radius, Campaign.START_RADIUS+Campaign.SIZE_PER_UPGRADE) and stats.magnet == 5, "upgrades change round stats")
	check(progress.reward(true, 3, 400) > progress.reward(false, 0, 400), "winning pays more coins than losing")
	# A maxed size upgrade must not let the starting hole eat a street building.
	var maxed := Campaign.START_RADIUS + Campaign.SIZE_PER_UPGRADE*progress.upgrade_max("size")
	var smallest_shop: float = 0.95 + 0.07
	check(maxed*0.85 < smallest_shop, "a maxed size upgrade (%.2f) cannot eat a shop from the start" % maxed)
	progress.skin = 7; progress.effect = 3; progress.trail = 3
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(progress.data())))
	check(restored.data() == progress.data(), "save round trip preserves progress, coins and upgrades")
	restored.restore({"version":4, "selected":999, "unlocked":999, "skin":999, "trail":-3, "effect":"bad", "medals":[null,99], "upgrades":{"size":99, "speed":"x"}})
	check(restored.selected == count-1 and restored.skin == Campaign.SKINS.size()-1 and restored.trail == 0 and restored.medals[1] == 3 and restored.upgrades.size == restored.upgrade_max("size"), "malformed save fields are bounded")
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
		# 30 city/prop batches plus one each for shield pylons and bombs.
		check(g.batches.size() <= 32, "level %d render batches bounded (%d)" % [i+1, g.batches.size()])
		var boss_mesh: Mesh = g.batches[g.items[g.boss_index].batch].mesh
		check(g.is_landmark() and g.minions.is_empty(),"level %d objective is a landmark, never a military unit" % (i+1))
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
		print("PAR %d %d" % [i, ceili(route.route_seconds)])
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
		g.items[g.boss_index].shielded = false
		g.hole_position = g.items[g.boss_index].position
		g.started = true
		for frame in 60: g.step(0.02,Vector2.ZERO)
		check(g.boss_down and g.mode == "playing", "level %d keeps playing after the boss falls" % (i+1))
		g.remaining = 0.01
		g.step(0.02,Vector2.ZERO)
		check(g.mode == "result" and g.hud.won and g.campaign.coins > coins_before, "level %d boss can be caught and pays coins" % (i+1))
		if i < Campaign.level_count()-1:
			g.on_play()
			check(g.campaign.selected == i+1 and g.score == 0, "next button loads a fresh level")

func check_goals_and_modes() -> void:
	var progress = Campaign.new()
	progress.unlock_all_for_testing = false
	progress.unlocked = 8
	check(progress.can_select(7) and not progress.can_select(8), "second continent needs stars")
	for i in 5: progress.medals[i] = 3
	check(progress.total_stars() == 15 and progress.can_select(8), "enough stars open the next continent")
	progress = Campaign.new()
	progress.restore({"version":4, "medals":[2, 0, 3]})
	check(progress.goals[0] == 3 and progress.goals[2] == 7 and progress.medals[0] == 2, "old star counts become goal masks")
	progress.selected = 0
	progress.complete_goals(0b101, 10)
	check(progress.goals[0] == 7 and progress.medals[0] == 3, "goal stars accumulate across replays")
	progress.selected = 1
	progress.complete_goals(0b110, 10)
	check(progress.goals[1] == 0 and progress.medals[1] == 0 and progress.unlocked == 1, "goals without conquering give nothing")
	var info := Campaign.level_info(20)
	var goals: Array = Campaign.Challenges.goals(info)
	check(goals.size() == 3 and goals[0].id == "win" and goals[2].id == ("rival" if info.rival else goals[2].id), "each city has three goals")
	check(not Campaign.has_rival(3) and Campaign.has_rival(12) and Campaign.has_rival(40), "rival cities follow the campaign")
	var day := "2026-09-30"
	check(Campaign.daily_level(day) == Campaign.daily_level(day) and Campaign.daily_level(day) < Campaign.level_count(), "daily city is deterministic")
	check(progress.record_daily(day, 500, true) and not progress.record_daily(day, 300, true) and progress.daily.best == 500, "daily bonus only on the first win")
	check(progress.daily_record("2026-10-01").best == 0 and not progress.daily_record("2026-10-01").won, "a new day starts a fresh record")
	check(progress.record_endless(900, 3) and not progress.record_endless(100, 1) and progress.endless.best == 900 and progress.endless.stage == 3, "endless keeps the best run")
	var rng := RandomNumberGenerator.new()
	check(Campaign.endless_level(0, rng) < 8 and Campaign.endless_level(20, rng) >= 40, "endless cities get harder by stage")
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(progress.data())))
	check(restored.data() == progress.data(), "save round trip keeps goals and records")

func check_challenge_systems(g) -> void:
	check(g.combo_seconds(8) == 2.0 and g.combo_seconds(16) == 3.0 and g.combo_seconds(30) == 5.0 and g.combo_seconds(45) == 3.0 and g.combo_seconds(9) == 0.0, "combo milestones grant time")
	g.load_level(40)
	g.on_play()
	check(g.defense.grace == 0.0 and g.defense.strike_cap == 5 and g.defense.warning_scale < 0.8, "late continents defend harder")
	g.started = true
	g.target_radius = 3.0
	var before: float = g.remaining
	g.take_hit()
	check(g.target_radius < 3.0 and g.remaining == before-2.0, "a hit shrinks the hole and costs time")
	g.load_level(10)
	g.on_play()
	g.started = true
	g.defense.grace = 0.0
	var reinforcements: Array = g.items.filter(func(item): return item.get("reinforcement", false))
	check(reinforcements.size() == 3 and reinforcements.all(func(item): return item.hidden), "reinforcements wait hidden")
	g.hole_position = Vector3(g.layout.move_x, 0, g.layout.move_z)
	g.target_radius = g.boss_radius/g.EAT_RATIO*g.COUNTER_AT + 0.05
	g.radius = g.target_radius
	g.step(0.02, Vector2.ZERO)
	check(g.counter_started and reinforcements.all(func(item): return not item.hidden), "landmark counter-attacks near the end")
	for frame in 60: g.step(0.02, Vector2.ZERO)
	check(g.defense.strikes.filter(func(s): return s.source.get("is_boss", false)).size() >= 3, "landmark fires a volley")
	# Goals: a clean win with no hits meets every goal it asks for.
	var summary: Dictionary = g.run_summary(true)
	summary.completion = 1.0; summary.best_combo = 99; summary.remaining = 999; summary.hits = 0; summary.defenders_eaten = 9; summary.rival_eaten = true
	check(g.Challenges.evaluate(g.goal_list, summary) == 7, "all goals can be met")

func check_rival(g) -> void:
	g.load_level(32)
	g.on_play()
	check(g.rival.active and g.level.rival, "rival hole joins its cities")
	g.started = true
	g.defense.grace = INF
	var snack: Dictionary = g.items.filter(func(item): return item.kind == "cone")[0]
	g.rival.position = Vector3(snack.position.x, 0, snack.position.z)
	g.rival.retarget = 99.0
	g.rival.target = snack
	g.hole_position = Vector3(g.layout.move_x, 0, -g.layout.move_z)
	g.step(0.02, Vector2.ZERO)
	check(snack.fall >= 0 and snack.get("sink", "") == "rival", "rival swallows food")
	for frame in 40: g.step(0.02, Vector2.ZERO)
	check(snack.eaten and g.rival.target_radius > g.START_RADIUS, "rival grows from its bites")
	# Race: how long the rival needs, left alone, to fit the landmark.
	g.reset_round()
	g.playing = true; g.mode = "playing"; g.started = true
	g.defense.grace = INF
	g.hole_position = Vector3(-g.layout.move_x, 0, g.layout.move_z)
	g.remaining = 9999.0
	var race := 0.0
	while race < 400.0 and g.playing:
		g.step(0.05, Vector2.ZERO)
		race += 0.05
	print("RIVAL RACE %.0fs (timer %ds, lose=%s)" % [race, g.level.seconds, g.lose_reason])
	check(g.lose_reason == "rival" and race > g.level.seconds*0.5, "an unchallenged rival takes the city, but not instantly")
	# Size decides who eats whom.
	g.reset_round()
	g.playing = true; g.mode = "playing"; g.started = true
	g.rival.target_radius = 4.0; g.rival.radius = 4.0
	g.rival.position = g.hole_position
	g.step(0.02, Vector2.ZERO)
	check(g.mode == "result" and not g.hud.won and g.lose_reason == "eaten", "a bigger rival swallows the player")
	g.reset_round()
	g.playing = true; g.mode = "playing"; g.started = true
	g.radius = 4.0; g.target_radius = 4.0
	g.rival.position = g.hole_position
	g.step(0.02, Vector2.ZERO)
	check(g.rival_eaten and not g.rival.active and g.playing, "a bigger player swallows the rival")

func check_special_runs(g) -> void:
	g.load_level(5)
	g.go_menu()
	g.start_daily()
	check(g.run_kind == "daily" and g.mode == "playing" and g.rival.active and g.campaign.selected == Campaign.daily_level(Campaign.today()), "daily challenge starts with a rival")
	g.go_menu()
	check(g.run_kind == "campaign" and g.campaign.selected == 5, "leaving the daily returns to the campaign city")
	g.start_endless()
	check(g.run_kind == "endless" and g.remaining == Campaign.ENDLESS_START_SECONDS and g.endless_stage == 0, "endless starts with a short clock")
	g.started = true
	g.score = 1234
	var clock: float = g.remaining
	var boss: Dictionary = g.items[g.boss_index]
	boss.shielded = false
	g.radius = g.boss_radius/g.EAT_RATIO + 0.3
	g.target_radius = g.radius
	g.hole_position = Vector3(boss.position.x, 0, boss.position.z)
	for frame in 60: g.step(0.02, Vector2.ZERO)
	check(g.endless_advance, "endless waits to load the next city")
	var carried: int = g.score
	g.advance_endless()
	check(g.endless_stage == 1 and g.score == carried and carried > 1234 and g.remaining > clock and g.playing, "endless carries score and time into the next city")
	g.started = true
	g.remaining = 0.01
	# Bites still add endless time, so run until the parked hole runs out of food.
	for frame in 300:
		if g.mode == "result": break
		g.step(0.02, Vector2.ZERO)
	check(g.mode == "result" and g.campaign.endless.stage >= 1,"endless ends on timeout and records the run")
	g.go_menu()
	check(g.run_kind == "campaign" and g.campaign.selected == 5, "leaving endless returns to the campaign city")

# Tuning aid (`-- --campaign-smoke --rival-bench`): seconds an unopposed rival
# needs to swallow each landmark, next to the level timer.
func bench_rival(g) -> void:
	for i in Campaign.level_count():
		g.load_level(i)
		g.on_play()
		g.playing = true; g.mode = "playing"; g.started = true
		g.defense.grace = INF
		g.level.rival = true
		g.reset_hazards()
		g.defense.grace = INF
		g.hole_position = Vector3(-g.layout.move_x, 0, g.layout.move_z)
		g.remaining = 9999.0
		var race := 0.0
		while race < 300.0 and g.playing:
			g.step(0.05, Vector2.ZERO)
			race += 0.05
		print("BOT %d %.0f %d" % [i, race, g.level.seconds])

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
	check(g.wardrobe.page == 5 and g.wardrobe.journey.stops.size() == 8 and g.wardrobe.controls.size() == 1, "last continent map shows eight 3D stops with bounded controls")
	g.wardrobe.choose_level(6)
	check(g.campaign.selected == 6 and g.mode == "menu", "level selection loads chosen map")
	g.open_panel("shop")
	var speed_before: int = g.campaign.upgrades.speed
	var speed_cost: int = g.campaign.upgrade_cost("speed")
	g.campaign.coins = speed_cost + 30
	g.wardrobe.buy("speed")
	check(g.campaign.upgrades.speed == speed_before+1 and g.campaign.coins == 30, "shop buys an upgrade")
	g.close_panel()
	check(is_equal_approx(g.stats.speed, 1.0 + g.campaign.upgrades.speed*Campaign.SPEED_PER_UPGRADE), "closing the shop applies upgrades")
	for skin in Campaign.SKINS.size():
		g.campaign.skin = skin
		g.campaign.effect = skin%4
		g.campaign.trail = skin%4
		g.apply_style()
		check(g.rim_shader.get_shader_parameter("style") == skin, "skin %d equips" % skin)
	check(g.fx.get_child_count() == 19, "cosmetic changes reuse fixed particle pools")
