extends RefCounted
# Checks for the classic-game dailies (snake, mole, red light), run from
# campaign_smoke.gd check_daily_games; `smoke` is that runner (its check()).
const Campaign = preload("res://scripts/campaign.gd")

static func run(smoke, g) -> void:
	check_snake(smoke, g)
	check_mole(smoke, g)
	check_red_light(smoke, g)

static func begin(g, type: String) -> void:
	g.campaign.daily = {}
	g.daily_override = type
	g.start_daily()
	g.defense.grace = INF

# Saucer snake (snake_trail.gd): fruit on the roads, a tail that grows by one
# orb a fruit and follows the hole's path, a saucer that keeps gliding, and a
# bite into the tail that ends the run.
static func check_snake(smoke, g) -> void:
	begin(g, "snake")
	var snake = g.daily.snake
	var limit: float = Campaign.START_RADIUS*g.EAT_RATIO
	smoke.check(g.mode == "playing" and snake.fruits.size() == snake.FRUITS and snake.fruits.all(func(f): return not f.hidden and f.radius < limit), "the snake starts with fruit on the roads, each fits the hole")
	g.step(0.02, Vector2(1, 0))
	var from: Vector3 = g.hole_position
	for frame in 40: g.step(0.02, Vector2.ZERO)
	smoke.check(g.hole_position.distance_to(from) > 2.0, "the snake saucer keeps gliding with the stick let go")
	var before: int = g.daily.count
	var bitten := 0
	for fruit in snake.fruits:
		if fruit.fall >= 0 or fruit.hidden: continue
		g.swallow(fruit)
		bitten += 1
	smoke.check(bitten > 0 and snake.length == g.daily.count and g.daily.count == before + bitten and is_equal_approx(g.target_radius, float(g.stats.start_radius)), "each fruit adds an orb to the tail and scores, and the hole keeps its size")
	for frame in 40: g.step(0.02, Vector2(0, 1))
	smoke.check(snake.fruits.all(func(f): return not f.eaten and (f.fall >= 0 or not f.hidden)), "eaten fruit comes back somewhere else")
	smoke.check(snake.orb_at(0).distance_to(Vector3(g.hole_position.x, 0, g.hole_position.z)) < snake.ORB_GAP*1.6 and snake.orbs[0].visible, "the tail follows right behind the saucer")
	smoke.check(not snake.crashed and g.mode == "playing", "a straight run never bites the tail")
	# A full loop: the trail circles back to the hole, so a later orb sits on it.
	snake.length = 10
	var loop: float = 8*snake.ORB_GAP
	var turn := int(loop/snake.STEP)
	var centre: Vector3 = Vector3(g.spawn.x, 0, g.spawn.z) + Vector3(loop/TAU, 0, 0)
	snake.trail.clear()
	for k in turn + 1:
		var angle: float = PI + k*TAU/turn
		snake.trail.append(centre + Vector3(cos(angle), 0, sin(angle))*loop/TAU)
	g.hole_position = snake.trail[-1]
	snake.update(g, 0.0)
	smoke.check(snake.crashed and g.daily.done(), "running into the tail ends the snake run")
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.mode == "result", "the bitten snake goes to the result")
	g.go_menu()

# Mole munch (mole_patch.gd): moles pop out of manholes near the hole, duck
# back down if missed, and score 1 (golden 3) when swallowed in time.
static func check_mole(smoke, g) -> void:
	begin(g, "mole")
	var moles = g.daily.moles
	smoke.check(moles.spots.size() == moles.MANHOLES and moles.lids.all(func(l): return l.visible) and (moles.moles + moles.bombs).all(func(m): return m.hidden), "manholes open on the roads and every mole starts hidden")
	g.started = true
	var brown: Array = moles.moles.slice(0, moles.MOLES)
	var up: Array = []
	for frame in 300:
		g.step(0.02, Vector2.ZERO)
		up = brown.filter(func(m): return not m.hidden and m.fall < 0)
		if not up.is_empty(): break
	var showing: int = (moles.moles + moles.bombs).filter(func(m): return not m.hidden).size()
	smoke.check(not up.is_empty() and showing <= moles.crowd(), "moles pop up near the hole, a few at a time")
	var mole: Dictionary = up[0]
	var gap: float = Vector2(mole.position.x - g.hole_position.x, mole.position.z - g.hole_position.z).length()
	smoke.check(gap <= moles.REACH.y + 0.1, "a mole pops up within reach (%.1f)" % gap)
	var count: int = g.daily.count
	g.hole_position = Vector3(mole.position.x, 0, mole.position.z)
	for frame in 3: g.step(0.02, Vector2.ZERO)
	smoke.check(g.daily.count == count + 1 and moles.catches == 1, "swallowing a mole that is up scores 1")
	var gold: Dictionary = moles.moles[-1]
	if gold.hidden: moles.pop(g, [gold])
	count = g.daily.count
	g.swallow(gold)
	smoke.check(g.daily.count == count + moles.GOLD_POINTS, "a golden mole is worth %d" % moles.GOLD_POINTS)
	g.hole_position = Vector3(g.layout.move_x, 0, g.layout.move_z)
	var missed: int = moles.missed
	for frame in int(moles.UP_TIME.x/0.02) + 80: g.step(0.02, Vector2.ZERO)
	smoke.check(moles.missed > missed, "a mole left alone ducks back down")
	g.go_menu()

# Red light, green light (red_light.gd): eat on green; moving on red after
# the grace is a strike that costs points and freezes the hole; three end it.
static func check_red_light(smoke, g) -> void:
	begin(g, "redlight")
	var light = g.daily.light
	smoke.check(light.phase == "green" and light.ring.visible and light.snacks.size() == light.SNACKS and g.level.weather == "clear", "red light starts on green with snacks on the roads, in clear weather")
	g.started = true
	var melon: Dictionary = light.snacks.filter(func(s): return s.variant == 2)[0]
	g.swallow(melon)
	smoke.check(g.daily.count == 3, "a watermelon is worth 3")
	light.timer = 0.0
	g.step(0.02, Vector2.ZERO)
	smoke.check(light.phase == "yellow", "green turns yellow")
	light.timer = 0.0
	g.step(0.02, Vector2.ZERO)
	smoke.check(light.phase == "red", "yellow turns red")
	light.timer = 99.0
	for frame in 30: g.step(0.02, Vector2.ZERO)
	smoke.check(light.strikes == 0, "standing still on red is safe")
	for frame in 10: g.step(0.02, Vector2(1, 0))
	smoke.check(light.strikes == 1 and g.daily.count == 0 and light.speed_scale() == 0.0, "moving on red is a strike: points lost, the hole frozen")
	light.strikes = light.MAX_STRIKES
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.mode == "result", "three strikes end the round")
	g.go_menu()
