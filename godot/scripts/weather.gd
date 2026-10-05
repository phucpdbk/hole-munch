extends Node3D

# Bounded CPU emitters (falling rain/snow/leaves plus rain splashes on the
# ground) that follow the camera, and for fog a single full-screen veil with a
# clear window around the saucer. No dynamic lights, physics or screen reads.
const FogVeil = preload("res://shaders/fog_veil.gdshader")
const Precipitation = preload("res://shaders/precipitation.gdshader")
# The fog window: world units of clear view around the saucer, growing with the hole.
const FOG_CLEAR_BASE := 3.2
const FOG_CLEAR_PER_RADIUS := 1.4
const DROP_HEIGHT := 10.0
const JUMP_REFILL := 12.0

var particles: CPUParticles3D
var splashes: CPUParticles3D
var veil_layer: CanvasLayer
var veil: ColorRect
var veil_material: ShaderMaterial
var precip: ColorRect
var precip_material: ShaderMaterial
var kind := "clear"
var clock := 0.0
var environment: Environment
var sun: DirectionalLight3D
var base_energy := 0.85
var last_at := Vector3.ZERO

func _ready() -> void:
	particles = make_emitter()
	splashes = make_emitter()
	veil_material = ShaderMaterial.new()
	veil_material.shader = FogVeil
	precip_material = ShaderMaterial.new()
	precip_material.shader = Precipitation
	veil_layer = CanvasLayer.new()
	# Above the 3D city, below the HUD (layer 1) so timer and goals stay readable.
	veil_layer.layer = 0
	add_child(veil_layer)
	precip = screen_rect(precip_material)
	veil = screen_rect(veil_material)

func screen_rect(material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.visible = false
	veil_layer.add_child(rect)
	return rect

func make_emitter() -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.emitting = false
	emitter.local_coords = false
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emitter.visibility_aabb = AABB(Vector3(-40,-20,-40), Vector3(80,40,80))
	add_child(emitter)
	return emitter

func configure(value: String, env: Environment, light: DirectionalLight3D, sky: Color) -> void:
	kind = value
	clock = 0.0
	environment = env
	sun = light
	base_energy = 0.95 if kind == "sun" else 0.58 if kind in ["rain","storm"] else 0.64 if kind == "fog" else 0.78 if kind == "snow" else 0.85
	sun.light_energy = base_energy
	sun.light_color = Color("ffe4b7") if kind == "sun" else Color("dde8ff") if kind in ["rain","storm","snow"] else Color("fff0da")
	# Wet weather greys the sky; snow whitens the distance.
	var wet := kind in ["rain", "storm"]
	environment.background_color = sky.darkened(0.3).lerp(Color("7d8a96"), 0.35) if wet else sky.lerp(Color("eef4f7"), 0.4) if kind == "snow" else sky
	environment.fog_enabled = kind in ["fog", "storm", "snow", "rain"]
	environment.fog_light_color = environment.background_color
	environment.fog_density = 0.012 if kind == "fog" else 0.007 if kind == "snow" else 0.005 if wet else 0.003
	veil.visible = false
	veil_material.set_shader_parameter("tint", sky.lerp(Color("e4e9ec"), 0.55))
	# The screen layer makes rain and snow read as thick; the 3D drops add depth.
	precip.visible = kind in ["rain", "storm", "snow"]
	precip_material.set_shader_parameter("mode", 2 if kind == "snow" else 1)
	precip_material.set_shader_parameter("heavy", 1.0 if kind == "storm" else 0.6 if kind == "snow" else 0.45)
	precip_material.set_shader_parameter("slant", 0.32 if kind == "storm" else 0.1)
	precip_material.set_shader_parameter("tint", Color(0.95, 0.97, 1.0, 0.1) if kind == "snow" else Color(0.14, 0.18, 0.26, 0.2 if kind == "storm" else 0.14))
	match kind:
		"rain", "storm": setup_rain(kind == "storm")
		"snow": setup_snow()
		"wind": setup_wind()
		_: setup_none()

func setup_none() -> void:
	for emitter in [particles, splashes]:
		emitter.emitting = false
		emitter.visible = false

func start(emitter: CPUParticles3D) -> void:
	# Place the box before the pre-run so the first drops already fill the view.
	follow_camera(last_at, get_viewport().get_camera_3d())
	emitter.speed_scale = 1.0
	emitter.preprocess = emitter.lifetime
	emitter.visible = true
	emitter.restart()
	emitter.emitting = true

# Thin, translucent streaks that stay upright toward the camera, slanted by the
# storm wind, plus short-lived rings where drops hit the ground.
func setup_rain(storm: bool) -> void:
	var streak := QuadMesh.new()
	streak.size = Vector2(0.055, 1.05)
	streak.material = particle_material(streak_texture(), BaseMaterial3D.BILLBOARD_FIXED_Y)
	particles.mesh = streak
	particles.amount = 760 if storm else 560
	particles.lifetime = 0.6
	particles.direction = Vector3(0.32, -1, 0.12) if storm else Vector3(0.1, -1, 0.04)
	particles.spread = 4
	particles.initial_velocity_min = 22
	particles.initial_velocity_max = 28
	particles.gravity = Vector3.ZERO
	particles.angular_velocity_min = 0
	particles.angular_velocity_max = 0
	particles.tangential_accel_min = 0
	particles.tangential_accel_max = 0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.25
	particles.color = Color(0.86, 0.91, 1.0, 0.78)
	particles.color_ramp = null
	start(particles)
	var ring := QuadMesh.new()
	ring.orientation = PlaneMesh.FACE_Y
	ring.size = Vector2(0.42, 0.42)
	ring.material = particle_material(ring_texture(), BaseMaterial3D.BILLBOARD_DISABLED)
	splashes.mesh = ring
	splashes.amount = 260 if storm else 190
	splashes.lifetime = 0.38
	splashes.direction = Vector3.UP
	splashes.spread = 0
	splashes.initial_velocity_min = 0
	splashes.initial_velocity_max = 0
	splashes.gravity = Vector3.ZERO
	splashes.scale_amount_min = 0.6
	splashes.scale_amount_max = 1.3
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.2))
	grow.add_point(Vector2(1, 1))
	splashes.scale_amount_curve = grow
	splashes.color = Color(0.86, 0.92, 1.0, 0.7)
	splashes.color_ramp = fade_ramp()
	start(splashes)

# Soft round flakes of mixed size drifting down slowly and swirling a little.
func setup_snow() -> void:
	var flake := QuadMesh.new()
	flake.size = Vector2(0.2, 0.2)
	flake.material = particle_material(flake_texture(), BaseMaterial3D.BILLBOARD_PARTICLES)
	particles.mesh = flake
	particles.amount = 820
	particles.lifetime = 6.5
	particles.direction = Vector3(0.18, -1, 0.06)
	particles.spread = 28
	particles.initial_velocity_min = 1.1
	particles.initial_velocity_max = 2.1
	particles.gravity = Vector3(0.2, -0.25, 0.08)
	particles.angular_velocity_min = 0
	particles.angular_velocity_max = 0
	particles.tangential_accel_min = -0.35
	particles.tangential_accel_max = 0.35
	particles.scale_amount_min = 0.45
	particles.scale_amount_max = 1.5
	particles.color = Color(1, 1, 1, 0.92)
	particles.color_ramp = null
	start(particles)
	splashes.emitting = false
	splashes.visible = false

func setup_wind() -> void:
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.16,0.025,0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("e6b67b")
	leaf.material = mat
	particles.mesh = leaf
	particles.amount = 36
	particles.lifetime = 5
	particles.direction = Vector3(1,-0.4,0.2)
	particles.spread = 5
	particles.initial_velocity_min = 3
	particles.initial_velocity_max = 5
	particles.gravity = Vector3.ZERO
	particles.angular_velocity_min = -140
	particles.angular_velocity_max = 140
	particles.tangential_accel_min = 0
	particles.tangential_accel_max = 0
	particles.scale_amount_min = 1
	particles.scale_amount_max = 1
	particles.color = Color.WHITE
	particles.color_ramp = null
	start(particles)
	splashes.emitting = false
	splashes.visible = false

func particle_material(texture: Texture2D, billboard: BaseMaterial3D.BillboardMode) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = texture
	mat.billboard_mode = billboard
	mat.billboard_keep_scale = true
	mat.disable_receive_shadows = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func fade_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	return ramp

# A streak brightest at its lower tip and fading toward its tail.
func streak_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 1))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 32
	texture.fill_from = Vector2(0.5, 0)
	texture.fill_to = Vector2(0.5, 1)
	return texture

func flake_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	return radial_texture(gradient)

func ring_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	return radial_texture(gradient)

func radial_texture(gradient: Gradient) -> Texture2D:
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture

# hole_radius > 0 while a round is on screen; it sizes the fog window.
func update(dt: float, at: Vector3, frozen: bool, hole_radius: float = 0.0) -> void:
	particles.speed_scale = 0.0 if frozen else 1.0
	splashes.speed_scale = particles.speed_scale
	var camera := get_viewport().get_camera_3d()
	update_veil(at, hole_radius, camera)
	if precip.visible:
		precip_material.set_shader_parameter("rect_size", get_viewport().get_visible_rect().size)
		precip_material.set_shader_parameter("clock", clock)
	if frozen: return
	clock += dt
	# A new round or city moves the hole at once; refill the sky over it.
	var jumped := at.distance_to(last_at) > JUMP_REFILL
	follow_camera(at, camera)
	if jumped:
		for emitter in [particles, splashes]:
			if emitter.emitting: start(emitter)
	# A gentle change in overcast light, deliberately no strobing full-screen flash.
	sun.light_energy = base_energy + (maxf(0.0, sin(clock*0.65)-0.94)*3.0 if kind == "storm" else 0.0)

# Emitters cover what the camera sees, however far it has zoomed out.
func follow_camera(at: Vector3, camera: Camera3D) -> void:
	last_at = at
	var span := maxf(camera.size if camera != null else 24.0, 20.0)
	particles.position = Vector3(at.x + 2.5, DROP_HEIGHT, at.z + 3.0)
	particles.emission_box_extents = Vector3(span*0.8, 1.2, span*0.8)
	splashes.position = Vector3(at.x, 0.2, at.z)
	splashes.emission_box_extents = Vector3(span*0.6, 0.0, span*0.6)

func update_veil(at: Vector3, hole_radius: float, camera: Camera3D) -> void:
	veil.visible = kind == "fog" and hole_radius > 0.0 and camera != null
	if not veil.visible: return
	var screen := get_viewport().get_visible_rect().size
	# The window centres between the hole and its saucer so both stay in view.
	var centre := at + Vector3(0, 1.7 + hole_radius*0.45, 0)
	var pixels_per_unit := screen.y/maxf(camera.size, 1.0)
	veil_material.set_shader_parameter("rect_size", screen)
	veil_material.set_shader_parameter("center", camera.unproject_position(centre))
	veil_material.set_shader_parameter("clear_radius", (FOG_CLEAR_BASE + hole_radius*FOG_CLEAR_PER_RADIUS)*pixels_per_unit)
	veil_material.set_shader_parameter("clock", clock)
