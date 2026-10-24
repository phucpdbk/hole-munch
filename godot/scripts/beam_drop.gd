extends Node3D

# Daily mini-game "beam" (daily_games.gd), lift and drop: a board of pads on
# the plaza of a toy depot (beam_yard.gd) shows a ghost of the toy each pad
# wants, one of SHAPES shapes in one of COLORS. The toys sit in piles round
# the depot. Tap (or Space) over a pile and the saucer's tractor beam lifts
# its top toy; carry it over the pad that wants it and tap again to drop it
# in. A wrong or full pad throws the toy back up and costs WRONG_COST seconds.
# Dropped anywhere else a toy lands on the ground, or on a pile in reach up to
# MAX_STACK high, so a toy buried in a pile is dug out by moving the ones on
# top. A full board adds BOARD_BONUS seconds and the next, bigger board
# (BOARDS) comes up, with decoys no pad wants and taller piles.
const I18n = preload("res://scripts/i18n.gd")
const SHAPES := 4
const COLORS := [Color("ff5a5a"), Color("ffd23f"), Color("3a8dff"), Color("3ddc84")]
# [columns, rows, decoys, tallest pile] for each board; the last repeats.
const BOARDS := [[2, 2, 0, 1], [3, 2, 2, 2], [3, 3, 3, 2], [4, 3, 4, 3]]
const PAD := 2.2
const TOY := 0.5
const GROUND_Y := 0.16
const PAD_TOP := 0.25
const MAX_STACK := 3
# How far from the hole's centre a pile can be beamed from or dropped on.
const REACH := 1.3
# Piles lie this far from the board, at least PILE_GAP apart.
const SPREAD := Vector2(7.0, 16.0)
const PILE_GAP := 3.2
const CARRY_HEIGHT := 2.4
const LIFT_TIME := 0.35
const DROP_TIME := 0.3
const WRONG_COST := 2.0
const BOARD_BONUS := 6.0
const BOARD_PAUSE := 1.0
const CARRY_SLOW := 0.85
# A touch let go this soon, this close to where it began, is a tap.
const TAP_TIME := 0.3
const TAP_MOVE := 14.0

var rng := RandomNumberGenerator.new()
var seed_value := 0
var board := 0
# {at, shape, color, tile, ghost, toy ({} until filled)}.
var pads: Array = []
# {at, stack (bottom first)}.
var piles: Array = []
# {node, shape, color}: every toy of the board, wherever it is.
var toys: Array = []
var carried := {}
# "lift" or "drop" while the beam moves a toy, else "".
var motion := ""
var motion_t := 0.0
var motion_from := Vector3.ZERO
var motion_to := Vector3.ZERO
var target_pad := {}
var target_pile := {}
var placed := 0
var next_board := -1.0
var clock := 0.0
var press_at := Vector2.ZERO
var press_time := -1.0
var toy_meshes := {}
var ghost_meshes := {}
var ghost_materials: Array[StandardMaterial3D] = []
var column: MeshInstance3D

func _ready() -> void:
	column = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.45
	cone.bottom_radius = 0.9
	cone.height = 1.0
	column.mesh = cone
	column.material_override = glow(Color(0.55, 1.0, 0.95, 0.28))
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.visible = false
	add_child(column)
	for color in COLORS: ghost_materials.append(glow(Color(color, 0.58)))

static func glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func build(_game, value: int) -> void:
	seed_value = value

func reset(game) -> void:
	rng.seed = seed_value
	board = 0
	placed = 0
	next_board = -1.0
	press_time = -1.0
	start_board(game)

func clear() -> void:
	clear_board()
	column.visible = false

func clear_board() -> void:
	for toy in toys: toy.node.queue_free()
	for pad in pads: pad.tile.queue_free()
	toys.clear()
	pads.clear()
	piles.clear()
	carried = {}
	motion = ""
	target_pad = {}
	target_pile = {}

# --- boards ------------------------------------------------------------------------

func spec() -> Array:
	return BOARDS[mini(board, BOARDS.size() - 1)]

func start_board(game) -> void:
	clear_board()
	var cols: int = spec()[0]
	var rows: int = spec()[1]
	var looks: Array = []
	for shape in SHAPES:
		for color in COLORS.size(): looks.append(Vector2i(shape, color))
	shuffle(looks)
	for i in cols*rows:
		var at := Vector3((i % cols - (cols - 1)/2.0)*PAD, GROUND_Y, (i / cols - (rows - 1)/2.0)*PAD)
		pads.append(make_pad(game, at, looks[i]))
	var wanted: Array = looks.slice(0, cols*rows + int(spec()[2]))
	shuffle(wanted)
	while not wanted.is_empty():
		var pile := {"at":pile_spot(game), "stack":[]}
		piles.append(pile)
		for k in mini(wanted.size(), rng.randi_range(1, spec()[3])):
			var look: Vector2i = wanted.pop_back()
			var toy := make_toy(game, look)
			toy.node.position = Vector3(pile.at.x, toy_y(pile.stack.size()), pile.at.z)
			pile.stack.append(toy)

func shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap

# A spot round the board, clear of the other piles and of the spawn street.
func pile_spot(game) -> Vector3:
	var at := Vector3.ZERO
	for attempt in 60:
		var angle := rng.randf_range(0, TAU)
		var reach := rng.randf_range(SPREAD.x, SPREAD.y)
		at = Vector3(clampf(cos(angle)*reach, -game.layout.move_x, game.layout.move_x), GROUND_Y, clampf(sin(angle)*reach, -game.layout.move_z, game.layout.move_z))
		if flat_gap(at, game.SPAWN) < PILE_GAP: continue
		if piles.all(func(pile): return flat_gap(pile.at, at) >= PILE_GAP): break
	return at

func toy_y(index: int) -> float:
	return GROUND_Y + TOY + index*TOY*2.0

func make_toy(game, look: Vector2i) -> Dictionary:
	var node := MeshInstance3D.new()
	node.mesh = toy_mesh(game.models, look)
	node.rotation.y = rng.randf_range(0, TAU)
	add_child(node)
	var toy := {"node":node, "shape":look.x, "color":look.y}
	toys.append(toy)
	return toy

func make_pad(game, at: Vector3, look: Vector2i) -> Dictionary:
	var tile := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(PAD*0.88, 0.1, PAD*0.88)
	tile.mesh = slab
	tile.material_override = StandardMaterial3D.new()
	tile.position = at + Vector3(0, PAD_TOP - GROUND_Y - 0.05, 0)
	add_child(tile)
	var ghost := MeshInstance3D.new()
	if not ghost_meshes.has(look.x): ghost_meshes[look.x] = game.models.bake(toy_parts(game.models, look.x, Color.WHITE))
	ghost.mesh = ghost_meshes[look.x]
	ghost.material_override = ghost_materials[look.y]
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.position = Vector3(0, 0.05 + TOY + 0.15, 0)
	tile.add_child(ghost)
	return {"at":at, "shape":look.x, "color":look.y, "tile":tile, "ghost":ghost, "toy":{}}

func toy_mesh(m, look: Vector2i) -> ArrayMesh:
	var key := look.x*10 + look.y
	if not toy_meshes.has(key): toy_meshes[key] = m.bake(toy_parts(m, look.x, COLORS[look.y]))
	return toy_meshes[key]

# A toy about 2*TOY across, centred on its middle: a block, a ball, a cone
# or a drum.
static func toy_parts(m, shape: int, color: Color) -> Array:
	var trim := color.lightened(0.45)
	match shape:
		0:
			return [m.piece("box", Vector3.ZERO, Vector3.ONE*0.92, color),
				m.piece("box", Vector3(0, 0.47, 0), Vector3(0.62, 0.04, 0.62), trim)]
		1:
			return [m.piece("ball", Vector3.ZERO, Vector3.ONE*0.5, color),
				m.piece("cyl", Vector3.ZERO, Vector3(0.51, 0.12, 0.51), trim)]
		2:
			return [m.piece("point", Vector3(0, -0.05, 0), Vector3(0.55, 0.9, 0.55), color),
				m.piece("ball", Vector3(0, 0.42, 0), Vector3.ONE*0.1, trim)]
	return [m.piece("cyl", Vector3.ZERO, Vector3(0.46, 0.9, 0.46), color),
		m.piece("cyl", Vector3(0, 0.4, 0), Vector3(0.5, 0.1, 0.5), trim),
		m.piece("cyl", Vector3(0, -0.4, 0), Vector3(0.5, 0.1, 0.5), trim)]

# --- round -------------------------------------------------------------------------

func update(game, dt: float) -> void:
	clock += dt
	if next_board >= 0:
		next_board -= dt
		if next_board < 0:
			board += 1
			start_board(game)
	if motion != "": move_beamed(game, dt)
	elif not carried.is_empty():
		carried.node.position = carry_at(game) + Vector3(0, sin(clock*4.0)*0.12, 0)
		carried.node.rotation.y += dt*1.6
	var over: Dictionary = pad_under(game.hole_position)
	for pad in pads:
		pad.ghost.visible = pad.toy.is_empty()
		pad.ghost.position.y = 0.05 + TOY + 0.15 + sin(clock*2.5 + pad.at.x)*0.08
		pad.ghost.rotation.y = clock*0.8
		var tint := Color("2d3550")
		if not pad.toy.is_empty(): tint = COLORS[pad.color].darkened(0.35)
		elif not carried.is_empty() and pad == over: tint = Color("3ddc84") if fits(pad, carried) else Color("ff4d4d")
		pad.tile.material_override.albedo_color = tint
	column.visible = not carried.is_empty()
	var top := CARRY_HEIGHT + 0.8
	column.position = Vector3(game.hole_position.x, top/2, game.hole_position.z)
	column.scale = Vector3(1, top, 1)

func carry_at(game) -> Vector3:
	return Vector3(game.hole_position.x, CARRY_HEIGHT, game.hole_position.z)

func move_beamed(game, dt: float) -> void:
	motion_t += dt
	var lifting := motion == "lift"
	var k := minf(1.0, motion_t/(LIFT_TIME if lifting else DROP_TIME))
	var to: Vector3 = carry_at(game) if lifting else motion_to
	carried.node.position = motion_from.lerp(to, k*k*(3.0 - 2.0*k))
	carried.node.rotation.y += dt*(6.0 if lifting else 2.0)
	if k < 1.0: return
	motion = ""
	if not lifting: land(game)

func fits(pad: Dictionary, toy: Dictionary) -> bool:
	return pad.toy.is_empty() and pad.shape == toy.shape and pad.color == toy.color

# Whether some empty pad still wants a toy of this look.
func wanted(toy: Dictionary) -> bool:
	return pads.any(func(pad): return fits(pad, toy))

func pad_under(at: Vector3) -> Dictionary:
	var best := {}
	var gap := PAD*0.75
	for pad in pads:
		var here := flat_gap(pad.at, at)
		if here < gap:
			gap = here
			best = pad
	return best

func pile_near(at: Vector3) -> Dictionary:
	var best := {}
	var gap := REACH
	for pile in piles:
		var here := flat_gap(pile.at, at)
		if here < gap:
			gap = here
			best = pile
	return best

static func flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# A tap lifts the top toy of the pile under the hole, or drops the toy carried.
func tap(game) -> void:
	if motion != "" or next_board >= 0: return
	if carried.is_empty(): lift(game)
	else: drop(game)

func lift(game) -> void:
	var pile := pile_near(game.hole_position)
	if pile.is_empty(): return
	carried = pile.stack.pop_back()
	if pile.stack.is_empty(): piles.erase(pile)
	motion = "lift"
	motion_t = 0.0
	motion_from = carried.node.position
	game.sfx.play("click", 0.8)

func drop(game) -> void:
	var at: Vector3 = game.hole_position
	var pad := pad_under(at)
	target_pad = {}
	target_pile = {}
	if not pad.is_empty():
		if not fits(pad, carried):
			reject(game)
			return
		target_pad = pad
		motion_to = Vector3(pad.at.x, PAD_TOP + TOY, pad.at.z)
	else:
		var pile := pile_near(at)
		if not pile.is_empty() and pile.stack.size() >= MAX_STACK:
			game.add_floater(at, I18n.t("beam_full"), false)
			game.sfx.play("tick", 0.6)
			return
		if pile.is_empty():
			pile = {"at":Vector3(at.x, GROUND_Y, at.z), "stack":[]}
			piles.append(pile)
		target_pile = pile
		motion_to = Vector3(pile.at.x, toy_y(pile.stack.size()), pile.at.z)
	motion = "drop"
	motion_t = 0.0
	motion_from = carried.node.position
	game.sfx.play("click", 1.2)

# A wrong pad throws the toy back up the beam and takes time off the clock.
func reject(game) -> void:
	game.remaining = maxf(0.0, game.remaining - WRONG_COST)
	game.add_floater(game.hole_position, I18n.t("beam_wrong", int(WRONG_COST)), false)
	game.fx.shake = maxf(game.fx.shake, 0.3)
	game.sfx.play("shot")

func land(game) -> void:
	var toy := carried
	carried = {}
	if target_pad.is_empty():
		target_pile.stack.append(toy)
		return
	target_pad.toy = toy
	placed += 1
	game.add_floater(target_pad.at, "+1", true)
	game.fx.ripple(target_pad.at + Vector3(0, PAD_TOP, 0), PAD*0.5, COLORS[toy.color])
	game.sfx.play("grow")
	if pads.any(func(pad): return pad.toy.is_empty()): return
	game.remaining += BOARD_BONUS
	game.add_floater(Vector3.ZERO, I18n.t("beam_board", int(BOARD_BONUS)), true)
	game.sfx.play("grow", 1.4)
	next_board = BOARD_PAUSE

func on_board() -> int:
	return pads.filter(func(pad): return not pad.toy.is_empty()).size()

# Quick taps (touch, mouse or Space) work the beam; drags still steer.
func input(game, event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_SPACE: tap(game)
		return
	var touch := event is InputEventScreenTouch
	var mouse: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION
	if not touch and not mouse: return
	if event.pressed:
		press_at = event.position
		press_time = game.elapsed
		return
	if press_time >= 0 and game.elapsed - press_time < TAP_TIME and event.position.distance_to(press_at) < TAP_MOVE: tap(game)
	press_time = -1.0

func speed_scale() -> float:
	return CARRY_SLOW if not carried.is_empty() else 1.0

func note() -> String:
	return I18n.t("beam_note_lift" if carried.is_empty() else "beam_note_drop", [board + 1, on_board(), pads.size()])

# Minimap dots: the piles holding a toy some pad still wants.
func dots() -> Array:
	var list: Array = []
	for pile in piles:
		if pile.stack.any(func(toy): return wanted(toy)): list.append(Vector2(pile.at.x, pile.at.z))
	return list
