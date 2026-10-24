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
	var map = g.countryside
	var city: Array = g.items.filter(func(item): return item.kind in ["shop", "tower", "house", "car", "person"] or item.kind.begins_with("army_"))
	smoke.check(map != null and map.get_script() == g.BeamYard and city.is_empty() and g.level.weather == "clear", "the beam daily plays on the world map, no city, clear skies")
	smoke.check(map.land.size() >= 10 and map.cities.size() == 48 and g.minimap_data().has("land"), "the map has its continents (on the minimap too) and every campaign city")
	var paris: Dictionary = map.cities.filter(func(c): return c.id == "eiffel")[0]
	var sydney: Dictionary = map.cities.filter(func(c): return c.id == "sydney")[0]
	smoke.check(map.on_land(Vector2(paris.at.x, paris.at.z)) and paris.at.z < 0 and sydney.at.x > paris.at.x and sydney.at.z > paris.at.z, "cities sit on land at their real place: Paris north-west of Sydney")
	smoke.check(beam.pins.size() == 3 and beam.landmarks.size() == 3 and beam.loose.size() == 3 and beam.board == 0, "the first map pins 3 cities and floats their 3 landmarks")
	smoke.check(beam.loose.all(func(l): return not map.on_land(Vector2(l.at.x, l.at.z))), "loose landmarks float at sea")
	var pins_apart := true
	for a in beam.pins:
		for b in beam.pins:
			if a != b and beam.flat_gap(a.at, b.at) < beam.PIN_GAP: pins_apart = false
	smoke.check(pins_apart and beam.pins.all(func(p): return p.label.text != ""), "pinned cities stand apart, each named")
	var pin: Dictionary = beam.pins[0]
	var landmark: Dictionary = landmark_for(beam, pin)
	# A long press that drags steers and does not beam; a quick tap does.
	g.hole_position = landmark.at
	touch(g, true, Vector2(200, 400))
	touch(g, false, Vector2(260, 400))
	smoke.check(beam.carried.is_empty(), "a drag does not work the beam")
	touch(g, true, Vector2(200, 400))
	touch(g, false, Vector2(203, 401))
	for frame in 25: g.step(0.02, Vector2.ZERO)
	smoke.check(beam.carried == landmark and beam.motion == "" and beam.loose.size() == 2 and beam.speed_scale() < 1.0, "a quick tap beams the landmark up, and carrying slows the saucer")
	smoke.check(absf(landmark.node.position.y - beam.CARRY_HEIGHT) < 0.3 and beam.note().contains(g.Campaign.boss_name(landmark.id)), "the landmark hangs under the saucer, its name on the HUD")
	var wrong: Dictionary = beam.pins.filter(func(p): return not beam.fits(p, landmark))[0]
	g.hole_position = wrong.at
	var clock: float = g.remaining
	beam.tap(g)
	smoke.check(not beam.carried.is_empty() and g.remaining < clock - beam.WRONG_COST + 0.1 and wrong.landmark.is_empty() and pin.hint > 0, "a wrong city throws the landmark back, costs time and blinks the right pin")
	g.hole_position = pin.at
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	smoke.check(pin.landmark == landmark and beam.carried.is_empty() and g.daily.count == 1, "set down on its city, the landmark locks in and scores")
	# A landmark dropped elsewhere stays there, and can be picked up again.
	var other: Dictionary = beam.loose[0]
	carry(g, beam, other.at, null)
	var spot := Vector3(g.layout.move_x - 1.0, 0, g.layout.move_z - 1.0)
	g.hole_position = spot
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	smoke.check(beam.carried.is_empty() and other in beam.loose and beam.flat_gap(other.at, spot) < 0.01, "a landmark dropped off any pin stays where it lands")
	carry(g, beam, spot, null)
	smoke.check(beam.carried == other, "and is beamed up again from there")
	g.hole_position = pin.at
	beam.tap(g)
	smoke.check(beam.motion == "" and beam.carried == other, "a filled pin takes no more")
	# Fill the map: a bonus, then the next, bigger map with a decoy.
	g.hole_position = spot
	beam.tap(g)
	for frame in 25: g.step(0.02, Vector2.ZERO)
	clock = g.remaining
	for left in beam.pins.filter(func(p): return p.landmark.is_empty()): carry(g, beam, landmark_for(beam, left).at, left.at)
	smoke.check(g.daily.count == 3 and beam.next_board > 0 and g.remaining > clock, "a full map adds time")
	var first: Array = beam.pins.map(func(p): return p.id)
	for frame in 60: g.step(0.02, Vector2.ZERO)
	var spec: Array = beam.BOARDS[1]
	smoke.check(beam.board == 1 and beam.pins.size() == spec[0] and beam.landmarks.size() == spec[0] + spec[1], "the next map pins more cities and brings a decoy")
	smoke.check(beam.pins.all(func(p): return not p.id in first) and beam.dots().size() > 0 and beam.note() != "", "new cities each map, wanted landmarks show on the minimap")
	var decoy: Dictionary = beam.loose.filter(func(l): return not beam.wanted(l))[0]
	smoke.check(beam.pins.all(func(p): return beam.flat_gap(p.at, map.cities.filter(func(c): return c.id == decoy.id)[0].at) >= beam.PIN_GAP), "a decoy's city is far from every pin")
	carry(g, beam, decoy.at, null)
	g.hole_position = beam.pins[0].at
	clock = g.remaining
	beam.tap(g)
	smoke.check(beam.carried == decoy and g.remaining < clock and beam.pins.all(func(p): return p.hint == 0.0), "a decoy fits no pin")
	g.remaining = 0.0
	g.step(0.02, Vector2.ZERO)
	smoke.check(g.mode == "result", "the beam round ends on the clock")
	g.go_menu()
	smoke.check(beam.pins.is_empty() and beam.landmarks.is_empty() and not beam.column.visible, "the beam's landmarks and pins go when a city loads")

static func touch(g, pressed: bool, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = at
	g._unhandled_input(event)

# The loose landmark the pin wants.
static func landmark_for(beam, pin: Dictionary) -> Dictionary:
	for landmark in beam.loose:
		if beam.fits(pin, landmark): return landmark
	return {}

# Beams up what lies at `from` and, given `to`, sets it down there.
static func carry(g, beam, from: Vector3, to) -> void:
	for at in [from, to]:
		if at == null: continue
		g.hole_position = at
		beam.tap(g)
		for frame in 25: g.step(0.02, Vector2.ZERO)
