extends MeshInstance3D

# A trail painted on the ground behind the hole (fx.gd): the rainbow is a soft
# fading band, the fire a burning strip that dies out from its edges. Points are
# dropped as the hole moves and age out; the ribbon is rebuilt each frame as one
# triangle strip just above the blocks' top, so it reads on roads and plazas.
const TrailShader = preload("res://shaders/ground_trail.gdshader")
const STEP := 0.3
const HEIGHT := 0.17
const MAX_POINTS := 90
# kind: [shader mode, lifetime in seconds, half width per hole radius]
const KINDS := {"rainbow":[0, 1.6, 0.85], "fire":[1, 1.5, 1.05]}

var kind := ""
var points: Array[Dictionary] = []
var head := Vector3.ZERO
var head_width := 0.0
var strip := ImmediateMesh.new()
var material := ShaderMaterial.new()

func _ready() -> void:
	mesh = strip
	material.shader = TrailShader
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The ribbon is rebuilt in world space, so it never culls against an old box.
	extra_cull_margin = 16384.0

func configure(value: String) -> void:
	kind = value if KINDS.has(value) else ""
	clear()
	if kind != "": material.set_shader_parameter("mode", KINDS[kind][0])

func clear() -> void:
	points.clear()
	strip.clear_surfaces()

# Called every frame with the hole; drops a point once it has moved far enough.
func follow(at: Vector3, moving: bool, hole_radius: float) -> void:
	if kind == "": return
	head = Vector3(at.x, HEIGHT, at.z)
	head_width = hole_radius*KINDS[kind][2]
	material.set_shader_parameter("hole_center", Vector2(at.x, at.z))
	material.set_shader_parameter("hole_radius", hole_radius)
	if not moving: return
	if points.is_empty() or points[-1].at.distance_to(head) >= STEP:
		points.append({"at":head, "age":0.0, "width":head_width})
		if points.size() > MAX_POINTS: points.pop_front()

func update(dt: float) -> void:
	if kind == "": return
	var lifetime: float = KINDS[kind][1]
	for point in points: point.age += dt
	while not points.is_empty() and points[0].age >= lifetime: points.pop_front()
	rebuild(lifetime)

func rebuild(lifetime: float) -> void:
	strip.clear_surfaces()
	var list: Array = points.duplicate()
	if not list.is_empty() and list[-1].at.distance_to(head) > 0.05: list.append({"at":head, "age":0.0, "width":head_width})
	if list.size() < 2: return
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var along := 0.0
	for i in list.size():
		var point: Dictionary = list[i]
		var ahead: Vector3 = list[mini(i + 1, list.size() - 1)].at
		var behind: Vector3 = list[maxi(i - 1, 0)].at
		var direction := (ahead - behind)*Vector3(1, 0, 1)
		if direction.length() < 0.001: direction = Vector3.FORWARD
		var side := direction.normalized().cross(Vector3.UP)*float(point.width)
		if i > 0: along += point.at.distance_to(list[i - 1].at)
		var life := clampf(1.0 - float(point.age)/lifetime, 0.0, 1.0)
		strip.surface_set_color(Color(1, 1, 1, life))
		strip.surface_set_uv(Vector2(0, along))
		strip.surface_add_vertex(point.at - side)
		strip.surface_set_color(Color(1, 1, 1, life))
		strip.surface_set_uv(Vector2(1, along))
		strip.surface_add_vertex(point.at + side)
	strip.surface_end()
