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
	# Shapes only (water, bridges, reachability) for every city, without the routes.
	if "--shapes" in OS.get_cmdline_user_args():
		for i in Campaign.level_count():
			g.load_level(i)
			g.go_menu()
			g.on_play()
			check_shape(g, i)
		print("CAMPAIGN CHECKS: ", failures, " failures")
		g.get_tree().quit(1 if failures else 0)
		return
	if "--spawn-bench" in OS.get_cmdline_user_args():
		bench_spawns(g)
		g.get_tree().quit()
		return
	check_progress()
	check_goals_and_modes()
	# `--quick` skips the slow 48-city sweep while iterating on other checks.
	if "--quick" not in OS.get_cmdline_user_args(): check_levels(g)
	check_challenge_systems(g)
	check_services(g)
	check_rival(g)
	check_special_runs(g)
	check_runner(g)
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
	var tables: Dictionary = I18n.Strings.S.merged(I18n.LandmarkLines.S)
	for key in tables:
		var row: Array = tables[key]
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
	check(Intro.pending_tips(Campaign.level_info(0), []).is_empty() and "guardian" in Intro.pending_tips(Campaign.level_info(1), ["weather_rain", "pickup"]), "the first city keeps it simple; the guardian is introduced in the second")
	var lines := 0
	for id in Campaign.LANDMARKS:
		if I18n.t("lmfun_" + id) != "lmfun_" + id: lines += 1
	check(lines == Campaign.LANDMARKS.size(), "every landmark has an intro line")
	check(Intro.landmark_tip(Campaign.level_info(0), []) == ["lm_onepillar"] and Intro.landmark_tip(Campaign.level_info(0), ["lm_onepillar"]).is_empty(), "each landmark is introduced once")
	check(Intro.tip_page("lm_eiffel").title == Campaign.boss_name("eiffel") and Intro.tip_page("lm_eiffel").tag != "", "landmark card shows name and city")
	check(Intro.tip_page("lm_onepillar").has("picture") and load(Intro.tip_page("lm_onepillar").picture) is Texture2D, "landmark card shows its picture when one exists")
	check(Intro.pending_tips(Campaign.level_info(1), []) == ["weather_rain"] and Intro.pending_tips(Campaign.level_info(1), ["weather_rain"]) == ["pickup"], "city 2 introduces rain, then power orbs on the next start")
	var seen: Array = ["weather_rain", "pickup", "guardian"]
	check(Intro.pending_tips(Campaign.level_info(1), seen).is_empty(), "seen tips are not repeated")
	check(Intro.pending_tips(Campaign.level_info(8), seen)[0] == "region_europe", "a new continent gets a welcome card first")
	check(Intro.pending_tips(Campaign.level_info(40), []).size() == Intro.MAX_TIPS, "tips per start are capped")
	check(Intro.story_pages().size() == 4 and Intro.tip_page("weather_storm").icon == "storm", "story and tip pages are built")

func check_progress() -> void:
	var count := Campaign.level_count()
	check(Campaign.regular_count() == 48 and count == 48 + Campaign.HOLIDAYS.size() and Campaign.REGIONS.size() == 6, "six continents with eight cities each, plus the festival cities")
	check_festivals()
	var progress = Campaign.new()
	progress.unlock_all_for_testing = true
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
	check_looks()
	progress.owned = {"crafts":[0, 2], "skins":[0, 7], "effects":[0, 3], "trails":[0, 3]}
	progress.skin = 7; progress.effect = 3; progress.trail = 3
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(progress.data())))
	check(restored.data() == progress.data(), "save round trip preserves progress, coins and upgrades")
	restored.restore({"version":4, "selected":999, "unlocked":999, "skin":999, "trail":-3, "effect":"bad", "medals":[null,99], "upgrades":{"size":99, "speed":"x"}})
	check(restored.selected == Campaign.regular_count()-1 and restored.skin == Campaign.SKINS.size()-1 and restored.trail == 0 and restored.medals[1] == 3 and restored.upgrades.size == restored.upgrade_max("size"), "malformed save fields are bounded")
	var sizes: Array = []
	for i in count:
		var info := Campaign.level_info(i)
		sizes.append(int(info.cols)*int(info.rows))
	check(sizes[0] == 9 and sizes[Campaign.regular_count()-1] == 35 and sizes[30] == 25 and sizes[23] > sizes[0], "maps grow from 3×3 to 5×7")
	check(sizes[7] > sizes[6], "continent finale uses a bigger map")

# Festival cities (campaign.gd HOLIDAYS): side stops after their city on the
# route, opened by beating it, never in the way, stars kept like any city.
func check_festivals() -> void:
	var tet := Campaign.regular_count()
	var lantern := tet + 1
	check(Campaign.route(0) == [0, 1, 2, lantern, 3, tet, 4, 5, 6, 7] and Campaign.region_of(tet) == 0, "festival stops sit after the city that opens them")
	check(Campaign.HOLIDAYS.all(func(h): return Campaign.region_of(int(h.after)) == int(h.region)), "each festival opens from a city of its own continent")
	var seen := {}
	for h in Campaign.HOLIDAYS:
		seen[h.boss] = Campaign.LANDMARKS.has(h.boss) and preload("res://scripts/map_shapes.gd").SHAPES.has("%dx%d" % [h.cols, h.rows])
	check(seen.size() == Campaign.HOLIDAYS.size() and seen.values().all(func(ok): return ok), "every festival has its own landmark and a shape for its grid")
	var fest = Campaign.new()
	check(not fest.can_select(tet), "a festival city starts locked")
	fest.unlocked = 4
	check(fest.can_select(tet) and fest.can_select(lantern) and not fest.can_select(tet + 2), "it opens once the city before it is beaten")
	check(fest.next_level(3) == tet and fest.next_level(tet) == 4, "next after that city is the festival, then the route goes on")
	fest.selected = tet
	fest.complete(3, 500)
	check(fest.medals[tet] == 3 and fest.unlocked == 4, "a festival win keeps its stars and leaves the main route as it was")
	check(fest.next_level(3) == 4 and fest.next_level(7) == 8 and fest.next_level(47) == -1, "a beaten festival is skipped; the route crosses continents and ends")
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(fest.data())))
	check(restored.medals[tet] == 3 and restored.total_stars() == fest.total_stars(), "festival stars survive a save")
	var info := Campaign.level_info(tet)
	check(info.holiday == "tet" and info.index == 4 and info.slot == -1 and info.share > Campaign.share_at(4.0/47.0), "a festival plays at its rank with a bigger meal")
	var tester = Campaign.new()
	tester.unlock_all_for_testing = true
	tester.selected = tet
	tester.complete(3, 100)
	check(tester.medals[tet] == 0, "a preview festival win awards nothing")

# Coin shop for the saucer and hole looks (cosmetics.gd), as in the 2D game.
func check_looks() -> void:
	var Cosmetics = preload("res://scripts/cosmetics.gd")
	var shop = Campaign.new()
	check(Cosmetics.count("skins") == Campaign.SKINS.size() and Cosmetics.count("effects") == Campaign.EFFECTS.size() and Cosmetics.count("trails") == Campaign.TRAILS.size(), "every look has a price")
	var order: Array = Cosmetics.SKIN_ORDER.duplicate()
	order.sort()
	check(order == range(Campaign.SKINS.size()), "shop order lists every skin once")
	check(shop.owns("skins", 0) and not shop.owns("skins", 1) and not shop.equip("skins", 1), "only the free looks start owned")
	check(not shop.buy_look("skins", 1) and shop.coins == 0, "a look cannot be bought without coins")
	shop.coins = 350
	check(shop.buy_look("skins", 1) and shop.coins == 50 and shop.owns("skins", 1) and shop.equip("skins", 1) and shop.skin == 1, "buying a skin spends its price and lets it be equipped")
	check(not shop.buy_look("skins", 1) and shop.coins == 50, "an owned look is never charged twice")
	check(Cosmetics.count("crafts") == preload("res://scripts/fleet.gd").NAMES.size() and not shop.owns("crafts", 1) and not shop.equip("crafts", 1), "saucers have prices and start locked")
	shop.coins = 99999
	check(shop.buy_look("skins", 11) and shop.buy_look("crafts", 2) and shop.equip("crafts", 2) and shop.craft == 2, "former journey skins and saucers are bought with coins")
	for i in 6: shop.medals[i] = 3
	check(not shop.owns("effects", 1), "stars no longer unlock looks")
	var legacy = Campaign.new()
	legacy.restore({"version":8, "craft":3, "medals":[3, 3, 3, 3, 3, 3], "unlocked":6})
	check(legacy.owns("crafts", 3) and legacy.craft == 3 and legacy.owns("skins", 11) and legacy.owns("skins", 9) and legacy.owns("effects", 1) and not legacy.owns("skins", 10), "an old save keeps its saucer and earned journey looks")
	var tester = Campaign.new()
	tester.enable_test_mode()
	check(tester.coins == Campaign.TEST_COINS and tester.can_select(Campaign.level_count()-1) and tester.save_path() == Campaign.TEST_SAVE_PATH, "test mode opens every city with its own save")
	check(tester.buy_look("trails", 5) and tester.buy("size") and tester.coins == Campaign.TEST_COINS, "test mode coins never run out")
	var old = Campaign.new()
	old.restore({"version":5, "skin":3, "effect":2, "trail":3})
	check(old.skin == 3 and old.effect == 5 and old.trail == 5 and old.owns("skins", 3) and old.owns("effects", 5) and old.owns("trails", 5), "looks equipped before the shop stay owned")
	var bad = Campaign.new()
	bad.restore({"version":6, "skin":4, "owned":{"skins":[99, -1, "x", 3, 3], "effects":"x"}})
	check(bad.owned.skins == [0, 3] and bad.owned.effects == [0] and bad.skin == 0, "bad owned lists are cleaned and unowned looks unequipped")

func check_levels(g) -> void:
	g.campaign.unlocked = Campaign.level_count()-1
	var route = preload("res://scripts/smoke.gd").new()
	route.g = g
	# `--levels-from=N` starts the sweep at city N (0-based) while iterating.
	var first := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels-from="): first = int(arg.trim_prefix("--levels-from="))
	for i in range(first, Campaign.level_count()):
		g.load_level(i)
		# The last city has no NEXT, so its result screen is still up: leave it
		# first, or HOME would treat this city as the one just won.
		g.mode = "menu"
		g.go_menu()
		g.on_play()
		var info: Dictionary = g.level
		check(is_equal_approx(g.remaining, float(info.seconds)) and g.boss_radius >= g.MIN_BOSS and g.boss_radius <= g.MAX_BOSS + g.FINALE_BOSS, "level %d config applied (boss %.1f, %ds)" % [i+1, g.boss_radius, info.seconds])
		# City/prop batches plus bombs, barriers, danger-zone kinds, up to seven
		# national-force unit kinds and two boat kinds (the guardian has its own node).
		check(g.batches.size() <= 43, "level %d render batches bounded (%d)" % [i+1, g.batches.size()])
		var wanted: Dictionary = g.MapFeatures.counts(int(info.index))
		var f = g.features
		check(f.gold_blocks.size() == wanted.gold and f.danger_blocks.size() == wanted.danger and f.shortcuts.size() == wanted.shortcuts \
			and f.barriers.size() <= wanted.barriers and (wanted.barriers == 0 or f.barriers.size() > 0), "level %d map features (%d gold, %d blocks, %d alleys, %d danger)" % [i+1, f.gold_blocks.size(), f.barriers.size(), f.shortcuts.size(), f.danger_blocks.size()])
		check_spawns(g, i)
		check_shape(g, i)
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
		check(g.boss_down and g.mode == "result", "level %d ends when the boss falls" % (i+1))
		check(g.mode == "result" and g.hud.won and g.campaign.coins > coins_before, "level %d boss can be caught and pays coins" % (i+1))
		if i == 0:
			g.go_menu()
			check(g.campaign.selected == 1 and g.mode == "menu" and g.score == 0, "home after a win shows the next city")
		elif g.campaign.next_level(i) >= 0:
			# The route goes on through a festival city not yet beaten.
			var next: int = g.campaign.next_level(i)
			g.on_play()
			check(g.campaign.selected == next and g.score == 0, "next button loads a fresh level (%d -> %d, wanted %d, score %d)" % [i, g.campaign.selected, next, g.score])

# Bays, lakes and rivers (map_shapes.gd): every land block can be reached, no food
# or crossing sits in the water, the hole is pushed back to the shore and the
# rival's way round the water reaches the landmark.
func check_shape(g, i: int) -> void:
	var layout = g.layout
	if i >= g.MapShapes.PLAIN_UNTIL and g.MapShapes.SHAPES.has("%dx%d" % [layout.cols, layout.rows]):
		check(layout.shaped(), "level %d has water in its shape" % (i+1))
	if not layout.shaped(): return
	check(g.MapShapes.connected(layout) and layout.is_land(0.0, 0.0), "level %d: every block is reachable over land or bridges" % (i+1))
	# Boats (boats.gd) are the only things meant to float.
	var wet: Array = g.items.filter(func(item): return item.kind != "boat" and layout.water_rects.any(func(rect: Rect2): return rect.grow(-0.3).has_point(Vector2(item.origin.x, item.origin.z))))
	check(wet.is_empty(), "level %d: nothing stands in the water (%s)" % [i+1, ", ".join(wet.map(func(item): return "%s@%.1f,%.1f" % [item.kind, item.origin.x, item.origin.z]))])
	check(layout.junctions().all(func(spot): return layout.inside(Vector3(spot.x, 0, spot.y))), "level %d: every signalled crossing is on land" % (i+1))
	var pool: Rect2 = layout.water_rects[0]
	var shore: Vector3 = layout.clamp_point(Vector3(pool.get_center().x, 0, pool.get_center().y))
	check(layout.inside(shore), "level %d: a hole driven into the water ends up on the shore (%.1f, %.1f)" % [i+1, shore.x, shore.z])
	var far: Vector3 = g.rival_corner()
	var length: float = layout.route_length(far, g.BOSS_HOME)
	check(layout.inside(far) and length < INF and length < 6.0*far.distance_to(g.BOSS_HOME) + 20.0, "level %d: the rival's way round the water reaches the landmark (%.0f)" % [i+1, length])

# Random drop points sit on inner streets, clear of the landmark, and the opening
# cones follow them onto that street without reaching a crossing.
func check_spawns(g, i: int) -> void:
	var spots: Array = g.SpawnPoints.candidates(g)
	var layout = g.layout
	var on_street := spots.all(func(spot): return spot.at.is_equal_approx(g.SPAWN) \
		or (spot.axis == Vector3.RIGHT and spot.at.z in layout.crossings_z) or (spot.axis == Vector3.BACK and spot.at.x in layout.crossings_x))
	check(spots.size() >= 4 and on_street, "level %d has %d random drop streets" % [i+1, spots.size()])
	var spot: Dictionary = spots[-1]
	g.SpawnPoints.place_opening(g, spot)
	var cones: Array = g.items.filter(func(item): return item.has("opening_origin"))
	var half: float = spot.length*0.5 - g.SpawnPoints.CONE_MARGIN + 0.01
	var lined := cones.all(func(cone):
		var offset: Vector3 = (cone.origin - spot.at)*Vector3(1, 0, 1)
		return absf(offset.dot(spot.axis)) <= half and is_zero_approx(offset.cross(spot.axis).length()))
	check(not cones.is_empty() and lined, "level %d opening cones line the drop street" % (i+1))
	g.SpawnPoints.place_opening(g, spots[0])
	check(cones.all(func(cone): return cone.origin == cone.opening_origin), "level %d designed opening restored" % (i+1))

func check_goals_and_modes() -> void:
	var progress = Campaign.new()
	progress.unlock_all_for_testing = false
	progress.unlocked = 8
	check(progress.can_select(7) and not progress.can_select(8), "second continent needs stars")
	for i in 6: progress.medals[i] = 3
	check(progress.total_stars() == 18 and progress.can_select(8), "enough stars open the next continent")
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
	check_streak(progress)
	progress.reminders = false
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(progress.data())))
	check(restored.data() == progress.data(), "save round trip keeps goals and records")
	check(restored.streak.count == progress.streak.count and not restored.reminders, "the streak and the reminder switch are saved")

# Leaderboard (play_games.gd) and reminders (notify.gd) without their addons.
func check_services(g) -> void:
	check(not g.play_games.available() and not g.hud.board_button.visible, "without Play Games no leaderboard button shows")
	var Notify = g.Notify
	check(Notify.delay_until_tomorrow({"hour":20, "minute":0, "second":0}) == 23*3600 and Notify.delay_until_tomorrow({"hour":0, "minute":0, "second":0}) == 43*3600, "the reminder lands at 19:00 the next day")
	check(Notify.message(4, "2026-10-22", true)[0].contains("4") and Notify.message(1, "2026-10-22", true)[0] != Notify.message(4, "2026-10-22", true)[0], "a streak gets its own reminder text")
	var day := "2026-10-23"
	check(Notify.message(4, day, false)[0].contains(g.DailyGames.title(Campaign.daily_type(day))) and Notify.message(0, day, true)[0].contains(Campaign.level_info(Campaign.daily_level(day)).city), "a reminder names that day's challenge and city")
	check(Notify.date_after(1) != Campaign.today() and Notify.date_after(1).length() == 10, "reminders are dated from tomorrow")
	check(not g.notify.available() and not g.hud.reminder_button.visible, "without the notification addon there is no reminder switch")
# Days in a row with a finished daily: coins grow over a week, day 7 adds a
# coin bonus (never a free look), a skipped day starts over, and the same day never pays twice.
func check_streak(progress) -> void:
	check(Campaign.day_before("2026-03-01") == "2026-02-28" and Campaign.day_before("2027-01-01") == "2026-12-31", "the day before crosses months and years")
	progress.streak = {"count":0, "last":""}
	var coins_before: int = progress.coins
	var owned_before: int = progress.owned.effects.size()
	var gifts: Array = []
	for day in range(1, 8): gifts.append(progress.advance_streak("2026-11-%02d" % day))
	check(progress.streak.count == 7 and gifts[0].coins == Campaign.STREAK_COINS[0] and gifts[6].day == 7, "seven days in a row count up")
	check(gifts[6].coins == int(Campaign.STREAK_COINS[6]) + Campaign.STREAK_WEEK_COINS and progress.owned.effects.size() == owned_before, "day seven pays a coin bonus, not a free look")
	check(progress.coins - coins_before == Campaign.STREAK_COINS.reduce(func(a, b): return a + b) + Campaign.STREAK_WEEK_COINS, "each day pays its coins")
	check(progress.advance_streak("2026-11-07").is_empty(), "a second daily the same day pays nothing")
	check(progress.streak_days("2026-11-08") == 7 and progress.streak_days("2026-11-09") == 0, "the streak shows until a day is skipped")
	check(progress.advance_streak("2026-11-10").day == 1, "a skipped day starts the streak over")

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
	# Park the player on the land block farthest from the rival's corner.
	var far_cell: Vector2 = Vector2.ZERO
	for cell in g.layout.cells():
		if cell.distance_to(Vector2(g.rival_corner().x, g.rival_corner().z)) > far_cell.distance_to(Vector2(g.rival_corner().x, g.rival_corner().z)): far_cell = cell
	g.hole_position = Vector3(far_cell.x, 0, far_cell.y)
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
	check_daily_games(g)
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

# Bonus run (runner.gd): offered on a first win of every fifth city, a gate-
# picking bot swallows the landmark, a bot taking the worse gates falls short,
# and PLAY afterwards goes on to the next city.
func check_runner(g) -> void:
	var Runner = g.Runner
	check(Runner.due(4) and Runner.due(9) and not Runner.due(5), "every fifth city opens a bonus run")
	var unlock: bool = g.campaign.unlock_all_for_testing
	g.campaign.unlock_all_for_testing = true
	g.load_level(4)
	g.go_menu()
	var goals_before: int = g.campaign.goals[4]
	g.campaign.goals[4] = 0
	g.playing = true
	g.mode = "playing"
	g.finish(true)
	g.update_hud()
	check(g.bonus_pending and g.hud.bonus_ready, "a first win on city 5 offers the bonus run")
	g.on_play()
	check(g.run_kind == "runner" and g.mode == "playing" and g.campaign_level == 4, "PLAY on that result starts the run")
	check(g.runner.gates.size() >= 6 and g.layout.cols == Runner.COLS and g.items[g.boss_index].position.z < g.hole_position.z - 100.0, "the course has gate pairs and the landmark at the far end")
	var good := drive_run(g, true)
	check(good.won, "taking the bigger gates swallows the landmark (r %.2f, boss %.2f, %.1fs)" % [good.radius, g.boss_radius, good.time])
	check(good.time > 35.0 and good.time < 55.0 and g.reward > 0, "the run lasts 35-55 s and pays coins (%.1fs, %d coins, %d picked, %d roadblocks hit, %d boosts)" % [good.time, g.reward, g.runner.props.picked, g.runner.props.hits, g.runner.props.boosts])
	check(g.runner.props.blocks.size() >= 10 and g.runner.props.blocks.any(func(block): return block.slide) and g.runner.props.pads.size() >= 5 and g.runner.props.coins.size() >= 60 and g.runner.props.hits == 0, "fixed and sliding roadblocks, boost pads and coin lines line the course; the bot dodges every roadblock")
	check(g.runner.gates.any(func(gate): return gate.swaps) and g.runner.gates.any(func(gate): return not gate.swaps), "gates in the second half swap sides")
	g.start_run()
	var bad := drive_run(g, false)
	check(not bad.won and bad.radius < good.radius, "always the worse gate falls short (r %.2f, %s at z %.1f after %.1fs)" % [bad.radius, bad.mode, bad.z, bad.time])
	g.start_run()
	var slip := drive_run(g, true, 1)
	check(slip.won, "one roadblock hit near the end is still forgiven (r %.2f)" % slip.radius)
	g.start_run()
	var crash := drive_run(g, true, 4)
	check(not crash.won and g.runner.props.hits == 4, "four roadblock hits cost the landmark (r %.2f)" % crash.radius)
	g.on_play()
	check(g.run_kind == "campaign" and g.campaign.selected == 5 and g.mode == "playing", "after the run PLAY goes on to the next city")
	check(g.runner.gates.is_empty(), "the course's gates are cleared in a normal city")
	g.go_menu()
	g.campaign.goals[4] = goals_before
	g.campaign.unlock_all_for_testing = unlock

# `hits` roadblocks from the end are driven into on purpose (a slip).
func drive_run(g, better: bool, hits := 0) -> Dictionary:
	g.started = true
	var time := 0.0
	var props = g.runner.props
	var blocks: Array = props.blocks
	while g.mode == "playing" and time < 90.0:
		var next: Dictionary = {}
		for gate in g.runner.gates:
			if gate.used or gate.at > g.hole_position.z: continue
			if next.is_empty() or gate.at > next.at or (gate.at == next.at and (gate.gain > next.gain) == better): next = gate
		var aim: float = next.side*g.Runner.LANE*0.5 if not next.is_empty() else 0.0
		# Both bots read the nearest roadblock before that gate (where a sliding
		# one will be on arrival) and pass on the open half.
		var near := -1
		for k in blocks.size():
			var block: Dictionary = blocks[k]
			if block.used or block.at > g.hole_position.z or (not next.is_empty() and block.at < next.at): continue
			if near < 0 or block.at > blocks[near].at: near = k
		if near >= 0:
			var block: Dictionary = blocks[near]
			var eta: float = (g.hole_position.z - block.at)/maxf(1.0, -g.hole_velocity.z)
			var x: float = props.block_x(block, props.clock + eta)
			if near >= blocks.size() - hits: aim = x
			elif absf(aim - x) < props.BLOCK_HALF + g.radius*props.BLOCK_REACH + 0.6: aim = -signf(x if x != 0.0 else 1.0)*g.Runner.LANE
		g.step(0.02, Vector2(clampf((aim - g.hole_position.x)*0.5, -1.0, 1.0), 0.0))
		time += 0.02
	return {"won":g.mode == "result" and g.hud.won, "radius":g.radius, "time":time, "mode":g.mode, "z":g.hole_position.z}

# Daily mini-games (daily_games.gd): setup, scoring, three tries a day and the
# carry-in power a first win pays.
func check_daily_games(g) -> void:
	var date := Campaign.today()
	check(Campaign.daily_type(date) == Campaign.daily_type(date) and Campaign.daily_type(date) in Campaign.DAILY_TYPES, "daily mini-game is deterministic per day")
	var types := {}
	for day in 30: types[Campaign.daily_type("2026-11-%02d" % (day+1))] = true
	check(types.size() == Campaign.DAILY_TYPES.size(), "every mini-game comes up within a month")
	g.campaign.daily = {}
	g.campaign.items = {"magnet":0, "speed":0, "time":0}
	g.daily_override = "goldrush"
	g.start_daily()
	var boss: Dictionary = g.items[g.boss_index]
	check(g.run_kind == "daily" and g.mode == "playing" and g.rival.active and g.campaign.selected == Campaign.daily_level(date), "gold rush starts with a rival in today's city")
	check(boss.hidden and g.items.filter(func(item): return item.get("defender", false) and not item.hidden).is_empty(), "the landmark and its defenders sit out the mini-game")
	check(is_equal_approx(g.remaining, g.DailyGames.SECONDS.goldrush + float(g.stats.bonus_time)) and g.campaign.daily_attempts_left(date) == 2, "a daily try is spent and the mini-game clock is set")
	var chest: Dictionary = g.items.filter(func(item): return item.kind == "gold" and item.variant == 1)[0]
	g.started = true
	g.swallow(chest)
	var food: Dictionary = g.items.filter(func(item): return item.kind == "cone")[0]
	g.swallow(food)
	check(g.daily.count == 3, "only golden treasure scores (a chest is worth 3)")
	g.go_menu()
	g.daily_override = "stampede"
	g.start_daily()
	var ducks: Array = g.items.filter(func(item): return item.kind == "duck")
	check(ducks.size() == g.DailyGames.DUCKS and not g.rival.active and g.daily.count == 0, "duck stampede fills the city with ducks")
	g.started = true
	g.defense.grace = INF
	var duck: Dictionary = ducks[0]
	var start: Vector3 = duck.position
	g.hole_position = start + Vector3(2.5, 0, 0)
	g.hole_position.y = 0
	for frame in 150: g.step(0.02, Vector2.ZERO)
	check(duck.position.distance_to(start) > 1.0 and duck.position.distance_to(g.hole_position) > 2.5, "ducks sprint away from the hole")
	g.hole_position = Vector3(duck.position.x, 0, duck.position.z)
	for frame in 3: g.step(0.02, Vector2.ZERO)
	check(g.daily.count >= 1, "swallowing a duck scores")
	g.daily.count = g.daily.target()
	g.remaining = 0.01
	g.step(0.02, Vector2.ZERO)
	var power := Campaign.daily_power(date)
	check(g.mode == "result" and g.hud.won and g.reward > 0 and g.hud.stars == 2 and g.campaign.items[power] == 1, "reaching the target wins coins and a carry-in power (%s)" % power)
	g.on_play()
	check(g.run_kind == "daily" and g.mode == "playing" and g.campaign.daily_attempts_left(date) == 0, "replay from the result spends the third try")
	g.daily_override = "coinrain"
	g.started = true
	g.remaining = 0.01
	g.step(0.02, Vector2.ZERO)
	check(g.mode == "result" and g.campaign.items[power] == 1, "a second win the same day pays no second power")
	g.on_play()
	check(g.run_kind == "campaign" and g.mode == "menu", "with no tries left the daily goes home")
	g.start_daily()
	check(g.run_kind == "campaign" and g.mode == "menu", "the daily is locked after three tries")
	g.campaign.daily = {}
	g.start_daily()
	check(g.items.filter(func(item): return item.kind == "coin").size() == g.DailyGames.COINS, "coin rain keeps a pool of coins in the sky")
	g.started = true
	g.defense.grace = INF
	for frame in 150: g.step(0.02, Vector2.ZERO)
	var landed: Array = g.items.filter(func(item): return item.kind == "coin" and not item.hidden and item.falling <= 0 and item.fall < 0)
	check(not landed.is_empty() and landed.all(func(c): return absf(c.position.y - 0.16) < 0.01), "coins fall from the sky and land")
	g.hole_position = Vector3(landed[0].position.x, 0, landed[0].position.z)
	for frame in 3: g.step(0.02, Vector2.ZERO)
	check(g.daily.count >= 1, "catching a coin scores")
	for frame in 40: g.step(0.02, Vector2.ZERO)
	check(g.items.filter(func(item): return item.kind == "coin" and not item.hidden and item.eaten).is_empty(), "caught coins go back to the sky pool")
	g.go_menu()
	check_cow_hunt(g)
	g.daily_override = ""
	var saved = Campaign.new()
	saved.daily = {"date":date, "type":"coinrain", "attempts":9, "best":-4, "won":true}
	saved.items = {"magnet":2, "speed":0, "time":1}
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(saved.data())))
	check(restored.daily.attempts == Campaign.DAILY_ATTEMPTS and restored.daily.best == 0 and restored.items.magnet == 2 and restored.items.time == 1, "daily tries and carry-in powers survive a save, bounded")
	g.campaign.items = {"magnet":1, "speed":1, "time":0}
	g.on_play()
	check(g.mechanics.powers.magnet > 0 and g.mechanics.powers.speed > 0 and g.campaign.items.magnet == 0, "carry-in powers start the next campaign round")
	g.go_menu()

# Find the cow (cow_hunt.gd): a herd where only today's cow matches every clue;
# a wrong bite costs time, a chew and opens a clue; the right one wins.
func check_cow_hunt(g) -> void:
	g.campaign.daily = {}
	g.daily_override = "findcow"
	g.start_daily()
	var hunt = g.daily.hunt
	var herd: Array = g.items.filter(func(item): return item.kind == "huntcow")
	var twins: Array = herd.filter(func(cow): return cow != hunt.star and cow.bell == hunt.star.bell and cow.coat == hunt.star.coat and hunt.quarter(cow.origin) == hunt.quarter(hunt.star.origin))
	var reachable := herd.all(func(cow): return absf(cow.origin.x) <= g.layout.move_x - 1.0 and absf(cow.origin.z) <= g.layout.move_z - 1.0)
	check(reachable and herd.size() == hunt.COWS and twins.is_empty() and hunt.note().contains(hunt.star_name) and g.daily.dots().is_empty(), "the herd has one cow that fits all clues, and no minimap help")
	g.started = true
	g.defense.grace = INF
	var decoy: Dictionary = herd.filter(func(cow): return cow != hunt.star)[0]
	var before: float = g.remaining
	# Hold the hole on the cow (drift and wind would carry it off).
	for frame in 30:
		if decoy.fall < 0 and not decoy.eaten: g.hole_position = Vector3(decoy.position.x, 0, decoy.position.z)
		g.step(0.02, Vector2.ZERO)
	check(hunt.wrong == 1 and hunt.clues == 2 and g.remaining < before - 2.0 and g.daily.speed_scale() < 1.0, "a wrong cow costs time, a chew, and opens the next clue")
	for frame in 60:
		if g.mode != "playing": break
		if hunt.star.fall < 0: g.hole_position = Vector3(hunt.star.position.x, 0, hunt.star.position.z)
		g.step(0.02, Vector2.ZERO)
	check(g.mode == "result" and g.hud.won and g.hud.stars == 3 and g.reward > 0, "swallowing today's cow wins the hunt")
	g.go_menu()

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

# The greedy par route from the drop point farthest from the landmark, against the
# timer: "SPAWN <level> <route s> <par s> <timer s>".
func bench_spawns(g) -> void:
	for i in Campaign.level_count():
		g.load_level(i)
		var spots: Array = g.SpawnPoints.candidates(g)
		spots.sort_custom(func(a, b): return g.SpawnPoints.flat(a.at, g.BOSS_HOME) > g.SpawnPoints.flat(b.at, g.BOSS_HOME))
		g.reset_round()
		g.SpawnPoints.place_opening(g, spots[0])
		for item in g.items: if item.has("opening_origin"): item.position = item.origin
		g.hole_position = spots[0].at
		g.playing = true; g.mode = "playing"; g.started = true
		g.defense.grace = INF
		g.rival.active = false
		g.remaining = 300.0
		var route := 0.0
		var boss: Dictionary = g.items[g.boss_index]
		while g.playing and not g.boss_down and route < 300.0:
			var target: Dictionary = g.Rival.best_target(g.items, boss, g.hole_position, g.radius)
			if not target.is_empty():
				var aim: Vector3 = g.layout.steer(g.hole_position, target.position)
				var offset := Vector3(aim.x - g.hole_position.x, 0, aim.z - g.hole_position.z)
				g.hole_position += offset.limit_length((5.8 + minf(g.radius, 4.0)*0.45)*float(g.stats.speed)*0.05)
			g.step(0.05, Vector2.ZERO)
			route += 0.05
		print("SPAWN %d %.0f %d %.0f" % [i+1, route, Campaign.PAR_SECONDS[i], g.level.seconds])

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
	check(g.wardrobe.page == 5 and g.wardrobe.journey.stops.size() == Campaign.route(5).size() and g.wardrobe.controls.size() == 1, "last continent map shows its 3D stops (festival included) with bounded controls")
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
		g.campaign.effect = skin%Campaign.EFFECTS.size()
		g.campaign.trail = skin%Campaign.TRAILS.size()
		g.apply_style()
		check(g.rim_shader.get_shader_parameter("style") == skin, "skin %d equips" % skin)
	check(g.fx.get_child_count() == 20, "cosmetic changes reuse fixed particle pools and the ground trail")
