extends Node3D

# Special hole skins ported from the 2D game: a Christmas wreath with blinking
# bulbs, a compass bezel that points where you travel, a jewelled crown and an
# orbiting comet. Built at unit radius and scaled with the hole every frame; a
# sibling of the hole (not a child) so its xz-only scale does not squash it.
const XMAS := 8
const COMPASS := 9
const CROWN := 10
const COMET := 11
const BLINK := 0.4
var models
var style := -1
var heading := 0.0
var lights_a: MeshInstance3D
var lights_b: MeshInstance3D

func build(models_ref, index: int) -> void:
	models = models_ref
	style = index
	for child in get_children(): child.queue_free()
	lights_a = null
	lights_b = null
	rotation = Vector3.ZERO
	match index:
		XMAS: wreath()
		COMPASS: compass()
		CROWN: crown()
		COMET: comet()

func add_mesh(parts: Array) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = models.bake(parts)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func around(count: int, radius: float, y: float, make: Callable) -> Array:
	var parts: Array = []
	for i in count:
		var a := i*TAU/count
		parts.append(make.call(i, a, Vector3(cos(a)*radius, y, sin(a)*radius)))
	return parts

func wreath() -> void:
	var leaves := around(20, 1.08, 0.22, func(i, a, at):
		return models.piece("ball", at, Vector3(0.2, 0.12, 0.2), Color("2f7d46") if i%2 == 0 else Color("4aa860")))
	leaves.append(models.piece("ball", Vector3(-0.14, 0.34, 1.16), Vector3(0.16, 0.1, 0.08), Color("e8423f")))
	leaves.append(models.piece("ball", Vector3(0.14, 0.34, 1.16), Vector3(0.16, 0.1, 0.08), Color("e8423f")))
	leaves.append(models.piece("ball", Vector3(0, 0.34, 1.17), Vector3.ONE*0.07, Color("ffd24a")))
	add_mesh(leaves)
	lights_a = add_mesh(bulbs(0.0, [Color("ff4d4d"), Color("ffd24a")]))
	lights_b = add_mesh(bulbs(PI/12, [Color("5fb8ff"), Color("fff6e0")]))

func bulbs(offset: float, colours: Array) -> Array:
	return around(12, 1.1, 0.33, func(i, a, at):
		var turn: float = a + offset
		return models.piece("ball", Vector3(cos(turn)*1.1, 0.33, sin(turn)*1.1), Vector3.ONE*0.075, colours[i%2]))

func compass() -> void:
	var parts: Array = [models.piece("ring", Vector3(0, 0.2, 0), Vector3(1.34, 0.14, 1.34), Color("f2d68a"))]
	parts.append_array(around(24, 1.24, 0.27, func(i, a, at):
		var long: bool = i%6 == 0
		return models.piece("box", at, Vector3(0.04, 0.05, 0.2 if long else 0.1), Color("2b3a3c"), Vector3(0, -a + PI/2, 0))))
	parts.append_array(around(4, 1.46, 0.24, func(i, a, at):
		var north: bool = i == 0
		var size: float = 0.2 if north else 0.14
		return models.piece("box", at, Vector3(size, size*0.4, size), Color("e8423f") if north else Color("f7f1dc"), Vector3(0, PI/4, 0))))
	add_mesh(parts)

func crown() -> void:
	var parts: Array = [models.piece("ring", Vector3(0, 0.22, 0), Vector3(1.14, 0.22, 1.14), Color("e6b95a"))]
	var gems := [Color("e8423f"), Color("4aa3ff"), Color("47c27a")]
	parts.append_array(around(8, 1.06, 0.46, func(i, a, at):
		return models.piece("point", at, Vector3(0.14, 0.5, 0.14), Color("ffd76a"))))
	parts.append_array(around(8, 1.06, 0.74, func(i, a, at):
		return models.piece("ball", at, Vector3.ONE*0.09, gems[i%gems.size()])))
	add_mesh(parts)

func comet() -> void:
	var parts: Array = [models.piece("ball", Vector3(1.12, 0.36, 0), Vector3.ONE*0.2, Color("fff6c8"))]
	for i in range(1, 8):
		var a := i*0.16
		var size := 0.2*(1.0 - i*0.11)
		var tail := Color("9fe8ff").lerp(Color("6651a9"), i/7.0)
		parts.append(models.piece("ball", Vector3(cos(a)*1.12, 0.36, sin(a)*1.12), Vector3.ONE*size, tail))
	add_mesh(parts)

# Follows the hole; each style has its own motion.
func sync(at: Vector3, radius: float, clock: float, velocity: Vector3, dt: float) -> void:
	visible = style >= XMAS and style <= COMET
	if not visible: return
	position = at
	scale = Vector3(radius, 1.0 + (radius-1.0)*0.35, radius)
	match style:
		XMAS:
			var on := fmod(clock, BLINK*2.0) < BLINK
			lights_a.visible = on
			lights_b.visible = not on
		COMPASS:
			# The red north marker swings round to the travel direction.
			if velocity.length() > 0.3: heading = atan2(-velocity.z, velocity.x)
			rotation.y = lerp_angle(rotation.y, heading, 1.0-exp(-dt*4.0))
		CROWN: rotation.y = clock*0.35
		COMET: rotation.y = clock*2.2
