extends RefCounted
# Checks for the beam daily (beam_drop.gd), run from campaign_smoke.gd
# check_daily_games; `smoke` is that runner (its check()).

static func run(smoke, g) -> void:
	g.campaign.daily = {}
	g.daily_override = "beam"
	g.start_daily()
	g.defense.grace = INF
	g.started = true
	var beam = g.daily.beam
	var city: Array = g.items.filter(func(item): return item.kind in ["shop", "tower", "house", "car", "person"] or item.kind.begins_with("army_"))
	smoke.check(g.countryside != null and g.countryside.get_script() == g.BeamYard and city.is_empty() and g.level.weather == "clear", "the beam daily plays in the toy depot, no city, clear skies")
	smoke.check(beam.pads.size() == 4 and beam.toys.size() == 4 and beam.piles.size() == 4 and beam.board == 0, "the first board has 4 pads and 4 toys, one a pile")
	var pad: Dictionary = beam.pads[0]
	var pile: Dictionary = pile_with(beam, pad)
	# A long press that drags steers and does not beam; a quick tap does.
	g.hole_position = pile.at
	touch(g, true, Vector2(200, 400))
	touch(g, false, Vector2(260, 400))
	smoke.check(beam.carried.is_empty(), "a drag does not work the beam")
	touch(g, true, Vector2(200, 400))
	touch(g, false, Vector2(203, 401))
	for frame in 25: g.step(0.02, Vector2.ZERO)
	smoke.check(not beam.carried.is_empty() and beam.motion == "" and beam.piles.size() == 3 and beam.speed_scale() < 1.0, "a quick tap beams the toy up, and carrying slows the saucer")
	smoke.check(absf(beam.carried.node.position.y - beam.CARRY_HEIGHT) < 0.3, "the toy hangs under the saucer")
	var wrong: Dictionary = beam.pads.filter(func(p): return not beam.fits(p, beam.carried))[0]
	g.hole_position = wrong.at
	var clock: float = g.remaining
	beam.tap(g)
	smoke.check(not beam.carried.is_empty() and g.remaining < clock - beam.WRONG_COST + 0.1 and wrong.toy.is_empty(), "a wrong pad throws the toy back and costs time")
	g.hole_position = pad.at
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	smoke.check(pad.toy.size() > 0 and beam.carried.is_empty() and g.daily.count == 1, "dropped on its pad, the toy locks in and scores")
	# A toy dropped on open ground makes a pile; one dropped on a pile stacks.
	var other: Dictionary = beam.piles[0]
	g.hole_position = other.at
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	var ground := Vector3(g.layout.move_x - 1.0, 0, -g.layout.move_z + 1.0)
	g.hole_position = ground
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	var made: Dictionary = beam.pile_near(ground)
	smoke.check(not made.is_empty() and made.stack.size() == 1 and absf(made.stack[0].node.position.y - beam.toy_y(0)) < 0.05, "a toy dropped on the ground makes a new pile")
	g.hole_position = beam.piles[0].at if beam.piles[0] != made else beam.piles[1].at
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	g.hole_position = ground
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	smoke.check(made.stack.size() == 2 and absf(made.stack[1].node.position.y - beam.toy_y(1)) < 0.05, "a toy dropped on a pile stacks on top")
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	smoke.check(made.stack.size() == 1 and not beam.carried.is_empty(), "the beam lifts the top toy of a pile")
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	# Fill the board: a bonus, then the next, bigger board with decoys.
	clock = g.remaining
	for left in beam.pads.filter(func(p): return p.toy.is_empty()): deliver(g, beam, left)
	smoke.check(g.daily.count == 4 and beam.next_board > 0 and g.remaining > clock, "a full board adds time")
	for frame in 60: g.step(0.02, Vector2.ZERO)
	var spec: Array = beam.BOARDS[1]
	smoke.check(beam.board == 1 and beam.pads.size() == spec[0]*spec[1] and beam.toys.size() == beam.pads.size() + spec[2], "the next board is bigger and brings decoys")
	smoke.check(beam.piles.all(func(p): return p.stack.size() <= spec[3]) and beam.dots().size() > 0 and beam.note() != "", "piles stay short, wanted piles show on the minimap")
	beam.piles[0].stack.resize(0)
	for i in beam.MAX_STACK: beam.piles[0].stack.append(beam.toys[i])
	g.hole_position = beam.piles[1].at
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	g.hole_position = beam.piles[0].at
	beam.tap(g)
	smoke.check(beam.motion == "" and not beam.carried.is_empty(), "a full pile takes no more toys")
	g.remaining = 0.0
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.mode == "result", "the beam round ends on the clock")
	g.go_menu()
	smoke.check(beam.pads.is_empty() and beam.toys.is_empty() and not beam.column.visible, "the beam's toys and pads go when a city loads")

static func touch(g, pressed: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = at
	g._unhandled_input(event)

# The pile holding a toy of the pad's look.
static func pile_with(beam, pad: Dictionary) -> Dictionary:
	for pile in beam.piles:
		if pile.stack.any(func(toy): return beam.fits(pad, toy)): return pile
	return {}

# Beams a wanted toy onto its pad, first moving any toys on top of it to a
# spare corner of the map.
static func deliver(g, beam, pad: Dictionary) -> void:
	var pile: Dictionary = pile_with(beam, pad)
	while not beam.fits(pad, pile.stack[-1]):
		carry(g, beam, pile.at, Vector3(-g.layout.move_x + 1.0, 0, g.layout.move_z - 1.0 - beam.piles.size()*beam.REACH*2.0))
	carry(g, beam, pile.at, pad.at)

static func carry(g, beam, from: Vector3, to: Vector3) -> void:
	for at in [from, to]:
		g.hole_position = at
		beam.tap(g)
		for frame in 25: g.step(0.02, Vector2.ZERO)
