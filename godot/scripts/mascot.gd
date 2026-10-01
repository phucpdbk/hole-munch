extends Node3D

# Landmark guardian: a toy mascot (mascot_specs.gd) that keeps the landmark's
# shield up until the hole swallows it. It stands guard beside the landmark,
# crouches, then breathes fire, sprays water, stomps or charges at a hole in
# range; once the hole can eat it, it runs off in short sprints instead.
# Attacks are telegraphed defence strikes, so hits go through game.take_hit().
# The game sets this node's transform from the guardian item; the animation only
# moves the inner rig and limb pivots.
const MascotSpecs = preload("res://scripts/mascot_specs.gd")
const Traffic = preload("res://scripts/traffic.gd")
const ATTACK_COLORS := {"fire":Color("ff7a2e"), "water":Color("4fc3ff"), "stomp":Color("e0b25a"), "charge":Color("ff4d6d")}
const FIRST_COOLDOWN := 4.0
const COOLDOWN := 3.2
const WINDUP := 0.75
const RECOVER := 0.9
const RANGE := 8.0
const WALK_SPEED := 2.4
const CHARGE_SPEED := 9.0
const FLEE_SPEED := 4.8
const FLEE_DASH := 0.8
const FLEE_REST := 1.5
const ALERT := 8.0
const ARENA := 5.0

var spec: Dictionary = {}
var item: Dictionary = {}
var home := Vector3.ZERO
var state := "guard"
var timer := 0.0
var cooldown := FIRST_COOLDOWN
var aim := Vector3.ZERO
var heading := Vector3.ZERO
var clock := 0.0
var stride := 0.0
var moving := 0.0
var crouch := 0.0
var lunge := 0.0
var squash := 0.0
var rig: Node3D
var pivots := {}

func build(models, value: Dictionary) -> void:
	spec = value
	rig = Node3D.new()
	add_child(rig)
	var shape: Dictionary = MascotSpecs.shape(models, spec)
	for group in shape.parts:
		if shape.parts[group].is_empty(): continue
		var pivot := Node3D.new()
		pivot.position = shape.pivots.get(group, Vector3.ZERO)
		rig.add_child(pivot)
		var mesh := MeshInstance3D.new()
		mesh.mesh = models.bake(shape.parts[group])
		pivot.add_child(mesh)
		pivots[group] = pivot

func reset() -> void:
	state = "guard"
	timer = 0.0
	cooldown = FIRST_COOLDOWN
	heading = Vector3.ZERO
	crouch = 0.0
	lunge = 0.0
	squash = 0.0
	moving = 0.0

func attack_color() -> Color:
	return ATTACK_COLORS.get(spec.get("attack", "stomp"), Color("ff7866"))

# --- behaviour (during play) ---------------------------------------------------------

func think(game, dt: float) -> void:
	if item.is_empty() or not Traffic.is_active(item): return
	var to_hole := Vector3(game.hole_position.x - item.position.x, 0, game.hole_position.z - item.position.z)
	var distance := to_hole.length()
	moving = 0.0
	var edible: bool = item.radius <= game.radius*game.EAT_RATIO
	if edible and not state.begins_with("flee") and state != "charge":
		state = "flee_rest"
		timer = 0.4
	match state:
		"guard":
			cooldown -= dt
			walk_to(home, WALK_SPEED, dt)
			face(to_hole)
			if cooldown <= 0 and distance < RANGE + item.radius and game.defense.grace <= 0:
				state = "windup"
				timer = WINDUP
				aim = game.hole_position + game.hole_velocity*0.35
				aim.y = 0
		"windup":
			timer -= dt
			face(aim - item.position)
			if timer <= 0: attack(game)
		"charge":
			timer -= dt
			walk_to(aim, CHARGE_SPEED, dt)
			if timer <= 0 or flat(aim - item.position).length() < 0.2:
				state = "recover"
				timer = RECOVER
				squash = 1.0
				game.fx.ripple(item.position, item.radius*1.4, attack_color())
		"recover":
			timer -= dt
			if timer <= 0:
				state = "guard"
				cooldown = COOLDOWN*game.defense.cooldown_scale
		"flee_rest":
			if not edible:
				state = "guard"
				cooldown = 1.0
			timer -= dt
			if timer <= 0 and distance < ALERT + item.radius:
				state = "flee"
				timer = FLEE_DASH
				heading = -to_hole/maxf(distance, 0.001)
				# Never run away from home for good: veer back inside the arena.
				var back := flat(home - item.position)
				if back.length() > ARENA*0.6: heading = (heading + back.normalized()*0.8).normalized()
		"flee":
			timer -= dt
			item.position += heading*FLEE_SPEED*dt
			moving = FLEE_SPEED
			face(heading)
			if timer <= 0:
				state = "flee_rest"
				timer = FLEE_REST
	item.position.x = clampf(item.position.x, home.x - ARENA*1.6, home.x + ARENA*1.6)
	item.position.z = clampf(item.position.z, home.z - ARENA*1.6, home.z + ARENA*1.6)
	item.position.x = clampf(item.position.x, -game.layout.move_x, game.layout.move_x)
	item.position.z = clampf(item.position.z, -game.layout.move_z, game.layout.move_z)
	game.set_item_transform(item)

static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

func walk_to(target: Vector3, speed: float, dt: float) -> void:
	var offset := flat(target - item.position)
	if offset.length() < 0.3: return
	item.position += offset.limit_length(speed*dt)
	moving = speed
	face(offset)

func face(direction: Vector3) -> void:
	if flat(direction).length() > 0.01: item.yaw = atan2(direction.x, direction.z)

# One telegraphed attack in the spec's style, aimed at where the hole was.
func attack(game) -> void:
	var defense = game.defense
	var color := attack_color()
	var direction := flat(aim - item.position)
	direction = direction.normalized() if direction.length() > 0.01 else Vector3.BACK
	var side := Vector3(-direction.z, 0, direction.x)
	var muzzle: Vector3 = item.position + Vector3(0, item.radius*1.2, 0) + direction*item.radius*0.7
	var warning: float = 0.9*defense.warning_scale
	var reach: float = item.radius + 1.2
	match spec.get("attack", "stomp"):
		"fire":
			# A widening cone of flame.
			for spot in [[0.0, 0.0], [1.9, -0.9], [1.9, 0.9], [3.8, -1.7], [3.8, 1.7]]:
				defense.add_strike(item, muzzle, item.position + direction*(reach + spot[0]) + side*spot[1], 1.25, warning, false, color)
		"water":
			# A jet that sweeps out along a line, splash by splash.
			for i in 5:
				defense.add_strike(item, muzzle, item.position + direction*(reach + i*1.7), 1.05, warning + i*0.12, false, color)
		"charge":
			var travel: float = maxf(0.4, flat(aim - item.position).length()/CHARGE_SPEED)
			defense.add_strike(item, muzzle, aim, item.radius*0.7 + 0.5, travel + 0.15, true, color)
			state = "charge"
			timer = travel + 0.4
			lunge = 1.0
			game.sfx.play("shot")
			return
		_:
			# A ground-shaking ring around the guardian, one wave toward the hole.
			var facing := atan2(direction.z, direction.x)
			for i in 6:
				var angle := facing + i*TAU/6.0
				defense.add_strike(item, item.position + Vector3(0, 0.4, 0), item.position + Vector3(cos(angle), 0, sin(angle))*(item.radius + 1.8), 1.6, warning, true, color)
			squash = 1.0
	state = "recover"
	timer = RECOVER
	lunge = 1.0
	game.fx.puff(muzzle, 0.6, 1.2)
	game.sfx.play("shot")

# --- animation (every frame, menu included) ----------------------------------------

func animate(dt: float) -> void:
	if rig == null: return
	clock += dt
	var crouching := state == "windup"
	crouch = move_toward(crouch, 1.0 if crouching else 0.0, dt*(2.5 if crouching else 6.0))
	lunge = maxf(0.0, lunge - dt*3.0)
	squash = maxf(0.0, squash - dt*4.0)
	var running := moving > 0.1
	if running: stride += dt*(6.0 + moving*1.2)
	var bob := absf(sin(stride))*0.1 if running else sin(clock*2.6)*0.035
	var shrink := crouch*0.22 + squash*0.25
	rig.position = Vector3(0, bob - crouch*0.08, lunge*0.35)
	rig.scale = Vector3(1.0 + shrink*0.6, 1.0 - shrink, 1.0 + shrink*0.6)
	# The windup shakes a little so the attack reads from far away.
	rig.rotation = Vector3(-crouch*0.12, 0, sin(clock*40.0)*0.04*crouch)
	var swing := sin(stride)*0.8 if running else 0.0
	var winged: bool = spec.get("archetype", "") in ["bird", "dragon"]
	for group in pivots:
		var pivot: Node3D = pivots[group]
		match group:
			"leg_l", "leg_br": pivot.rotation.x = swing
			"leg_r", "leg_bl": pivot.rotation.x = -swing
			"arm_l", "arm_r":
				var sign := 1.0 if group == "arm_l" else -1.0
				if winged:
					var flap := sin(clock*(16.0 if running or crouching else 3.0))*(0.7 if running or crouching else 0.15)
					pivot.rotation = Vector3(0, 0, sign*(flap + crouch*0.6))
				else:
					pivot.rotation = Vector3(-crouch*2.2 - swing*sign*0.6, 0, sign*(0.1 + sin(clock*2.0)*0.05))
			"head": pivot.rotation = Vector3(-crouch*0.25 + lunge*0.3, sin(clock*1.3)*0.25*(1.0 - crouch), 0)
			"tail": pivot.rotation = Vector3(0, sin(clock*(9.0 if running else 3.5))*0.45, 0)
