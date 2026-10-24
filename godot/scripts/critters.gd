extends Node3D

# A toy animal with real moving limbs for the snake daily (snake_trail.gd): a
# puppy, kitten, piglet, bunny or chick built from primitives, with its legs,
# head, ears, tail and wings on their own pivots. animate() swings them by
# gait instead of sliding the whole body: puppies, kittens and piglets trot
# (diagonal legs together), bunnies hop (front and back pairs together, the
# body arcing up), chicks waddle on two legs and flap. Standing still, they
# breathe, wag and look about. Every animal faces +z, about HEIGHT tall.
const KINDS := ["puppy", "kitten", "piglet", "bunny", "chick"]
const HEIGHT := 0.8

var kind := "puppy"
var body: Node3D
var pivots := {}
var phase := 0.0
var clock := 0.0
var last := Vector3.INF
var speed := 0.0

# --- build -----------------------------------------------------------------------

func build(models, kind_index: int) -> void:
	kind = KINDS[kind_index % KINDS.size()]
	clock = float(kind_index)*1.7
	body = Node3D.new()
	add_child(body)
	var spec := parts(models)
	body.add_child(mesh(models, spec.body))
	for name in spec.pivots:
		var pivot := Node3D.new()
		pivot.position = spec.pivots[name][0]
		pivot.add_child(mesh(models, spec.pivots[name][1]))
		body.add_child(pivot)
		pivots[name] = pivot

func mesh(models, list: Array) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = models.bake(list)
	return node

# Eyes with a white glint, so the faces read as cute from the camera above.
static func eyes(m, list: Array, centre: Vector3, gap: float, size: float) -> void:
	for side in [-1, 1]:
		var at := centre + Vector3(side*gap, 0, 0)
		list.append(m.piece("ball", at, Vector3.ONE*size, Color("1d2430")))
		list.append(m.piece("ball", at + Vector3(side*size*0.25, size*0.35, size*0.7), Vector3.ONE*size*0.35, Color("ffffff")))

static func cheeks(m, list: Array, centre: Vector3, gap: float) -> void:
	for side in [-1, 1]:
		list.append(m.piece("ball", centre + Vector3(side*gap, 0, 0), Vector3(0.05, 0.03, 0.02), Color("ff8fa8")))

# {body: parts, pivots: {name: [hip position, parts below it]}} for the kind.
func parts(m) -> Dictionary:
	match kind:
		"kitten": return kitten(m)
		"piglet": return piglet(m)
		"bunny": return bunny(m)
		"chick": return chick(m)
	return puppy(m)

# Four legs hanging from hips at (±x, y, ±z), each `length` long.
static func legs(m, pivots: Dictionary, x: float, y: float, z_front: float, z_back: float, length: float, color: Color, paw: Color) -> void:
	for name in ["fl", "fr", "bl", "br"]:
		var side := -1.0 if name.ends_with("l") else 1.0
		var z := z_front if name.begins_with("f") else z_back
		pivots[name] = [Vector3(side*x, y, z), [
			m.piece("cyl", Vector3(0, -length/2, 0), Vector3(0.075, length, 0.075), color),
			m.piece("ball", Vector3(0, -length + 0.03, 0.02), Vector3(0.08, 0.05, 0.09), paw)]]

func puppy(m) -> Dictionary:
	var fur := Color("e8c39e")
	var dark := Color("9a6a43")
	var cream := Color("fff1dc")
	var list: Array = []
	list.append(m.piece("smooth", Vector3(0, 0.36, 0), Vector3(0.2, 0.18, 0.28), fur))
	list.append(m.piece("smooth", Vector3(0, 0.32, 0.06), Vector3(0.15, 0.13, 0.2), cream))
	var pivots := {}
	var head: Array = []
	head.append(m.piece("smooth", Vector3(0, 0.1, 0.06), Vector3.ONE*0.19, fur))
	head.append(m.piece("smooth", Vector3(0, 0.04, 0.2), Vector3(0.1, 0.08, 0.09), cream))
	head.append(m.piece("ball", Vector3(0, 0.08, 0.29), Vector3(0.04, 0.03, 0.03), Color("2b2024")))
	eyes(m, head, Vector3(0, 0.15, 0.2), 0.075, 0.03)
	cheeks(m, head, Vector3(0, 0.06, 0.2), 0.12)
	pivots.head = [Vector3(0, 0.5, 0.22), head]
	for side in [-1, 1]:
		pivots["ear_" + ("l" if side < 0 else "r")] = [Vector3(side*0.15, 0.7, 0.26), [
			m.piece("smooth", Vector3(side*0.03, -0.09, 0), Vector3(0.05, 0.12, 0.08), dark, Vector3(0, 0, side*0.3))]]
	pivots.tail = [Vector3(0, 0.44, -0.26), [m.piece("smooth", Vector3(0, 0.08, -0.04), Vector3(0.035, 0.11, 0.035), fur, Vector3(-0.6, 0, 0))]]
	legs(m, pivots, 0.1, 0.28, 0.14, -0.14, 0.24, fur, cream)
	return {"body":list, "pivots":pivots}

func kitten(m) -> Dictionary:
	var fur := Color("ffa94d")
	var stripe := Color("e07a1f")
	var cream := Color("fff4e0")
	var list: Array = []
	list.append(m.piece("smooth", Vector3(0, 0.36, 0), Vector3(0.17, 0.16, 0.27), fur))
	for z in [-0.12, 0.0, 0.12]: list.append(m.piece("smooth", Vector3(0, 0.48, z), Vector3(0.12, 0.04, 0.035), stripe))
	list.append(m.piece("smooth", Vector3(0, 0.3, 0.08), Vector3(0.12, 0.1, 0.16), cream))
	var pivots := {}
	var head: Array = []
	head.append(m.piece("smooth", Vector3(0, 0.1, 0.04), Vector3(0.2, 0.17, 0.17), fur))
	head.append(m.piece("smooth", Vector3(0, 0.05, 0.16), Vector3(0.08, 0.06, 0.05), cream))
	head.append(m.piece("ball", Vector3(0, 0.08, 0.21), Vector3(0.025, 0.02, 0.02), Color("ff6b8a")))
	for side in [-1, 1]:
		head.append(m.piece("point", Vector3(side*0.11, 0.27, 0.02), Vector3(0.07, 0.13, 0.05), fur, Vector3(0, 0, -side*0.25)))
		head.append(m.piece("point", Vector3(side*0.11, 0.26, 0.04), Vector3(0.04, 0.09, 0.02), Color("ffc2cd"), Vector3(0, 0, -side*0.25)))
		for k in [-1, 1]: head.append(m.piece("box", Vector3(side*0.13, 0.05 + k*0.02, 0.17), Vector3(0.12, 0.006, 0.006), Color("ffffff"), Vector3(0, 0, side*k*0.15)))
	eyes(m, head, Vector3(0, 0.13, 0.17), 0.075, 0.035)
	head.append(m.piece("ball", Vector3(-0.075, 0.13, 0.19), Vector3(0.02, 0.03, 0.01), Color("2f9e44")))
	head.append(m.piece("ball", Vector3(0.075, 0.13, 0.19), Vector3(0.02, 0.03, 0.01), Color("2f9e44")))
	pivots.head = [Vector3(0, 0.5, 0.22), head]
	pivots.tail = [Vector3(0, 0.42, -0.25), [
		m.piece("cyl", Vector3(0, 0.14, -0.06), Vector3(0.03, 0.3, 0.03), fur, Vector3(-0.4, 0, 0)),
		m.piece("ball", Vector3(0, 0.28, -0.12), Vector3.ONE*0.035, stripe)]]
	legs(m, pivots, 0.09, 0.28, 0.14, -0.14, 0.24, fur, cream)
	return {"body":list, "pivots":pivots}

func piglet(m) -> Dictionary:
	var skin := Color("ffb3c1")
	var deep := Color("ff8fa8")
	var list: Array = []
	list.append(m.piece("smooth", Vector3(0, 0.36, 0), Vector3(0.23, 0.2, 0.28), skin))
	var pivots := {}
	var head: Array = []
	head.append(m.piece("smooth", Vector3(0, 0.06, 0.05), Vector3(0.2, 0.18, 0.17), skin))
	head.append(m.piece("cyl", Vector3(0, 0.03, 0.2), Vector3(0.08, 0.06, 0.08), deep, Vector3(PI/2, 0, 0)))
	for side in [-1, 1]:
		head.append(m.piece("ball", Vector3(side*0.03, 0.03, 0.235), Vector3(0.015, 0.02, 0.01), Color("c2566e")))
		head.append(m.piece("point", Vector3(side*0.12, 0.22, 0.02), Vector3(0.06, 0.1, 0.04), deep, Vector3(0.5, 0, -side*0.4)))
	eyes(m, head, Vector3(0, 0.12, 0.17), 0.08, 0.03)
	cheeks(m, head, Vector3(0, 0.04, 0.17), 0.13)
	pivots.head = [Vector3(0, 0.44, 0.24), head]
	pivots.tail = [Vector3(0, 0.42, -0.28), [m.piece("ring", Vector3(0, 0.04, -0.02), Vector3(0.05, 0.08, 0.05), deep, Vector3(0, PI/2, 0))]]
	legs(m, pivots, 0.12, 0.24, 0.14, -0.14, 0.2, skin, deep)
	return {"body":list, "pivots":pivots}

func bunny(m) -> Dictionary:
	var fur := Color("f7f4ee")
	var pink := Color("ffb3c1")
	var list: Array = []
	list.append(m.piece("smooth", Vector3(0, 0.3, -0.02), Vector3(0.19, 0.19, 0.24), fur))
	list.append(m.piece("smooth", Vector3(0, 0.34, -0.25), Vector3.ONE*0.08, Color("ffffff")))
	var pivots := {}
	var head: Array = []
	head.append(m.piece("smooth", Vector3(0, 0.1, 0.04), Vector3(0.17, 0.16, 0.16), fur))
	head.append(m.piece("ball", Vector3(0, 0.06, 0.19), Vector3(0.025, 0.02, 0.02), Color("ff6b8a")))
	eyes(m, head, Vector3(0, 0.14, 0.16), 0.07, 0.035)
	cheeks(m, head, Vector3(0, 0.06, 0.16), 0.11)
	pivots.head = [Vector3(0, 0.44, 0.16), head]
	for side in [-1, 1]:
		pivots["ear_" + ("l" if side < 0 else "r")] = [Vector3(side*0.06, 0.68, 0.18), [
			m.piece("smooth", Vector3(0, 0.15, 0), Vector3(0.05, 0.17, 0.035), fur),
			m.piece("smooth", Vector3(0, 0.15, 0.02), Vector3(0.03, 0.13, 0.02), pink)]]
	# Big back feet and short front paws.
	for name in ["fl", "fr"]:
		var side := -1.0 if name.ends_with("l") else 1.0
		pivots[name] = [Vector3(side*0.08, 0.2, 0.14), [m.piece("smooth", Vector3(0, -0.09, 0.02), Vector3(0.05, 0.1, 0.05), fur)]]
	for name in ["bl", "br"]:
		var side := -1.0 if name.ends_with("l") else 1.0
		pivots[name] = [Vector3(side*0.12, 0.2, -0.1), [
			m.piece("smooth", Vector3(0, -0.06, 0), Vector3(0.07, 0.12, 0.09), fur),
			m.piece("smooth", Vector3(0, -0.17, 0.07), Vector3(0.06, 0.035, 0.12), fur)]]
	return {"body":list, "pivots":pivots}

func chick(m) -> Dictionary:
	var yellow := Color("ffe066")
	var orange := Color("ff9a3c")
	var list: Array = []
	list.append(m.piece("smooth", Vector3(0, 0.34, 0), Vector3(0.21, 0.2, 0.22), yellow))
	list.append(m.piece("smooth", Vector3(0, 0.56, 0.06), Vector3.ONE*0.15, Color("ffe680")))
	list.append(m.piece("point", Vector3(0, 0.55, 0.22), Vector3(0.045, 0.08, 0.03), orange, Vector3(PI/2, 0, 0)))
	list.append(m.piece("smooth", Vector3(0, 0.72, 0.04), Vector3(0.03, 0.05, 0.05), Color("ffd23f")))
	eyes(m, list, Vector3(0, 0.6, 0.18), 0.065, 0.028)
	cheeks(m, list, Vector3(0, 0.53, 0.17), 0.1)
	list.append(m.piece("smooth", Vector3(0, 0.38, -0.2), Vector3(0.06, 0.05, 0.05), Color("ffd23f"), Vector3(-0.6, 0, 0)))
	var pivots := {}
	for side in [-1, 1]:
		var name := "l" if side < 0 else "r"
		pivots["leg_" + name] = [Vector3(side*0.07, 0.17, 0.0), [
			m.piece("cyl", Vector3(0, -0.07, 0), Vector3(0.02, 0.14, 0.02), orange),
			m.piece("box", Vector3(0, -0.14, 0.04), Vector3(0.08, 0.02, 0.1), orange)]]
		pivots["wing_" + name] = [Vector3(side*0.2, 0.4, 0.0), [
			m.piece("smooth", Vector3(side*0.03, -0.04, -0.02), Vector3(0.04, 0.1, 0.12), Color("ffd23f"))]]
	return {"body":list, "pivots":pivots}

# --- motion -------------------------------------------------------------------------

# Moves the animal by its own displacement since the last frame (or the
# speed given), swinging its limbs by gait.
func animate(dt: float, override_speed := -1.0) -> void:
	clock += dt
	if dt > 0.0:
		var moved := 0.0 if last == Vector3.INF else Vector2(position.x - last.x, position.z - last.z).length()/dt
		speed = lerpf(speed, override_speed if override_speed >= 0 else moved, 1.0 - exp(-dt*12.0))
	last = position
	var moving := clampf(speed/3.0, 0.0, 1.0)
	if speed > 0.15: phase += dt*(7.0 + speed*2.0)
	match kind:
		"bunny": hop(moving)
		"chick": waddle(moving)
		_: trot(moving)
	# Idle life: a wagging tail and a head that looks about.
	if pivots.has("tail"): pivots.tail.rotation = Vector3(0, sin(clock*(14.0 if moving > 0.1 else 5.0))*0.5, 0)
	if pivots.has("head"): pivots.head.rotation = Vector3(sin(phase*2.0)*0.06*moving, sin(clock*0.9)*0.35*(1.0 - moving), 0)

func swing(name: String, angle: float) -> void:
	if pivots.has(name): pivots[name].rotation.x = angle

func trot(moving: float) -> void:
	var stride := sin(phase)*0.75*moving
	swing("fl", stride)
	swing("br", stride)
	swing("fr", -stride)
	swing("bl", -stride)
	body.position.y = absf(cos(phase))*0.05*moving + sin(clock*3.0)*0.006
	body.rotation.x = sin(phase*2.0)*0.04*moving
	for ear in ["ear_l", "ear_r"]:
		if pivots.has(ear): pivots[ear].rotation.x = -0.3*moving + sin(phase*2.0)*0.15*moving

func hop(moving: float) -> void:
	var lift := maxf(0.0, sin(phase))
	body.position.y = lift*0.22*moving + sin(clock*3.0)*0.006
	body.rotation.x = -cos(phase)*0.25*moving
	swing("fl", -0.6*lift*moving + 0.3*moving)
	swing("fr", -0.6*lift*moving + 0.3*moving)
	swing("bl", 0.9*lift*moving)
	swing("br", 0.9*lift*moving)
	for ear in ["ear_l", "ear_r"]:
		if pivots.has(ear): pivots[ear].rotation.x = -0.6*lift*moving + sin(clock*2.0)*0.05

func waddle(moving: float) -> void:
	var step := sin(phase)
	swing("leg_l", step*0.8*moving)
	swing("leg_r", -step*0.8*moving)
	body.rotation.z = step*0.14*moving
	body.position.y = absf(step)*0.04*moving + sin(clock*3.0)*0.006
	var flap := sin(clock*(22.0 if moving > 0.5 else 3.0))*(0.7*moving + 0.08)
	if pivots.has("wing_l"): pivots.wing_l.rotation.z = -flap
	if pivots.has("wing_r"): pivots.wing_r.rotation.z = flap
