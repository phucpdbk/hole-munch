extends Node3D

# 3D versions of the 2D eating effects: dust puffs on each bite, expanding rings on
# big bites and growth, and the boss celebration (confetti, fireworks, shockwave,
# screen shake and flash). All emitters are pooled and created once.
const PUFFS := 6
const RINGS := 8
const RING_TIME := 0.55
const CONFETTI := [Color("ff595e"), Color("ffca3a"), Color("8ac926"), Color("1982c4"), Color("6a4c93"), Color("f15bb5"), Color("ffffff")]

var puffs: Array[CPUParticles3D] = []
var next_puff := 0
var rings: Array[Dictionary] = []
var confetti: CPUParticles3D
var sparks: Array[CPUParticles3D] = []
var pending: Array[Dictionary] = []
var shake := 0.0
var flash := 0.0
var trail_particles: CPUParticles3D
var trail_style := 0

func _ready() -> void:
	for i in PUFFS: puffs.append(make_puff())
	for i in RINGS: rings.append(make_ring())
	confetti = make_confetti()
	for i in 3: sparks.append(make_spark())
	trail_particles = make_puff()
	trail_particles.one_shot = false
	trail_particles.explosiveness = 0.0
	trail_particles.amount = 60
	trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	trail_particles.emission_ring_axis = Vector3.UP
	trail_particles.emission_ring_height = 0.0
	trail_particles.lifetime = 0.8
	trail_particles.direction = Vector3.UP
	trail_particles.initial_velocity_min = 0.25
	trail_particles.initial_velocity_max = 0.6
	trail_particles.gravity = Vector3(0,0.3,0)

func configure(effect: int, trail: int, tint: Color) -> void:
	clear()
	trail_style = trail
	for p in puffs:
		var mesh: Mesh
		if effect == 0:
			mesh = SphereMesh.new()
			mesh.radius = 0.12; mesh.height = 0.24; mesh.radial_segments = 8; mesh.rings = 4
		else:
			mesh = BoxMesh.new()
			mesh.size = Vector3(0.16,0.025,0.22) if effect == 1 else Vector3.ONE*0.12 if effect == 2 else Vector3(0.07,0.24,0.07)
		mesh.material = particle_material(effect > 1)
		p.mesh = mesh
		p.color_initial_ramp = palette() if effect == 1 else null
		p.color_ramp = fading(Color("d9dade") if effect == 0 else Color.WHITE if effect == 1 else tint if effect == 2 else Color("ffb568"))
		p.angular_velocity_min = -180 if effect > 0 else 0
		p.angular_velocity_max = 180 if effect > 0 else 0
	trail_particles.color_initial_ramp = palette() if trail == 3 else null
	trail_particles.color_ramp = fading(Color.WHITE if trail == 3 else Color("c3ecf4") if trail == 1 else tint)
	trail_particles.scale_amount_min = 0.45 if trail == 2 else 0.8
	trail_particles.scale_amount_max = 0.8 if trail == 2 else 1.5
	trail_particles.visible = true

# The trail sheds from the whole rim, so it is as wide as the hole.
func move_trail(at: Vector3, moving: bool, hole_radius: float) -> void:
	trail_particles.visible = true
	trail_particles.position = at + Vector3(0,0.24,0)
	trail_particles.emission_ring_radius = hole_radius
	trail_particles.emission_ring_inner_radius = hole_radius*0.75
	trail_particles.scale_amount_min = 0.6 + hole_radius*0.25
	trail_particles.scale_amount_max = 1.0 + hole_radius*0.35
	trail_particles.emitting = moving and trail_style > 0

func set_frozen(value: bool) -> void:
	for child in get_children():
		if child is CPUParticles3D: child.speed_scale = 0.0 if value else 1.0

func particle_material(unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded: material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func fading(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color, 0.0))
	return gradient

func emitter(amount: int, lifetime: float, mesh: Mesh) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.mesh = mesh
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles

func make_puff() -> CPUParticles3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = particle_material(false)
	var puff_particles := emitter(10, 0.6, mesh)
	puff_particles.direction = Vector3.UP
	puff_particles.spread = 80
	puff_particles.gravity = Vector3(0, -1.5, 0)
	puff_particles.damping_min = 2.0
	puff_particles.damping_max = 3.0
	puff_particles.color_ramp = fading(Color(0.85, 0.85, 0.88, 0.85))
	return puff_particles

func make_ring() -> Dictionary:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.96
	mesh.outer_radius = 1.04
	mesh.rings = 40
	mesh.ring_segments = 4
	var material := particle_material(true)
	material.vertex_color_use_as_albedo = false
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return {"node":node, "material":material, "t":-1.0, "radius":1.0}

func make_confetti() -> CPUParticles3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.22, 0.02, 0.34)
	mesh.material = particle_material(false)
	var particles := emitter(140, 2.2, mesh)
	particles.direction = Vector3.UP
	particles.spread = 60
	particles.initial_velocity_min = 7.0
	particles.initial_velocity_max = 15.0
	particles.gravity = Vector3(0, -9.0, 0)
	particles.damping_min = 1.0
	particles.damping_max = 2.5
	particles.angle_min = -180
	particles.angle_max = 180
	particles.angular_velocity_min = -360
	particles.angular_velocity_max = 360
	particles.particle_flag_rotate_y = true
	particles.color_initial_ramp = palette()
	return particles

func make_spark() -> CPUParticles3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.1
	mesh.height = 0.2
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = particle_material(true)
	var particles := emitter(36, 0.9, mesh)
	particles.direction = Vector3.UP
	particles.spread = 180
	particles.initial_velocity_min = 5.0
	particles.initial_velocity_max = 6.5
	particles.gravity = Vector3(0, -3.0, 0)
	particles.damping_min = 1.5
	particles.damping_max = 1.5
	return particles

func palette() -> Gradient:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in CONFETTI.size(): offsets.append(float(i) / CONFETTI.size())
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(CONFETTI)
	return gradient

# Dust thrown up by a bite, scaled to both the object and the hole.
func puff(at: Vector3, object_radius: float, hole_radius: float) -> void:
	var particles := puffs[next_puff]
	particles.visible = true
	next_puff = (next_puff + 1) % PUFFS
	particles.position = Vector3(at.x, 0.2, at.z)
	particles.amount = clampi(3 + int(object_radius * 8.0), 3, 10)
	particles.initial_velocity_min = hole_radius * 1.2
	particles.initial_velocity_max = hole_radius * 2.4
	particles.scale_amount_min = 0.5 + object_radius * 0.4
	particles.scale_amount_max = 0.9 + object_radius * 0.8
	particles.restart()

func ripple(at: Vector3, radius: float, color := Color("fff0a0")) -> void:
	var ring: Dictionary = rings[0]
	for candidate in rings:
		if candidate.t < 0:
			ring = candidate
			break
	ring.t = 0.0
	ring.radius = radius
	ring.material.albedo_color = color
	ring.node.position = Vector3(at.x, 0.24, at.z)
	ring.node.scale = Vector3(radius, 1.0, radius)
	ring.node.visible = true

func burst(at: Vector3, radius: float) -> void:
	shake = 1.0
	flash = 1.0
	ripple(at, radius, Color("ffffff"))
	pending.append({"at":0.15, "kind":"ring", "position":at, "radius":radius})
	confetti.position = Vector3(at.x, radius * 0.8, at.z)
	confetti.visible = true
	confetti.restart()
	for i in 6:
		var angle := randf() * TAU
		var offset := Vector3(cos(angle), 0, sin(angle)) * randf_range(4.0, 9.0)
		pending.append({"at":0.15 + i * 0.22, "kind":"spark", "position":at + offset + Vector3(0, randf_range(3.0, 6.0), 0)})

func clear() -> void:
	for child in get_children():
		if child is CPUParticles3D:
			child.emitting = false
			child.visible = false
	pending.clear()
	shake = 0.0
	flash = 0.0
	for ring in rings:
		ring.t = -1.0
		ring.node.visible = false

func update(dt: float) -> void:
	shake = maxf(0.0, shake - dt * 1.4)
	flash = maxf(0.0, flash - dt * 2.5)
	for ring in rings:
		if ring.t < 0: continue
		ring.t += dt
		var k: float = ring.t / RING_TIME
		if k >= 1.0:
			ring.t = -1.0
			ring.node.visible = false
			continue
		var size: float = ring.radius * (1.0 + k * 1.4)
		ring.node.scale = Vector3(size, 1.0 + k, size)
		ring.material.albedo_color.a = 1.0 - k
	for event in pending: event.at -= dt
	for event in pending.filter(func(e): return e.at <= 0):
		if event.kind == "ring": ripple(event.position, event.radius, Color("ffe066"))
		else: firework(event.position)
	pending.assign(pending.filter(func(e): return e.at > 0))

func firework(at: Vector3) -> void:
	var particles: CPUParticles3D = sparks[0]
	for candidate in sparks:
		if not candidate.emitting:
			particles = candidate
			break
	particles.position = at
	particles.visible = true
	particles.color_ramp = fading(CONFETTI[randi() % 6])
	particles.restart()

func shake_offset(time: float) -> Vector3:
	if shake <= 0: return Vector3.ZERO
	return Vector3(sin(time * 53.0), 0, cos(time * 47.0)) * shake * shake * 0.35
