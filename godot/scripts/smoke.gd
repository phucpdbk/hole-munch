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
	check_duck()
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=0.01
	g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and not g.hud.won,"timeout ends the round")
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true; g.remaining=0.1
	var boss: Dictionary = g.items[g.boss_index]
	g.target_radius = g.boss_radius/g.EAT_RATIO+0.1; g.radius = g.target_radius
	g.hole_position = Vector3(boss.position.x,0,boss.position.z)
	for i in range(60): g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and g.hud.won,"catching the boss in the final second still wins")
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
	check(g.stars(true)==2 and g.stars(false)==0,"stars follow completion")

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

# A deterministic greedy route verifies the growth ladder is completable while
# food moves. The hole chases each target, paying estimated travel time.
func check_growth_route() -> void:
	g.reset_round()
	g.playing=true; g.mode="playing"; g.started=true
	for iteration in range(2500):
		if not g.playing: break
		var nearest: Dictionary = {}
		var distance := INF
		for item in g.items:
			if not Traffic.is_active(item) or item.radius>g.radius*g.EAT_RATIO: continue
			var d: float = item.position.distance_to(g.hole_position)
			if d<distance: distance=d; nearest=item
		# Like a player, head straight for the boss once it fits.
		var boss: Dictionary = g.items[g.boss_index]
		if Traffic.is_active(boss) and boss.radius <= g.radius*g.EAT_RATIO:
			nearest = boss
			distance = boss.position.distance_to(g.hole_position)
		if nearest.is_empty():
			g.step(0.02,Vector2.ZERO)
			continue
		g.remaining -= distance/(5.8+minf(g.radius,4.0)*0.45)
		for frame in range(40):
			if nearest.fall>=0 or not g.playing: break
			g.hole_position = Vector3(nearest.position.x,0,nearest.position.z)
			g.step(0.02,Vector2.ZERO)
	check(g.mode=="result" and g.hud.won,"growth route reaches and swallows the boss within the timer")
