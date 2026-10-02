extends Node3D

# Guardian attacks. launch() queues the telegraphed defence strikes for one attack
# (the red-ringed ground zone under the hole is what the player dodges); this node
# draws them: fire, water and lightning shoot from the guardian's mouth up to the
# saucer over the zone, and a leap is drawn by the guardian itself jumping to ram
# the saucer. Pools are built once; nothing is created while fighting.
const Defense = preload("res://scripts/defense.gd")
const COLORS := {"fire":Color("ff7a2e"), "water":Color("4fc3ff"), "lightning":Color("ffe14d"),
	"leap":Color("c69bff"), "stomp":Color("e0b25a"), "charge":Color("ff4d6d")}
const BOLT_SEGMENTS := 7
const SPLASHES := 3
const LEAP_TIME := 1.1
const CHARGE_SPEED := 9.0

var beam: MeshInstance3D
var bolt: Array[MeshInstance3D] = []
var orb: MeshInstance3D
var flames: CPUParticles3D
var spray: CPUParticles3D
var sparks: CPUParticles3D
var jitter := RandomNumberGenerator.new()

# --- attacks ---------------------------------------------------------------------

# Queue one attack aimed at `aim` (ground, where the hole is heading). Returns the
# state the guardian moves to: "recover", "charge" or "leap".
static func launch(mascot, game, aim: Vector3) -> String:
	var item: Dictionary = mascot.item
	var defense = game.defense
	var kind: String = mascot.spec.get("attack", "stomp")
	var color: Color = COLORS.get(kind, Color("ff7866"))
	var direction := flat(aim - item.position)
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.BACK
	var side := Vector3(-direction.z, 0, direction.x)
	var muzzle: Vector3 = mouth(item, direction)
	var warning: float = 0.9*defense.warning_scale
	match kind:
		"fire":
			# A flame jet at the saucer, licking the ground on both sides of it.
			defense.add_strike(item, muzzle, aim, 1.5, warning, true, color, "fire")
			for offset in [-1.6, 1.6]:
				defense.add_strike(item, muzzle, aim + side*offset - direction*0.6, 1.0, warning + 0.15, false, color, "flame")
		"water":
			# A water cannon at the saucer; the spray then rains down around it.
			defense.add_strike(item, muzzle, aim, 1.4, warning, true, color, "water")
			for i in SPLASHES:
				var angle := i*TAU/SPLASHES + randf()*0.6
				defense.add_strike(item, aim + Vector3(0, 5.0, 0), aim + Vector3(cos(angle), 0, sin(angle))*2.2, 0.9, warning + 0.55, false, color)
		"lightning":
			# A bolt straight up into the saucer, with a smaller arc jumping beside it.
			defense.add_strike(item, muzzle, aim, 1.3, warning, true, color, "lightning")
			defense.add_strike(item, muzzle, aim + side*(2.0 if randf() < 0.5 else -2.0), 1.0, warning + 0.3, false, color, "lightning")
		"leap":
			# Jump up to the saucer's height over the zone and ram it at the peak.
			var air_time := LEAP_TIME*0.5
			defense.add_strike(item, item.position, aim, item.radius*0.7 + 0.8, air_time, true, color, "leap")
			game.sfx.play("shot")
			return "leap"
		"charge":
			var travel: float = maxf(0.4, flat(aim - item.position).length()/CHARGE_SPEED)
			defense.add_strike(item, muzzle, aim, item.radius*0.7 + 0.5, travel + 0.15, true, color)
			game.sfx.play("shot")
			return "charge"
		_:
			# A ground-shaking ring around the guardian, one wave toward the hole.
			var facing := atan2(direction.z, direction.x)
			for i in 6:
				var angle := facing + i*TAU/6.0
				defense.add_strike(item, item.position + Vector3(0, 0.4, 0), item.position + Vector3(cos(angle), 0, sin(angle))*(item.radius + 1.8), 1.6, warning, true, color)
			mascot.squash = 1.0
	game.fx.puff(muzzle, 0.6, 1.2)
	game.sfx.play("shot")
	return "recover"

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

static func mouth(item: Dictionary, direction: Vector3) -> Vector3:
	return item.position + Vector3(0, item.radius*1.2, 0) + direction*item.radius*0.7

# --- drawing -----------------------------------------------------------------------

func _ready() -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 8
	tube.rings = 1
	beam = glow_mesh(tube)
	for i in BOLT_SEGMENTS*2: bolt.append(glow_mesh(tube))
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	orb = glow_mesh(ball)
	flames = jet(Color("ffb347"), Color("ff3d1f"), 0.0)
	spray = jet(Color("bfefff"), Color("2f8fff"), -9.8)
	sparks = jet(Color("fffbd0"), Color("ffe14d"), 0.0)
	jitter.seed = 1709

func glow_mesh(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node

func jet(start: Color, end: Color, gravity: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.12
	dot.height = 0.24
	dot.radial_segments = 6
	dot.rings = 3
	particles.mesh = dot
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	dot.material = material
	particles.amount = 72
	particles.lifetime = 0.45
	particles.emitting = false
	particles.local_coords = false
	particles.spread = 9.0
	particles.initial_velocity_min = 11.0
	particles.initial_velocity_max = 15.0
	particles.gravity = Vector3(0, gravity, 0)
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 3.2
	var ramp := Gradient.new()
	ramp.set_color(0, start)
	ramp.set_color(1, Color(end, 0.0))
	particles.color_ramp = ramp
	add_child(particles)
	return particles

func update(game, mascot) -> void:
	beam.visible = false
	orb.visible = false
	for segment in bolt: segment.visible = false
	var jets := {"fire":false, "water":false, "lightning":false}
	if mascot == null or not game.playing:
		stop_jets(jets)
		return
	var item: Dictionary = mascot.item
	if mascot.state == "windup": draw_charge(mascot, item)
	var lit := false
	for strike in game.defense.strikes:
		if strike.source != item or strike.time > strike.flight: continue
		var style: String = strike.get("style", "")
		if style not in ["fire", "water", "lightning"] or lit: continue
		# One beam at a time, from the mouth up to the saucer over the zone.
		lit = true
		var start: Vector3 = mouth(item, flat(strike.target - item.position).normalized())
		var end: Vector3 = strike.target + Vector3(0, game.saucer.position.y - 0.3, 0)
		var progress := clampf(1.0 - strike.time/strike.flight, 0.0, 1.0)
		var tip := start.lerp(end, minf(1.0, progress*4.0))
		if style == "lightning":
			# A white-hot core and a tinted branch; sparks burst where it strikes.
			draw_bolt(start, tip, Color("fffbe8"), 0, 0.22)
			draw_bolt(start, tip, strike.color, BOLT_SEGMENTS, 0.11)
			if progress*4.0 >= 1.0: burst_at(sparks, end)
		else:
			draw_beam(start, tip, strike.color, 0.34 if style == "water" else 0.5)
			aim_jet(flames if style == "fire" else spray, start, end)
		jets[style] = true
	stop_jets(jets)

func stop_jets(active: Dictionary) -> void:
	flames.emitting = active.get("fire", false)
	spray.emitting = active.get("water", false)
	sparks.emitting = active.get("lightning", false)

# A glowing ball grows in the guardian's mouth while it winds up.
func draw_charge(mascot, item: Dictionary) -> void:
	var direction := Vector3(sin(item.yaw), 0, cos(item.yaw))
	var progress: float = mascot.crouch
	orb.position = mouth(item, direction)
	orb.scale = Vector3.ONE*(0.2 + progress*0.7)*maxf(1.0, item.radius*0.6)
	(orb.material_override as StandardMaterial3D).albedo_color = Color(mascot.attack_color(), 0.55 + progress*0.4)
	orb.visible = true

func draw_beam(start: Vector3, end: Vector3, color: Color, width: float) -> void:
	place_tube(beam, start, end, width*(0.85 + jitter.randf()*0.3))
	(beam.material_override as StandardMaterial3D).albedo_color = Color(color, 0.85)

# A zig-zag of short tubes from bolt[first], re-jittered every frame so it crackles.
func draw_bolt(start: Vector3, end: Vector3, color: Color, first: int, width: float) -> void:
	var previous := start
	var offset := end - start
	var side := offset.cross(Vector3.UP).normalized() if absf(offset.normalized().y) < 0.95 else Vector3.RIGHT
	for i in BOLT_SEGMENTS:
		var t := float(i + 1)/BOLT_SEGMENTS
		var point := start + offset*t
		if i < BOLT_SEGMENTS - 1: point += side*jitter.randf_range(-0.7, 0.7) + Vector3(0, jitter.randf_range(-0.4, 0.4), 0)
		var segment: MeshInstance3D = bolt[first + i]
		place_tube(segment, previous, point, width)
		(segment.material_override as StandardMaterial3D).albedo_color = Color(color, 0.95)
		previous = point

func burst_at(particles: CPUParticles3D, at: Vector3) -> void:
	particles.global_position = at
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.0
	particles.initial_velocity_max = 6.0
	particles.emitting = true

func place_tube(node: MeshInstance3D, start: Vector3, end: Vector3, width: float) -> void:
	var offset := end - start
	var length := offset.length()
	if length < 0.01: return
	var up := offset/length
	var basis := Basis(Quaternion(Vector3.UP, up))*Basis.from_scale(Vector3(width, length, width))
	node.transform = Transform3D(basis, (start + end)*0.5)
	node.visible = true

func aim_jet(particles: CPUParticles3D, start: Vector3, end: Vector3) -> void:
	var offset := end - start
	if offset.length() < 0.01: return
	particles.global_position = start
	particles.direction = offset.normalized()
	particles.initial_velocity_min = offset.length()/particles.lifetime*0.8
	particles.initial_velocity_max = offset.length()/particles.lifetime*1.1
	particles.emitting = true
