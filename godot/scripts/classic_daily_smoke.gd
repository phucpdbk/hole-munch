extends RefCounted
# Checks for the classic-game dailies (snake, mole, red light), run from
# campaign_smoke.gd check_daily_games; `smoke` is that runner (its check()).
const Campaign = preload("res://scripts/campaign.gd")

static func run(smoke, g) -> void:
	check_snake(smoke, g)
	check_mole(smoke, g)
	check_red_light(smoke, g)
	check_maps(smoke, g)

static func begin(g, type: String) -> void:
	g.campaign.daily = {}
	g.daily_override = type
	g.start_daily()
	g.defense.grace = INF

# Saucer snake (snake_trail.gd): fruit on the garden paths, a line of pets
# that grows by one a fruit and follows the hole's path, a saucer that keeps
# gliding, a monster that chomps the last pet, and running into the line that
# ends the run.
static func check_snake(smoke, g) -> void:
	begin(g, "snake")
	var snake = g.daily.snake
	var limit: float = Campaign.START_RADIUS*g.EAT_RATIO
	smoke.check(g.mode == "playing" and snake.fruits.size() == snake.FRUITS and snake.fruits.all(func(f): return not f.hidden and f.radius < limit), "the snake starts with fruit on the paths, each fits the hole")
	smoke.check(snake.monster.visible and snake.monster_wait > 0 and snake.flat_gap(snake.monster_at, g.hole_position) > 10.0, "the monster naps far from the saucer at the start")
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
	smoke.check(bitten > 0 and snake.length == g.daily.count and g.daily.count == before + bitten and is_equal_approx(g.target_radius, float(g.stats.start_radius)), "each fruit brings a pet into the line and scores, and the hole keeps its size")
	for frame in 40: g.step(0.02, Vector2(0, 1))
	smoke.check(snake.fruits.all(func(f): return not f.eaten and (f.fall >= 0 or not f.hidden)), "eaten fruit comes back somewhere else")
	var first: MeshInstance3D = snake.pets[0]
	smoke.check(snake.flat_gap(first.position, g.hole_position) < snake.ORB_GAP*1.6 and first.visible and not snake.pets[snake.length].visible, "the pets hop right behind the saucer")
	smoke.check(not snake.crashed and g.mode == "playing", "a straight run never bites the line")
	# The monster catches the last pet: the line and the score drop by one.
	var line: int = snake.length
	snake.monster_wait = 0.0
	snake.monster_at = snake.orb_at(line - 1)
	g.step(0.02, Vector2.ZERO)
	smoke.check(snake.length == line - 1 and g.daily.count == line - 1 and snake.chomped == 1 and snake.monster_wait > 0, "the monster chomps the last pet, then chews")
	snake.length = 0
	snake.monster_wait = 0.0
	snake.monster_at = Vector3(g.hole_position.x, 0, g.hole_position.z)
	var clock: float = g.remaining
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.remaining < clock - snake.BITE_TIME + 0.1, "with no pets left the monster bites the saucer's clock")
	# A full loop: the trail circles back to the hole, so a later pet sits on it.
	snake.length = 10
	snake.monster_wait = 99.0
	var loop: float = 8*snake.ORB_GAP
	var turn := int(loop/snake.STEP)
	var centre: Vector3 = Vector3(g.spawn.x, 0, g.spawn.z) + Vector3(loop/TAU, 0, 0)
	snake.trail.clear()
	for k in turn + 1:
		var angle: float = PI + k*TAU/turn
		snake.trail.append(centre + Vector3(cos(angle), 0, sin(angle))*loop/TAU)
	g.hole_position = snake.trail[-1]
	snake.update(g, 0.0)
	smoke.check(snake.crashed and g.daily.done(), "running into the pet line ends the snake run")
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.mode == "result", "the crashed snake goes to the result")
	g.go_menu()

# Each classic game plays on its own themed map, not a city: no buildings,
# traffic or army, and no decoration the hole could swallow.
static func check_maps(smoke, g) -> void:
	var limit: float = Campaign.START_RADIUS*g.EAT_RATIO
	for type in ["snake", "mole", "redlight"]:
		begin(g, type)
		var map = g.countryside
		var city: Array = g.items.filter(func(item): return item.kind in ["shop", "tower", "house", "car", "jamcar", "person"] or item.kind.begins_with("army_") or item.get("defender", false))
		var decor: Array = g.items.filter(func(item): return item.kind.begins_with("theme_"))
		smoke.check(map != null and map.theme == g.ThemeMaps.THEME[type] and city.is_empty() and not decor.is_empty(), "%s plays on the %s map with no city" % [type, map.theme if map else "?"])
		smoke.check(decor.all(func(item): return item.radius > limit), "%s decorations are too big to swallow" % type)
		g.go_menu()
	smoke.check(g.daily.light.poles.size() == g.layout.junctions().size() and g.daily.light.poles.all(func(p): return not p.visible), "the track has a traffic light on every crossing, hidden back in the city")

# Mole munch (mole_patch.gd): moles pop out of mole hills near the hole, duck
# back down if missed, and score 1 (golden 3) when swallowed in time.
static func check_mole(smoke, g) -> void:
	begin(g, "mole")
	var moles = g.daily.moles
	smoke.check(moles.spots.size() == moles.HILLS and moles.lids.all(func(l): return l.visible) and (moles.moles + moles.bombs).all(func(m): return m.hidden), "mole hills dot the paths and every mole starts hidden")
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
