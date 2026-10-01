extends Node3D

# A rival hole races the player for the same city. It greedily chases the most
# food it can reach, flees a bigger player, hunts a smaller one, and wins the
# city if it swallows the landmark first. The ground and object shaders cut a
# second opening at its position, so its bites sink like the player's.
const Traffic = preload("res://scripts/traffic.gd")
const Mechanics = preload("res://scripts/mechanics.gd")
const EAT_RATIO := 0.85
const GROWTH := 0.45
const MAX_RADIUS := 8.5
const RETARGET := 0.35
const HUNT_RANGE := 9.0
const GOLD_PULL := 2.5
const FLEE_RANGE := 7.0
# The rival stops to chew after each bite, longer for bigger food.
const DIGEST_PER_RADIUS := 0.5
const DIGEST_CAP := 1.2
const COLOR_A := Color("ff5a4e")
const COLOR_B := Color("ffc2a8")

var active := false
var radius := 0.86
var target_radius := 0.86
var speed_scale := 0.8
var bounds := Vector2(20, 20)
var target: Dictionary = {}
var retarget := 0.0
var heading := Vector3.ZERO
var digest := 0.0
var digest_scale := 1.0
var rim_material: StandardMaterial3D
var shaft: MeshInstance3D
var shaft_material: ShaderMaterial
var ring: MeshInstance3D

func _ready() -> void:
	shaft = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 0.78
	cylinder.height = 1.8
	cylinder.cap_top = false
	cylinder.radial_segments = 40
	shaft.mesh = cylinder
	# Same swirling black-hole shaft as the player, lit red.
	shaft_material = ShaderMaterial.new()
	shaft_material.shader = load("res://shaders/hole_shaft.gdshader")
	shaft_material.set_shader_parameter("glow", COLOR_A)
	shaft.material_override = shaft_material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shaft)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.97
	torus.outer_radius = 1.12
	torus.rings = 40
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = 0.19
	rim_material = StandardMaterial3D.new()
	rim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_material.albedo_color = COLOR_A
	ring.material_override = rim_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	visible = false

func reset(enabled: bool, start: Vector3, start_radius: float, speed: float, area: Vector2, chew := 1.0) -> void:
	active = enabled
	visible = enabled
	position = Vector3(start.x, 0, start.z)
	radius = start_radius
	target_radius = start_radius
	speed_scale = speed
	bounds = area
	target = {}
	retarget = 0.0
	heading = Vector3.ZERO
	digest = 0.0
	digest_scale = chew
	sync_view(0.0)

# Set each update: the guardian is only worth a fight once the landmark fits.
var boss_fits := false

func can_eat(item: Dictionary) -> bool:
	if item.get("guardian", false) and not boss_fits: return false
	return Traffic.is_active(item) and item.radius <= radius*EAT_RATIO and not item.get("shielded", false)

func speed() -> float:
	return (5.8 + minf(radius, 4.0)*0.45)*speed_scale

# Moves and returns the items that start falling into the rival this frame.
func update(dt: float, items: Array, boss: Dictionary, player: Vector3, player_radius: float) -> Array:
	if not active: return []
	radius = lerpf(radius, target_radius, 1.0-exp(-dt*8.0))
	boss_fits = boss.radius <= radius*EAT_RATIO
	retarget -= dt
	if retarget <= 0 or target.is_empty() or not can_eat(target):
		retarget = RETARGET
		target = choose_target(items, boss)
	heading = steer(player, player_radius)
	digest = maxf(0.0, digest-dt)
	if digest <= 0.0: position += heading*speed()*dt
	position.x = clampf(position.x, -bounds.x, bounds.x)
	position.z = clampf(position.z, -bounds.y, bounds.y)
	var bites: Array = []
	for item in items:
		if not can_eat(item): continue
		var reach: float = radius - item.radius*0.4
		if Vector2(item.position.x-position.x, item.position.z-position.z).length() < reach:
			bites.append(item)
			digest = minf(DIGEST_CAP, digest + item.radius*DIGEST_PER_RADIUS*digest_scale)
	return bites

func choose_target(items: Array, boss: Dictionary) -> Dictionary:
	return best_target(items, boss, position, radius)

# Greedy value per distance; the landmark always wins once it fits. Its guardian
# fights back, so it is left alone until the landmark fits, then hunted first.
# Shared with the par route in smoke.gd, so timers and the rival use the same yardstick.
static func best_target(items: Array, boss: Dictionary, from: Vector3, hole_radius: float) -> Dictionary:
	var limit := hole_radius*EAT_RATIO
	var fits: bool = Traffic.is_active(boss) and boss.radius <= limit
	if fits and not boss.get("shielded", false): return boss
	for item in items:
		if fits and item.get("guardian", false) and Traffic.is_active(item) and item.radius <= limit: return item
	var best: Dictionary = {}
	var best_value := 0.0
	for item in items:
		if item.get("is_boss", false) or not Traffic.is_active(item) or item.radius > limit: continue
		# Like a player, steer clear of bombs while small and of anything still falling.
		if item.get("falling", 0.0) > 0 or (item.get("bomb", false) and hole_radius < Mechanics.BOMB_SAFE): continue
		var distance := Vector2(item.position.x-from.x, item.position.z-from.z).length()
		var value: float = item.radius*item.radius/(distance + 3.0)
		# Golden food (gold districts, gold-rush treasure) is worth a detour.
		if item.get("gold", false): value *= GOLD_PULL
		if item.get("guardian", false): continue
		if value > best_value:
			best_value = value
			best = item
	return best

func steer(player: Vector3, player_radius: float) -> Vector3:
	var to_player := Vector3(player.x-position.x, 0, player.z-position.z)
	var distance := to_player.length()
	if distance > 0.01:
		# A smaller player is prey; a bigger one is a threat.
		if player_radius <= radius*EAT_RATIO and distance < HUNT_RANGE: return to_player/distance
		if radius <= player_radius*EAT_RATIO and distance < FLEE_RANGE: return -to_player/distance
	if target.is_empty(): return Vector3.ZERO
	var offset := Vector3(target.position.x-position.x, 0, target.position.z-position.z)
	return offset.normalized() if offset.length() > 0.05 else Vector3.ZERO

func grow(bite_radius: float) -> void:
	target_radius = minf(MAX_RADIUS, sqrt(target_radius*target_radius + bite_radius*bite_radius*GROWTH))

# True when the rival covers the player's centre and is big enough to eat it.
func swallows(player: Vector3, player_radius: float) -> bool:
	return active and player_radius <= radius*EAT_RATIO and flat_distance(player) < radius - player_radius*0.4

# True when the player can swallow the rival.
func swallowed_by(player: Vector3, player_radius: float) -> bool:
	return active and radius <= player_radius*EAT_RATIO and flat_distance(player) < player_radius - radius*0.4

func flat_distance(point: Vector3) -> float:
	return Vector2(point.x-position.x, point.z-position.z).length()

func sync_view(elapsed: float) -> void:
	scale = Vector3(radius, 1, radius)
	var depth := 1.8*maxf(1.0, radius*0.9)
	shaft.scale = Vector3(1, depth/1.8, 1)
	shaft.position.y = 0.1-depth/2
	rim_material.albedo_color = COLOR_A.lerp(COLOR_B, 0.5+0.5*sin(elapsed*4.0))
	shaft_material.set_shader_parameter("clock", elapsed)
