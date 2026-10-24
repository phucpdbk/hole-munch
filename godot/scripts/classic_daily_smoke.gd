extends RefCounted
# Checks for the classic-game dailies (snake, mole, red light), run from
# campaign_smoke.gd check_daily_games; `smoke` is that runner (its check()).
const Campaign = preload("res://scripts/campaign.gd")
const MascotRig = preload("res://scripts/mascot_rig.gd")

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

# Saucer snake (snake_trail.gd): pets roam a garden and join the line behind
# the saucer when it catches them; hedges block the hole; monsters (the
# Meshy gobbler) bite the nearest pet and scatter the pets behind it, bite the
# clock when the line is empty, and grow in number; the target unlocks the
# next garden; running into the line ends the run.
static func check_snake(smoke, g) -> void:
	g.campaign.checkpoints = {}
	begin(g, "snake")
	var snake = g.daily.snake
	var map = g.countryside
	var tier: Array = snake.TIERS[0]
	smoke.check(map.tier == 0 and snake.roamers.size() == tier[3] and snake.monsters.size() == tier[0] and snake.line.is_empty(), "the snake starts in the open garden with roaming pets and its first monster")
	smoke.check(snake.monsters[0].body is MascotRig and snake.monsters[0].body.source == "animated" and snake.monsters[0].wait > 0, "the monster is the rigged Meshy gobbler, napping at the start")
	smoke.check(snake.roamers.all(func(c): return map.is_free(c.position, snake.ANIMAL_RADIUS)), "pets start clear of hedges, beds and ponds")
	g.step(0.02, Vector2(1, 0))
	var from: Vector3 = g.hole_position
	for frame in 40: g.step(0.02, Vector2.ZERO)
	smoke.check(g.hole_position.distance_to(from) > 2.0, "the snake saucer keeps gliding with the stick let go")
	# A pet runs on its legs: the Meshy pets step through their run frames, the
	# primitive ones swing their front leg.
	var walker = snake.roamers[0]
	var poses: Array = []
	for frame in 30:
		walker.position += Vector3(0.1, 0, 0)
		walker.animate(0.02)
		poses.append(walker.frame(snake.flock.length(walker.kind, walker.clip)) if snake.flipbook else walker.pivots.get("fl", walker.pivots.get("leg_l")).rotation.x)
	if snake.flipbook:
		var frames := {}
		for pose in poses.slice(15): frames[pose] = true
		smoke.check(walker.clip == "run" and frames.size() >= 3, "a running Meshy pet steps through its run frames (%d)" % frames.size())
		g.step(0.02, Vector2.ZERO)
		var batches: Array = snake.flock.batches.values().filter(func(b): return b.multimesh.visible_instance_count > 0)
		var drawn := 0
		for b in batches: drawn += b.multimesh.visible_instance_count
		smoke.check(drawn == snake.roamers.size() and batches.size() <= drawn, "every pet is drawn from the flipbook batches (%d pets, %d batches)" % [drawn, batches.size()])
	else:
		smoke.check(poses.max() - poses.min() > 0.2, "a moving pet swings its legs (%.2f)" % (poses.max() - poses.min()))
	# Catching: the saucer over a pet adds it to the line and a new pet appears.
	var pet = snake.roamers[0]
	g.hole_position = Vector3(pet.position.x, 0, pet.position.z)
	snake.monsters[0].wait = 99.0
	g.step(0.02, Vector2.ZERO)
	smoke.check(snake.line.size() == 1 and snake.line[0] == pet and g.daily.count == 1 and snake.roamers.size() == tier[3], "catching a roaming pet adds it to the line, and another pet appears")
	# Hedges block the saucer.
	var wall: Dictionary = map.solids.filter(func(s): return s.has("h"))[0]
	g.hole_position = Vector3(wall.c.x, 0, wall.c.y)
	g.step(0.02, Vector2.ZERO)
	smoke.check(map.is_free(g.hole_position, g.radius*0.6 - 0.01), "a hedge pushes the saucer out")
	# Six pets in line; the monster bites the third and the three behind scatter.
	for i in 5:
		var extra = snake.take_critter(g)
		extra.visible = true
		extra.position = snake.orb_at(snake.line.size())
		snake.line.append(extra)
	for frame in 5: g.step(0.02, Vector2.ZERO)
	var monster: Dictionary = snake.monsters[0]
	var roaming: int = snake.roamers.size()
	monster.wait = 0.0
	monster.holder.position = snake.line[2].position
	g.step(0.02, Vector2.ZERO)
	smoke.check(snake.line.size() == 2 and g.daily.count == 2 and snake.roamers.size() == roaming + 3 and snake.chomped == 1 and monster.wait > 0, "a monster bites the nearest pet and the pets behind it scatter")
	for critter in snake.line.duplicate(): snake.park(critter)
	snake.line.clear()
	monster.wait = 0.0
	monster.holder.position = Vector3(g.hole_position.x, 0.16, g.hole_position.z)
	var clock: float = g.remaining
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.remaining < clock - snake.BITE_TIME + 0.1, "with no pets left a monster bites the saucer's clock")
	snake.next_monster = 0.0
	g.step(0.02, Vector2.ZERO)
	smoke.check(snake.monsters.size() == tier[0] + 1 and snake.next_monster > 0, "another monster joins after a while")
	# Reaching the target unlocks the hedge garden for the next run.
	for i in g.daily.target():
		var extra = snake.take_critter(g)
		extra.visible = true
		snake.line.append(extra)
	for monster_entry in snake.monsters: monster_entry.wait = 99.0
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.campaign.checkpoint("snake") == 1, "reaching the target unlocks the next garden")
	# A full loop: the trail circles back to the hole, so a later pet sits on it.
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
	# The next runs play the harder gardens: hedged rooms, then the maze.
	begin(g, "snake")
	smoke.check(g.countryside.tier == 1 and g.daily.snake.monsters.size() == snake.TIERS[1][0], "the next run plays the hedge garden")
	g.go_menu()
	g.campaign.checkpoints = {"snake":{"at":3, "lap":0}}
	begin(g, "snake")
	var maze = g.countryside
	var hedges: int = maze.solids.filter(func(s): return s.has("h")).size()
	smoke.check(maze.tier == 3 and hedges > 60 and maze.is_free(Vector3(g.spawn.x, 0, g.spawn.z), g.radius*0.6) and g.daily.snake.monsters.size() == snake.TIERS[3][0], "the hardest garden is a hedge maze (%d hedges) with a clear start" % hedges)
	g.go_menu()
	g.campaign.checkpoints = {}

# Each classic game plays on its own themed map, not a city: no buildings,
# traffic or army, and no decoration the hole could swallow.
static func check_maps(smoke, g) -> void:
	var limit: float = Campaign.START_RADIUS*g.EAT_RATIO
	for type in ["snake", "mole", "redlight"]:
		begin(g, type)
		var map = g.countryside
		var city: Array = g.items.filter(func(item): return item.kind in ["shop", "tower", "house", "car", "jamcar", "person"] or item.kind.begins_with("army_") or item.get("defender", false))
		var decor: Array = g.items.filter(func(item): return item.kind.begins_with("theme_") or item.kind.begins_with("deco_"))
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
