extends Node3D

# One bounded emitter, no dynamic lights, physics or screen-space post effects.
var particles: CPUParticles3D
var kind := "clear"
var clock := 0.0
var environment: Environment
var sun: DirectionalLight3D
var base_energy := 0.85

func _ready() -> void:
	particles = CPUParticles3D.new()
	particles.emitting = false
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(16, 1, 16)
	particles.visibility_aabb = AABB(Vector3(-24,-20,-24), Vector3(48,40,48))
	add_child(particles)

func configure(value: String, env: Environment, light: DirectionalLight3D, sky: Color) -> void:
	kind = value
	clock = 0.0
	environment = env
	sun = light
	base_energy = 0.95 if kind == "sun" else 0.64 if kind in ["rain","storm","fog"] else 0.85
	sun.light_energy = base_energy
	sun.light_color = Color("ffe4b7") if kind == "sun" else Color("dde8ff") if kind in ["rain","storm","snow"] else Color("fff0da")
	environment.background_color = sky
	environment.fog_enabled = kind in ["fog", "storm", "snow"]
	environment.fog_light_color = sky
	environment.fog_density = 0.012 if kind == "fog" else 0.003
	particles.emitting = false
	particles.speed_scale = 1.0
	var mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("b6d7ef")
	mesh.size = Vector3(0.025, 0.55, 0.025)
	particles.amount = 110 if kind == "storm" else 80
	particles.lifetime = 1.8
	particles.direction = Vector3(0.18,-1,0)
	particles.spread = 5
	particles.initial_velocity_min = 12
	particles.initial_velocity_max = 15
	particles.gravity = Vector3.ZERO
	particles.angular_velocity_min = 0
	particles.angular_velocity_max = 0
	if kind == "snow":
		mesh.size = Vector3(0.09,0.07,0.09)
		mat.albedo_color = Color("effbff")
		particles.amount = 95
		particles.lifetime = 7
		particles.initial_velocity_min = 2
		particles.initial_velocity_max = 3
		particles.spread = 18
	elif kind == "wind":
		mesh.size = Vector3(0.16,0.025,0.09)
		mat.albedo_color = Color("e6b67b")
		particles.amount = 36
		particles.lifetime = 5
		particles.direction = Vector3(1,-0.4,0.2)
		particles.initial_velocity_min = 3
		particles.initial_velocity_max = 5
		particles.angular_velocity_min = -140
		particles.angular_velocity_max = 140
	mesh.material = mat
	particles.mesh = mesh
	particles.preprocess = particles.lifetime
	particles.visible = kind in ["rain","storm","snow","wind"]
	if particles.visible: particles.restart()
	particles.emitting = particles.visible

func update(dt: float, at: Vector3, frozen: bool) -> void:
	particles.speed_scale = 0.0 if frozen else 1.0
	if frozen: return
	clock += dt
	position = Vector3(at.x, 12, at.z)
	# A gentle change in overcast light, deliberately no strobing full-screen flash.
	sun.light_energy = base_energy + (maxf(0.0, sin(clock*0.65)-0.94)*3.0 if kind == "storm" else 0.0)
