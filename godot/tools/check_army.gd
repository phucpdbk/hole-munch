extends SceneTree

# Headless checks for the national forces (army_forces.gd, army.gd): rosters
# grow with the city, every round flies at the saucer, a hovering saucer is
# reeled, a moving one slips the rifles, flak leads, the missile lock needs a
# still saucer and its missile always lands, grace holds fire, eaten units stop.
const Forces = preload("res://scripts/army_forces.gd")
const Army = preload("res://scripts/army.gd")
const STILL := Vector3.ZERO

func unit(kind: String, at: Vector3) -> Dictionary:
	return {"position":at, "eaten":false, "fall":-1.0, "hidden":false, "gunner":true, "defender":true, "army":true, "unit":kind, "yaw":0.0}

func level(index: int) -> Dictionary:
	return {"index":index, "boss":["onepillar", "eiffel", "liberty", "sydney"][index % 4]}

func _initialize() -> void:
	check_rosters()
	check_rifles()
	check_flak()
	check_missile()
	print("ARMY CHECKS: passed")
	quit()

func check_rosters() -> void:
	var first: Dictionary = Forces.force({"index":0, "boss":"onepillar"})
	assert(first.police == 24 and first.car == 3 and first.missile == 0 and first.soldier == 0, "the first city fields only police")
	var last: Dictionary = Forces.force({"index":47, "boss":"parliament"})
	assert(last.soldier >= 16 and last.rocket > 0 and last.missile >= 2 and last.flak >= 1 and last.tank >= 1, "the last city fields the full arsenal")
	var previous := 0
	for index in 48:
		var force: Dictionary = Forces.force({"index":index, "boss":"eiffel"})
		var heavy: int = force.rocket + force.missile*3 + force.flak*3 + force.tank*3 + force.soldier
		assert(heavy >= previous, "firepower never drops from one city to the next (%d)" % index)
		previous = heavy
	for id in Forces.COUNTRY: assert(Forces.LOOKS.has(Forces.COUNTRY[id]), "every landmark country has a look: %s" % id)
	assert(Forces.look({"boss":"bigben"}).checker.size() == 2 and Forces.look({"boss":"liberty"}).lower != "", "liveries differ by country")

func check_rifles() -> void:
	var army = Army.new()
	var saucer := Vector3(0, 4.3, 0)
	var squad := [unit("police", Vector3(4, 0.16, 0)), unit("police", Vector3(-4, 0.16, 1)), unit("soldier", Vector3(0, 0.16, 5))]
	army.reset(squad, {"pressure":0.0})
	for i in 100: assert(not army.update(0.1, saucer, STILL, 1.1, true), "grace holds fire")
	assert(army.shots.is_empty(), "no rounds during grace")
	assert(absf(squad[0].yaw - atan2(-4.0, 0.0)) < 0.01, "gunners turn to face the saucer")
	var reeled := 0
	for i in 200:
		if army.update(0.05, saucer, STILL, 1.1, false): reeled += 1
	assert(reeled >= 1 and army.hits == reeled, "a hovering saucer gets reeled")
	for shot in army.shots: assert(shot.aim.y > 3.0, "rounds aim at the saucer, not the ground")
	army.reset(squad, {"pressure":0.0})
	var moving := saucer
	for i in 200:
		var t := i*0.05
		moving.x = 9.0*sin(t*0.7)
		moving.z = 6.0*cos(t*0.9)
		army.update(0.05, moving, Vector3(6.3*cos(t*0.7), 0, -5.4*sin(t*0.9)), 1.1, false)
	assert(army.hits == 0, "a saucer on the move slips the police bursts")
	army.reset(squad, {"pressure":0.0})
	for item in squad: item.eaten = true
	for i in 100: army.update(0.1, saucer, STILL, 1.1, false)
	assert(army.shots.is_empty() and army.active_count() == 0, "eaten gunners fall silent")

func check_flak() -> void:
	var army = Army.new()
	var gun := unit("flak", Vector3(0, 0.08, -8))
	army.reset([gun], {"pressure":0.5})
	army.gunners[0].cooldown = 0.0
	for i in 2: army.update(0.01, Vector3(0, 4.3, 0), Vector3(6, 0, 0), 1.1, false)
	assert(army.shots.size() == 1 and army.shots[0].kind == "flak", "flak fires shells")
	assert(army.shots[0].aim.x > 2.0, "flak aims where a moving saucer is heading")

func check_missile() -> void:
	var army = Army.new()
	var truck := unit("missile", Vector3(10, 0.08, 0))
	army.reset([truck], {"pressure":0.0})
	assert(army.trucks.size() == 1 and army.gunners.is_empty(), "missile trucks lock rather than shoot")
	var saucer := Vector3(0, 4.3, 0)
	# Moving: never locks.
	for i in 100: army.update(0.05, saucer, Vector3(3, 0, 0), 1.1, false)
	assert(army.lock.progress == 0.0 and army.shots.is_empty(), "a moving saucer is never locked")
	# Sitting still: the reticle shows after the lock delay...
	var seen_at := -1.0
	var launched_at := -1.0
	for i in 120:
		army.update(0.05, saucer, STILL, 1.1, false)
		if seen_at < 0 and army.lock.progress > 0: seen_at = i*0.05
		if army.launched: launched_at = i*0.05
		if launched_at >= 0: break
	assert(absf(seen_at - army.lock_delay()) < 0.11, "the reticle shows after %.1fs still (got %.2f)" % [army.lock_delay(), seen_at])
	assert(launched_at > seen_at + army.lock_confirm() - 0.11, "the missile flies only once the lock fills")
	# ...and the missile lands even if the saucer now runs.
	var hit := false
	for i in 40:
		saucer.x += 0.3
		if army.update(0.05, saucer, Vector3(6, 0, 0), 1.1, false): hit = army.heavy
	assert(hit and army.hits == 1, "a launched missile always lands, as a heavy hit")
	# Breaking the lock: start locking, then move away before it fills.
	army.reset([truck], {"pressure":0.0})
	for i in int((army.lock_delay() + 0.3)/0.05): army.update(0.05, saucer, STILL, 1.1, false)
	assert(army.lock.progress > 0, "the lock is filling")
	army.update(0.05, saucer, Vector3(4, 0, 0), 1.1, false)
	assert(army.lock.progress == 0 and army.lock.still == 0, "moving breaks the lock")
	for i in 60: army.update(0.05, saucer, Vector3(4, 0, 0), 1.1, false)
	assert(army.shots.is_empty(), "no missile after a broken lock")
	# Later cities lock faster.
	army.reset([truck], {"pressure":1.0})
	assert(army.lock_delay() < 1.5 and army.lock_confirm() < 1.0, "late cities lock on faster")
