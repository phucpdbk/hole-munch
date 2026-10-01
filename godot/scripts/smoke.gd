extends RefCounted

# Headless gameplay checks: run with `--headless --path . -- --smoke`. They drive the
# game directly and never write the player save.
const Traffic = preload("res://scripts/traffic.gd")
const DuckBoss = preload("res://scripts/duck_boss.gd")
var g
var failures := 0

func check(value: bool, description: String) -> void:
	if value:
		print("PASS: "+description)
	else:
		failures += 1
		push_error("FAIL: "+description)

func run(game) -> void:
	g = game
	g.on_play()
	var full_time = g.remaining
	check(g.items.size()>150,"city contains a complete snack ladder")
	check(g.batches.size()<=26,"repeated toys share a bounded number of batches")
	var touch := InputEventScreenTouch.new()
	touch.index=0; touch.position=Vector2(120,400); touch.pressed=true
	g._unhandled_input(touch)
	var drag = InputEventScreenDrag.new()
	drag.index=0; drag.position=Vector2(175,400)
	g._unhandled_input(drag)
	check(g.move_direction().x>0.9,"touch drag produces movement")
	touch.pressed=false
	g._unhandled_input(touch)
	check(g.move_direction()==Vector2.ZERO and not g.dragging,"touch release stops movement")
	g.step(1.0,Vector2.ZERO)
	check(g.remaining==full_time,"timer waits for first movement")
	g.step(0.02,Vector2.RIGHT)
	check(g.remaining<full_time,"movement starts the round")
	var snack: Dictionary = g.items.filter(func(item): return item.kind=="cone")[0]
	g.hole_position = snack.position
	g.step(0.02,Vector2.ZERO)
	check(snack.fall>=0,"small objects begin falling")
	for i in range(35): g.step(0.02,Vector2.ZERO)
	check(snack.eaten and g.target_radius>g.START_RADIUS,"swallowing grows the hole")
	var old_score = g.score
	for i in range(35): g.step(0.02,Vector2.ZERO)
	check(g.score==old_score,"eaten objects cannot score twice")
	g.toggle_pause()
	var time_before = g.remaining
	var parked: Vector3 = moving("car")[0].position
	g._process(0.2)
	check(g.remaining==time_before and moving("car")[0].position==parked,"pause freezes simulation and traffic")
	g.on_play()
	check(g.remaining==time_before,"resume keeps the current round")
	g.reset_round()
	check(g.score==0 and g.eaten==0 and not snack.eaten,"retry restores all objects")
	check_traffic()
	check_walkers()
	check_combo()
	check_growth_route()
	# Defence units (not landmarks) flee and drop minions.
	g.load_level(1)
	# Every campaign objective is now a landmark; the duck check only applies to military bosses.
	if not g.is_landmark(): check_duck()
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=0.01
	g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and not g.hud.won,"timeout ends the round")
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=0.1
	var boss: Dictionary = g.items[g.boss_index]
	boss.shielded = false
	g.target_radius = g.boss_radius/g.EAT_RATIO+0.1; g.radius = g.target_radius
	g.hole_position = Vector3(boss.position.x,0,boss.position.z)
	for i in range(60): g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and g.hud.won,"catching the boss in the final second still wins")
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=30.0
	boss.shielded = false
	g.target_radius = g.boss_radius/g.EAT_RATIO+0.1; g.radius = g.target_radius
	g.hole_position = Vector3(boss.position.x,0,boss.position.z)
	for i in range(60): g.step(0.02,Vector2.ZERO)
	check(g.boss_down and g.mode=="playing","eating the boss keeps the round running")
	for item in g.items:
		if not item.get("bonus",false) and not item.get("is_boss",false) and not item.eaten and item.fall < 0: g.swallow(item)
	for i in range(60): g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and g.hud.won and g.remaining > 20,"clearing the map ends the round early")
	check_mechanics()
	check_ads()
	check_updates()
	if failures > 0:
		push_error("%d GODOT CHECKS FAILED" % failures)
		g.get_tree().quit(1)
	else:
		print("ALL GODOT CHECKS PASSED")
		g.get_tree().quit()

func moving(kind: String) -> Array:
	return g.items.filter(func(item): return item.get("move","")==kind)

func cars_overlap(a: Dictionary, b: Dictionary) -> bool:
	var a_half := Vector2(0.75,0.385) if a.axis=="h" else Vector2(0.385,0.75)
	var b_half := Vector2(0.75,0.385) if b.axis=="h" else Vector2(0.385,0.75)
	return absf(a.position.x-b.position.x) < a_half.x+b_half.x-0.05 and absf(a.position.z-b.position.z) < a_half.y+b_half.y-0.05

func check_traffic() -> void:
	g.reset_round()
	var cars := moving("car")
	check(cars.size()>=12,"inner roads carry two-way traffic")
	var car: Dictionary = cars[0]
	var lateral: float = car.lateral
	var before: Vector3 = car.position
	g.animate_world(0.5)
	check(car.position.distance_to(before)>0.5,"cars drive along their lane")
	check(is_equal_approx(car.position.z if car.axis=="h" else car.position.x, lateral),"cars keep their lane")
	var heading := Vector3(car.direction,0,0) if car.axis=="h" else Vector3(0,0,car.direction)
	check((Basis.from_euler(Vector3(0,car.yaw,0))*Vector3.RIGHT).dot(heading)>0.99,"cars face their travel direction")
	var travelled := {}
	var crashes := 0
	var stops := 0
	for frame in range(3000):
		var previous: Array = cars.map(func(c): return c.along)
		g.animate_world(0.02)
		for i in cars.size():
			var moved := absf(wrapf(cars[i].along-previous[i],-cars[i].wrap,cars[i].wrap))
			travelled[i] = travelled.get(i,0.0)+moved
			if moved==0.0: stops += 1
		if frame%5==0:
			for i in cars.size():
				for j in range(i+1,cars.size()):
					if cars_overlap(cars[i],cars[j]): crashes += 1
	check(crashes==0,"signals and queues keep cars from overlapping")
	check(stops>0,"cars stop at red lights and queues")
	check(travelled.values().all(func(d): return d>20.0),"no car stays stuck in traffic")
	check(cars.all(func(c): return absf(c.along)<=c.wrap),"cars wrap around the map edge")

func check_walkers() -> void:
	g.reset_round()
	var walkers := moving("walk").filter(func(w): return not w.get("hidden",false))
	var starts: Array = walkers.map(func(w): return w.position)
	var farthest: Array = walkers.map(func(_w): return 0.0)
	var strays := 0
	for frame in range(500):
		g.animate_world(0.02)
		for i in walkers.size():
			var w: Dictionary = walkers[i]
			farthest[i] = maxf(farthest[i], w.position.distance_to(starts[i]))
			var offset: Vector3 = w.position-w.home
			if absf(offset.x)>w.amplitude.x+0.01 or absf(offset.z)>w.amplitude.y+0.01: strays += 1
	check(strays==0,"pedestrians stay near their sidewalk")
	check(farthest.all(func(d): return d>0.1),"every pedestrian walks")

func check_combo() -> void:
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true
	var cones = g.items.filter(func(item): return item.kind=="cone")
	for i in range(9):
		g.hole_position = Vector3(cones[i].position.x,0,cones[i].position.z)
		g.step(0.05,Vector2.ZERO)
	check(g.combo>=8 and g.combo_multiplier(g.combo)==1.5,"quick bites build a 1.5x combo")
	var cone_points = g.base_points(cones[0])
	check(g.score>cone_points*g.combo,"combo multiplies score")
	g.hole_position = Vector3(0,0,20)
	for i in range(30): g.step(0.05,Vector2.ZERO)
	check(g.combo==0 and g.best_combo>=8,"combo resets after one second without a bite")
	var eaten_cones: int = cones.filter(func(c): return c.fall>=0).size()
	check(g.eaten_points==cone_points*eaten_cones and g.eaten==eaten_cones,"completion uses original points")
	g.eaten_points = int(g.total_points*0.8)
	var goals := [{"id":"win"},{"id":"clean","value":0.75},{"id":"spotless","value":0.9}]
	var run := {"won":true,"completion":g.completion(),"best_combo":0,"remaining":0,"hits":0,"defenders_eaten":0,"rival_eaten":false}
	check(g.Challenges.evaluate(goals,run)==3 and g.Challenges.evaluate(goals,{"won":false,"completion":1.0})==0,"goal stars follow completion and need a win")

func check_duck() -> void:
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true
	var boss: Dictionary = g.items[g.boss_index]
	g.hole_position = boss.origin+Vector3(0,0,4.8)
	g.hole_position.y = 0
	for i in range(int(DuckBoss.FIRST_REST/0.05)+2): g.step(0.05,Vector2.ZERO)
	check(g.duck.phase=="dash" and boss.position.z<boss.origin.z,"defence boss sprints away from the hole")
	check(g.duck.drops==1 and not g.minions[0].hidden,"defence boss drops a minion")
	var duckling: Dictionary = g.minions[0]
	var points_before = g.eaten_points
	g.hole_position = Vector3(duckling.position.x,0,duckling.position.z)
	g.step(0.02,Vector2.ZERO)
	check(duckling.fall>=0 and g.eaten_points==points_before,"minions are bonus food")
	g.hole_position = boss.origin+Vector3(0,0,4.8)
	g.hole_position.y = 0
	for i in range(1200): g.step(0.05,Vector2.ZERO)
	check(g.duck.drops==DuckBoss.MAX_DROPS,"defence boss drops at most eight minions")
	var offset: Vector3 = boss.position-boss.origin
	check(absf(offset.x)<=DuckBoss.ARENA+0.001 and absf(offset.z)<=DuckBoss.ARENA+0.001,"defence boss stays in the plaza")

# A deterministic real-time route verifies the growth ladder is completable while
# food moves: the hole steers at player speed toward the best food per distance
# (the same choice the rival makes). Its duration is the level's par time.
const ROUTE_STEP := 0.05
const ROUTE_LIMIT := 300.0
var route_seconds := 0.0

func check_growth_route() -> void:
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true
	# Par measures pure eating time: no shots and no rival.
	g.defense.grace = INF
	g.rival.active = false
	# Measure the true par without the clock ending it, then compare with the timer.
	var timer: float = g.remaining
	g.remaining = ROUTE_LIMIT
	route_seconds = 0.0
	var boss: Dictionary = g.items[g.boss_index]
	while g.playing and not g.boss_down and route_seconds < ROUTE_LIMIT:
		var target: Dictionary = g.Rival.best_target(g.items, boss, g.hole_position, g.radius)
		if not target.is_empty():
			var offset := Vector3(target.position.x-g.hole_position.x, 0, target.position.z-g.hole_position.z)
			var speed: float = (5.8+minf(g.radius,4.0)*0.45)*float(g.stats.speed)
			g.hole_position += offset.limit_length(speed*ROUTE_STEP)
		g.step(ROUTE_STEP,Vector2.ZERO)
		route_seconds += ROUTE_STEP
	g.remaining = timer - route_seconds
	check(g.boss_down and g.remaining > 0,"growth route reaches and swallows the boss within the timer")

# Rewarded-ad rescue and coin doubling, plus the interstitial pacing (scripts/ads.gd).
func check_ads() -> void:
	var ads = g.ads
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=0.01
	g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and not g.hud.won, "a small hole that runs out of time gets no revive offer")
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=0.01
	var start: float = g.stats.start_radius
	g.radius = start + 0.8*(g.boss_radius/g.EAT_RATIO - start)
	g.target_radius = g.radius
	g.hole_position = Vector3(0, 0, 30)
	g.step(0.02,Vector2.ZERO)
	check(g.mode=="revive" and not g.playing, "running out of time near the landmark offers a revive")
	g.accept_revive()
	check(g.mode=="playing" and g.revive_used and absf(g.remaining-ads.REVIVE_SECONDS) < 0.1, "watching the ad adds %d seconds" % int(ads.REVIVE_SECONDS))
	g.remaining = 0.01
	g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and not g.hud.won, "the revive is offered only once per round")
	g.reward = 10
	var coins: int = g.campaign.coins
	check(g.can_double(), "a result with coins offers doubling")
	g.double_reward()
	check(g.campaign.coins == coins+10 and g.reward == 20 and not g.can_double(), "doubling pays once")
	ads.round_ends = ads.INTERSTITIAL_EVERY
	var later: int = Time.get_ticks_msec() + ads.REWARDED_QUIET_MS + ads.INTERSTITIAL_GAP_MS
	check(not ads.interstitial_due(0, later) and not ads.interstitial_due(ads.INTERSTITIAL_FROM_LEVEL, Time.get_ticks_msec()), "no interstitial in early cities or right after a rewarded ad")
	check(ads.interstitial_due(ads.INTERSTITIAL_FROM_LEVEL, later), "interstitial allowed after several rounds")
	g.go_menu()

# version.json parsing (scripts/update_check.gd): only newer builds with safe links.
func check_updates() -> void:
	var U = g.UpdateCheck
	var newer: Dictionary = U.parse('{"version_code": 13, "version_name": "0.6", "url": "https://example.org/a.apk"}', 12)
	check(newer.code == 13 and newer.url.begins_with("https://"), "a newer build is offered")
	check(U.parse('{"version_code": 12, "url": "https://example.org"}', 12).is_empty(), "the same build is not offered")
	check(U.parse('{"version_code": 99, "url": "javascript:alert(1)"}', 12).is_empty() and U.parse('not json', 12).is_empty() \
		and U.parse('{"version_code": "13", "url": "https://x"}', 12).is_empty(), "bad or unsafe version files are ignored")
	check(U.current_code() > 0, "the build code is set in project settings")

# Shield pylons, bombs, hunger and pickups (scripts/mechanics.gd).
func check_mechanics() -> void:
	g.load_level(0)
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=60.0
	g.defense.grace = INF
	g.rival.active = false
	var mech = g.mechanics
	var boss: Dictionary = g.items[g.boss_index]
	check(mech.pylons.size() == mech.PYLONS and boss.shielded, "landmark starts behind %d shield pylons" % mech.PYLONS)
	g.target_radius = g.boss_radius/g.EAT_RATIO+0.2; g.radius = g.target_radius
	g.hole_position = Vector3(boss.position.x,0,boss.position.z)
	for i in 10: g.step(0.02,Vector2.ZERO)
	check(boss.fall < 0 and not boss.eaten, "shielded landmark cannot be swallowed")
	for pylon in mech.pylons: g.swallow(pylon)
	for i in 40: g.step(0.02,Vector2.ZERO)
	check(not boss.shielded and (boss.fall >= 0 or boss.eaten), "breaking every pylon drops the shield")
	var bombs: Array = g.items.filter(func(item): return item.get("bomb", false))
	check(bombs.size() == mech.BOMBS and bombs.all(func(item): return item.optional), "every map hides optional bombs")
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=60.0
	g.defense.grace = INF
	var before: float = g.remaining
	g.swallow(bombs[0])
	check(mech.stun > 0 and g.remaining == before-mech.BOMB_SECONDS and mech.speed_multiplier() == 0.0, "a small hole is stunned by a bomb")
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=60.0
	g.target_radius = 2.6; g.radius = 2.6
	var eaten_before: int = g.eaten
	g.swallow(bombs[1])
	check(mech.stun == 0.0 and g.eaten > eaten_before+1, "a big hole turns a bomb blast into food")
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=60.0
	g.target_radius = 2.0; g.radius = 2.0
	g.hole_position = Vector3(0, 0, 30)
	mech.hunger = mech.HUNGER_DELAY + 0.1
	mech.update_hunger(g, 1.0)
	check(mech.hungry and g.target_radius < 2.0, "a starving hole shrinks")
	mech.update_hunger(g, 60.0)
	check(is_equal_approx(g.target_radius, 2.0*mech.HUNGER_KEEP), "starving stops at a share of the round's best size")
	mech.fed()
	mech.update_hunger(g, 0.1)
	check(not mech.hungry, "a bite ends hunger")
	mech.spawn_pickup(g)
	var kind: String = mech.pickup.kind
	before = g.remaining
	g.hole_position = mech.pickup.position
	mech.update_pickup(g, 0.02)
	check(mech.pickup.is_empty() and (kind != "time" or g.remaining == before+mech.TIME_PICKUP), "touching a pickup collects it (%s)" % kind)
	var kinds := {}
	for i in 40:
		mech.spawn_pickup(g)
		kinds[mech.pickup.kind] = true
		mech.clear_pickup()
	check(g.run_kind == "campaign" and not kinds.has("time") and kinds.size() >= 2, "campaign pickups never add time")
	before = g.remaining
	g.combo = 7
	var food: Dictionary = g.items.filter(func(item): return not item.eaten and not item.get("is_boss", false) and not item.get("bomb", false))[0]
	g.swallow(food)
	check(g.combo == 8 and g.remaining == before, "campaign combos never add time")
	mech.weather = "wind"
	var drift: Vector3 = mech.steer(Vector3.ZERO, 0.02, 0.0)
	for i in 200: drift = mech.steer(Vector3.ZERO, 0.02, 0.0)
	check(drift.length() <= mech.WIND_PUSH + 0.01, "wind drift stays bounded")
