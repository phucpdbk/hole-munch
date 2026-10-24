extends Node3D

# Daily mini-game "beam" (daily_games.gd), landmarks home: the map is the
# whole world (beam_yard.gd) and each board pins a few cities on it, each pin
# with the city's name. Their landmarks float out at sea round the saucer,
# with decoys whose city has no pin. Tap (or Space) over a landmark and the
# saucer's tractor beam lifts it; carry it to its city's pin and tap again to
# set it down. A wrong pin throws it back up, costs WRONG_COST seconds and
# makes the right pin blink for HINT_TIME. Dropped anywhere else a landmark
# stays where it lands, at least LOOSE_GAP from the next. Pins only light up
# under the saucer, never green or red, so the map must be known (or learnt
# from the blinks). A full board adds BOARD_BONUS seconds and the next, bigger
# board (BOARDS) comes up with new cities.
const I18n = preload("res://scripts/i18n.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Landmarks = preload("res://scripts/landmarks.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
# [pins, decoys] for each board; the last repeats.
const BOARDS := [[3, 0], [4, 1], [5, 2], [6, 2]]
# Pinned cities stand at least this far apart, and decoys come from cities at
# least this far from every pin (so Hanoi's second landmark is never a decoy
# next to Hanoi's pin).
const PIN_GAP := 5.0
const PIN_RADIUS := 0.8
const PIN_TOP := 0.14
# A landmark fits a box this wide across and this tall.
const LANDMARK_SIZE := Vector2(1.5, 1.7)
# How far from the hole's centre a landmark can be beamed from or a pin hit.
const REACH := 1.3
# Loose landmarks float this far from the saucer, at least LOOSE_GAP apart
# and SEA_CLEAR off any coast.
const SPREAD := Vector2(4.0, 14.0)
const LOOSE_GAP := 2.2
const SEA_CLEAR := 0.9
const CARRY_HEIGHT := 1.7
const LIFT_TIME := 0.35
const DROP_TIME := 0.3
const WRONG_COST := 2.0
const HINT_TIME := 2.0
const BOARD_BONUS := 6.0
const BOARD_PAUSE := 1.0
const CARRY_SLOW := 0.9
# The camera stands further back to show more of the map.
const ZOOM := 1.3
# A touch let go this soon, this close to where it began, is a tap.
const TAP_TIME := 0.3
const TAP_MOVE := 14.0
const PLINTH := Color("fff4e0")
const HOVER := Color("9fe8ff")
const BLINK := Color("ff9a3c")
const GOLD := Color("ffd23f")

var rng := RandomNumberGenerator.new()
var seed_value := 0
var board := 0
# {at, id, city, plinth, stick, label, landmark ({} until filled), hint}.
var pins: Array = []
# {node, id, at}: every landmark of the board, wherever it is.
var landmarks: Array = []
# The landmarks lying on the map, free to be beamed up.
var loose: Array = []
var carried := {}
# "lift" or "drop" while the beam moves a landmark, else "".
var motion := ""
var motion_t := 0.0
var motion_from := Vector3.ZERO
var motion_to := Vector3.ZERO
var target_pin := {}
var placed := 0
var next_board := -1.0
var clock := 0.0
var press_at := Vector2.ZERO
var press_time := -1.0
# Landmarks pinned earlier this round, not pinned again while others are left.
var used: Array = []
# {mesh, material, scale, offset} per landmark id.
var looks := {}
var column: MeshInstance3D
var plinth_mesh := CylinderMesh.new()
var stick_mesh := CylinderMesh.new()
var stand_mesh := CylinderMesh.new()
var stand_material := StandardMaterial3D.new()
var stick_material := StandardMaterial3D.new()

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
	plinth_mesh.top_radius = PIN_RADIUS
	plinth_mesh.bottom_radius = PIN_RADIUS*1.08
	plinth_mesh.height = PIN_TOP
	stick_mesh.top_radius = 0.05
	stick_mesh.bottom_radius = 0.05
	stick_mesh.height = 1.3
	stand_mesh.top_radius = 0.72
	stand_mesh.bottom_radius = 0.78
	stand_mesh.height = 0.1
	stand_material.albedo_color = Color("e9eef2")
	stick_material.albedo_color = Color("e5566e")

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
	used.clear()
	# The hole is put back on its spawn only after the daily resets.
	start_board(game, game.SPAWN)

func clear() -> void:
	clear_board()
	column.visible = false

func clear_board() -> void:
	for landmark in landmarks: landmark.node.queue_free()
	for pin in pins: pin.plinth.queue_free()
	landmarks.clear()
	pins.clear()
	loose.clear()
	carried = {}
	motion = ""
	target_pin = {}

# --- boards ------------------------------------------------------------------------

func spec() -> Array:
	return BOARDS[mini(board, BOARDS.size() - 1)]

func start_board(game, near: Vector3) -> void:
	clear_board()
	var cities: Array = game.countryside.cities
	var pinned := pick_pins(cities, int(spec()[0]))
	for city in pinned: pins.append(make_pin(city))
	var decoys: Array = cities.filter(func(city): return pins.all(func(pin): return flat_gap(pin.at, city.at) >= PIN_GAP))
	shuffle(decoys)
	var wanted: Array = pinned + decoys.slice(0, int(spec()[1]))
	shuffle(wanted)
	for city in wanted:
		var landmark := make_landmark(game.models, city.id)
		landmark.at = sea_spot(game, near)
		landmark.node.position = landmark.at
		loose.append(landmark)

func shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = list[i]
		list[i] = list[j]
		list[j] = swap

# Cities at least PIN_GAP apart, those not pinned yet this round first.
func pick_pins(cities: Array, count: int) -> Array:
	var fresh: Array = cities.filter(func(city): return not city.id in used)
	var rest: Array = cities.filter(func(city): return city.id in used)
	shuffle(fresh)
	shuffle(rest)
	var chosen: Array = []
	for city in fresh + rest:
		if chosen.size() == count: break
		if chosen.all(func(other): return flat_gap(other.at, city.at) >= PIN_GAP): chosen.append(city)
	for city in chosen: used.append(city.id)
	return chosen

# Open sea round `near`, clear of the pins and the other loose landmarks; the
# ring widens while no such spot turns up (the saucer may be inland).
func sea_spot(game, near: Vector3) -> Vector3:
	var map = game.countryside
	var at := Vector2(near.x, near.z)
	for attempt in 160:
		var angle := rng.randf_range(0, TAU)
		var reach := rng.randf_range(SPREAD.x, SPREAD.y + attempt*0.25)
		at = Vector2(clampf(near.x + cos(angle)*reach, -game.layout.move_x, game.layout.move_x), clampf(near.z + sin(angle)*reach, -game.layout.move_z, game.layout.move_z))
		if not map.at_sea(at, SEA_CLEAR): continue
		var spot := Vector3(at.x, 0, at.y)
		if pins.any(func(pin): return flat_gap(pin.at, spot) < LOOSE_GAP): continue
		if loose.all(func(other): return flat_gap(other.at, spot) >= LOOSE_GAP): break
	return Vector3(at.x, map.height_at(at), at.y)

# A landmark on a little round stand, its origin at the stand's foot.
func make_landmark(m, id: String) -> Dictionary:
	var look := landmark_look(m, id)
	var node := Node3D.new()
	var stand := MeshInstance3D.new()
	stand.mesh = stand_mesh
	stand.material_override = stand_material
	stand.position.y = 0.05
	node.add_child(stand)
	var model := MeshInstance3D.new()
	model.mesh = look.mesh
	model.material_override = look.material
	model.scale = Vector3.ONE*look.scale
	model.position = look.offset + Vector3(0, 0.1, 0)
	node.add_child(model)
	add_child(node)
	var landmark := {"node":node, "id":id, "at":Vector3.ZERO}
	landmarks.append(landmark)
	return landmark

# The Meshy bake when there is one, else the primitive model (as the journey
# map), with the object shader's hole moved far away so nothing is cut.
func landmark_look(m, id: String) -> Dictionary:
	if looks.has(id): return looks[id]
	var material := ShaderMaterial.new()
	material.shader = m.material.shader
	material.set_shader_parameter("hole_center", Vector2(1e5, 1e5))
	material.set_shader_parameter("hole_radius", 0.0)
	var mesh: ArrayMesh
	var path := "res://assets/landmarks/%s.res" % id
	var texture_path := "res://assets/landmarks/%s_albedo.res" % id
	if ResourceLoader.exists(path) and ResourceLoader.exists(texture_path):
		mesh = load(path)
		material.set_shader_parameter("albedo_tex", load(texture_path))
	else:
		mesh = m.bake(Landmarks.new().build(m, id))
	var box := mesh.get_aabb()
	var k := minf(LANDMARK_SIZE.x/maxf(maxf(box.size.x, box.size.z), 0.01), LANDMARK_SIZE.y/maxf(box.size.y, 0.01))
	var centre := box.get_center()
	looks[id] = {"mesh":mesh, "material":material, "scale":k, "offset":Vector3(-centre.x*k, -box.position.y*k, -centre.z*k)}
	return looks[id]

# A round plinth on the city's spot with a map pin and the city's name.
func make_pin(city: Dictionary) -> Dictionary:
	var plinth := MeshInstance3D.new()
	plinth.mesh = plinth_mesh
	plinth.material_override = StandardMaterial3D.new()
	plinth.position = city.at + Vector3(0, PIN_TOP/2, 0)
	add_child(plinth)
	var stick := MeshInstance3D.new()
	stick.mesh = stick_mesh
	stick.material_override = stick_material
	stick.position.y = 0.65
	plinth.add_child(stick)
	var head := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.2
	ball.height = 0.4
	head.mesh = ball
	head.material_override = stick_material
	head.position.y = 0.7
	stick.add_child(head)
	var label := Label3D.new()
	label.text = city.city
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = UiStyle.font(800)
	label.font_size = 110
	label.outline_size = 28
	label.pixel_size = 0.011
	label.outline_modulate = Color("1b3048")
	label.no_depth_test = true
	label.position.y = 2.5
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plinth.add_child(label)
	return {"at":city.at, "id":city.id, "city":city.city, "plinth":plinth, "stick":stick, "label":label, "landmark":{}, "hint":0.0}

# --- round -------------------------------------------------------------------------

func update(game, dt: float) -> void:
	clock += dt
	if next_board >= 0:
		next_board -= dt
		if next_board < 0:
			board += 1
			start_board(game, game.hole_position)
	if motion != "": move_beamed(game, dt)
	elif not carried.is_empty():
		carried.node.position = carry_at(game) + Vector3(0, sin(clock*4.0)*0.12, 0)
		carried.node.rotation.y += dt*1.6
	var over: Dictionary = pin_under(game.hole_position)
	for pin in pins:
		pin.hint = maxf(0.0, pin.hint - dt)
		var filled: bool = not pin.landmark.is_empty()
		var tint := PLINTH
		if filled: tint = GOLD
		elif pin.hint > 0 and fmod(pin.hint, 0.4) > 0.2: tint = BLINK
		elif not carried.is_empty() and pin == over: tint = HOVER
		pin.plinth.material_override.albedo_color = tint
		pin.stick.visible = not filled
		pin.label.modulate = GOLD if filled else Color.WHITE
	column.visible = not carried.is_empty()
	var top := CARRY_HEIGHT + 1.6
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

func fits(pin: Dictionary, landmark: Dictionary) -> bool:
	return pin.landmark.is_empty() and pin.id == landmark.id

# Whether some empty pin still wants this landmark.
func wanted(landmark: Dictionary) -> bool:
	return pins.any(func(pin): return fits(pin, landmark))

func pin_under(at: Vector3) -> Dictionary:
	var best := {}
	var gap := REACH
	for pin in pins:
		var here := flat_gap(pin.at, at)
		if here < gap:
			gap = here
			best = pin
	return best

func loose_near(at: Vector3) -> Dictionary:
	var best := {}
	var gap := REACH
	for landmark in loose:
		var here := flat_gap(landmark.at, at)
		if here < gap:
			gap = here
			best = landmark
	return best

static func flat_gap(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# A tap lifts the landmark under the hole, or drops the one carried.
func tap(game) -> void:
	if motion != "" or next_board >= 0: return
	if carried.is_empty(): lift(game)
	else: drop(game)

func lift(game) -> void:
	var landmark := loose_near(game.hole_position)
	if landmark.is_empty(): return
	loose.erase(landmark)
	carried = landmark
	motion = "lift"
	motion_t = 0.0
	motion_from = carried.node.position
	game.sfx.play("click", 0.8)

func drop(game) -> void:
	var at: Vector3 = game.hole_position
	var pin := pin_under(at)
	target_pin = {}
	if not pin.is_empty() and pin.landmark.is_empty():
		if not fits(pin, carried):
			reject(game)
			return
		target_pin = pin
		motion_to = pin.at + Vector3(0, PIN_TOP, 0)
	elif not pin.is_empty() or loose.any(func(other): return flat_gap(other.at, at) < LOOSE_GAP*0.6):
		game.add_floater(at, I18n.t("beam_full"), false)
		game.sfx.play("tick", 0.6)
		return
	else:
		motion_to = Vector3(at.x, game.countryside.height_at(Vector2(at.x, at.z)), at.z)
	motion = "drop"
	motion_t = 0.0
	motion_from = carried.node.position
	game.sfx.play("click", 1.2)

# A wrong pin throws the landmark back up the beam, takes time off the clock
# and makes its own pin blink (a decoy has none).
func reject(game) -> void:
	game.remaining = maxf(0.0, game.remaining - WRONG_COST)
	var home: Array = pins.filter(func(pin): return fits(pin, carried))
	for pin in home: pin.hint = HINT_TIME
	game.add_floater(game.hole_position, I18n.t("beam_wrong" if not home.is_empty() else "beam_decoy", int(WRONG_COST)), false)
	game.fx.shake = maxf(game.fx.shake, 0.3)
	game.sfx.play("shot")

func land(game) -> void:
	var landmark := carried
	carried = {}
	landmark.at = motion_to
	if target_pin.is_empty():
		loose.append(landmark)
		return
	target_pin.landmark = landmark
	placed += 1
	game.add_floater(target_pin.at, "+1", true)
	game.fx.ripple(target_pin.at + Vector3(0, PIN_TOP, 0), PIN_RADIUS*1.4, GOLD)
	game.sfx.play("grow")
	if pins.any(func(pin): return pin.landmark.is_empty()): return
	game.remaining += BOARD_BONUS
	game.add_floater(game.hole_position, I18n.t("beam_board", int(BOARD_BONUS)), true)
	game.sfx.play("grow", 1.4)
	next_board = BOARD_PAUSE

func on_board() -> int:
	return pins.filter(func(pin): return not pin.landmark.is_empty()).size()

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

# Empty-handed: the board's progress. Carrying: the landmark's name.
func note() -> String:
	if carried.is_empty(): return I18n.t("beam_note_lift", [board + 1, on_board(), pins.size()])
	return I18n.t("beam_note_drop", Campaign.boss_name(carried.id))

# Minimap dots: the loose landmarks some pin still wants, or while carrying
# the empty pins.
func dots() -> Array:
	if not carried.is_empty():
		return pins.filter(func(pin): return pin.landmark.is_empty()).map(func(pin): return Vector2(pin.at.x, pin.at.z))
	return loose.filter(func(landmark): return wanted(landmark)).map(func(landmark): return Vector2(landmark.at.x, landmark.at.z))
