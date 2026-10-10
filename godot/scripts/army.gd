extends RefCounted

# National forces in combat (who and where: army_forces.gd). Every weapon
# shoots the saucer, never the ground, and each asks for its own dodge:
# - police and soldier rifles: tracer bursts at the saucer -> keep moving.
# - rocket troops and tanks: one slow round, aimed a little ahead -> sidestep.
# - flak guns: shells aimed fully ahead that burst in the air -> turn.
# - missile trucks: a saucer that sits still gets a lock reticle, and if it
#   stays put a homing missile flies in -> never hover in one spot.
# Damage adds up and every REEL points reel the saucer (time, shrink, knock);
# a missile reels it at once and shrinks it harder.
const Traffic = preload("res://scripts/traffic.gd")
const Forces = preload("res://scripts/army_forces.gd")
const MAX_SHOTS := 64
const MAX_BLASTS := 32
const REEL := 10
# Damage drains this many points a second (less in later cities), so only
# sustained fire reels.
const DRAIN := 0.8
const REEL_IMMUNITY := 2.5
# Seconds a missed tracer keeps flying past the saucer before it fades.
const OVERSHOOT := 0.4
const SPARK_TIME := 0.22
# The saucer counts as still below this speed (units per second).
const STILL_SPEED := 1.2
const MISSILE_FLIGHT := 0.9
const MISSILE_RANGE := 22.0
const MISSILE_RELOAD := 3.0
const FOOT_MUZZLE := Vector3(0, 1.15, 0)
# A unit swells by this share when it fires, easing back over KICK_TIME.
const KICK := 0.3
const KICK_TIME := 0.18

# shot kind, rounds per burst, gap between rounds, cooldown range, reach, round
# speed, aim spread, damage, how far ahead it aims (seconds of flight), and the
# blast radius round its burst point (0: tracers need a direct hit).
const WEAPONS := {
	"police": {"shot":"bullet", "burst":3, "gap":0.1, "cooldown":Vector2(3.2, 5.5), "range":9.0, "speed":15.0, "spread":0.75, "damage":1, "lead":0.0, "blast":0.0},
	"soldier": {"shot":"bullet", "burst":4, "gap":0.09, "cooldown":Vector2(2.6, 4.4), "range":10.0, "speed":17.0, "spread":0.55, "damage":1, "lead":0.3, "blast":0.0},
	"rocket": {"shot":"rocket", "burst":1, "gap":0.0, "cooldown":Vector2(5.0, 7.5), "range":13.0, "speed":7.5, "spread":0.2, "damage":4, "lead":0.5, "blast":0.7},
	"tank": {"shot":"shell", "burst":1, "gap":0.0, "cooldown":Vector2(4.0, 6.0), "range":14.0, "speed":12.0, "spread":0.2, "damage":4, "lead":0.6, "blast":0.6},
	"flak": {"shot":"flak", "burst":2, "gap":0.35, "cooldown":Vector2(3.5, 5.5), "range":16.0, "speed":16.0, "spread":0.3, "damage":3, "lead":1.0, "blast":1.6},
}

var gunners: Array = []
var trucks: Array = []
var shots: Array = []
var blasts: Array = []
# still: seconds the saucer has sat still in a truck's reach; progress: 0..1
# of the lock once the reticle shows (it fires at 1).
var lock := {"still":0.0, "progress":0.0}
var pressure := 0.0
var damage := 0.0
var hits := 0
var immunity := 0.0
# Set for one frame each.
var fired := false
var pinged := false
var launched := false
var heavy := false
# Where the last reeling round came from, so the hole is knocked away from it.
var last_from := Vector3.ZERO
var rng := RandomNumberGenerator.new()

func reset(items: Array, force_spec: Dictionary) -> void:
	gunners.clear()
	trucks.clear()
	shots.clear()
	blasts.clear()
	lock = {"still":0.0, "progress":0.0}
	pressure = float(force_spec.get("pressure", 0.0))
	damage = 0.0
	hits = 0
	immunity = 0.0
	clear_flags()
	rng.seed = 7331
	if force_spec.is_empty(): return
	for item in items:
		if not item.get("gunner", false): continue
		if item.unit == "missile":
			trucks.append({"item":item, "cooldown":0.0})
			continue
		var weapon: Dictionary = WEAPONS[item.unit]
		gunners.append({"item":item, "weapon":weapon, "cooldown":rng.randf_range(0.3, weapon.cooldown.y), "shots":0, "gap":0.0, "engaged":false})

func clear_flags() -> void:
	fired = false
	pinged = false
	launched = false
	heavy = false

func cooldown_scale() -> float:
	return lerpf(1.0, 0.75, pressure)

# Later cities lock on sooner and fire faster once locked.
# Later cities reach further.
func reach_scale() -> float:
	return lerpf(1.0, 1.35, pressure)

func lock_delay() -> float:
	return lerpf(2.0, 1.0, pressure)

func lock_confirm() -> float:
	return lerpf(1.2, 0.6, pressure)

# Advances rounds, gunners and the missile lock; true when the saucer reels this
# frame (heavy: a missile). hold: grace, a clinging guardian or a cinematic.
func update(dt: float, saucer: Vector3, velocity: Vector3, saucer_radius: float, hold: bool) -> bool:
	clear_flags()
	immunity = maxf(0.0, immunity - dt)
	damage = maxf(0.0, damage - DRAIN*lerpf(1.0, 0.5, pressure)*dt)
	var reeled := advance(dt, saucer, saucer_radius)
	for gunner in gunners:
		var item: Dictionary = gunner.item
		if not Traffic.is_active(item): continue
		item.kick = maxf(0.0, float(item.get("kick", 0.0)) - dt/KICK_TIME)
		var reach := Vector2(saucer.x - item.position.x, saucer.z - item.position.z).length()
		gunner.engaged = not hold and reach <= float(gunner.weapon.range)*reach_scale()
		if reach <= float(gunner.weapon.range)*reach_scale()*1.4: face(item, saucer)
		if hold: continue
		gunner.cooldown -= dt
		if gunner.shots > 0:
			gunner.gap -= dt
			if gunner.gap <= 0:
				shoot(item, gunner.weapon, saucer, velocity)
				gunner.shots -= 1
				gunner.gap = gunner.weapon.gap
		elif gunner.cooldown <= 0 and reach <= float(gunner.weapon.range)*reach_scale():
			gunner.shots = int(gunner.weapon.burst)
			gunner.gap = 0.0
			gunner.cooldown = rng.randf_range(gunner.weapon.cooldown.x, gunner.weapon.cooldown.y)*cooldown_scale()
			fired = true
	update_lock(dt, saucer, velocity, hold)
	return reeled

static func face(item: Dictionary, target: Vector3) -> void:
	var offset: Vector3 = target - item.position
	item.yaw = atan2(offset.x, offset.z) if item.unit in Forces.FOOT else atan2(-offset.z, offset.x)

static func muzzle(item: Dictionary, target: Vector3) -> Vector3:
	if item.unit in Forces.FOOT: return item.position + FOOT_MUZZLE
	var ahead := Vector3(target.x - item.position.x, 0, target.z - item.position.z).normalized()
	return item.position + Vector3(0, 1.3, 0) + ahead*0.7

func shoot(item: Dictionary, weapon: Dictionary, saucer: Vector3, velocity: Vector3) -> void:
	if shots.size() >= MAX_SHOTS: return
	item.kick = 1.0
	var start := muzzle(item, saucer)
	# Flak always leads fully; the rest lead more as the cities get harder.
	var lead: float = weapon.lead*(1.0 if weapon.shot == "flak" else lerpf(0.5, 1.0, pressure))
	var ahead: Vector3 = Vector3(velocity.x, 0, velocity.z)*(start.distance_to(saucer)/float(weapon.speed))*lead
	var spread: float = weapon.spread
	var aim: Vector3 = saucer + ahead + Vector3(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)*0.5, rng.randf_range(-spread, spread))
	shots.append({"kind":weapon.shot, "start":start, "aim":aim, "time":0.0, "flight":start.distance_to(aim)/weapon.speed,
		"damage":weapon.damage, "blast":weapon.blast, "resolved":false})

func update_lock(dt: float, saucer: Vector3, velocity: Vector3, hold: bool) -> void:
	var ready: Dictionary = {}
	var best := MISSILE_RANGE
	for truck in trucks:
		truck.cooldown = maxf(0.0, truck.cooldown - dt)
		var item: Dictionary = truck.item
		if not Traffic.is_active(item): continue
		item.kick = maxf(0.0, float(item.get("kick", 0.0)) - dt/KICK_TIME)
		var reach := Vector2(saucer.x - item.position.x, saucer.z - item.position.z).length()
		if reach <= MISSILE_RANGE*1.2: face(item, saucer)
		if truck.cooldown <= 0 and reach <= best:
			best = reach
			ready = truck
	if hold or ready.is_empty() or Vector2(velocity.x, velocity.z).length() > STILL_SPEED:
		lock.still = 0.0
		lock.progress = 0.0
		return
	lock.still += dt
	if lock.still < lock_delay(): return
	lock.progress = minf(1.0, lock.progress + dt/lock_confirm())
	if lock.progress < 1.0: return
	launch(ready, saucer)
	lock.still = 0.0
	lock.progress = 0.0

func launch(truck: Dictionary, saucer: Vector3) -> void:
	truck.item.kick = 1.0
	truck.cooldown = MISSILE_RELOAD
	var start := muzzle(truck.item, saucer)
	shots.append({"kind":"missile", "start":start, "control":start + Vector3(0, 5.0, 0), "aim":saucer, "time":0.0,
		"flight":MISSILE_FLIGHT, "damage":REEL, "blast":1.8, "resolved":false})
	launched = true

func advance(dt: float, saucer: Vector3, saucer_radius: float) -> bool:
	var reeled := false
	for i in range(blasts.size()-1, -1, -1):
		blasts[i].time -= dt
		if blasts[i].time <= 0: blasts.remove_at(i)
	for i in range(shots.size()-1, -1, -1):
		var shot: Dictionary = shots[i]
		shot.time += dt
		# The missile homes: it always ends on the saucer.
		if shot.kind == "missile": shot.aim = saucer
		if shot.resolved:
			if shot.time >= shot.flight + OVERSHOOT: shots.remove_at(i)
			continue
		if shot.time < shot.flight: continue
		shot.resolved = true
		if land(shot, saucer, saucer_radius): reeled = true
		if shot.kind != "bullet" or saucer.distance_to(shot.aim) < saucer_radius: shots.remove_at(i)
	return reeled

# A round reaches its aim point: tracers need a direct hit, the rest burst.
func land(shot: Dictionary, saucer: Vector3, saucer_radius: float) -> bool:
	var miss := saucer.distance_to(shot.aim)
	match shot.kind:
		"bullet":
			if miss >= saucer_radius: return false
			add_blast(saucer + (shot.start - saucer).normalized()*saucer_radius*0.6, "spark", 1.0)
			pinged = true
			return hurt(shot.damage, shot.start)
		"missile":
			add_blast(saucer, "boom", shot.blast)
			pinged = true
			heavy = true
			damage = 0.0
			hits += 1
			immunity = REEL_IMMUNITY
			last_from = shot.start
			return true
	add_blast(shot.aim, "flak" if shot.kind == "flak" else "boom", shot.blast + 0.3)
	if miss >= saucer_radius + shot.blast*(0.5 if shot.kind == "flak" else 1.0): return false
	pinged = true
	return hurt(shot.damage, shot.start)

func hurt(amount: float, from: Vector3) -> bool:
	if immunity > 0: return false
	damage += amount
	if damage < REEL: return false
	damage = 0.0
	hits += 1
	immunity = REEL_IMMUNITY
	last_from = from
	return true

func add_blast(at: Vector3, kind: String, size: float) -> void:
	if blasts.size() >= MAX_BLASTS: blasts.pop_front()
	var duration := SPARK_TIME if kind == "spark" else 0.5
	blasts.append({"position":at, "kind":kind, "size":size, "time":duration, "duration":duration})

static func shot_position(shot: Dictionary) -> Vector3:
	var t: float = shot.time/maxf(shot.flight, 0.001)
	if shot.kind == "missile":
		t = minf(t, 1.0)
		return shot.start.lerp(shot.control, t).lerp(shot.control.lerp(shot.aim, t), t)
	return shot.start + (shot.aim - shot.start)*t

static func shot_direction(shot: Dictionary) -> Vector3:
	if shot.kind == "missile":
		var t: float = minf(shot.time/maxf(shot.flight, 0.001), 1.0)
		var tangent: Vector3 = shot.control.lerp(shot.aim, t) - shot.start.lerp(shot.control, t)
		return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector3.UP
	return (shot.aim - shot.start).normalized()

func active_count() -> int:
	var count := 0
	for unit in gunners + trucks:
		if Traffic.is_active(unit.item): count += 1
	return count
