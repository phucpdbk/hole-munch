extends RefCounted

# Port of the 2D duck trick: short sprints away from a nearby hole, a long rest,
# and a duckling dropped on each sprint. Movement stays inside the central plaza.
const DASH_TIME := 0.85
const REST_TIME := 3.0
const FIRST_REST := 2.0
const DASH_SPEED := 3.7
const ALERT_RANGE := 6.9
const ARENA := 3.0
const MAX_DROPS := 8

var phase := "rest"
var phase_time := FIRST_REST
var direction := Vector3.RIGHT
var drops := 0
var home := Vector3.ZERO

func reset(boss: Dictionary) -> void:
	phase = "rest"
	phase_time = FIRST_REST
	direction = Vector3.RIGHT
	drops = 0
	home = boss.origin

# Returns the duckling revealed this frame, or an empty Dictionary.
func update(boss: Dictionary, ducklings: Array, hole_position: Vector3, hole_radius: float, dt: float) -> Dictionary:
	if boss.eaten or boss.fall >= 0: return {}
	phase_time -= dt
	var away := Vector3(boss.position.x - hole_position.x, 0, boss.position.z - hole_position.z)
	var distance := away.length()
	var dropped: Dictionary = {}
	if phase == "rest" and phase_time <= 0 and distance < boss.radius + hole_radius + ALERT_RANGE:
		phase = "dash"
		phase_time = DASH_TIME
		direction = away / distance if distance > 0.001 else Vector3.RIGHT
		if drops < mini(MAX_DROPS, ducklings.size()):
			dropped = ducklings[drops]
			drops += 1
	if phase == "dash":
		boss.position += direction * DASH_SPEED * dt
		boss.yaw = atan2(direction.x, direction.z)
		boss.roll = sin(phase_time * 22.0) * 0.07
		if phase_time <= 0:
			phase = "rest"
			phase_time = REST_TIME
			boss.roll = 0.0
	boss.position.x = clampf(boss.position.x, home.x - ARENA, home.x + ARENA)
	boss.position.z = clampf(boss.position.z, home.z - ARENA, home.z + ARENA)
	return dropped
