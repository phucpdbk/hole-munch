extends RefCounted
# Campaign checks: `--headless --path . -- --campaign-smoke`. Never writes the save.
const Campaign = preload("res://scripts/campaign.gd")
const I18n = preload("res://scripts/i18n.gd")
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
	check_album(g)
	check_daily_picker(g)
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
	check_replay_coins(progress)
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

# Replays only pay in full for stars the city did not have yet.
func check_replay_coins(progress) -> void:
	var keep: int = progress.selected
	progress.selected = 0
	var full: int = progress.reward(true, 3, 2000, 0, 3)
	var grind: int = progress.reward(true, 3, 2000, 0, progress.new_star_count(7))
	check(progress.goals[0] == 7 and progress.is_farm_replay(0) and grind > 0 and grind*4 < full, "a replay with no new star pays a small share (%d vs %d)" % [grind, full])
	var parts: Dictionary = progress.reward_parts(true, 3, 2000, 0, 0)
	check(parts.replay and parts.stars == 0 and parts.win == 0, "a grind replay pays no star or win coins")
	progress.selected = 1
	progress.goals[1] = 1
	var mended: Dictionary = progress.reward_parts(true, 3, 2000, 0, progress.new_star_count(7))
	check(progress.new_star_count(7) == 2 and not mended.replay and mended.stars == 30 and mended.win > 0, "a replay that adds stars pays them and the win")
	progress.goals[1] = 0
	check(not progress.is_farm_replay(0), "a city never won is not a grind replay")
	progress.selected = keep

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
	check(info.holiday == "tet" and info.index == 4 and info.slot == -1 and is_equal_approx(info.share, Campaign.share_at(4.0/47.0) + Campaign.HOLIDAY_SHARE), "a festival plays at its rank and meal")
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
		# The route above already won the city, so this catch is a replay without a new star.
		check(g.mode == "result" and g.hud.won and g.campaign.coins >= coins_before and g.time_coins == 0 and g.record_note == I18n.t("replay_coins"), "level %d boss can be caught; the replay pays as a grind" % (i+1))
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
	check(g.target_radius < 3.0 and g.remaining == before-g.HIT_SECONDS, "a hit shrinks the hole and costs time")
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
	check(g.daily.carried == 3 and g.daily.count == 0 and g.daily.speed_scale() < 1.0, "gold is carried (a chest is worth 3), slows the hole and scores nothing yet")
	check(is_equal_approx(g.target_radius, float(g.stats.start_radius)), "the gold rush hole keeps its starting size")
	var gold_limit: float = Campaign.START_RADIUS*g.EAT_RATIO
	check(g.items.filter(func(item): return item.kind == "gold" and item.radius > gold_limit).is_empty(), "every treasure fits a starting hole")
	g.rival.position = g.hole_position + Vector3(9, 0, 0)
	g.hole_position = g.daily.bank_at()
	g.daily.update_gold(g, 0.02)
	check(g.daily.count == 3 and g.daily.carried == 0, "the bank ring turns carried gold into score")
	g.daily.carried = 5
	g.hole_position = Vector3(6, 0, 6)
	g.rival.position = g.hole_position
	g.daily.update_gold(g, 0.02)
	check(g.daily.carried == 0 and g.daily.count == 3, "the rival steals the gold the hole carries")
	g.go_menu()
	g.daily_override = "stampede"
	g.start_daily()
	var ducks: Array = g.items.filter(func(item): return item.kind == "duck")
	var daily = g.daily
	check(ducks.size() == daily.FAMILIES*(daily.CHICKS + 1) and not g.rival.active and daily.count == 0, "duck families fill the city")
	var family: Dictionary = daily.families[0]
	g.started = true
	for frame in 40: g.step(0.02, Vector2.ZERO)
	var line_ok := true
	var leader: Dictionary = family.mother
	for chick in family.chicks:
		line_ok = line_ok and chick.position.distance_to(leader.position) < daily.CHICK_GAP*2.5
		leader = chick
	check(line_ok, "ducklings follow their mother in a line")
	var chain: Array = []
	for i in range(family.chicks.size() - 1, -1, -1):
		var before_count: int = daily.count
		g.swallow(family.chicks[i])
		chain.append(daily.count - before_count)
	var family_count: int = daily.count
	g.swallow(family.mother)
	check(chain == [1, 2, 3, 4, 5] and daily.count - family_count == daily.FAMILY_POINTS, "a line eaten from its tail chains 1-5 and the mother then pays the family bonus %s" % [chain])
	var other: Dictionary = daily.families[1]
	family_count = daily.count
	g.swallow(other.mother)
	check(daily.count - family_count == daily.MOTHER_POINTS and other.scattered, "a mother eaten first scatters her ducklings")
	daily.count = 0
	g.started = true
	g.defense.grace = INF
	var duck: Dictionary = daily.families[2].mother
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
	# With no rewarded ad on offer (check_ad_try covers the ad), the day is over.
	var simulate: bool = g.ads.simulate
	g.ads.simulate = false
	g.on_play()
	check(g.run_kind == "campaign" and g.mode == "menu", "with no tries left the daily goes home")
	g.start_daily()
	check(g.run_kind == "campaign" and g.mode == "menu", "the daily is locked after three tries")
	g.ads.simulate = simulate
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
	check_sky_hop(g)
	check_slide_puzzle(g)
	check_siege(g)
	preload("res://scripts/classic_daily_smoke.gd").run(self, g)
	preload("res://scripts/beam_smoke.gd").run(self, g)
	check_ad_try(g)
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

# Find the cow (cow_hunt.gd): a card shows the named cow's look before the
# first move; its look is unique among the cows on show; a warm/cold radar
# tells how close it is; a wrong bite costs time and shows the card again; a
# find raises the level (a bigger herd), adds time and is kept as a checkpoint.
func check_cow_hunt(g) -> void:
	g.campaign.daily = {}
	g.campaign.checkpoints = {}
	g.daily_override = "findcow"
	g.start_daily()
	var hunt = g.daily.hunt
	var on_show := func() -> Array: return hunt.cows.filter(func(cow): return not cow.hidden and not cow.eaten)
	var herd: Array = on_show.call()
	var twins: Array = herd.filter(func(cow): return cow != hunt.star and cow.variant == hunt.star.variant)
	var city: Array = g.items.filter(func(item): return item.kind in ["car", "person", "house", "soldier", "police", "patrol_car"])
	check(g.countryside != null and city.is_empty() and hunt.level == 0 and herd.size() == hunt.HERD_START and herd.has(hunt.star) and twins.is_empty(), "the hunt starts on farmland with a small herd and one cow of its look")
	g.update_hud()
	check(not g.hud.cow_card.is_empty() and g.hud.cow_warmth < 0.0 and g.daily.dots().is_empty(), "the named cow's card shows before the first move, with no radar or minimap yet")
	g.started = true
	g.defense.grace = INF
	for frame in int(hunt.MEMO_TIME/0.02) + 5: g.step(0.02, Vector2.ZERO)
	g.update_hud()
	check(g.hud.cow_card.is_empty() and g.hud.cow_warmth >= 0.0, "the card fades and the radar takes over")
	g.hole_position = Vector3(hunt.star.position.x, 0, hunt.star.position.z) + Vector3(18, 0, 0)
	var cold: float = hunt.warmth(g)
	g.hole_position = Vector3(hunt.star.position.x, 0, hunt.star.position.z) + Vector3(1.5, 0, 0)
	check(hunt.warmth(g) > 0.9 and cold < hunt.warmth(g), "the radar warms up near the named cow")
	var decoy: Dictionary = herd.filter(func(cow): return cow != hunt.star)[0]
	var before: float = g.remaining
	# Hold the hole on the cow (drift and wind would carry it off).
	for frame in 30:
		if decoy.fall < 0 and not decoy.eaten: g.hole_position = Vector3(decoy.position.x, 0, decoy.position.z)
		g.step(0.02, Vector2.ZERO)
	check(hunt.wrong == 1 and g.remaining < before - 2.0 and not hunt.card().is_empty(), "a wrong cow costs time and shows the card again")
	check(is_equal_approx(g.target_radius, g.START_RADIUS), "the hunt's hole keeps its small size")
	var named: Dictionary = hunt.star
	before = g.remaining
	for frame in 60:
		if hunt.finds > 0: break
		if named.fall < 0: g.hole_position = Vector3(named.position.x, 0, named.position.z)
		g.step(0.02, Vector2.ZERO)
	check(hunt.finds == 1 and hunt.level == 1 and hunt.star != named and on_show.call().size() > herd.size() - 2 and g.remaining > before, "a find raises the level, brings more of the herd and adds time")
	check(g.campaign.checkpoint("findcow") == 1, "the level reached is kept")
	g.remaining = 0.01
	g.step(0.02, Vector2.ZERO)
	check(g.mode == "result" and g.hud.won and g.hud.stars == 1 and g.reward > 0, "a find wins the round")
	g.go_menu()
	g.campaign.daily = {}
	g.start_daily()
	check(hunt.level == 1 and on_show.call().size() == hunt.HERD_START + hunt.HERD_STEP, "the next run starts at the kept level")
	g.go_menu()

# Sky hop (sky_hop.gd): the clock waits for the first tap, a pilot that hops
# under each gap's middle clears the target, and one that never taps crashes
# into the street, which ends the round.
func check_sky_hop(g) -> void:
	g.campaign.daily = {}
	g.campaign.checkpoints = {}
	g.daily_override = "skyhop"
	# A bigger equipped craft still flies the hop as the default saucer.
	var craft: int = g.campaign.craft
	g.campaign.craft = 5
	g.apply_style()
	g.start_daily()
	var hop = g.daily.hop
	check(hop.craft.mesh == g.craft_meshes[0] and g.saucer.mesh != hop.craft.mesh, "the sky hop always flies the default saucer")
	g.campaign.craft = craft
	g.apply_style()
	var before: float = g.remaining
	for frame in 50: g.step(0.02, Vector2.ZERO)
	check(not hop.running and g.remaining == before, "the sky hop waits for the first tap")
	var target: int = g.daily.target()
	# The first tap starts the flight even when the first gap sits low.
	hop.flap(g)
	for frame in 6000:
		if g.mode != "playing" or hop.passed >= target: break
		# Far below a high gap it hops again before the last hop peaks.
		var below: float = hop_aim(hop) - hop.y
		if below > 0.6 and hop.vy < (4.0 if below > 2.5 else 1.0): hop.flap(g)
		g.step(0.02, Vector2.ZERO)
	check(hop.passed >= target and not hop.crashed and g.daily.count == hop.passed and g.remaining < before, "a steady pilot flies through the target's gaps (%d/%d, crashed %s, level %d)" % [hop.passed, target, hop.crashed, g.campaign.selected])
	for frame in 200:
		if g.mode != "playing": break
		g.step(0.02, Vector2.ZERO)
	check(hop.crashed and g.mode == "result" and g.hud.won and g.hud.stars >= 2 and g.reward > 0, "falling into the street ends the run and pays the gaps")
	check(g.campaign.checkpoint("skyhop") == 20, "every 10 gaps is kept as a checkpoint (%d)" % g.campaign.checkpoint("skyhop"))
	g.go_menu()
	g.update_view(0.02)
	check(not hop.visible and g.camera.current, "home hands the view back to the city camera")
	g.campaign.daily = {}
	g.start_daily()
	check(hop.first == 20 and hop.passed == 20 and hop.map_of(hop.passed).id == "desert" and g.daily.count == 0, "the next run starts at the checkpoint, on the desert map")
	check_hop_hazards(g, hop)
	g.go_menu()

# Each map's hazard catches or pushes the saucer where it should.
func check_hop_hazards(g, hop) -> void:
	var find := func(kind: String) -> int:
		for i in range(0, hop.COURSE):
			if hop.gap_at(i).hazard == kind: return i
		return -1
	var maps: Array = hop.MAPS.map(func(map): return map.hazard)
	check(maps == ["", "wind", "icicle", "beam", "gull"] and find.call("wind") >= 20 and find.call("gull") >= 80 and find.call("") == 0, "five maps of 20 gaps, each with its own hazard")
	var gust: Dictionary = hop.gap_at(find.call("wind"))
	hop.running = true
	hop.crashed = false
	hop.passed = find.call("wind")
	hop.x = gust.x - hop.SPACING*0.5
	hop.y = hop.centre(gust)
	hop.vy = 0.0
	hop.update(g, 0.02)
	check(not is_equal_approx(hop.vy, -hop.GRAVITY*0.02), "desert gusts push the saucer up or down")
	var ice: Dictionary = hop.gap_at(find.call("icicle"))
	hop.passed = find.call("icicle")
	hop.x = ice.x - 2.0
	hop.y = hop.centre(ice)
	for frame in 15: hop.update(g, 0.02)
	check(float(ice.drop) > 0.5, "an icicle drops into the gap ahead")
	var light: Dictionary = hop.gap_at(find.call("beam"))
	var ends: Array = hop.beam_ends(light)
	hop.x = ends[1].x
	hop.y = ends[1].y
	check(hop.hazard_hits(light), "the searchlight's beam catches the saucer")
	var gull: Dictionary = hop.gap_at(find.call("gull"))
	var bird: Vector2 = hop.gull_at(gull)
	hop.x = bird.x
	hop.y = bird.y
	check(hop.hazard_hits(gull) and not hop.hazard_hits(gust), "a gull catches the saucer; a plain gap has nothing to hit")

# Slide puzzle (slide_puzzle.gd): today's 30-board ladder is seeded, gets
# harder and every board is solvable in its tier's par range; each board has
# its own clock that costs a life when it runs out; undo and reset are free;
# the solver's path climbs the whole ladder for three stars.
func check_slide_puzzle(g) -> void:
	g.campaign.daily = {}
	g.campaign.checkpoints = {}
	g.daily_override = "slide"
	g.start_daily()
	var puzzle = g.daily.puzzle
	var path: Array = puzzle.solution()
	check(g.slide_puzzle() and puzzle.board == 0 and puzzle.boards.size() == 1 and puzzle.par == path.size(), "the ladder opens on its first board, made on its own")
	check(is_equal_approx(g.remaining, puzzle.board_seconds()) and puzzle.lives == puzzle.LIVES, "the board's own clock is set and every life is there")
	var twin = load("res://scripts/slide_puzzle.gd").new()
	twin.generate(puzzle.seed_value)
	var started := Time.get_ticks_msec()
	twin.layout_of(puzzle.BOARD_COUNT - 1)
	var made_in := Time.get_ticks_msec() - started
	var pars: Array = twin.boards.map(func(entry): return int(entry.get("par", 0)))
	var misses: Array = []
	for i in pars.size():
		var bounds: Array = puzzle.tier_of(i).par
		if pars[i] < int(bounds[0]) or pars[i] > int(bounds[1]): misses.append([i + 1, pars[i]])
	print("SLIDE pars %s (made in %d ms)" % [pars, made_in])
	check(pars.size() == puzzle.BOARD_COUNT and misses.is_empty() and pars[0] < pars[-1], "all 30 boards land in their tier's par range %s" % [misses])
	check(twin.boards[0].walls == puzzle.walls and twin.boards[0].start == puzzle.start and int(twin.boards[0].par) == puzzle.par, "the same day builds the same boards")
	twin.free()
	var before: float = g.remaining
	for frame in 30: g.step(0.02, Vector2.ZERO)
	check(g.remaining == before and puzzle.moves == 0, "the puzzle clock waits for the first slide")
	g.slide(path[0])
	check(puzzle.moves == 1 and puzzle.cell != puzzle.start, "a swipe slides the hole")
	puzzle.undo()
	check(puzzle.moves == 0 and puzzle.cell == puzzle.start and puzzle.mask == 0, "undo gives the slide back")
	var blocked := false
	for dir in puzzle.DIRS:
		if puzzle.slide(puzzle.cell, puzzle.mask, dir)[0] == puzzle.cell:
			blocked = not g.daily.puzzle.move(g, dir) and puzzle.moves == 0
			break
	check(blocked or puzzle.DIRS.all(func(dir): return puzzle.slide(puzzle.start, 0, dir)[0] != puzzle.start), "a slide that cannot move is not a move")
	g.slide(path[0])
	g.remaining = 0.01
	g.step(0.02, Vector2.ZERO)
	check(g.mode == "playing" and puzzle.lives == puzzle.LIVES - 1 and puzzle.moves == 0 and is_equal_approx(g.remaining, puzzle.board_seconds()), "running out of time costs a life and restarts the board")
	var climbed := true
	for i in puzzle.BOARD_COUNT:
		climbed = climbed and puzzle.board == i and not puzzle.solved
		for dir in puzzle.solution(): g.slide(dir)
		climbed = climbed and puzzle.solved and puzzle.moves == puzzle.par and puzzle.cleared == i + 1
		for frame in 200:
			if g.mode != "playing" or puzzle.board != i: break
			g.step(0.02, Vector2.ZERO)
	check(climbed and puzzle.cleared == puzzle.BOARD_COUNT, "the solver's path clears every board in par, one after another")
	check(g.mode == "result" and g.hud.won and g.hud.stars == 3 and puzzle.in_par == puzzle.BOARD_COUNT and g.reward > 0, "the whole ladder wins three stars")
	check(g.campaign.lap("slide") == 1 and g.campaign.checkpoint("slide") == 0, "finishing the ladder starts a new lap")
	g.go_menu()
	g.campaign.reach_checkpoint("slide", 4, puzzle.BOARD_COUNT)
	g.campaign.daily = {}
	g.start_daily()
	check(puzzle.board == 4 and puzzle.first_board == 4 and puzzle.seed_value == puzzle.ladder_seed(1), "a run starts at the kept board of the current lap")
	g.campaign.checkpoints = {}
	g.go_menu()
	g.campaign.daily = {}
	g.start_daily()
	for i in puzzle.LIVES:
		g.slide(puzzle.solution()[0])
		g.remaining = 0.01
		g.step(0.02, Vector2.ZERO)
	check(g.mode == "result" and not g.hud.won and puzzle.lives == 0, "the last life lost ends the run")
	g.go_menu()
	g.update_view(0.02)
	check(not puzzle.visible and g.camera.current, "home hands the view back from the puzzle board")

# Sky siege (sky_siege.gd): the saucer fires on its own, the beam turns a
# helicopter into an escort, and three hits end the run.
func check_siege(g) -> void:
	g.campaign.daily = {}
	g.campaign.checkpoints = {}
	g.daily_override = "siege"
	g.start_daily()
	var siege = g.daily.siege
	check(g.siege() and siege.lives == siege.LIVES and siege.foes.is_empty(), "the siege starts with full lives and an empty sky")
	var before: float = g.remaining
	for frame in 30: g.step(0.02, Vector2.ZERO)
	check(g.remaining == before and siege.foes.is_empty(), "the siege waits for the first move")
	g.started = true
	var player: Vector3 = g.hole_position
	siege.spawn_timer = 99.0
	siege.add_foe(g, "heli", player)
	var heli: Dictionary = siege.foes[0]
	heli.pos = player + Vector3(5, 0, 0)
	heli.timer = 99.0
	for frame in 100:
		if siege.foes.is_empty(): break
		heli.timer = 99.0
		g.step(0.02, Vector2.ZERO)
	check(siege.downed == 1 and siege.count == 1 and g.score > 0, "auto-fire downs a helicopter in range")
	siege.add_foe(g, "heli", player)
	var prey: Dictionary = siege.foes[0]
	prey.pos = g.hole_position + Vector3(2.0, 0, 0)
	prey.timer = 99.0
	prey.hp = 99
	for frame in 60:
		if not siege.escort.is_empty(): break
		prey.timer = 99.0
		g.step(0.02, Vector2.ZERO)
	check(not siege.escort.is_empty() and siege.count == 2 and siege.foes.is_empty(), "holding still beside a helicopter captures it as an escort")
	for i in 3:
		siege.grace = 0.0
		siege.hit(g)
	check(siege.lives == 0 and siege.done(), "three hits end the siege")
	siege.lives = 1
	siege.stage_points = siege.stage_goal()
	g.step(0.02, Vector2.ZERO)
	check(siege.stage == 1 and siege.lives == 2 and siege.stages_cleared() == 1 and g.campaign.checkpoint("siege") == 1, "a stage's goal opens the next stage, gives a life back and is kept")
	siege.stage_points = siege.stage_goal()
	g.step(0.02, Vector2.ZERO)
	var blimps: Array = siege.foes.filter(func(foe): return foe.kind == "blimp")
	check(siege.stage == 2 and siege.stage_goal() == 0 and blimps.size() == 1, "the last stage brings the command blimp")
	siege.damage(g, blimps[0], 999)
	check(siege.won() and siege.stages_cleared() == 3, "downing the blimp clears the last stage")
	g.step(0.02, Vector2.ZERO)
	check(g.mode == "result" and g.hud.won and g.reward > 0 and g.hud.stars == 3, "all three stages win three stars and pay out")
	check(g.campaign.lap("siege") == 1 and g.campaign.checkpoint("siege") == 0, "downing the blimp finishes the lap")
	g.go_menu()
	g.campaign.reach_checkpoint("siege", 2, 3)
	g.campaign.daily = {}
	g.start_daily()
	g.started = true
	g.step(0.02, Vector2.ZERO)
	check(siege.stage == 2 and siege.first_stage == 2 and siege.foes.any(func(foe): return foe.kind == "blimp"), "a run starts at the kept stage, its blimp and all")
	g.campaign.checkpoints = {}
	g.go_menu()
	g.update_view(0.02)
	check(not siege.visible, "home hides the siege's planes")

# Out of daily tries, a rewarded ad (simulated in debug builds) buys one more,
# up to Campaign.DAILY_AD_TRIES a day.
func check_ad_try(g) -> void:
	var date := Campaign.today()
	g.campaign.daily = {}
	g.daily_override = "stampede"
	for i in Campaign.DAILY_ATTEMPTS: g.campaign.use_daily_attempt(date)
	g.update_hud()
	check(g.campaign.daily_attempts_left(date) == 0 and g.hud.daily_ad and not g.hud.daily_button.disabled, "with no tries left the daily button offers an ad")
	g.start_daily()
	check(g.run_kind == "daily" and g.mode == "playing" and int(g.campaign.daily.bonus) == 1 and g.campaign.daily_attempts_left(date) == 0, "the ad adds a try and starts the game")
	g.go_menu()
	g.campaign.add_daily_try(date)
	check(not g.campaign.can_add_daily_try(date) and not g.campaign.add_daily_try(date), "ads add at most %d tries a day" % Campaign.DAILY_AD_TRIES)
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(g.campaign.data())))
	check(int(restored.daily.bonus) == Campaign.DAILY_AD_TRIES and restored.daily_attempts_left(date) == 1, "ad tries survive a save")
	g.campaign.record_daily(date, 10, false)
	check(int(g.campaign.daily.bonus) == Campaign.DAILY_AD_TRIES, "a finished run keeps the ad tries")
	g.campaign.daily = {}
	check_daily_swap(g)

# Swapping the day's game (game.gd watch_for_swap): once a day for a rewarded
# ad, from the menu or a daily result, to the day's other game, keeping tries.
func check_daily_swap(g) -> void:
	var date := Campaign.today()
	var override: String = g.daily_override
	g.daily_override = ""
	g.campaign.daily = {}
	g.go_menu()
	g.campaign.use_daily_attempt(date)
	g.update_hud()
	var first := Campaign.daily_type(date)
	check(g.hud.daily_swap and g.hud.swap_button.visible and Campaign.swap_type(date) != first and Campaign.swap_type(date) == Campaign.swap_type(date), "the menu offers to swap today's game for an ad, to a fixed other game")
	g.watch_for_swap()
	check(g.run_kind == "daily" and g.mode == "playing" and g.daily_kind == Campaign.swap_type(date), "the ad swaps today's game and starts the new one")
	check(int(g.campaign.daily.attempts) == 2 and g.campaign.daily_attempts_left(date) == 1, "the swap keeps the tries already used (1 + 1 for the new game)")
	# Some games run their own clock (sky hop, slide): end the round directly.
	g.finish(false)
	g.update_hud()
	check(g.mode == "result" and not g.hud.daily_swap and not g.hud.swap_button.visible, "one swap a day: the result offers no second one")
	var restored = Campaign.new()
	restored.restore(JSON.parse_string(JSON.stringify(g.campaign.data())))
	check(str(restored.daily_record(date).type) == Campaign.swap_type(date) and not restored.can_swap_daily(date), "the swapped game survives a save")
	g.go_menu()
	g.campaign.daily = {}
	g.launch_daily()
	g.finish(false)
	g.update_hud()
	check(g.mode == "result" and g.hud.swap_button.visible and g.hud.swap_button.text == I18n.t("ad_daily_swap"), "a daily result offers the swap while tries are left")
	g.go_menu()
	g.campaign.daily = {}
	g.daily_override = override

# Where the test pilot aims: a little under the next gap's centre as it will
# be when the craft gets there (swaying gaps move meanwhile).
func hop_aim(hop) -> float:
	var gap: Dictionary = hop.gap_at(hop.passed)
	var ahead := maxf(0.0, (float(gap.x) - hop.x)/hop.SPEED)
	var sway: float = sin((hop.clock + ahead)*1.6 + float(gap.phase))*hop.SWAY if gap.sway else 0.0
	return float(gap.y) + sway - 0.3

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

# Conquest album: counts follow the save, locked cities stay silhouettes until
# test mode reveals them, every landmark has its render, and the cards fit the
# screen in portrait and landscape.
func check_album(g) -> void:
	var Album = preload("res://scripts/album.gd")
	var campaign = g.campaign
	var saved := {"goals":campaign.goals.duplicate(), "medals":campaign.medals.duplicate(), "unlocked":campaign.unlocked,
		"unlock":campaign.unlock_all_for_testing}
	campaign.goals.fill(0)
	campaign.medals.fill(0)
	campaign.unlocked = 2
	campaign.unlock_all_for_testing = false
	campaign.goals[0] = 7
	campaign.goals[1] = 1
	var tet := Campaign.regular_count()
	campaign.goals[tet] = 3
	check(campaign.is_conquered(0) and campaign.is_conquered(1) and campaign.is_conquered(tet) and not campaign.is_conquered(2) and not campaign.is_conquered(8),
		"album counts a city conquered once its landmark falls (festival cities too)")
	check(Album.region_count(campaign, 0) == Vector2i(3, Campaign.route(0).size()) and Album.region_count(campaign, 1) == Vector2i(0, Campaign.route(1).size()),
		"album counts conquered stops per continent, festival cities included")
	var missing: Array = []
	for i in Campaign.level_count():
		var boss: String = Campaign.level_info(i).boss
		if not ResourceLoader.exists(Album.THUMB % boss): missing.append(boss)
	check(missing.is_empty(), "every landmark has an album render (tools/bake_landmark_thumbs.gd) %s" % [missing])
	g.go_menu()
	g.hud.album_requested.emit()
	var album = g.wardrobe.album
	check(g.wardrobe.visible and album.visible and g.wardrobe.tab == "album" and not g.hud.visible, "menu album button opens the album over the menu")
	check(album.cards.size() == Campaign.route(album.region).size(), "album page lists every stop of the continent")
	check(not Album.revealed(campaign, 2) and Album.revealed(campaign, 0), "a city not yet taken shows as a locked silhouette")
	album.pick(5)
	check(album.region == 5 and album.cards.size() == Campaign.route(5).size() and album.tabs[5].text.ends_with("0/%d" % Campaign.route(5).size()),
		"album tabs switch continent and show its progress")
	album.pick(0)
	album.tap_card(2)
	check(not g.intro.visible, "a locked card opens nothing")
	album.tap_card(0)
	check(g.intro.visible and g.intro.pages[0].has("picture"), "a conquered card opens its landmark card with the render")
	g.intro.close()
	campaign.unlock_all_for_testing = true
	check(Album.revealed(campaign, 47) and Album.region_count(campaign, 5).x == 0, "test mode reveals every card but keeps the real count")
	for screen in [Vector2(960, 2058), Vector2(960, 1600), Vector2(960, 540), Vector2(1158, 540)]:
		g.wardrobe.size = screen
		album.layout()
		var shown: Vector2 = album.size*album.scale
		check(shown.is_equal_approx(screen) and (screen.x > screen.y or album.size.x == album.PORTRAIT_WIDTH), "album covers a %dx%d screen (portrait laid out %d wide)" % [screen.x, screen.y, album.size.x])
		var fits := true
		for region in Campaign.REGIONS.size():
			album.region = region
			album.layout()
			var tabs_end: float = album.tab_rect(Campaign.REGIONS.size()-1).end.y
			for card in album.cards:
				fits = fits and Rect2(Vector2.ZERO, album.size).encloses(card.rect) and card.rect.position.y > tabs_end and card.rect.size.y >= 120
		check(fits, "album cards fit a %dx%d screen below the tabs" % [screen.x, screen.y])
	g.wardrobe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.close_panel()
	check(not album.visible and not g.get_viewport().disable_3d and g.mode == "menu", "closing the album returns to the menu")
	campaign.goals = saved.goals
	campaign.medals = saved.medals
	campaign.unlocked = saved.unlocked
	campaign.unlock_all_for_testing = saved.unlock

# Test mode: the daily button opens the list of every mini-game, and each row
# starts that game (AUTO plays today's); outside test mode it starts at once.
func check_daily_picker(g) -> void:
	var Picker = preload("res://scripts/daily_picker.gd")
	var saved := {"daily":g.campaign.daily.duplicate(), "coins":g.campaign.coins}
	g.campaign.test_mode = true
	g.go_menu()
	g.hud.daily_requested.emit()
	var picker = g.daily_picker
	check(picker.visible and g.mode == "menu" and picker.rows.size() == Campaign.DAILY_TYPES.size() + 1, "test-mode daily button lists AUTO and every mini-game")
	var fits := true
	for screen in [Vector2(960, 540), Vector2(1158, 540), Vector2(960, 2058)]:
		picker.size = screen
		picker.layout()
		for i in picker.rows.size():
			fits = fits and Rect2(Vector2.ZERO, screen).encloses(picker.row_rect(i).grow_individual(0, 0, 0, Picker.GOAL_H))
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	check(fits, "the daily list fits landscape and portrait screens")
	var started := true
	for type in Picker.choices():
		g.go_menu()
		g.hud.daily_requested.emit()
		picker.rows[Picker.choices().find(type)].pressed.emit()
		var expected: String = type if type != "" else Campaign.daily_type(Campaign.today())
		started = started and not picker.visible and g.run_kind == "daily" and g.daily_kind == expected and g.mode == "playing"
	check(started, "each row of the daily list starts its mini-game")
	g.go_menu()
	g.daily_picker.hide()
	g.campaign.test_mode = false
	g.daily_override = ""
	# Test-mode plays still count tries, so start the real check on a fresh day.
	g.campaign.daily = {}
	g.hud.daily_requested.emit()
	check(not picker.visible and g.run_kind == "daily" and g.mode == "playing", "outside test mode the daily button starts today's game at once")
	g.go_menu()
	g.campaign.daily = saved.daily
	g.campaign.coins = saved.coins
