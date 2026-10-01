extends RefCounted

# Telegraphs lock onto a ground position, never follow the player after firing.
# One hit grants immunity against overlapping blasts. Each continent sharpens the
# defence: shorter warnings, more simultaneous shots, less opening grace, and
# gunners that lead a moving hole.
const Traffic = preload("res://scripts/traffic.gd")
const MAX_STRIKES := 8
const REGION_SIZE := 8
const LAST_REGION := 5.0
var units: Array = []
var strikes: Array = []
var slow := 0.0
var immunity := 0.0
var grace := 8.0
var hits := 0
var age := 0.0
var fired := false
var impacts: Array = []
var roads_x: Array[float] = []
var roads_z: Array[float] = []
# Difficulty for the current level, set by reset().
var strike_cap := 3
var warning_scale := 1.0
var hit_immunity := 2.5
var lead := 0.0
var cooldown_scale := 1.0

func reset(items: Array, military_boss: bool, level: int, extra_region := 0) -> void:
	units.clear()
	strikes.clear()
	impacts.clear()
	slow = 0.0
	immunity = 0.0
	var region := mini(level/REGION_SIZE + extra_region, int(LAST_REGION))
	var t := region/LAST_REGION
	grace = 10.0 if level == 0 else maxf(0.0, 8.0 - region*2.0)
	strike_cap = mini(5, 3 + (region+1)/2)
	warning_scale = lerpf(1.0, 0.64, t)
	hit_immunity = lerpf(2.5, 1.5, t)
	lead = lerpf(0.0, 0.45, t)
	cooldown_scale = lerpf(0.9, 0.65, t)
	hits = 0
	age = 0.0
	fired = false
	for item in items:
		if item.get("defender",false) or (military_boss and item.get("is_boss",false)):
			add_unit(item)

func add_unit(item: Dictionary, delay := -1.0) -> void:
	units.append({"item":item,"cooldown":delay if delay >= 0 else 2.0+units.size()*1.7,"route":[]})

# Landmark counter-attack: the landmark itself fires volleys of blasts around
# the hole, ignoring the usual cap on simultaneous shots.
const VOLLEY_INTERVAL := 4.5
const VOLLEY_RADIUS := 1.7
const VOLLEY_SPREAD := 2.6

func add_volley(item: Dictionary, count: int) -> void:
	units.append({"item":item,"cooldown":1.0,"route":[],"volley":count})

# A unit revealed mid-round waits a moment before its first shot.
func wake(item: Dictionary, delay: float) -> void:
	for unit in units:
		if unit.item == item: unit.cooldown = delay

func volley(unit: Dictionary, player: Vector3, velocity: Vector3) -> void:
	var item: Dictionary = unit.item
	var warning := 1.5*warning_scale
	var aim := player + Vector3(velocity.x,0,velocity.z)*warning*maxf(lead,0.25)
	var muzzle: Vector3 = item.position + Vector3(0, item.radius*1.4, 0)
	add_strike(item, muzzle, aim, VOLLEY_RADIUS, warning, true)
	for i in int(unit.volley)-1:
		var angle := age*1.7 + i*TAU/float(int(unit.volley)-1)
		add_strike(item, muzzle, aim + Vector3(cos(angle),0,sin(angle))*VOLLEY_SPREAD, VOLLEY_RADIUS, warning, true)
	unit.cooldown = VOLLEY_INTERVAL*cooldown_scale

func is_aiming(item: Dictionary) -> bool:
	for strike in strikes:
		if strike.source == item: return true
	return false

func approach(unit: Dictionary, player: Vector3, dt: float) -> void:
	var item: Dictionary = unit.item
	if not item.get("defender",false) or item.get("stay",false) or roads_x.is_empty() or roads_z.is_empty(): return
	var offset: Vector3 = player-item.position
	offset.y = 0
	if offset.length() <= 7.0 or is_aiming(item): return
	if unit.route.is_empty():
		var x := roads_x[0]
		var z := roads_z[0]
		for road in roads_x:
			if absf(road-player.x) < absf(x-player.x): x = road
		for road in roads_z:
			if absf(road-player.z) < absf(z-player.z): z = road
		unit.route = [Vector3(x,item.position.y,item.position.z),Vector3(x,item.position.y,z)]
	var goal: Vector3 = unit.route[0]
	item.position = item.position.move_toward(goal,(2.0 if item.kind == "patrol_tank" else 2.7)*dt)
	if item.position.distance_to(goal) < 0.05: unit.route.pop_front()

static func projectile_position(strike: Dictionary) -> Vector3:
	var t := clampf(1.0-strike.time/strike.flight,0,1)
	return strike.start.lerp(strike.target+Vector3(0,0.15,0),t)+Vector3(0,sin(t*PI)*(1.3 if strike.heavy else 0.2),0)

# Queue one telegraphed blast. Returns false when the sky is already full.
# Mascot attacks tint their shots (fire, water...); the default is the gunners' gold.
const SHOT_COLOR := Color("ffd96a")

func add_strike(source: Dictionary, start: Vector3, target: Vector3, radius: float, warning: float, heavy: bool, color := SHOT_COLOR) -> bool:
	if strikes.size() >= MAX_STRIKES: return false
	strikes.append({"source":source,"target":target,"radius":radius,"time":warning,"duration":warning,"flight":0.75,"start":start,"heavy":heavy,"color":color})
	return true

# Advances shots and returns true when the hole is hit this frame.
func update(dt: float, player: Vector3, level: int, velocity := Vector3.ZERO) -> bool:
	fired = false
	age += dt
	slow = maxf(0,slow-dt)
	immunity = maxf(0,immunity-dt)
	grace = maxf(0,grace-dt)
	var hit := land_strikes(dt, player)
	if grace > 0: return hit
	for unit in units:
		var item: Dictionary = unit.item
		if not Traffic.is_active(item): continue
		if unit.has("volley"):
			unit.cooldown = maxf(0,unit.cooldown-dt)
			if unit.cooldown <= 0: volley(unit, player, velocity)
			continue
		approach(unit,player,dt)
		var offset: Vector3 = player-item.position
		if offset.length_squared() > 0.001 and not item.get("landmark", false):
			item.yaw = atan2(-offset.z,offset.x) if item.kind in ["patrol_tank","boss"] else atan2(offset.x,offset.z)
		unit.cooldown = maxf(0,unit.cooldown-dt)
		var distance := Vector2(player.x-item.position.x,player.z-item.position.z).length()
		if unit.cooldown > 0 or distance > (22.0 if item.get("is_boss",false) else 13.0) or strikes.size() >= strike_cap: continue
		fire(unit, player, velocity, level)
	return hit

func land_strikes(dt: float, player: Vector3) -> bool:
	var hit := false
	for i in range(impacts.size()-1,-1,-1):
		impacts[i].time -= dt
		if impacts[i].time <= 0: impacts.remove_at(i)
	for i in range(strikes.size()-1,-1,-1):
		var strike: Dictionary = strikes[i]
		if not Traffic.is_active(strike.source):
			strikes.remove_at(i)
			continue
		var previous: float = strike.time
		strike.time -= dt
		if previous > strike.flight and strike.time <= strike.flight: fired = true
		if strike.time > 0: continue
		if impacts.size() < MAX_STRIKES: impacts.append({"position":strike.target,"radius":strike.radius,"time":0.35,"color":strike.color})
		var distance := Vector2(player.x-strike.target.x,player.z-strike.target.z).length()
		if distance < strike.radius and immunity <= 0:
			hit = true
			hits += 1
			slow = 0.85
			immunity = hit_immunity
		strikes.remove_at(i)
	return hit

func fire(unit: Dictionary, player: Vector3, velocity: Vector3, level: int) -> void:
	var item: Dictionary = unit.item
	var boss: bool = item.get("is_boss",false)
	var heavy: bool = boss or item.kind == "patrol_tank"
	var warning := (1.5 if boss else 1.25)*warning_scale
	# Later gunners aim where the hole is heading, not where it is.
	var target := player + Vector3(velocity.x,0,velocity.z)*warning*lead
	var direction := Vector3(target.x-item.position.x,0,target.z-item.position.z).normalized()
	var muzzle: Vector3 = item.position+direction*(item.radius*1.15 if heavy else 0.3)+Vector3(0,item.radius*0.65 if heavy else 0.5,0)
	add_strike(item, muzzle, target, 2.3 if heavy else 1.2, warning, heavy)
	var base := maxf(3.8,6.8-level*0.05) if boss else maxf(5.0,8.5-level*0.05)
	unit.cooldown = base*cooldown_scale

func active_count() -> int:
	var count := 0
	for unit in units:
		if Traffic.is_active(unit.item): count += 1
	return count

func speed_multiplier() -> float:
	return 0.65 if slow > 0 else 1.0
