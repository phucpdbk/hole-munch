extends Node3D

# 3D versions of the 2D eating effects: dust puffs on each bite, expanding rings on
# big bites and growth, and the boss celebration (confetti, fireworks, shockwave,
# screen shake and flash). All emitters are pooled and created once.
const PUFFS := 6
const RINGS := 8
const RING_TIME := 0.55
const CONFETTI := [Color("ff595e"), Color("ffca3a"), Color("8ac926"), Color("1982c4"), Color("6a4c93"), Color("f15bb5"), Color("ffffff")]
const RAINBOW := [Color("ff4d4d"), Color("ff9f1a"), Color("ffe14d"), Color("4dff88"), Color("4dc3ff"), Color("8a5cff"), Color("ff5cd6")]
const ShapeTextures = preload("res://scripts/shape_textures.gd")
# Bite effects in Campaign.EFFECTS order, after src/cosmetics.js emitEatFx:
# [shape, colours ("palette" / "tint" / hex list), gravity, spin, lifetime, speed].
const EFFECT_LOOKS := [
	["dust", ["d9dade"], -1.5, false, 0.6, 1.0],
	["confetti", "palette", -6.0, true, 0.9, 1.2],
	["heart", ["ff4d8d", "ff8fab"], 2.0, false, 1.1, 0.6],
	["star", ["ffd23f", "ffd23f", "ffffff"], -1.5, true, 0.8, 1.0],
	["coin", ["ffc300"], -9.0, true, 0.9, 1.4],
	["pixel", "tint", -4.0, true, 0.8, 1.0],
	["flake", ["ffffff"], -0.6, true, 1.2, 0.6],
]
# Trails in Campaign.TRAILS order, after emitTrail: [shape, colours, gravity, lifetime].
const TRAIL_LOOKS := [
	[],
	["ring", ["a0e7ff"], 0.6, 1.0],
	["star", ["ffffff", "ffd23f"], 0.0, 0.7],
	["circle", ["ffffff"], -0.8, 1.3],
	["flame", ["ff6a00", "ff9d1a", "ffd23f"], 1.2, 0.6],
	["circle", "rainbow", 0.0, 0.9],
]

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
	var look: Array = EFFECT_LOOKS[clampi(effect, 0, EFFECT_LOOKS.size()-1)]
	var mesh := look_mesh(look[0])
	for p in puffs:
		p.mesh = mesh
		paint(p, look[1], tint)
		p.gravity = Vector3(0, look[2], 0)
		p.lifetime = look[4]
		p.set_meta("speed", look[5])
		p.angle_min = -180 if look[3] else 0
		p.angle_max = 180 if look[3] else 0
		p.angular_velocity_min = -240 if look[3] else 0
		p.angular_velocity_max = 240 if look[3] else 0
	trail_style = clampi(trail, 0, TRAIL_LOOKS.size()-1)
	var trail_look: Array = TRAIL_LOOKS[trail_style]
	if not trail_look.is_empty():
		trail_particles.mesh = look_mesh(trail_look[0])
		paint(trail_particles, trail_look[1], tint)
		trail_particles.gravity = Vector3(0, trail_look[2], 0)
		trail_particles.lifetime = trail_look[3]
		# Snow drifts down from the rim; everything else rises off it.
		trail_particles.initial_velocity_min = 0.0 if trail_look[2] < 0 else 0.25
		trail_particles.initial_velocity_max = 0.1 if trail_look[2] < 0 else 0.6
		trail_particles.scale_amount_curve = growing() if trail_look[0] == "flame" else null
	trail_particles.visible = true

# Dust stays a lit sphere and confetti/pixels stay boxes; the rest are camera-facing
# textured quads, so hearts, stars and flakes read the same as the 2D sprites.
func look_mesh(shape: String) -> Mesh:
	match shape:
		"dust":
			var sphere := SphereMesh.new()
			sphere.radius = 0.12; sphere.height = 0.24; sphere.radial_segments = 8; sphere.rings = 4
			sphere.material = particle_material(false)
			return sphere
		"confetti", "pixel":
			var box := BoxMesh.new()
			box.size = Vector3(0.16, 0.025, 0.22) if shape == "confetti" else Vector3.ONE*0.13
			box.material = particle_material(shape == "pixel")
			return box
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*0.3
	var material := particle_material(true)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = ShapeTextures.texture(shape)
	quad.material = material
	return quad

func paint(particles: CPUParticles3D, colours, tint: Color) -> void:
	var list: Array = CONFETTI if colours is String and colours == "palette" else RAINBOW if colours is String and colours == "rainbow" \
		else [tint] if colours is String else colours.map(func(c): return Color(c))
	particles.color_initial_ramp = constant_ramp(list) if list.size() > 1 else null
	particles.color_ramp = fading(Color.WHITE if list.size() > 1 else list[0])

func constant_ramp(colours: Array) -> Gradient:
	var gradient := Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in colours.size(): offsets.append(float(i)/colours.size())
	gradient.offsets = offsets
	gradient.colors = PackedColorArray(colours)
	return gradient

func growing() -> Curve:
	var curve := Curve.new()
	curve.max_value = 2.5
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 2.5))
	return curve

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
	return constant_ramp(CONFETTI)

# Dust thrown up by a bite, scaled to both the object and the hole.
func puff(at: Vector3, object_radius: float, hole_radius: float) -> void:
	var particles := puffs[next_puff]
	particles.visible = true
	next_puff = (next_puff + 1) % PUFFS
	particles.position = Vector3(at.x, 0.2, at.z)
	particles.amount = clampi(3 + int(object_radius * 8.0), 3, 10)
	var speed: float = particles.get_meta("speed", 1.0)
	particles.initial_velocity_min = hole_radius * 1.2 * speed
	particles.initial_velocity_max = hole_radius * 2.4 * speed
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
