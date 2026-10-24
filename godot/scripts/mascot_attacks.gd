extends Node3D

# Guardian attacks. launch() queues the telegraphed defence strikes for one attack
# (the red-ringed ground zone under the hole is what the player dodges); this node
# draws them: fire, water and lightning shoot from the guardian's mouth up to the
# saucer over the zone (shaders/attack_beam.gdshader), splashing, burning or
# sparking where they hit, and a leap is drawn by the guardian itself jumping to
# ram the saucer. Pools are built once; nothing is created while fighting.
const Defense = preload("res://scripts/defense.gd")
const BEAM_SHADER := preload("res://shaders/attack_beam.gdshader")
const BEAM_STYLES := {"water":0, "fire":1, "lightning":2}
const CORE_COLORS := {"water":Color("e6f9ff"), "fire":Color("fff6c8"), "lightning":Color("ffffff")}
const EDGE_COLORS := {"water":Color("2f9bff"), "fire":Color("e8361b")}
const COLORS := {"fire":Color("ff7a2e"), "water":Color("4fc3ff"), "lightning":Color("ffe14d"),
	"leap":Color("c69bff"), "stomp":Color("e0b25a"), "charge":Color("ff4d6d")}
const BOLT_SEGMENTS := 7
const SPLASHES := 3
const LEAP_TIME := 1.1
const CHARGE_SPEED := 9.0
# Seconds a strike zone shows before it lands (scaled by the level's defence).
const WARNING := 0.9
# The main zone grows with the hole, so a big hole cannot shrug it off on its rim.
const ZONE_SHARE := 0.7

var beam: MeshInstance3D
var bolt: Array[MeshInstance3D] = []
var orb: MeshInstance3D
var halo: MeshInstance3D
var flash: MeshInstance3D
var flames: CPUParticles3D
var spray: CPUParticles3D
var splash: CPUParticles3D
var embers: CPUParticles3D
var sparks: CPUParticles3D
var gather: CPUParticles3D
var soft_dot: GradientTexture2D
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
	var warning: float = WARNING*defense.warning_scale
	var grown: float = game.radius*ZONE_SHARE
	match kind:
		"fire":
			# A flame jet at the saucer, licking the ground on both sides of it.
			defense.add_strike(item, muzzle, aim, maxf(1.5, grown), warning, true, color, "fire")
			for offset in [-1.6, 1.6]:
				defense.add_strike(item, muzzle, aim + side*offset - direction*0.6, 1.0, warning + 0.15, false, color, "flame")
		"water":
			# A water cannon at the saucer; the spray then rains down around it.
			defense.add_strike(item, muzzle, aim, maxf(1.4, grown), warning, true, color, "water")
			for i in SPLASHES:
				var angle := i*TAU/SPLASHES + randf()*0.6
				defense.add_strike(item, aim + Vector3(0, 5.0, 0), aim + Vector3(cos(angle), 0, sin(angle))*2.2, 0.9, warning + 0.55, false, color)
		"lightning":
			# A bolt straight up into the saucer, with a smaller arc jumping beside it.
			defense.add_strike(item, muzzle, aim, maxf(1.3, grown), warning, true, color, "lightning")
			defense.add_strike(item, muzzle, aim + side*(2.0 if randf() < 0.5 else -2.0), 1.0, warning + 0.3, false, color, "lightning")
		"leap":
			# Jump up to the saucer's height over the zone and ram it at the peak.
			var air_time := LEAP_TIME*0.5
			defense.add_strike(item, item.position, aim, maxf(item.radius*0.7 + 0.8, grown), air_time, true, color, "leap")
			game.sfx.play("shot")
			return "leap"
		"charge":
			var travel: float = maxf(0.4, flat(aim - item.position).length()/CHARGE_SPEED)
			defense.add_strike(item, muzzle, aim, maxf(item.radius*0.7 + 0.5, grown), travel + 0.15, true, color)
			game.sfx.play("shot")
			return "charge"
		_:
			# A ground-shaking ring around the guardian, one wave toward the hole.
			var facing := atan2(direction.z, direction.x)
			for i in 6:
				var angle := facing + i*TAU/6.0
				defense.add_strike(item, item.position + Vector3(0, 0.4, 0), item.position + Vector3(cos(angle), 0, sin(angle))*(item.radius + 1.8), maxf(1.6, grown), warning, true, color)
			mascot.squash = 1.0
			game.fx.ripple(item.position, item.radius + 1.0, color)
	game.fx.puff(muzzle, 0.6, 1.2)
	game.sfx.play("shot")
	return "recover"

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

static func mouth(item: Dictionary, direction: Vector3) -> Vector3:
	return item.position + Vector3(0, item.radius*1.2, 0) + direction*item.radius*0.7

# --- drawing -----------------------------------------------------------------------

func _ready() -> void:
	soft_dot = make_soft_dot()
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 12
	tube.rings = 8
	tube.cap_top = false
	tube.cap_bottom = false
	beam = shader_mesh(tube, beam_material())
	# Bolts: a white-hot core (first half) inside a tinted glow (second half).
	var core := beam_material()
	core.set_shader_parameter("style", BEAM_STYLES.lightning)
	core.set_shader_parameter("edge_color", Color("fffbe8"))
	core.render_priority = 1
	var glow := core.duplicate() as ShaderMaterial
	glow.render_priority = 0
	glow.set_shader_parameter("opacity", 0.45)
	for i in BOLT_SEGMENTS*2: bolt.append(shader_mesh(tube, core if i < BOLT_SEGMENTS else glow))
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	orb = glow_mesh(ball, false)
	var quad := QuadMesh.new()
	halo = glow_mesh(quad, true)
	flash = glow_mesh(quad, true)
	flames = jet(ramp(Color("fff1a8"), Color("ff3d1f")), 0.0)
	spray = jet(ramp(Color("e6f9ff"), Color("2f8fff")), -9.8)
	splash = burst(ramp(Color("ffffff"), Color("4fc3ff")), -9.8, 70.0, Vector2(3.0, 6.5), 0.6)
	var smoke := ramp(Color("ffe08a"), Color(0.25, 0.22, 0.22))
	smoke.add_point(0.35, Color("ff7a2e"))
	embers = burst(smoke, 3.0, 50.0, Vector2(1.0, 3.0), 0.8)
	sparks = burst(ramp(Color("fffbd0"), Color("ffe14d")), -4.0, 180.0, Vector2(3.0, 6.0), 0.35)
	gather = make_gather()
	jitter.seed = 1709

# A round white dot that fades to clear at its edge: every particle and glow uses it.
static func make_soft_dot() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.75))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	return texture

static func ramp(start: Color, end: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, start)
	gradient.set_color(1, Color(end, 0.0))
	return gradient

func beam_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = BEAM_SHADER
	return material

func shader_mesh(mesh: Mesh, material: ShaderMaterial) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node

# A flat glow (sprite) always faces the camera; otherwise a plain see-through mesh.
func glow_mesh(mesh: Mesh, sprite: bool) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if sprite:
		material.albedo_texture = soft_dot
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node

func particles(colors: Gradient, size: float, amount: int, lifetime: float) -> CPUParticles3D:
	var dot := QuadMesh.new()
	dot.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = soft_dot
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	dot.material = material
	var node := CPUParticles3D.new()
	node.mesh = dot
	node.amount = amount
	node.lifetime = lifetime
	node.emitting = false
	node.local_coords = false
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.color_ramp = colors
	add_child(node)
	return node

# The stream leaving the mouth; aim_jet() sets its speed to reach the target.
func jet(colors: Gradient, gravity: float) -> CPUParticles3D:
	var node := particles(colors, 0.3, 72, 0.45)
	node.spread = 9.0
	node.gravity = Vector3(0, gravity, 0)
	node.scale_amount_min = 0.8
	node.scale_amount_max = 3.2
	return node

# What flies off where a beam hits: water splashes, fire embers and smoke, sparks.
func burst(colors: Gradient, gravity: float, spread: float, speed: Vector2, lifetime: float) -> CPUParticles3D:
	var node := particles(colors, 0.32, 40, lifetime)
	node.direction = Vector3.UP
	node.spread = spread
	node.gravity = Vector3(0, gravity, 0)
	node.initial_velocity_min = speed.x
	node.initial_velocity_max = speed.y
	node.scale_amount_min = 0.7
	node.scale_amount_max = 2.4
	return node

# Motes drawn into the mouth while the guardian winds up, tinted per attack.
func make_gather() -> CPUParticles3D:
	var colors := ramp(Color(1, 1, 1, 0), Color.WHITE)
	colors.add_point(0.35, Color.WHITE)
	var node := particles(colors, 0.22, 32, 0.4)
	node.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	node.emission_sphere_radius = 1.2
	node.initial_velocity_min = 0.0
	node.initial_velocity_max = 0.0
	node.gravity = Vector3.ZERO
	node.radial_accel_min = -14.0
	node.radial_accel_max = -10.0
	node.scale_amount_min = 0.8
	node.scale_amount_max = 1.6
	return node

func update(game, mascot) -> void:
	for node in [beam, orb, halo, flash]: node.visible = false
	for segment in bolt: segment.visible = false
	var active := {}
	if mascot != null and game.playing:
		var item: Dictionary = mascot.item
		if mascot.state == "windup":
			draw_charge(mascot, item)
			active[gather] = true
		for strike in game.defense.strikes:
			if strike.source != item or strike.time > strike.flight: continue
			if not BEAM_STYLES.has(strike.get("style", "")): continue
			# One beam at a time, from the mouth up to the saucer over the zone.
			draw_strike(game, item, strike, active)
			break
	for node in [flames, spray, splash, embers, sparks, gather]: node.emitting = active.has(node)

func draw_strike(game, item: Dictionary, strike: Dictionary, active: Dictionary) -> void:
	var style: String = strike.style
	var start: Vector3 = mouth(item, flat(strike.target - item.position).normalized())
	var end: Vector3 = strike.target + Vector3(0, game.saucer.position.y - 0.3, 0)
	var progress := clampf(1.0 - strike.time/strike.flight, 0.0, 1.0)
	var reach := minf(1.0, progress*4.0)
	var tip := start.lerp(end, reach)
	if style == "lightning":
		var glow := bolt[BOLT_SEGMENTS].material_override as ShaderMaterial
		glow.set_shader_parameter("core_color", strike.color.lightened(0.3))
		glow.set_shader_parameter("edge_color", strike.color)
		draw_bolt(start, tip, 0.1)
	else:
		draw_beam(start, tip, style, 0.34 if style == "water" else 0.5)
		var stream := flames if style == "fire" else spray
		aim_jet(stream, start, tip)
		active[stream] = true
	if reach < 1.0: return
	var impact: CPUParticles3D = {"water":splash, "fire":embers, "lightning":sparks}[style]
	impact.global_position = end
	active[impact] = true
	draw_glow(flash, end, strike.color.lightened(0.35), (1.4 + jitter.randf()*0.7)*(1.4 if style == "lightning" else 1.0))

# A glowing ball grows in the guardian's mouth while it winds up, motes pouring in.
func draw_charge(mascot, item: Dictionary) -> void:
	var direction := Vector3(sin(item.yaw), 0, cos(item.yaw))
	var progress: float = mascot.crouch
	var color: Color = mascot.attack_color()
	var size: float = (0.2 + progress*0.7)*maxf(1.0, item.radius*0.6)
	orb.position = mouth(item, direction)
	orb.scale = Vector3.ONE*size
	(orb.material_override as StandardMaterial3D).albedo_color = Color(color.lightened(0.5), 0.6 + progress*0.4)
	orb.visible = true
	draw_glow(halo, orb.position, color, size*(2.4 + sin(Time.get_ticks_msec()*0.025)*0.3))
	gather.global_position = orb.position
	gather.emission_sphere_radius = 1.2*maxf(1.0, item.radius*0.6)
	gather.color = color

func draw_glow(node: MeshInstance3D, at: Vector3, color: Color, size: float) -> void:
	node.position = at
	node.scale = Vector3.ONE*size
	(node.material_override as StandardMaterial3D).albedo_color = Color(color, 0.8)
	node.visible = true

func draw_beam(start: Vector3, end: Vector3, style: String, width: float) -> void:
	place_tube(beam, start, end, width*(0.92 + jitter.randf()*0.16))
	var material := beam.material_override as ShaderMaterial
	material.set_shader_parameter("style", BEAM_STYLES[style])
	material.set_shader_parameter("core_color", CORE_COLORS[style])
	material.set_shader_parameter("edge_color", EDGE_COLORS[style])
	material.set_shader_parameter("beam_length", start.distance_to(end))

# A zig-zag of short tubes, re-jittered every frame so it crackles: a thin white
# core (bolt[0..]) wrapped in a wider tinted glow (bolt[BOLT_SEGMENTS..]).
func draw_bolt(start: Vector3, end: Vector3, width: float) -> void:
	var previous := start
	var offset := end - start
	var side := offset.cross(Vector3.UP).normalized() if absf(offset.normalized().y) < 0.95 else Vector3.RIGHT
	for i in BOLT_SEGMENTS:
		var t := float(i + 1)/BOLT_SEGMENTS
		var point := start + offset*t
		if i < BOLT_SEGMENTS - 1: point += side*jitter.randf_range(-0.7, 0.7) + Vector3(0, jitter.randf_range(-0.4, 0.4), 0)
		place_tube(bolt[i], previous, point, width)
		place_tube(bolt[BOLT_SEGMENTS + i], previous, point, width*3.5)
		previous = point

func place_tube(node: MeshInstance3D, start: Vector3, end: Vector3, width: float) -> void:
	var offset := end - start
	var length := offset.length()
	if length < 0.01: return
	var up := offset/length
	var basis := Basis(Quaternion(Vector3.UP, up))*Basis.from_scale(Vector3(width, length, width))
	node.transform = Transform3D(basis, (start + end)*0.5)
	node.visible = true

func aim_jet(stream: CPUParticles3D, start: Vector3, end: Vector3) -> void:
	var offset := end - start
	if offset.length() < 0.01: return
	stream.global_position = start
	stream.direction = offset.normalized()
	stream.initial_velocity_min = offset.length()/stream.lifetime*0.8
	stream.initial_velocity_max = offset.length()/stream.lifetime*1.1
