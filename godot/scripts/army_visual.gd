extends Node3D

# Rounds, smoke trails, muzzle flashes and air bursts for army.gd. One
# multimesh per look, tinted per instance: a handful of draw calls however
# many guns are firing.
const Army = preload("res://scripts/army.gd")
const TRACER_LENGTH := 1.6
const FLASH_TIME := 0.09
const TRAIL_PUFFS := 5
const BODY_COLOR := {"rocket":Color("d9d3b0"), "shell":Color("3a3f45"), "flak":Color("2f3338"), "missile":Color("f4f4f4")}
const BODY_SCALE := {"rocket":1.0, "shell":0.75, "flak":0.65, "missile":1.6}
const BLAST_COLOR := {"spark":Color("fff7d6"), "boom":Color("ffae3a"), "flak":Color("3a3d42")}

var tracers: MultiMesh
var bodies: MultiMesh
var trails: MultiMesh
var flashes: MultiMesh
var blasts: MultiMesh

func _ready() -> void:
	var rod := CylinderMesh.new()
	rod.top_radius = 0.07
	rod.bottom_radius = 0.045
	rod.height = 1.0
	rod.radial_segments = 5
	rod.rings = 1
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.09
	capsule.height = 0.55
	capsule.radial_segments = 8
	capsule.rings = 2
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	ball.radial_segments = 8
	ball.rings = 4
	tracers = pool(rod, Army.MAX_SHOTS)
	bodies = pool(capsule, Army.MAX_SHOTS)
	trails = pool(ball, Army.MAX_SHOTS*TRAIL_PUFFS)
	flashes = pool(ball, Army.MAX_SHOTS)
	blasts = pool(ball, Army.MAX_BLASTS*2)

func pool(source: PrimitiveMesh, count: int) -> MultiMesh:
	var mesh: PrimitiveMesh = source.duplicate()
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	mesh.material = glow
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = count
	multi.visible_instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multi

static func put(multi: MultiMesh, index: int, transform: Transform3D, color: Color) -> int:
	if index >= multi.instance_count: return index
	multi.set_instance_transform(index, transform)
	multi.set_instance_color(index, color)
	return index + 1

static func along(direction: Vector3, length: float, width := 1.0) -> Basis:
	return Basis(Quaternion(Vector3.UP, direction))*Basis.from_scale(Vector3(width, length, width))

func update(army, active: bool) -> void:
	var counts := {"tracer":0, "body":0, "trail":0, "flash":0, "blast":0}
	if active:
		for shot in army.shots: draw_shot(shot, counts)
		for blast in army.blasts: draw_blast(blast, counts)
	tracers.visible_instance_count = counts.tracer
	bodies.visible_instance_count = counts.body
	trails.visible_instance_count = counts.trail
	flashes.visible_instance_count = counts.flash
	blasts.visible_instance_count = counts.blast

func draw_shot(shot: Dictionary, counts: Dictionary) -> void:
	var pos: Vector3 = Army.shot_position(shot)
	var direction: Vector3 = Army.shot_direction(shot)
	if shot.time < FLASH_TIME*(1.0 if shot.kind == "bullet" else 2.5):
		var flash_size := 2.6 if shot.kind == "bullet" else 3.6
		counts.flash = put(flashes, counts.flash, Transform3D(Basis.from_scale(Vector3.ONE*flash_size), shot.start), Color("ffcf5a"))
	if shot.kind == "bullet":
		counts.tracer = put(tracers, counts.tracer, Transform3D(along(direction, TRACER_LENGTH), pos - direction*TRACER_LENGTH*0.5), Color("ffd23f"))
		return
	var size: float = BODY_SCALE[shot.kind]
	counts.body = put(bodies, counts.body, Transform3D(along(direction, size, size), pos), BODY_COLOR[shot.kind])
	if shot.kind in ["rocket", "missile"]:
		# Smoke puffs strung out behind, growing and fading back to grey.
		for k in TRAIL_PUFFS:
			var back := direction*(0.35 + k*0.4)*size
			var puff := (0.8 + k*0.35)*size
			var tone := lerpf(1.0, 0.7, float(k)/TRAIL_PUFFS)
			counts.trail = put(trails, counts.trail, Transform3D(Basis.from_scale(Vector3.ONE*puff), pos - back), Color(tone, tone, tone*0.98) if k > 0 else Color("ffb347"))

func draw_blast(blast: Dictionary, counts: Dictionary) -> void:
	var age: float = 1.0 - blast.time/blast.duration
	var color: Color = BLAST_COLOR[blast.kind]
	if blast.kind == "spark":
		counts.blast = put(blasts, counts.blast, Transform3D(Basis.from_scale(Vector3.ONE*(0.6 + age*1.4)), blast.position), color)
		return
	# Burst: a ball that swells to the blast radius, white-hot, then its own
	# colour, then cooling to smoke.
	var radius: float = blast.size*(0.4 + age*0.6)/0.12
	var tint: Color = Color("fff3b0").lerp(color, minf(1.0, age*3.0)).lerp(Color("5a5d63"), maxf(0.0, age - 0.35))
	counts.blast = put(blasts, counts.blast, Transform3D(Basis.from_scale(Vector3.ONE*radius), blast.position), tint)
