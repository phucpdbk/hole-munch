extends RefCounted

# Stylized toy landmarks, assembled from primitives and baked once per level into
# one vertex-coloured surface. Each sits on a small detailed plaza; models.gd scales
# the footprint to the boss radius. Faces toward +x/+z are the ones the camera sees.
var m
var parts: Array = []
const STONE = Color("dccaa7")
const WHITE = Color("f1efe4")
const DARK = Color("3b4a5a")
const GLASS = Color("7fb3c9")
const GOLD = Color("e9c162")
const GRASS = Color("8fbf73")
const LEAF = Color("5f9e62")
const WATER = Color("6fb6c9")
const WOOD = Color("8a5a3c")

func build(models, id: String) -> Array:
	m = models
	parts = []
	call("lm_" + id)
	return parts

# --- helpers -------------------------------------------------------------------

func add(shape: String, at: Vector3, size: Vector3, color: Color, rotate := Vector3.ZERO) -> void:
	parts.append(m.piece(shape, at, size, color, rotate))

func box(at: Vector3, size: Vector3, color: Color, rotate := Vector3.ZERO) -> void:
	add("box", at, size, color, rotate)

func beam(a: Vector3, b: Vector3, width: float, color: Color, shape := "box") -> void:
	var delta := b - a
	if delta.length() < 0.001: return
	add(shape, (a + b) * 0.5, Vector3(width, delta.length(), width), color, Quaternion(Vector3.UP, delta.normalized()).get_euler())

# Two-slope roof with its ridge along x (the lower half hides inside the walls).
func gable_x(center: Vector3, length: float, half_depth: float, height: float, color: Color) -> void:
	add("prism", center, Vector3(height, length, half_depth), color, Vector3(0, 0, PI/2))

# Arched opening on a wall facing yaw (0 = +z, PI/2 = +x).
func arch(center: Vector3, width: float, height: float, yaw: float, color := DARK) -> void:
	var normal := Vector3(sin(yaw), 0, cos(yaw))
	box(center + normal*0.02, Vector3(width, height, 0.08), color, Vector3(0, yaw, 0))
	add("cyl", center + normal*0.02 + Vector3(0, height/2, 0), Vector3(width/2, 0.08, width/2), color, Vector3(PI/2, yaw, 0))

func tree(at: Vector3, size: float, color := LEAF) -> void:
	add("cylinder", at + Vector3(0, 0.35*size, 0), Vector3(0.09, 0.7, 0.09)*size, WOOD)
	add("ball", at + Vector3(0, 0.9*size, 0), Vector3(0.42, 0.5, 0.42)*size, color)

func cypress(at: Vector3, size: float) -> void:
	add("point", at + Vector3(0, 0.75*size, 0), Vector3(0.22, 1.5, 0.22)*size, Color("3f7a52"))

func plaza_round(radius: float, color := STONE, rim := WHITE) -> void:
	add("cyl", Vector3(0, 0.06, 0), Vector3(radius, 0.12, radius), rim)
	add("cyl", Vector3(0, 0.13, 0), Vector3(radius*0.94, 0.04, radius*0.94), color)

func plaza_square(half: float, color := STONE, rim := WHITE) -> void:
	box(Vector3(0, 0.06, 0), Vector3(half*2, 0.12, half*2), rim)
	box(Vector3(0, 0.13, 0), Vector3(half*2-0.2, 0.04, half*2-0.2), color)

func lamp(at: Vector3) -> void:
	add("cylinder", at + Vector3(0, 0.35, 0), Vector3(0.04, 0.7, 0.04), DARK)
	add("ball", at + Vector3(0, 0.74, 0), Vector3.ONE*0.08, Color("fff1b8"))

# Pyramid roof with upturned corner tips, as on Vietnamese and Japanese pavilions.
func asian_roof(center: Vector3, half: float, height: float, color: Color) -> void:
	add("roof", center + Vector3(0, height/2, 0), Vector3(half*1.42, height, half*1.42), color, Vector3(0, PI/4, 0))
	box(center + Vector3(0, 0.03, 0), Vector3(half*2, 0.08, half*2), color.darkened(0.2))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var corner := center + Vector3(sx*half, 0, sz*half)
			box(corner + Vector3(sx*0.08, 0.1, sz*0.08), Vector3(0.12, 0.34, 0.12), color, Vector3(-sz*0.6, 0, sx*0.6))

# --- Asia ------------------------------------------------------------------------

func lm_onepillar() -> void:
	# Lotus pond with the pavilion on a single stone pillar.
	box(Vector3(0, 0.08, 0), Vector3(5.4, 0.16, 5.4), Color("a79d8a"))
	box(Vector3(0, 0.14, 0), Vector3(4.9, 0.06, 4.9), WATER)
	for i in 9:
		var a := i*TAU/9.0
		var at := Vector3(cos(a)*1.85, 0.18, sin(a)*1.85)
		add("cyl", at, Vector3(0.32, 0.03, 0.32), Color("5f9e5c"))
		if i % 3 == 0: add("ball", at + Vector3(0, 0.12, 0), Vector3(0.12, 0.1, 0.12), Color("f09bb8"))
	add("cyl", Vector3(0, 1.1, 0), Vector3(0.32, 2.0, 0.32), Color("b8ad99"))
	for i in 8:
		var a := i*TAU/8.0
		add("point", Vector3(cos(a)*0.55, 2.02, sin(a)*0.55), Vector3(0.28, 0.5, 0.18), Color("c7ae8a"), Vector3(PI, a, 0))
	box(Vector3(0, 2.25, 0), Vector3(2.3, 0.16, 2.3), WOOD)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			add("cyl", Vector3(sx*0.95, 2.85, sz*0.95), Vector3(0.08, 1.1, 0.08), Color("7a3b2c"))
	box(Vector3(0, 2.85, 0), Vector3(1.75, 1.0, 1.75), Color("a8563f"))
	for yaw in [0.0, PI/2]:
		var normal := Vector3(sin(yaw), 0, cos(yaw))
		var along := Vector3(cos(yaw), 0, -sin(yaw))
		box(Vector3(0, 2.8, 0) + normal*0.88, Vector3(1.0, 0.7, 0.05), Color("e7c78a"), Vector3(0, yaw, 0))
		for i in 4: box(Vector3(0, 2.8, 0) + normal*0.9 + along*(-0.36+i*0.24), Vector3(0.04, 0.7, 0.06), WOOD, Vector3(0, yaw, 0))
	asian_roof(Vector3(0, 3.4, 0), 1.45, 1.0, Color("7c4b3a"))
	add("ball", Vector3(0, 4.45, 0), Vector3(0.12, 0.16, 0.12), GOLD)
	for i in 6: box(Vector3(0, 0.25+i*0.33, 2.55-i*0.3), Vector3(0.9, 0.12, 0.35), Color("b8ad99"))
	for x in [-2.3, 2.3]: tree(Vector3(x, 0.16, -2.2), 1.3)

func lm_khuevan() -> void:
	plaza_square(2.7, Color("cfc4a8"))
	# Four brick pillars carry the Constellation of Literature pavilion.
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var at := Vector3(sx*1.15, 0, sz*0.95)
			box(at + Vector3(0, 1.15, 0), Vector3(0.5, 2.1, 0.5), Color("efe6d2"))
			box(at + Vector3(0, 2.25, 0), Vector3(0.62, 0.12, 0.62), Color("d9cdb4"))
			box(at + Vector3(0, 0.25, 0), Vector3(0.62, 0.3, 0.62), Color("d9cdb4"))
	box(Vector3(0, 2.4, 0), Vector3(3.1, 0.18, 2.7), Color("d9cdb4"))
	for i in 11: box(Vector3(-1.5+i*0.3, 2.62, 1.3), Vector3(0.05, 0.26, 0.05), Color("7a3b2c"))
	box(Vector3(0, 2.72, 1.3), Vector3(3.0, 0.05, 0.05), Color("7a3b2c"))
	box(Vector3(0, 3.2, 0), Vector3(2.2, 1.2, 1.9), Color("b3503d"))
	# Round "sun" windows with radiating bars on every face.
	for yaw in [0.0, PI/2, PI, -PI/2]:
		var normal := Vector3(sin(yaw), 0, cos(yaw))
		var face := 0.97 if absf(normal.z) > 0.5 else 1.12
		add("cyl", Vector3(0, 3.2, 0) + normal*face, Vector3(0.42, 0.05, 0.42), WHITE, Vector3(PI/2, yaw, 0))
		add("cyl", Vector3(0, 3.2, 0) + normal*(face+0.02), Vector3(0.3, 0.05, 0.3), DARK, Vector3(PI/2, yaw, 0))
		for k in 4: box(Vector3(0, 3.2, 0) + normal*(face+0.05), Vector3(0.62, 0.04, 0.04), WHITE, Vector3(0, yaw, k*PI/4))
	asian_roof(Vector3(0, 3.85, 0), 1.45, 0.75, Color("6f4034"))
	asian_roof(Vector3(0, 4.5, 0), 1.0, 0.8, Color("6f4034"))
	add("ball", Vector3(0, 5.3, 0), Vector3(0.14, 0.2, 0.14), GOLD)
	for x in [-2.3, 2.3]: box(Vector3(x, 0.5, 2.2), Vector3(0.35, 0.8, 0.12), Color("b8ad99"))
	for x in [-2.2, 2.2]: tree(Vector3(x, 0.16, -2.1), 1.2)

func lm_taj() -> void:
	var marble := Color("f4f0e6")
	box(Vector3(0, 0.25, 0), Vector3(5.6, 0.5, 5.6), Color("d8c7a8"))
	box(Vector3(0, 0.55, 0), Vector3(4.2, 0.1, 4.2), marble)
	box(Vector3(0, 0.52, 2.45), Vector3(0.6, 0.06, 0.5), WATER)
	for x in [-0.7, 0.7]:
		for i in 2: cypress(Vector3(x, 0.5, 2.25+i*0.4), 0.6)
	# Chamfered main hall with deep arched iwans.
	add("cylinder", Vector3(0, 1.55, 0), Vector3(1.55, 1.9, 1.55), marble, Vector3(0, PI/8, 0))
	for yaw in [0.0, PI/2, PI, -PI/2]:
		var normal := Vector3(sin(yaw), 0, cos(yaw))
		var along := Vector3(cos(yaw), 0, -sin(yaw))
		arch(Vector3(0, 1.4, 0) + normal*1.42, 0.8, 1.1, yaw, Color("9a8f7d"))
		for side in [-1, 1]:
			arch(Vector3(0, 1.1, 0) + normal*1.3 + along*side*0.8, 0.3, 0.5, yaw, Color("b5ab99"))
	add("cyl", Vector3(0, 2.7, 0), Vector3(0.95, 0.5, 0.95), marble)
	add("smooth", Vector3(0, 3.45, 0), Vector3(1.15, 1.05, 1.15), Color("fbf8f0"))
	add("point", Vector3(0, 4.55, 0), Vector3(0.28, 0.6, 0.28), marble)
	beam(Vector3(0, 4.7, 0), Vector3(0, 5.3, 0), 0.05, GOLD)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var at := Vector3(sx*1.05, 2.5, sz*1.05)
			add("cyl", at, Vector3(0.3, 0.3, 0.3), marble)
			add("smooth", at + Vector3(0, 0.35, 0), Vector3.ONE*0.3, marble)
			# Minarets at the plinth corners.
			var tower := Vector3(sx*1.95, 0.6, sz*1.95)
			add("cyl", tower + Vector3(0, 1.4, 0), Vector3(0.14, 2.8, 0.14), marble)
			for y in [0.9, 1.9, 2.8]: add("cyl", tower + Vector3(0, y, 0), Vector3(0.22, 0.07, 0.22), Color("e2dccd"))
			add("smooth", tower + Vector3(0, 3.0, 0), Vector3.ONE*0.18, marble)

func lm_fuji() -> void:
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.3, 0.1, 3.3), Color("7ea36b"))
	add("cyl", Vector3(0.9, 0.12, 2.3), Vector3(1.0, 0.04, 0.6), WATER)
	add("point", Vector3(0, 2.3, -0.2), Vector3(3.0, 4.4, 2.8), Color("6f86a3"))
	add("point", Vector3(0, 3.85, -0.2), Vector3(1.28, 1.35, 1.2), WHITE)
	for i in 10:
		var a := i*TAU/10.0
		add("point", Vector3(cos(a)*0.95, 3.05, sin(a)*0.9-0.2), Vector3(0.3, 0.8, 0.3), WHITE, Vector3(PI, 0, 0))
	for i in 14:
		var a := i*TAU/14.0
		add("point", Vector3(cos(a)*2.55, 0.55, sin(a)*2.4-0.2), Vector3(0.35, 0.9, 0.35), Color("3f7a52"))
	# Chureito-style pagoda and a torii gate in the foreground.
	for level in 5:
		var y := 0.2 + level*0.42
		var half := 0.45 - level*0.05
		box(Vector3(2.0, y+0.15, 1.2), Vector3(half*1.4, 0.3, half*1.4), Color("c0503e"))
		asian_roof(Vector3(2.0, y+0.32, 1.2), half+0.12, 0.14, Color("5a3b33"))
	beam(Vector3(2.0, 2.3, 1.2), Vector3(2.0, 2.8, 1.2), 0.04, GOLD)
	for x in [-0.9, -0.1]: add("cyl", Vector3(x, 0.65, 2.6), Vector3(0.07, 1.2, 0.07), Color("d4473a"))
	box(Vector3(-0.5, 1.25, 2.6), Vector3(1.3, 0.09, 0.12), Color("d4473a"))
	box(Vector3(-0.5, 1.4, 2.6), Vector3(1.5, 0.1, 0.14), DARK)
	for at in [Vector3(-2.2, 0.1, 1.6), Vector3(-1.6, 0.1, 2.4), Vector3(2.6, 0.1, -0.4)]: tree(at, 1.1, Color("f2a9c4"))

# --- Europe ----------------------------------------------------------------------

func lm_eiffel() -> void:
	var iron := Color("9c7a5e")
	plaza_square(2.9, Color("cbbf9c"))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(Vector3(sx*2.0, 0.3, sz*2.0), Vector3(0.9, 0.45, 0.2), GRASS)
	# Curved legs from segments; lattice bracing on each section.
	var profile := [Vector3(2.0, 0.15, 0), Vector3(1.55, 1.2, 0), Vector3(1.15, 2.2, 0), Vector3(0.75, 3.4, 0), Vector3(0.45, 4.6, 0), Vector3(0.22, 5.8, 0), Vector3(0.1, 6.8, 0)]
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			for i in profile.size()-1:
				var a := Vector3(profile[i].x*sx, profile[i].y, profile[i].x*sz)
				var b := Vector3(profile[i+1].x*sx, profile[i+1].y, profile[i+1].x*sz)
				beam(a, b, 0.24 - i*0.025, iron)
	for i in profile.size()-2:
		var lo: Vector3 = profile[i]
		var hi: Vector3 = profile[i+1]
		for side in [-1, 1]:
			beam(Vector3(-lo.x, lo.y, side*lo.x), Vector3(hi.x, hi.y, side*hi.x), 0.05, iron.lightened(0.1))
			beam(Vector3(lo.x, lo.y, side*lo.x), Vector3(-hi.x, hi.y, side*hi.x), 0.05, iron.lightened(0.1))
			beam(Vector3(side*lo.x, lo.y, -lo.x), Vector3(side*hi.x, hi.y, hi.x), 0.05, iron.lightened(0.1))
			beam(Vector3(side*lo.x, lo.y, lo.x), Vector3(side*hi.x, hi.y, -hi.x), 0.05, iron.lightened(0.1))
	# The big arches under the first platform.
	for yaw in [0.0, PI/2, PI, -PI/2]:
		add("ring", Vector3(0, 0.95, 0) + Vector3(sin(yaw), 0, cos(yaw))*1.55, Vector3(1.25, 0.3, 0.9), iron, Vector3(PI/2, yaw, 0))
	box(Vector3(0, 1.95, 0), Vector3(3.0, 0.22, 3.0), iron.darkened(0.1))
	box(Vector3(0, 2.1, 0), Vector3(3.1, 0.08, 3.1), GOLD.darkened(0.25))
	box(Vector3(0, 3.4, 0), Vector3(1.6, 0.18, 1.6), iron.darkened(0.1))
	box(Vector3(0, 5.85, 0), Vector3(0.6, 0.25, 0.6), iron.darkened(0.15))
	beam(Vector3(0, 5.9, 0), Vector3(0, 7.6, 0), 0.08, iron)
	add("ball", Vector3(0, 7.6, 0), Vector3.ONE*0.08, Color("f26a5a"))
	for at in [Vector3(-2.5, 0.16, 2.5), Vector3(2.5, 0.16, 2.5)]: tree(at, 1.0)

func lm_bigben() -> void:
	var sand := Color("d9c08e")
	plaza_square(2.8, Color("b9b6aa"))
	# Parliament wing behind the tower.
	box(Vector3(-0.8, 0.8, -1.6), Vector3(3.8, 1.3, 1.0), sand)
	gable_x(Vector3(-0.8, 1.45, -1.6), 3.8, 0.5, 0.45, Color("6a7584"))
	for i in 9: add("point", Vector3(-2.6+i*0.45, 1.75, -1.1), Vector3(0.07, 0.5, 0.07), sand)
	for i in 8: arch(Vector3(-2.4+i*0.45, 0.85, -1.08), 0.2, 0.5, 0.0)
	# Elizabeth Tower: ribbed shaft, clock stage, belfry and spire.
	var tower := Vector3(0.9, 0, 0.6)
	box(tower + Vector3(0, 1.9, 0), Vector3(1.3, 3.6, 1.3), sand)
	for sx in [-1, 1]:
		for sz in [-1, 1]: box(tower + Vector3(sx*0.62, 2.0, sz*0.62), Vector3(0.14, 3.8, 0.14), sand.lightened(0.15))
	for y in [1.0, 1.8, 2.6, 3.3]:
		for yaw in [0.0, PI/2]:
			for k in [-0.25, 0.25]:
				arch(tower + Vector3(0, y, 0) + Vector3(sin(yaw), 0, cos(yaw))*0.66 + Vector3(cos(yaw), 0, -sin(yaw))*k, 0.14, 0.4, yaw)
	box(tower + Vector3(0, 4.2, 0), Vector3(1.55, 1.1, 1.55), sand.lightened(0.05))
	for yaw in [0.0, PI/2, PI, -PI/2]:
		var normal := Vector3(sin(yaw), 0, cos(yaw))
		var at := tower + Vector3(0, 4.2, 0) + normal*0.79
		add("cyl", at, Vector3(0.45, 0.04, 0.45), GOLD, Vector3(PI/2, yaw, 0))
		add("cyl", at + normal*0.02, Vector3(0.38, 0.04, 0.38), Color("f8f3dc"), Vector3(PI/2, yaw, 0))
		box(at + normal*0.05 + Vector3(0, 0.12, 0), Vector3(0.04, 0.26, 0.02), DARK, Vector3(0, yaw, 0))
		box(at + normal*0.05 + Vector3(cos(yaw)*0.08, 0, -sin(yaw)*0.08), Vector3(0.18, 0.04, 0.02), DARK, Vector3(0, yaw, 0))
	box(tower + Vector3(0, 5.0, 0), Vector3(1.35, 0.55, 1.35), sand)
	for yaw in [0.0, PI/2]:
		for k in [-0.3, 0.0, 0.3]: arch(tower + Vector3(0, 4.95, 0) + Vector3(sin(yaw), 0, cos(yaw))*0.68 + Vector3(cos(yaw), 0, -sin(yaw))*k, 0.16, 0.3, yaw)
	add("roof", tower + Vector3(0, 6.0, 0), Vector3(1.0, 1.5, 1.0), Color("4f6070"), Vector3(0, PI/4, 0))
	for sx in [-1, 1]:
		for sz in [-1, 1]: add("point", tower + Vector3(sx*0.6, 5.55, sz*0.6), Vector3(0.1, 0.6, 0.1), GOLD)
	beam(tower + Vector3(0, 6.7, 0), tower + Vector3(0, 7.4, 0), 0.06, GOLD)
	for x in [-2.3, 2.4]: lamp(Vector3(x, 0.14, 2.4))

func lm_pisa() -> void:
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.2, 0.1, 3.2), GRASS)
	box(Vector3(0, 0.12, 2.6), Vector3(4.5, 0.05, 0.6), STONE)
	# Build straight, then lean the whole tower about its base.
	var tower: Array = []
	var base := 0.12
	for level in 7:
		var y := base + level*0.72
		var radius := 1.05 if level < 6 else 0.8
		tower.append(m.piece("cyl", Vector3(0, y+0.36, 0), Vector3(radius*0.82, 0.72, radius*0.82), Color("efe8d6")))
		tower.append(m.piece("cyl", Vector3(0, y+0.7, 0), Vector3(radius, 0.08, radius), WHITE))
		var count := 16 if level < 6 else 12
		for i in count:
			var a := i*TAU/count
			tower.append(m.piece("cylinder", Vector3(cos(a)*radius*0.95, y+0.35, sin(a)*radius*0.95), Vector3(0.05, 0.62, 0.05), WHITE))
			if i % 2 == 0: tower.append(m.piece("box", Vector3(cos(a)*radius*0.84, y+0.35, sin(a)*radius*0.84), Vector3(0.14, 0.4, 0.04), Color("9d937f"), Vector3(0, -a+PI/2, 0)))
	tower.append(m.piece("cyl", Vector3(0, base+5.3, 0), Vector3(0.62, 0.3, 0.62), WHITE))
	tower.append(m.piece("hemi", Vector3(0, base+5.45, 0), Vector3(0.5, 0.25, 0.5), Color("d9d0bc")))
	var lean := Transform3D(Basis(Vector3.BACK, -0.12), Vector3.ZERO)
	for p in tower:
		p.transform = lean * p.transform
		parts.append(p)
	for i in 7: box(Vector3(-2.2+i*0.7, 0.3, -2.4), Vector3(0.08, 0.35, 0.08), WHITE)
	box(Vector3(0, 0.45, -2.4), Vector3(4.3, 0.05, 0.05), WHITE)

func lm_colosseum() -> void:
	var travertine := Color("dcc59c")
	add("cyl", Vector3(0, 0.06, 0), Vector3(3.3, 0.12, 2.8), Color("c9b58f"))
	add("cyl", Vector3(0, 0.15, 0), Vector3(1.4, 0.06, 1.0), Color("e0c48b"))
	# Tiered seating inside.
	for step in 4:
		add("ring", Vector3(0, 0.3+step*0.35, 0), Vector3(1.75+step*0.28, 0.5, 1.3+step*0.28), travertine.darkened(0.12))
	var count := 28
	for floor_index in 4:
		for i in count:
			var a := i*TAU/count
			# The south-west side is ruined down to the lower tiers.
			if floor_index >= 2 and a > PI*1.05 and a < PI*1.6: continue
			var at := Vector3(cos(a)*2.9, 0.12 + floor_index*0.95, sin(a)*2.4)
			var outward := PI/2 - a
			if floor_index < 3:
				box(at + Vector3(0, 0.45, 0), Vector3(0.34, 0.9, 0.12), travertine, Vector3(0, outward, 0))
				arch(at + Vector3(0, 0.35, 0) + Vector3(cos(a), 0, sin(a))*0.02, 0.3, 0.45, outward, Color("7b6b55"))
				box(at + Vector3(0, 0.92, 0), Vector3(0.7, 0.12, 0.4), travertine.lightened(0.08), Vector3(0, outward, 0))
			else:
				box(at + Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 0.3), travertine, Vector3(0, outward, 0))

# --- Africa ----------------------------------------------------------------------

func lm_pyramid() -> void:
	var sand := Color("e2c48c")
	add("cyl", Vector3(0, 0.04, 0), Vector3(3.3, 0.08, 3.3), Color("e6cf9f"))
	for step in 12:
		var half := 2.2 - step*0.18
		box(Vector3(0, 0.12 + step*0.34, 0), Vector3(half*2, 0.34, half*2), sand if step % 2 == 0 else sand.darkened(0.06))
	add("roof", Vector3(0, 4.35, 0), Vector3(0.34, 0.45, 0.34), GOLD, Vector3(0, PI/4, 0))
	box(Vector3(0, 0.55, 2.2), Vector3(0.45, 0.7, 0.2), Color("7b654b"))
	for at in [Vector3(2.5, 0, 1.8), Vector3(-2.4, 0, 2.1)]:
		add("roof", at + Vector3(0, 0.55, 0), Vector3(0.75, 1.1, 0.75), sand.darkened(0.08), Vector3(0, PI/4, 0))
	# A resting camel.
	box(Vector3(1.4, 0.35, 2.6), Vector3(0.7, 0.3, 0.3), Color("b98a55"))
	add("ball", Vector3(1.4, 0.55, 2.6), Vector3(0.2, 0.18, 0.14), Color("b98a55"))
	beam(Vector3(1.75, 0.4, 2.6), Vector3(1.95, 0.8, 2.6), 0.1, Color("b98a55"))
	box(Vector3(2.02, 0.82, 2.6), Vector3(0.2, 0.1, 0.12), Color("b98a55"))

func lm_sphinx() -> void:
	var stone := Color("d7b27a")
	box(Vector3(0, 0.1, 0), Vector3(6.2, 0.2, 4.2), Color("c9a86d"))
	box(Vector3(0, 0.3, 0), Vector3(5.8, 0.2, 3.8), Color("e3c792"))
	# Lying lion body with forward paws.
	add("smooth", Vector3(-0.6, 1.0, 0), Vector3(2.3, 0.85, 1.05), stone)
	add("smooth", Vector3(-2.3, 0.85, 0), Vector3(0.8, 0.6, 0.95), stone)
	for z in [-0.55, 0.55]:
		box(Vector3(1.6, 0.55, z), Vector3(2.0, 0.4, 0.42), stone)
		add("smooth", Vector3(2.6, 0.55, z), Vector3(0.28, 0.2, 0.22), stone)
	# Head with the striped nemes headdress.
	box(Vector3(1.25, 2.05, 0), Vector3(0.9, 0.95, 1.1), stone)
	box(Vector3(1.55, 1.85, 0), Vector3(0.4, 0.75, 0.6), stone.lightened(0.05))
	for i in 6: box(Vector3(1.2, 1.7+i*0.12, 0), Vector3(0.95, 0.05, 1.18), Color("5e7ca8") if i % 2 == 0 else Color("e2c06a"))
	box(Vector3(1.25, 2.6, 0), Vector3(0.95, 0.2, 1.0), stone)
	box(Vector3(1.76, 2.0, 0), Vector3(0.05, 0.08, 0.34), Color("6b4f36"))
	box(Vector3(1.76, 2.2, 0), Vector3(0.12, 0.25, 0.12), stone.darkened(0.08))
	for z in [-0.18, 0.18]: box(Vector3(1.76, 2.35, z), Vector3(0.05, 0.06, 0.14), Color("3b2d22"))
	box(Vector3(1.9, 1.55, 0), Vector3(0.12, 0.35, 0.14), stone)
	add("roof", Vector3(-2.6, 1.0, -2.2), Vector3(0.9, 1.4, 0.9), Color("dcbc80"), Vector3(0, PI/4, 0))

func lm_djenne() -> void:
	var mud := Color("b9794a")
	box(Vector3(0, 0.25, 0), Vector3(5.8, 0.5, 4.6), mud.darkened(0.1))
	box(Vector3(0, 1.3, -0.3), Vector3(5.2, 1.7, 3.6), mud)
	# Three tapering minaret towers on the front wall.
	for x in [-1.8, 0.0, 1.8]:
		var h := 3.3 if x == 0.0 else 2.9
		add("frustum", Vector3(x, 0.5+h/2, 1.6), Vector3(0.7, h, 0.7), mud.lightened(0.05), Vector3(0, PI/4, 0))
		add("point", Vector3(x, 0.5+h+0.25, 1.6), Vector3(0.28, 0.5, 0.28), mud.lightened(0.05))
		add("ball", Vector3(x, 0.5+h+0.55, 1.6), Vector3.ONE*0.1, WHITE)
		# Toron palm sticks poke out of the mud walls.
		for level in 4:
			for side in [-1, 1]:
				box(Vector3(x+side*0.22, 1.0+level*0.6, 2.05), Vector3(0.05, 0.05, 0.45), WOOD)
	for i in 11:
		var x := -2.5 + i*0.5
		add("frustum", Vector3(x, 2.4, 1.45), Vector3(0.26, 0.9, 0.26), mud.lightened(0.02), Vector3(0, PI/4, 0))
		add("ball", Vector3(x, 2.9, 1.45), Vector3.ONE*0.08, WHITE)
		for level in 3: box(Vector3(x, 0.8+level*0.5, 1.5), Vector3(0.04, 0.04, 0.35), WOOD)
	for i in 8: box(Vector3(2.62, 1.0+(i%3)*0.5, -1.6+i*0.4), Vector3(0.35, 0.04, 0.04), WOOD)
	arch(Vector3(0, 1.0, 1.97), 0.5, 0.8, 0.0)

func lm_baobab() -> void:
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.2, 0.1, 3.2), Color("d4b877"))
	var bark := Color("a78b72")
	add("smooth", Vector3(0, 1.8, 0), Vector3(1.05, 1.9, 1.05), bark)
	add("cyl", Vector3(0, 3.8, 0), Vector3(0.6, 1.2, 0.6), bark)
	for i in 7:
		var a := i*TAU/7.0
		var tip := Vector3(cos(a)*1.9, 5.2 + (i%2)*0.4, sin(a)*1.9)
		beam(Vector3(0, 4.2, 0), tip, 0.22, bark)
		add("ball", tip + Vector3(0, 0.2, 0), Vector3(0.75, 0.35, 0.75), Color("6f9a4f"))
	add("ball", Vector3(0, 4.8, 0), Vector3(0.8, 0.4, 0.8), Color("7aa65a"))
	# Smaller baobabs, a hut and grass tufts around the giant.
	for at in [Vector3(2.4, 0, 1.6), Vector3(-2.3, 0, 1.9)]:
		add("smooth", at + Vector3(0, 0.8, 0), Vector3(0.35, 0.8, 0.35), bark)
		add("ball", at + Vector3(0, 1.75, 0), Vector3(0.5, 0.25, 0.5), Color("6f9a4f"))
	add("cyl", Vector3(-1.9, 0.35, -1.9), Vector3(0.5, 0.6, 0.5), Color("c79a63"))
	add("point", Vector3(-1.9, 0.95, -1.9), Vector3(0.7, 0.6, 0.7), Color("c8a55c"))
	for i in 10:
		var a := i*2.4
		add("point", Vector3(cos(a)*2.6, 0.2, sin(a)*2.6), Vector3(0.12, 0.3, 0.12), Color("a4a45a"))

# --- North America ----------------------------------------------------------------

func lm_liberty() -> void:
	var copper := Color("7fbba3")
	# Star-shaped Fort Wood base.
	for i in 11:
		box(Vector3(0, 0.2, 0), Vector3(4.6, 0.4, 1.5), Color("b9b0a0"), Vector3(0, i*TAU/11.0, 0))
	plaza_square(1.6, Color("c9c2b1"))
	box(Vector3(0, 0.9, 0), Vector3(1.9, 1.2, 1.9), Color("d9cdb4"))
	box(Vector3(0, 1.8, 0), Vector3(1.5, 0.6, 1.5), Color("cfc2a7"))
	box(Vector3(0, 2.2, 0), Vector3(1.7, 0.2, 1.7), Color("d9cdb4"))
	for yaw in [0.0, PI/2]: arch(Vector3(0, 1.0, 0) + Vector3(sin(yaw), 0, cos(yaw))*0.96, 0.4, 0.6, yaw)
	# Draped robe from stacked folds.
	add("frustum", Vector3(0, 3.1, 0), Vector3(0.95, 1.8, 0.85), copper, Vector3(0, PI/4, 0))
	for i in 8:
		var a := i*TAU/8.0
		add("point", Vector3(cos(a)*0.42, 2.9, sin(a)*0.42), Vector3(0.16, 1.4, 0.16), copper.darkened(0.08))
	add("cyl", Vector3(0, 4.15, 0), Vector3(0.38, 0.5, 0.35), copper)
	add("smooth", Vector3(0, 4.62, 0.02), Vector3(0.24, 0.3, 0.24), copper)
	for i in 7:
		var a := (i-3)*0.32
		beam(Vector3(0, 4.85, 0), Vector3(sin(a)*0.45, 4.85+cos(a)*0.45, -0.05), 0.06, copper)
	beam(Vector3(0.3, 4.2, 0), Vector3(0.75, 5.6, 0.1), 0.2, copper)
	add("cyl", Vector3(0.78, 5.75, 0.1), Vector3(0.12, 0.3, 0.12), copper.darkened(0.1))
	add("point", Vector3(0.78, 6.1, 0.1), Vector3(0.16, 0.45, 0.16), Color("f2c14e"))
	box(Vector3(-0.42, 3.9, 0.2), Vector3(0.18, 0.55, 0.36), copper.darkened(0.15), Vector3(0, 0, 0.25))

func lm_empire() -> void:
	var stone := Color("cfc8b8")
	plaza_square(2.4, Color("a9a9a4"))
	# Art-deco setbacks with vertical window strips.
	var tiers := [[3.6, 1.0], [2.8, 0.8], [2.2, 3.2], [1.6, 0.6], [1.2, 0.6]]
	var y := 0.14
	for tier in tiers:
		var width: float = tier[0]
		var height: float = tier[1]
		box(Vector3(0, y + height/2, 0), Vector3(width, height, width*0.85), stone)
		for i in int(width/0.28):
			for face in [1, -1]:
				box(Vector3(-width/2 + 0.14 + i*0.28, y + height/2, face*width*0.425), Vector3(0.08, height*0.9, 0.03), Color("6d7f91"))
		y += height
	add("cyl", Vector3(0, y+0.4, 0), Vector3(0.4, 0.8, 0.4), stone)
	add("cyl", Vector3(0, y+1.0, 0), Vector3(0.25, 0.5, 0.25), Color("dcd6c7"))
	add("point", Vector3(0, y+1.5, 0), Vector3(0.2, 0.6, 0.2), Color("dcd6c7"))
	beam(Vector3(0, y+1.7, 0), Vector3(0, y+2.6, 0), 0.05, Color("9aa4ad"))

func lm_needle() -> void:
	plaza_round(2.6, Color("b7c6b4"))
	var white := Color("f3f2ec")
	# Three pairs of legs pinched at the waist.
	for i in 3:
		var a := i*TAU/3.0
		var foot := Vector3(cos(a)*1.9, 0.15, sin(a)*1.9)
		var waist := Vector3(cos(a)*0.25, 2.6, sin(a)*0.25)
		var top := Vector3(cos(a)*0.55, 4.9, sin(a)*0.55)
		for side in [-0.2, 0.2]:
			var offset: Vector3 = Vector3(-sin(a), 0, cos(a))*side
			beam(foot + offset, waist, 0.12, white)
			beam(waist, top + offset, 0.12, white)
	add("cyl", Vector3(0, 2.6, 0), Vector3(0.26, 5.2, 0.26), Color("dedcd4"))
	add("cyl", Vector3(0, 1.9, 0), Vector3(0.6, 0.06, 0.6), Color("e8a24a"))
	# The halo: restaurant saucer with glass band and golden roof.
	add("cyl", Vector3(0, 5.0, 0), Vector3(1.55, 0.18, 1.55), white)
	add("cyl", Vector3(0, 5.25, 0), Vector3(1.35, 0.32, 1.35), GLASS)
	add("cyl", Vector3(0, 5.48, 0), Vector3(1.65, 0.1, 1.65), white)
	add("point", Vector3(0, 5.75, 0), Vector3(1.3, 0.45, 1.3), Color("e8a24a"))
	beam(Vector3(0, 5.9, 0), Vector3(0, 7.2, 0), 0.07, white)

func lm_chichen() -> void:
	var stone := Color("cfc6ae")
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.4, 0.1, 3.4), GRASS)
	for step in 9:
		var half := 2.3 - step*0.2
		box(Vector3(0, 0.15 + step*0.36, 0), Vector3(half*2, 0.36, half*2), stone if step % 2 == 0 else stone.darkened(0.07))
	# Stairways with balustrades and serpent heads on every side.
	for yaw in [0.0, PI/2, PI, -PI/2]:
		var normal := Vector3(sin(yaw), 0, cos(yaw))
		var side := Vector3(cos(yaw), 0, -sin(yaw))
		beam(normal*2.35 + Vector3(0, 0.15, 0), normal*0.8 + Vector3(0, 3.35, 0), 0.8, stone.lightened(0.06))
		for s in [-1, 1]:
			beam(normal*2.4 + side*s*0.45 + Vector3(0, 0.3, 0), normal*0.85 + side*s*0.45 + Vector3(0, 3.5, 0), 0.12, stone.darkened(0.12))
			add("ball", normal*2.55 + side*s*0.45 + Vector3(0, 0.25, 0), Vector3(0.16, 0.14, 0.2), Color("7fa06a"))
	box(Vector3(0, 3.75, 0), Vector3(1.2, 0.8, 1.2), stone.lightened(0.04))
	box(Vector3(0, 4.2, 0), Vector3(1.35, 0.15, 1.35), stone.darkened(0.08))
	for yaw in [0.0, PI/2]: arch(Vector3(0, 3.65, 0) + Vector3(sin(yaw), 0, cos(yaw))*0.61, 0.35, 0.5, yaw)

# --- South America ----------------------------------------------------------------

func lm_christ() -> void:
	var soapstone := Color("e6e3d8")
	# Corcovado peak with forest.
	add("point", Vector3(0, 1.3, 0), Vector3(3.0, 2.6, 2.8), Color("6f8f5d"))
	for i in 12:
		var a := i*TAU/12.0
		add("ball", Vector3(cos(a)*2.2, 0.45, sin(a)*2.0), Vector3(0.45, 0.4, 0.45), Color("4f8a4f"))
	add("point", Vector3(0, 1.9, 0), Vector3(1.6, 1.4, 1.5), Color("8d8a7c"))
	box(Vector3(0, 2.7, 0), Vector3(0.95, 0.35, 0.95), Color("cfcabb"))
	box(Vector3(0, 3.2, 0), Vector3(0.6, 0.7, 0.6), Color("d9d5c8"))
	# Robed figure with outstretched arms.
	add("frustum", Vector3(0, 4.5, 0), Vector3(0.55, 2.0, 0.45), soapstone, Vector3(0, PI/4, 0))
	for i in 5: box(Vector3(-0.2+i*0.1, 4.2, 0.24), Vector3(0.03, 1.6, 0.03), soapstone.darkened(0.08))
	box(Vector3(0, 5.55, 0), Vector3(0.55, 0.45, 0.35), soapstone)
	box(Vector3(0, 5.6, 0), Vector3(3.6, 0.28, 0.28), soapstone)
	for x in [-1.65, 1.65]: box(Vector3(x, 5.5, 0), Vector3(0.25, 0.35, 0.3), soapstone)
	add("smooth", Vector3(0, 6.0, 0), Vector3(0.2, 0.26, 0.22), soapstone)

func lm_machu() -> void:
	var stone := Color("a8a293")
	# Terraced ridge with ruins, and Huayna Picchu rising behind.
	add("point", Vector3(-0.4, 2.4, -1.6), Vector3(1.5, 4.8, 1.3), Color("5d8a55"))
	add("point", Vector3(-0.4, 4.2, -1.6), Vector3(0.5, 1.0, 0.45), stone)
	for step in 6:
		var w := 5.6 - step*0.6
		var d := 4.2 - step*0.45
		box(Vector3(0.3, 0.2 + step*0.4, 0.4), Vector3(w, 0.4, d), Color("7fae63") if step % 2 == 0 else Color("73a45a"))
		box(Vector3(0.3, 0.2 + step*0.4, 0.4 + d/2), Vector3(w, 0.4, 0.06), stone)
	var top := 2.5
	for at in [Vector3(-0.6, top, 0.6), Vector3(0.6, top, 0.9), Vector3(1.3, top, -0.1), Vector3(-0.1, top, -0.3), Vector3(1.0, top-0.4, 1.5)]:
		box(at + Vector3(0, 0.25, 0), Vector3(0.6, 0.5, 0.45), stone)
		gable_x(at + Vector3(0, 0.5, 0), 0.6, 0.25, 0.3, Color("c9a55a"))
	# A llama on the lawn.
	box(Vector3(2.4, 0.5, 1.8), Vector3(0.4, 0.22, 0.2), WHITE)
	beam(Vector3(2.55, 0.55, 1.8), Vector3(2.62, 0.9, 1.8), 0.08, WHITE)
	for x in [2.28, 2.52]: box(Vector3(x, 0.3, 1.8), Vector3(0.05, 0.3, 0.14), WHITE)

func lm_obelisco() -> void:
	plaza_round(3.0, Color("b7c4a2"), Color("cfcac0"))
	add("ring", Vector3(0, 0.14, 0), Vector3(2.5, 0.2, 2.5), Color("6c7179"))
	for i in 8:
		var a := i*TAU/8.0
		add("ball", Vector3(cos(a)*1.4, 0.25, sin(a)*1.4), Vector3(0.3, 0.14, 0.3), Color("e38bb0") if i % 2 == 0 else Color("f2d36b"))
		if i % 2 == 1: beam(Vector3(cos(a)*1.9, 0.14, sin(a)*1.9), Vector3(cos(a)*1.9, 1.4, sin(a)*1.9), 0.04, Color("cfd5dc"))
	box(Vector3(0, 0.35, 0), Vector3(1.0, 0.4, 1.0), Color("dcd6c8"))
	add("frustum", Vector3(0, 3.6, 0), Vector3(0.8, 6.2, 0.8), WHITE, Vector3(0, PI/4, 0))
	add("roof", Vector3(0, 6.95, 0), Vector3(0.36, 0.5, 0.36), WHITE, Vector3(0, PI/4, 0))
	for yaw in [0.0, PI/2]: box(Vector3(0, 6.3, 0) + Vector3(sin(yaw), 0, cos(yaw))*0.24, Vector3(0.1, 0.12, 0.02), DARK, Vector3(0, yaw, 0))

func lm_sugarloaf() -> void:
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.3, 0.1, 3.3), WATER)
	add("cyl", Vector3(-0.2, 0.15, -0.2), Vector3(2.6, 0.12, 2.4), Color("e6d7a8"))
	var granite := Color("9a9588")
	add("smooth", Vector3(0.4, 1.8, -0.5), Vector3(1.4, 2.6, 1.3), granite)
	add("smooth", Vector3(0.4, 0.8, -0.5), Vector3(1.8, 1.0, 1.7), Color("5f9055"))
	add("smooth", Vector3(-1.6, 0.8, 0.9), Vector3(1.0, 1.2, 0.9), granite.lightened(0.05))
	add("smooth", Vector3(-1.6, 0.45, 0.9), Vector3(1.2, 0.6, 1.1), Color("5f9055"))
	# Cable car line between the two peaks.
	beam(Vector3(-1.6, 2.0, 0.9), Vector3(0.4, 4.35, -0.5), 0.03, DARK)
	box(Vector3(-0.6, 3.05, 0.2), Vector3(0.35, 0.3, 0.3), Color("e2574c"))
	for at in [Vector3(1.9, 0.2, 1.8), Vector3(2.4, 0.2, 1.1), Vector3(1.4, 0.2, 2.3)]:
		beam(at, at + Vector3(0.1, 1.0, 0), 0.08, WOOD)
		for k in 5: box(at + Vector3(0.1, 1.0, 0), Vector3(0.6, 0.05, 0.14), Color("4f9b5c"), Vector3(0, k*TAU/5.0, -0.4))

# --- Oceania --------------------------------------------------------------------

func lm_sydney() -> void:
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.3, 0.1, 3.3), WATER)
	box(Vector3(0, 0.35, 0), Vector3(5.0, 0.5, 3.0), Color("d9c7a7"))
	for i in 7: box(Vector3(-1.5+i*0.5, 0.65, 1.55), Vector3(0.45, 0.1, 0.25), Color("cdbb9b"))
	# Two rows of interlocking shells with glass fronts.
	var shell := Color("f7f6f0")
	for row in [-0.55, 0.65]:
		for i in 3:
			var x: float = -1.6 + i*1.15 + row*0.4
			var height := 1.6 + i*0.35
			add("hemi", Vector3(x, 0.6, row), Vector3(0.55, height, 0.62), shell, Vector3(0, 0, -0.45))
			add("hemi", Vector3(x+0.45, 0.6, row), Vector3(0.42, height*0.72, 0.5), shell.darkened(0.04), Vector3(0, 0, -0.45))
			box(Vector3(x-0.2, 0.9, row+0.55), Vector3(0.5, 0.5, 0.04), GLASS)
			beam(Vector3(x, 0.6, row+0.6), Vector3(x+0.6, 0.6+height*0.85, row+0.6), 0.03, Color("dcd9cf"))

func lm_uluru() -> void:
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.4, 0.1, 3.4), Color("d0874f"))
	var rock := Color("c0603a")
	add("smooth", Vector3(0, 0.9, 0), Vector3(3.0, 1.35, 1.8), rock)
	add("smooth", Vector3(0.5, 1.3, -0.1), Vector3(2.0, 1.05, 1.3), rock.lightened(0.05))
	# Weathered gullies and caves.
	for i in 9:
		var x := -2.2 + i*0.55
		var z := sqrt(maxf(0.0, 1.0 - pow(x/3.0, 2)))*1.75
		box(Vector3(x, 0.9, z), Vector3(0.07, 1.2, 0.08), rock.darkened(0.25), Vector3(0.35, 0, 0))
	for x in [-1.2, 0.8]: add("hemi", Vector3(x, 0.1, 1.55), Vector3(0.25, 0.3, 0.1), Color("5a2d1c"))
	for i in 14:
		var a := i*2.3
		add("ball", Vector3(cos(a)*3.0, 0.18, sin(a)*2.9), Vector3(0.2, 0.12, 0.2), Color("b4a258"))

func lm_skytower() -> void:
	plaza_round(2.2, Color("c2c8c9"))
	var concrete := Color("dcdcd6")
	for i in 3:
		var a := i*TAU/3.0 + 0.3
		beam(Vector3(cos(a)*1.0, 0.15, sin(a)*1.0), Vector3(cos(a)*0.4, 1.8, sin(a)*0.4), 0.28, concrete)
	add("cyl", Vector3(0, 2.9, 0), Vector3(0.42, 5.4, 0.42), concrete)
	# Observation pod: stacked discs with glass bands.
	add("cyl", Vector3(0, 5.4, 0), Vector3(1.05, 0.18, 1.05), concrete)
	add("cyl", Vector3(0, 5.65, 0), Vector3(1.15, 0.34, 1.15), GLASS)
	add("cyl", Vector3(0, 5.9, 0), Vector3(1.2, 0.14, 1.2), concrete)
	add("cyl", Vector3(0, 6.1, 0), Vector3(0.95, 0.28, 0.95), GLASS.darkened(0.1))
	add("cyl", Vector3(0, 6.3, 0), Vector3(0.8, 0.12, 0.8), concrete)
	for i in 6:
		var color := Color("e2574c") if i % 2 == 0 else WHITE
		add("cyl", Vector3(0, 6.5+i*0.22, 0), Vector3(0.1-i*0.01, 0.22, 0.1-i*0.01), color)
	for x in [-1.8, 1.8]: tree(Vector3(x, 0.14, 1.4), 1.0)

func lm_moai() -> void:
	add("cyl", Vector3(0, 0.05, 0), Vector3(3.3, 0.1, 3.3), GRASS)
	add("cyl", Vector3(0, 0.08, 2.7), Vector3(2.5, 0.06, 0.8), WATER)
	box(Vector3(0, 0.35, -0.3), Vector3(5.2, 0.5, 1.6), Color("8f8b80"))
	var rock := Color("8d8a7e")
	for i in 5:
		var h := 2.4 + (0.4 if i == 2 else 0.0) - absf(i-2)*0.15
		var at := Vector3(-2.0 + i*1.0, 0.6, -0.3)
		box(at + Vector3(0, h*0.35, 0), Vector3(0.7, h*0.7, 0.55), rock)
		box(at + Vector3(0, h*0.83, 0.04), Vector3(0.62, h*0.35, 0.6), rock.lightened(0.04))
		box(at + Vector3(0, h*0.93, 0.3), Vector3(0.64, 0.12, 0.2), rock.darkened(0.15))
		box(at + Vector3(0, h*0.8, 0.36), Vector3(0.16, h*0.24, 0.18), rock.darkened(0.05))
		box(at + Vector3(0, h*0.68, 0.32), Vector3(0.36, 0.06, 0.1), rock.darkened(0.2))
		for side in [-0.36, 0.36]: box(at + Vector3(side, h*0.84, 0), Vector3(0.07, h*0.26, 0.16), rock.darkened(0.1))
		if i % 2 == 0: add("cyl", at + Vector3(0, h+0.12, 0.02), Vector3(0.3, 0.24, 0.3), Color("a8553f"))
