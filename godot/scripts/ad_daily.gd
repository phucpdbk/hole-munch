extends RefCounted

# Daily mini-game ad clips (`--ad=daily-<type>`), driven from ad_capture.gd: a
# bot plays the game in real time with captions on the beats scripted in
# ADS-SCRIPTS.md. The HUD stays up, since score chips, the cow card and the
# light ring are part of the joke. Never writes the player's save (capture mode).
const RED := Color("ff5d6c")
const GOLD := Color("f6cb70")
const MINT := Color("9ff0d8")
const TAIL := 1.4

var ad
var g
# Captions said once; lambdas copy locals, so the flags live here.
var said := {}

func run(capture, type: String) -> void:
	ad = capture
	g = capture.g
	g.go_menu()
	g.campaign.daily = {}
	g.campaign.checkpoints = {}
	g.daily_override = type
	g.start_daily()
	g.hud.visible = true
	ad.overlay.top = 0.7
	g.defense.grace = INF
	match type:
		"findcow": await find_cow()
		"redlight": await red_light()
		"skyhop": await sky_hop()
		"slide": await slide()
		"snake": await snake()
		"mole": await mole()
		"siege": await siege()
		"beam": await beam()
		"stampede": await stampede()
		"coinrain": await coin_rain()
		"goldrush": await gold_rush()
	g.bot_input = Vector2.ZERO
	await ad.hold(TAIL)
	await ad.shot("end")

# --- games --------------------------------------------------------------------------

# The card first, a warm/cold search, a look-alike bitten by mistake, then her.
func find_cow() -> void:
	var hunt = g.daily.hunt
	ad.say("Find this cow.", 2.2)
	await ad.hold(1.2)
	await ad.shot("card")
	g.started = true
	await ad.hold(1.2)
	var star: Dictionary = hunt.star
	var herd: Array = hunt.cows.filter(func(cow): return not cow.hidden and not cow.eaten and cow != star)
	herd.sort_custom(func(a, b): return hunt.alike(a, [star]) > hunt.alike(b, [star]))
	var twin: Dictionary = herd[0]
	ad.say("Hmm... which one?", 1.8)
	await chase(func(): return twin.position, func(): return hunt.wrong > 0, 9.0)
	ad.say("THAT'S NOT HER!", 1.8, RED)
	await ad.shot("wrong")
	await ad.hold(1.0)
	await chase(func(): return star.position, func():
		if hunt.warmth(g) > 0.6 and once("warmer"):
			ad.say("Warmer... HOTTER!", 1.6, GOLD)
		return hunt.finds > 0, 12.0)
	ad.say("FOUND HER!", 2.0, MINT)
	await ad.shot("found")
	await ad.hold(0.8)
	ad.say("Can YOU find\nthe next one?", 2.4, GOLD)

# Eat on green, freeze on red, then move on red anyway.
func red_light() -> void:
	var light = g.daily.light
	ad.say("Red light...\nGREEN LIGHT!", 2.0)
	g.started = true
	var greens := 0
	var phase: String = light.phase
	var clock := 0.0
	while clock < 22.0 and g.mode == "playing":
		if light.phase != phase:
			phase = light.phase
			if phase == "green":
				greens += 1
				ad.say("GO GO GO!", 1.2, MINT)
			elif phase == "red":
				ad.say("RED!\nDon't move!" if greens < 2 else "RED! ...eh,\nwho's watching?", 1.6, RED)
		var reckless: bool = greens >= 2 and phase == "red" and light.since > 0.5
		if phase == "red" and not reckless: g.bot_input = Vector2.ZERO
		else:
			var snack = nearest(light.snacks.filter(func(s): return not s.eaten and not s.get("hidden", false)))
			if snack != null: ad.steer(snack)
		if light.strikes > 0: break
		await ad.g.get_tree().process_frame
		clock += g.get_process_delta_time()
	g.bot_input = Vector2.ZERO
	ad.say("...oops.", 1.8, RED)
	await ad.shot("strike")
	await ad.hold(1.4)
	ad.say("Could YOU\nstand still?", 2.2, GOLD)

# A steady pilot for ten-odd gaps, then a missed tap.
func sky_hop() -> void:
	var hop = g.daily.hop
	ad.say("How far can\na UFO fly?", 2.0)
	await ad.hold(0.8)
	hop.flap(g)
	var calls := {5:"5!", 10:"10!!", 15:"15!!!"}
	var give_up := 18
	while g.mode == "playing" and not hop.crashed:
		if hop.passed < give_up:
			var gap: Dictionary = hop.gap_at(hop.passed)
			var ahead := maxf(0.0, (float(gap.x) - hop.x)/hop.SPEED)
			var sway: float = sin((hop.clock + ahead)*1.6 + float(gap.phase))*hop.SWAY if gap.sway else 0.0
			var below: float = float(gap.y) + sway - 0.3 - hop.y
			if below > 0.6 and hop.vy < (4.0 if below > 2.5 else 1.0): hop.flap(g)
		if calls.has(hop.passed):
			ad.say(calls[hop.passed], 0.9, GOLD)
			calls.erase(hop.passed)
		if hop.passed == give_up - 1 and not calls.has(-1):
			calls[-1] = true
			ad.say("Easy...", 1.0)
		await g.get_tree().process_frame
	ad.say("...not that far.", 2.0, RED)
	await ad.shot("crash")
	await ad.hold(1.2)
	ad.say("Beat %d gaps?" % hop.passed, 2.2, GOLD)

# A board shown, a beat to think, then the solver slides it in par; twice.
func slide() -> void:
	var puzzle = g.daily.puzzle
	ad.say("Can you\nsolve it?", 2.2)
	await ad.hold(1.4)
	await ad.shot("board")
	ad.say("Think...", 1.2)
	await ad.hold(1.4)
	for board in 3:
		if g.mode != "playing": break
		var start: int = puzzle.board
		for dir in puzzle.solution():
			g.slide(dir)
			await ad.hold(0.5)
		ad.say(["Solved!", "In par!", "BIG BRAIN"][board], 1.4, MINT if board < 2 else GOLD)
		await ad.until(func(): return puzzle.board != start or g.mode != "playing")
		await ad.hold(0.5)
	await ad.shot("solved")
	ad.say("30 boards.\nHow far can YOU go?", 2.4, GOLD)

# Catch pets, then the gobbler wakes up and bites the line.
func snake() -> void:
	var trail = g.daily.snake
	for monster in trail.monsters: monster.wait = 99.0
	ad.say("Collect ALL\nthe pets", 2.0)
	g.started = true
	await chase(func(): return nearest_node(trail.roamers), func():
		if trail.line.size() >= 3 and once("cute"):
			ad.say("so cute", 1.4, MINT)
		return trail.line.size() >= 5, 11.0)
	await ad.shot("line")
	ad.say("uh oh...", 1.4, GOLD)
	var monster: Dictionary = trail.monsters[0]
	var tail: Node3D = trail.line[trail.line.size()/2]
	monster.holder.position = tail.position + Vector3(-2.6, 0, 1.6)
	monster.wait = 0.0
	var size: int = trail.line.size()
	await chase(func(): return nearest_node(trail.roamers), func(): return trail.line.size() < size, 6.0)
	ad.say("HEY!\nThat was MY puppy!", 2.0, RED)
	await ad.shot("bite")
	await chase(func(): return nearest_node(trail.roamers), func(): return false, 1.6)

# Moles near the hole, snapped up while they are out; a golden one on cue.
func mole() -> void:
	var moles = g.daily.moles
	# Hills spread over a big map can all sit out of pop-up reach: start the
	# saucer where most hills are in reach.
	var best := -1
	for spot in moles.spots:
		var near: int = moles.spots.filter(func(other): return in_reach(moles, spot, other)).size()
		if near > best:
			best = near
			g.hole_position = Vector3(spot.x + 1.5, 0, spot.z + 1.5)
	g.camera_target = g.hole_position
	ad.say("Whack-a-mole...\nbut you EAT them", 2.4)
	await ad.hold(0.5)
	g.started = true
	var gold: Dictionary = moles.moles[-1]
	await chase(func(): return nearest(moles.moles.filter(func(m): return not m.hidden and m.fall < 0 and m.up > 0.3)), func():
		if moles.catches >= 5 and once("golden"):
			if gold.hidden: moles.pop(g, [gold])
		if said.has("golden") and not gold.hidden and gold.fall < 0 and once("shouted"):
			ad.say("GOLDEN ONE!", 1.4, GOLD)
		return moles.catches >= 12, 20.0)
	await ad.shot("moles")
	ad.say("MUNCH-A-MOLE", 2.0, MINT)

# Auto-fire downs the helicopters; holding still under one steals it.
func siege() -> void:
	var sky = g.daily.siege
	ad.say("The army\nfights back", 2.0)
	g.started = true
	var pew := false
	var stealing := false
	var clock := 0.0
	while clock < 20.0 and g.mode == "playing" and sky.escort.is_empty():
		var heli: Dictionary = sky.nearest(g.hole_position, 30.0)
		if heli.is_empty():
			g.bot_input = Vector2.ZERO
		else:
			var gap: float = sky.flat_distance(heli.pos, g.hole_position)
			# Stand off at gun range at first, then go in close to steal one.
			var close: float = 2.2 if sky.downed >= 3 else 5.0
			if gap > close: ad.steer(heli.pos)
			else: g.bot_input = Vector2.ZERO
			if sky.downed >= 3 and not stealing and heli.kind == "heli":
				stealing = true
				ad.say("Now... steal\ntheir helicopter!", 2.2, GOLD)
		if not pew and sky.downed >= 1:
			pew = true
			ad.say("pew pew pew", 1.4, MINT)
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()
	ad.say("IT'S OURS NOW", 2.0, MINT)
	await ad.shot("escort")
	await chase(func(): return g.hole_position + Vector3(4, 0, -3), func(): return false, 2.0)

# Beam one up, try the wrong city, then the right one.
func beam() -> void:
	var drop = g.daily.beam
	ad.say("Put the landmarks\nback. Easy?", 2.2)
	g.started = true
	await ad.hold(0.6)
	# The pin, its landmark and a wrong pin on the shortest flight, so the clip
	# shows beaming rather than ocean.
	var pin: Dictionary = {}
	var landmark: Dictionary = {}
	var wrong: Dictionary = {}
	var best := INF
	for p in drop.pins:
		var l: Dictionary = drop.loose.filter(func(l): return drop.fits(p, l))[0]
		for w in drop.pins:
			if w == p: continue
			var flight: float = drop.flat_gap(g.hole_position, l.at) + drop.flat_gap(l.at, w.at) + drop.flat_gap(w.at, p.at)
			if flight < best:
				best = flight
				pin = p
				landmark = l
				wrong = w
	await drive_to(landmark.at, 2.0)
	drop.tap(g)
	ad.say(g.Campaign.boss_name(landmark.id).to_upper(), 1.6, GOLD)
	await ad.hold(0.8)
	await drive_to(wrong.at, 2.0)
	ad.say("Here?", 0.8)
	await ad.hold(0.5)
	drop.tap(g)
	ad.say("WRONG CITY", 1.6, RED)
	await ad.shot("wrong")
	await ad.hold(0.8)
	await drive_to(pin.at, 2.0)
	drop.tap(g)
	ad.say("Geography: 100", 2.0, MINT)
	await ad.hold(1.0)
	await ad.shot("placed")

# A family eaten from its tail chains 1-5, then the mother pays the bonus.
func stampede() -> void:
	var daily = g.daily
	ad.say("Eat the ducks\nIN ORDER", 2.0)
	g.started = true
	var family: Dictionary = daily.families[0]
	for family_entry in daily.families:
		if family_entry.mother.position.distance_to(g.hole_position) < family.mother.position.distance_to(g.hole_position): family = family_entry
	var calls := ["1...", "2...", "3...", "4...", "5!"]
	for i in range(family.chicks.size() - 1, -1, -1):
		var chick: Dictionary = family.chicks[i]
		await chase(func(): return chick.position, func(): return chick.eaten, 6.0)
		if not calls.is_empty(): ad.say(calls.pop_front(), 0.9, GOLD)
	var mother: Dictionary = family.mother
	await chase(func(): return mother.position, func(): return mother.eaten, 6.0)
	ad.say("WHOLE FAMILY!", 2.0, MINT)
	await ad.shot("family")
	await ad.hold(0.6)

# Landed coins, never a bomb; one near miss gets a caption.
func coin_rain() -> void:
	ad.say("It's raining\nCOINS!", 2.0)
	g.started = true
	await chase(safe_coin, func():
		if landed("bomb").any(func(b): return b.position.distance_to(g.hole_position) < 3.0) and once("warned"):
			ad.say("NOT THE BOMB!", 1.4, RED)
		return g.daily.count >= 18, 18.0)
	await ad.shot("coins")
	ad.say("Rich.", 1.8, MINT)

# Grab gold until it drags, then race the red hole to the bank.
func gold_rush() -> void:
	var daily = g.daily
	ad.say("Grab the gold...", 1.8)
	g.started = true
	await chase(func(): return nearest(g.items.filter(func(item): return item.get("gold", false) and not item.eaten and not item.get("hidden", false))), func():
		if daily.carried >= 4 and once("slow"):
			ad.say("so... heavy...", 1.6, GOLD)
		return daily.carried >= 6, 10.0)
	ad.say("BANK IT!", 1.6, RED)
	g.rival.position = g.hole_position + (g.hole_position - daily.bank_at()).normalized()*9.0
	await chase(func(): return daily.bank_at(), func(): return daily.carried == 0, 12.0)
	ad.say("SAFE!" if daily.count > 0 else "ROBBED!", 1.8, MINT if daily.count > 0 else RED)
	await ad.shot("bank")

# --- helpers ------------------------------------------------------------------------

func in_reach(moles, from: Vector3, spot: Vector3) -> bool:
	var gap := Vector2(spot.x - from.x, spot.z - from.z).length()
	return gap >= moles.REACH.x and gap <= moles.REACH.y

func landed(kind: String) -> Array:
	return g.items.filter(func(item): return item.kind == kind and not item.get("hidden", false) and not item.eaten and item.fall < 0)

# The nearest landed coin with no bomb beside it.
func safe_coin():
	var bombs := landed("bomb")
	return nearest(landed("coin").filter(func(coin): return bombs.all(func(b): return b.position.distance_to(coin.position) > 1.6)))

# Steer at where() each frame until done() holds, the round ends or time is up.
func chase(where: Callable, done: Callable, seconds: float) -> void:
	var clock := 0.0
	while clock < seconds and g.mode == "playing":
		if done.call(): break
		var at = where.call()
		if at is Vector3: ad.steer(at)
		else: g.bot_input = Vector2.ZERO
		await g.get_tree().process_frame
		clock += g.get_process_delta_time()
	g.bot_input = Vector2.ZERO

# Long flights may run fast-forward; captions keep real time.
func drive_to(at: Vector3, fast := 1.0) -> void:
	Engine.time_scale = fast
	await chase(func(): return at, func(): return Vector2(at.x - g.hole_position.x, at.z - g.hole_position.z).length() < 0.35, 10.0)
	Engine.time_scale = 1.0

# The closest item's position, or null with nothing left.
func nearest(items: Array):
	var best = null
	var gap := INF
	for item in items:
		var here: float = Vector2(item.position.x - g.hole_position.x, item.position.z - g.hole_position.z).length()
		if here < gap:
			gap = here
			best = item.position
	return best

func nearest_node(nodes: Array):
	return nearest(nodes.map(func(node): return {"position":node.position}))

# True the first time `key` is asked for.
func once(key: String) -> bool:
	if said.has(key): return false
	said[key] = true
	return true
