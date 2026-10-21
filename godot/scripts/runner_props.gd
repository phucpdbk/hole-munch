extends RefCounted

# Bonus run extras (runner.gd): coin lines to grab, roadblocks to dodge and boost
# pads to hit.
# - A roadblock fills one half of the avenue just past a gate, with a coin line on
#   the same side in front of it, so the coins ask for a late swerve.
# - A sliding roadblock sweeps from side to side across the avenue: read its
#   rhythm and pass on the open half.
# - A boost pad on one half speeds the hole up for BOOST_TIME seconds and doubles
#   every coin picked up meanwhile; a coin line runs over it.
# Driving into any roadblock costs a fifth of the hole's size. Everything grows
# along the course ("grow", 0 at the start to 1 at the finish) so it still reads
# next to a big hole.
const COIN_VALUE := 1
const COIN_GAP := 1.7
const COIN_HEIGHT := 0.9
const COIN_GROW := 1.2
const HIT_KEEP := 0.8
# A roadblock is BLOCK_HALF either side of its centre; a fixed one sits in the
# middle of its half of the road (the barrier model is BARRIER_WIDTH wide at
# scale 1 and grows to BLOCK_GROW + 1 at the end).
const BLOCK_HALF := 3.0
const BLOCK_CENTRE := 3.3
const BARRIER_WIDTH := 3.0
const BLOCK_GROW := 1.0
# A sliding roadblock's centre swings this far either side, at SLIDE_RATE rad/s.
const SLIDE_SWING := 3.3
const SLIDE_RATE := 2.4
# How much of the hole's radius has to overlap a roadblock for it to hurt: a
# big hole still fits past one by keeping to the far half.
const BLOCK_REACH := 0.3
const PAD_LENGTH := 8.0
const PAD_WIDTH := 5.6
const BOOST_TIME := 2.5
const BOOST_SPEED := 1.35
const BAD := Color("ff5a5f")
const GOLD := Color("ffd166")
const BOOST := Color("4fd8ff")

var coins: Array = []
var blocks: Array = []
var pads: Array = []
var picked := 0
var hits := 0
var boosts := 0
# Seconds of boost left, and the run's own clock for the sliding roadblocks.
var boost := 0.0
var clock := 0.0
var coin_mesh: CylinderMesh
var coin_material: StandardMaterial3D
var pad_material: StandardMaterial3D
var arrow_material: StandardMaterial3D

func _init() -> void:
	coin_mesh = CylinderMesh.new()
	coin_mesh.top_radius = 0.42
	coin_mesh.bottom_radius = 0.42
	coin_mesh.height = 0.1
	coin_mesh.radial_segments = 16
	coin_material = glow_material(GOLD, 0.45)
	coin_material.metallic = 0.6
	coin_material.roughness = 0.3
	pad_material = glow_material(Color(BOOST, 0.45), 0.6)
	pad_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pad_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_material = glow_material(Color("eaffff"), 0.8)
	arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

static func glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color, 1.0)
	material.emission_energy_multiplier = energy
	return material

func clear() -> void:
	for list in [coins, blocks, pads]:
		for entry in list: entry.node.queue_free()
		list.clear()

func add_coin_line(parent: Node3D, x: float, from_z: float, count: int, grow: float) -> void:
	var size := 1.0 + grow*COIN_GROW
	for k in count:
		var node := MeshInstance3D.new()
		node.mesh = coin_mesh
		node.material_override = coin_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.position = Vector3(x, COIN_HEIGHT*size, from_z - k*COIN_GAP*(0.5 + 0.5*size))
		node.rotation = Vector3(PI/2, 0, 0)
		node.scale = Vector3.ONE*size
		parent.add_child(node)
		coins.append({"node":node, "at":node.position, "size":size, "taken":false})

# A fixed roadblock on one half ("side") or, with slide set, one that sweeps the
# whole avenue. Fewer, bigger barriers further along.
func add_block(parent: Node3D, mesh: Mesh, z: float, side: float, grow: float, slide := false) -> void:
	var node := Node3D.new()
	node.position = Vector3(side*BLOCK_CENTRE, 0.16, z)
	parent.add_child(node)
	var size := 1.0 + grow*BLOCK_GROW
	var span := BLOCK_HALF*2.0
	var count := maxi(1, roundi(span/(BARRIER_WIDTH*size)))
	for k in count:
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.scale = Vector3(span/(BARRIER_WIDTH*count), size, size)
		part.position = Vector3((k + 0.5)*span/count - span/2.0, 0, 0)
		node.add_child(part)
	# Sliding ones start at a random point of their swing.
	var phase := (side + 1.0)*PI/2.0 + z
	blocks.append({"node":node, "at":z, "side":side, "used":false, "slide":slide, "phase":phase})

# Chevrons on a glowing strip, pointing up the road.
func add_pad(parent: Node3D, z: float, side: float) -> void:
	var node := Node3D.new()
	node.position = Vector3(side*BLOCK_CENTRE, 0.18, z - PAD_LENGTH/2.0)
	parent.add_child(node)
	node.add_child(slab(Vector3.ZERO, Vector3(PAD_WIDTH, 0.04, PAD_LENGTH), pad_material, 0.0))
	for k in 3:
		var at := PAD_LENGTH*(0.3 - k*0.3)
		for x in [-1.0, 1.0]:
			node.add_child(slab(Vector3(x*0.75, 0.04, at), Vector3(2.0, 0.05, 0.45), arrow_material, x*PI/4.0))
	pads.append({"node":node, "at":z, "side":side, "used":false})

static func slab(at: Vector3, size: Vector3, material: Material, yaw: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	mesh.rotation = Vector3(0, yaw, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

func reset() -> void:
	picked = 0
	hits = 0
	boosts = 0
	boost = 0.0
	clock = 0.0
	for coin in coins:
		coin.taken = false
		coin.node.visible = true
	for block in blocks:
		block.used = false
		block.node.visible = true
		place_block(block)
	for pad in pads: pad.used = false

func block_x(block: Dictionary, time: float) -> float:
	return sin(time*SLIDE_RATE + block.phase)*SLIDE_SWING if block.slide else block.side*BLOCK_CENTRE

func place_block(block: Dictionary) -> void:
	block.node.position.x = block_x(block, clock)

func speed_scale() -> float:
	return BOOST_SPEED if boost > 0.0 else 1.0

func update(game, dt: float, last_z: float) -> void:
	clock += dt
	boost = maxf(0.0, boost - dt)
	var at: Vector3 = game.hole_position
	var r: float = game.radius
	for coin in coins:
		if coin.taken: continue
		coin.node.rotate_y(dt*3.0)
		if absf(coin.at.z - at.z) < 0.5*coin.size + r*0.6 and absf(coin.at.x - at.x) < r*0.8 + 0.3*coin.size:
			coin.taken = true
			coin.node.visible = false
			picked += COIN_VALUE*(2 if boost > 0.0 else 1)
			game.sfx.play("tick")
	for pad in pads:
		if pad.used or not (last_z > pad.at and at.z <= pad.at): continue
		pad.used = true
		if pad.side*at.x > -0.5: start_boost(game)
	for block in blocks:
		if block.slide and block.node.visible: place_block(block)
		if block.used or not (last_z > block.at and at.z <= block.at): continue
		block.used = true
		if absf(at.x - block_x(block, clock)) < BLOCK_HALF + r*BLOCK_REACH: hit(game, block)

func start_boost(game) -> void:
	boosts += 1
	boost = BOOST_TIME
	game.fx.ripple(game.hole_position, game.radius*1.4, BOOST)
	game.showtime.callout("BOOST ×2", BOOST)
	game.pulse = 1.0
	game.sfx.play("grow")

func hit(game, block: Dictionary) -> void:
	hits += 1
	game.target_radius = maxf(float(game.stats.start_radius), game.target_radius*HIT_KEEP)
	block.node.visible = false
	game.fx.ripple(game.hole_position, game.radius*1.3, BAD)
	game.fx.shake = maxf(game.fx.shake, 0.6)
	game.showtime.callout("−%d%%" % roundi((1.0 - HIT_KEEP)*100), BAD)
	game.sfx.play("shot")
