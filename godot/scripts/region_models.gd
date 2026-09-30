extends RefCounted

# Regional houses and trees, Earth's defence bosses, their minions and the alien
# saucer. Everything returns primitive parts for ToyModels.bake().
var m
var parts: Array = []
const DARK = Color("33414f")
const GLASS = Color("8fc3d6")
const WOOD = Color("8a5a3c")
const WINDOW = Color("9cc8d6")

func _init(models) -> void:
	m = models

func add(shape: String, at: Vector3, size: Vector3, color: Color, rotate := Vector3.ZERO) -> void:
	parts.append(m.piece(shape, at, size, color, rotate))

func box(at: Vector3, size: Vector3, color: Color, rotate := Vector3.ZERO) -> void:
	add("box", at, size, color, rotate)

func beam(a: Vector3, b: Vector3, width: float, color: Color, shape := "box") -> void:
	var delta := b - a
	if delta.length() < 0.001: return
	add(shape, (a + b)*0.5, Vector3(width, delta.length(), width), color, Quaternion(Vector3.UP, delta.normalized()).get_euler())

func gable_x(center: Vector3, length: float, half_depth: float, height: float, color: Color) -> void:
	add("prism", center, Vector3(height, length, half_depth), color, Vector3(0, 0, PI/2))

# Window grid on the +z and +x faces (the ones the camera sees).
func windows(center: Vector3, size: Vector3, floors: int, per_floor: int, color := WINDOW) -> void:
	for f in floors:
		var y := center.y - size.y/2 + (f + 0.6)*size.y/(floors + 0.4)
		for i in per_floor:
			var t := (i + 0.5)/per_floor - 0.5
			box(Vector3(center.x + t*size.x*0.8, y, center.z + size.z/2 + 0.02), Vector3(size.x*0.5/per_floor, size.y*0.35/floors, 0.05), color)
			box(Vector3(center.x + size.x/2 + 0.02, y, center.z + t*size.z*0.8), Vector3(0.05, size.y*0.35/floors, size.z*0.5/per_floor), color)

func take() -> Array:
	var result := parts
	parts = []
	return result

# --- houses ----------------------------------------------------------------------

func house(style: String, color: Color, variant: int) -> Array:
	match style:
		"asia": asia_house(color, variant)
		"europe": europe_house(color, variant)
		"africa": africa_house(color, variant)
		"namerica": namerica_house(color, variant)
		"samerica": samerica_house(color, variant)
		_: oceania_house(color, variant)
	return take()

func asia_house(color: Color, variant: int) -> void:
	box(Vector3(0, 0.1, 0), Vector3(2.3, 0.2, 2.0), Color("b9ae98"))
	box(Vector3(0, 0.75, 0), Vector3(1.9, 1.1, 1.6), Color("f3ead6"))
	for sx in [-1, 1]:
		for sz in [-1, 1]: add("cylinder", Vector3(sx*0.95, 0.75, sz*0.8), Vector3(0.07, 1.1, 0.07), Color("7a3b2c"))
	box(Vector3(0, 0.6, 0.81), Vector3(0.45, 0.8, 0.05), Color("a8413a"))
	for x in [-0.6, 0.6]: box(Vector3(x, 0.85, 0.81), Vector3(0.36, 0.36, 0.05), Color("5b4636"))
	add("roof", Vector3(0, 1.62, 0), Vector3(1.6, 0.75, 1.45), color, Vector3(0, PI/4, 0))
	box(Vector3(0, 1.3, 0), Vector3(2.4, 0.08, 2.1), color.darkened(0.2))
	for sx in [-1, 1]:
		for sz in [-1, 1]: box(Vector3(sx*1.2, 1.38, sz*1.05), Vector3(0.1, 0.28, 0.1), color, Vector3(-sz*0.6, 0, sx*0.6))
	if variant % 2 == 1:
		box(Vector3(0, 2.1, 0), Vector3(0.9, 0.5, 0.8), Color("f3ead6"))
		add("roof", Vector3(0, 2.55, 0), Vector3(0.85, 0.45, 0.8), color, Vector3(0, PI/4, 0))
	add("ball", Vector3(0, 2.0 if variant % 2 == 0 else 2.8, 0), Vector3.ONE*0.08, Color("e9c162"))

func europe_house(color: Color, variant: int) -> void:
	var wall: Color = [Color("f1e3c8"), Color("e8d0c0"), Color("d8e0e3"), Color("efe7c9")][variant % 4]
	var height := 2.2 if variant % 2 == 0 else 1.7
	var at := Vector3(0, height/2, 0)
	box(at, Vector3(1.8, height, 1.6), wall)
	windows(at + Vector3(0, 0.15, 0), Vector3(1.8, height, 1.6), 3 if height > 2 else 2, 2, Color("7aa7bd"))
	for f in 2: box(Vector3(0, 0.6 + f*0.7, 0.82), Vector3(1.6, 0.05, 0.08), Color("d6c3a4"))
	box(Vector3(0, 0.4, 0.81), Vector3(0.36, 0.7, 0.05), Color("5b4636"))
	gable_x(Vector3(0, height, 0), 1.95, 0.9, 0.85, color)
	box(Vector3(0.5, height+0.55, -0.3), Vector3(0.22, 0.6, 0.22), Color("b5776a"))
	if variant == 3:
		for x in [-0.4, 0.4]: add("roof", Vector3(x, height+0.35, 0.75), Vector3(0.25, 0.35, 0.18), color.darkened(0.1), Vector3(0, PI/4, 0))

func africa_house(color: Color, variant: int) -> void:
	var mud := Color("d7a56b").lerp(color, 0.2)
	box(Vector3(0, 0.6, 0), Vector3(2.1, 1.2, 1.8), mud)
	# Parapet with little crenels and toron sticks.
	for side in [-1, 1]:
		box(Vector3(0, 1.28, side*0.87), Vector3(2.1, 0.16, 0.08), mud.darkened(0.08))
		box(Vector3(side*1.02, 1.28, 0), Vector3(0.08, 0.16, 1.8), mud.darkened(0.08))
	for i in 5: add("point", Vector3(-0.8+i*0.4, 1.45, 0.87), Vector3(0.08, 0.2, 0.08), mud.darkened(0.08))
	for i in 4: box(Vector3(-0.75+i*0.5, 0.95, 0.95), Vector3(0.04, 0.04, 0.25), WOOD)
	box(Vector3(0, 0.45, 0.91), Vector3(0.4, 0.8, 0.05), Color("5b3d2a"))
	for z in [-0.4, 0.4]: box(Vector3(1.06, 0.75, z), Vector3(0.05, 0.3, 0.25), Color("3e2c22"))
	if variant % 3 == 1:
		add("hemi", Vector3(0, 1.2, 0), Vector3(0.7, 0.6, 0.7), Color("f1ead8"))
	elif variant % 3 == 2:
		box(Vector3(-0.4, 1.6, -0.3), Vector3(1.0, 0.8, 0.9), mud.lightened(0.06))
		box(Vector3(-0.4, 1.4, 0.16), Vector3(0.3, 0.4, 0.04), Color("3e2c22"))

func namerica_house(color: Color, variant: int) -> void:
	if variant == 3:
		# Downtown glass office block.
		var tower := Vector3(0, 2.0, 0)
		box(tower, Vector3(1.8, 4.0, 1.6), Color("7fa2bf"))
		for f in 8: box(tower + Vector3(0, -1.75 + f*0.5, 0), Vector3(1.84, 0.06, 1.64), Color("dfe6ea"))
		box(tower + Vector3(0, 2.1, 0), Vector3(1.2, 0.3, 1.0), Color("c8d0d6"))
		return
	var siding: Color = [Color("eef0ea"), Color("d8e4ef"), Color("f1e2c6")][variant]
	box(Vector3(-0.2, 0.55, 0), Vector3(1.6, 1.1, 1.6), siding)
	gable_x(Vector3(-0.2, 1.1, 0), 1.75, 0.9, 0.7, color)
	box(Vector3(0.95, 0.4, 0.1), Vector3(0.8, 0.8, 1.4), siding.darkened(0.04))
	box(Vector3(0.95, 0.85, 0.1), Vector3(0.9, 0.1, 1.5), color.darkened(0.1))
	box(Vector3(0.95, 0.35, 0.81), Vector3(0.6, 0.6, 0.04), Color("dcdcd6"))
	for i in 4: box(Vector3(0.95, 0.12+i*0.15, 0.84), Vector3(0.6, 0.02, 0.02), Color("b7b7b0"))
	box(Vector3(-0.2, 0.4, 0.81), Vector3(0.32, 0.65, 0.05), Color("6d4c3d"))
	for x in [-0.72, 0.3]: box(Vector3(x, 0.65, 0.81), Vector3(0.3, 0.3, 0.05), WINDOW)
	box(Vector3(-0.2, 0.08, 1.05), Vector3(1.6, 0.06, 0.5), Color("c9b89a"))

func samerica_house(color: Color, variant: int) -> void:
	var brights := [Color("f28b66"), Color("f4cf5d"), Color("6cc3b2"), Color("e46a8e"), Color("7fa6e8")]
	var lower: Color = brights[variant % brights.size()]
	var upper: Color = brights[(variant + 2) % brights.size()]
	box(Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 1.7), lower)
	box(Vector3(-0.25, 1.6, -0.2), Vector3(1.3, 0.8, 1.2), upper)
	box(Vector3(0, 1.22, 0), Vector3(2.1, 0.06, 1.8), Color("c46f4d"))
	box(Vector3(-0.25, 2.03, -0.2), Vector3(1.4, 0.06, 1.3), Color("c46f4d"))
	add("cyl", Vector3(0.5, 2.3, -0.4), Vector3(0.2, 0.4, 0.2), Color("4d7fb0"))
	box(Vector3(0.4, 0.45, 0.86), Vector3(0.36, 0.75, 0.05), Color("4a3b30"))
	box(Vector3(-0.5, 0.7, 0.86), Vector3(0.4, 0.35, 0.05), WINDOW)
	box(Vector3(-0.25, 1.6, 0.41), Vector3(0.4, 0.3, 0.05), WINDOW)
	box(Vector3(1.01, 0.7, 0), Vector3(0.05, 0.35, 0.5), WINDOW)
	beam(Vector3(-1.0, 1.25, 0.85), Vector3(0.9, 1.25, 0.85), 0.04, color)

func oceania_house(color: Color, variant: int) -> void:
	for sx in [-1, 1]:
		for sz in [-1, 1]: add("cylinder", Vector3(sx*0.85, 0.2, sz*0.7), Vector3(0.07, 0.4, 0.07), WOOD)
	box(Vector3(0, 0.42, 0.1), Vector3(2.1, 0.08, 1.9), Color("b98d62"))
	box(Vector3(0, 0.85, -0.1), Vector3(1.7, 0.8, 1.3), Color("e6caa0") if variant % 2 == 0 else Color("cfe2dc"))
	box(Vector3(0, 0.75, 0.56), Vector3(0.36, 0.6, 0.04), Color("6b4a35"))
	for x in [-0.55, 0.55]: box(Vector3(x, 0.9, 0.56), Vector3(0.34, 0.3, 0.04), WINDOW)
	for i in 8: box(Vector3(-0.95+i*0.27, 0.62, 1.02), Vector3(0.04, 0.35, 0.04), Color("f2e4c8"))
	box(Vector3(0, 0.8, 1.02), Vector3(2.0, 0.04, 0.05), Color("f2e4c8"))
	add("roof", Vector3(0, 1.6, 0), Vector3(1.75, 0.85, 1.6), Color("c9a560").lerp(color, 0.25), Vector3(0, PI/4, 0))

# --- trees -----------------------------------------------------------------------

func tree(style: String, foliage: Color, variant: int) -> Array:
	var kind := ""
	match style:
		"asia": kind = "blossom" if variant == 0 else "bamboo"
		"europe": kind = "round" if variant == 0 else "pine"
		"africa": kind = "acacia" if variant == 0 else "palm"
		"namerica": kind = "pine" if variant == 0 else "round"
		"samerica": kind = "palm" if variant == 0 else "round"
		_: kind = "palm" if variant == 0 else "eucalyptus"
	call("tree_" + kind, foliage)
	return take()

func tree_round(foliage: Color) -> void:
	add("cylinder", Vector3(0, 0.62, 0), Vector3(0.13, 1.24, 0.13), Color("a08367"))
	add("ball", Vector3(0, 1.43, 0), Vector3(0.71, 0.85, 0.68), foliage)
	add("ball", Vector3(-0.35, 1.12, 0.18), Vector3(0.43, 0.5, 0.42), foliage.lightened(0.17))

func tree_blossom(_foliage: Color) -> void:
	beam(Vector3(0, 0, 0), Vector3(0.15, 1.1, 0.05), 0.16, Color("7d5a4a"))
	for at in [Vector3(0.15, 1.35, 0), Vector3(-0.35, 1.15, 0.2), Vector3(0.45, 1.1, -0.2), Vector3(0, 1.1, 0.4)]:
		add("ball", at, Vector3(0.45, 0.38, 0.45), Color("f2a9c4") if at.x >= 0 else Color("f7c5d7"))

func tree_bamboo(foliage: Color) -> void:
	for i in 5:
		var at := Vector3(cos(i*1.3)*0.25, 0, sin(i*1.3)*0.25)
		add("cylinder", at + Vector3(0, 0.8 + i*0.08, 0), Vector3(0.05, 1.6 + i*0.16, 0.05), Color("8fb85a"))
		add("ball", at + Vector3(0, 1.6 + i*0.16, 0), Vector3(0.22, 0.3, 0.22), foliage.lerp(Color("6aa85a"), 0.7))

func tree_pine(_foliage: Color) -> void:
	add("cylinder", Vector3(0, 0.3, 0), Vector3(0.1, 0.6, 0.1), Color("7a5a44"))
	for i in 3:
		add("point", Vector3(0, 0.7 + i*0.42, 0), Vector3(0.7 - i*0.17, 0.75, 0.7 - i*0.17), Color("3f7a52").lightened(i*0.05))

func tree_acacia(_foliage: Color) -> void:
	beam(Vector3(0, 0, 0), Vector3(0.1, 1.1, 0), 0.12, Color("7d6250"))
	beam(Vector3(0.1, 1.0, 0), Vector3(-0.4, 1.4, 0.1), 0.08, Color("7d6250"))
	beam(Vector3(0.1, 1.0, 0), Vector3(0.5, 1.45, -0.1), 0.08, Color("7d6250"))
	add("ball", Vector3(0.05, 1.55, 0), Vector3(0.95, 0.2, 0.8), Color("7e9c4c"))

func tree_palm(_foliage: Color) -> void:
	for i in 4:
		add("cylinder", Vector3(i*0.06, 0.2 + i*0.4, 0), Vector3(0.1 - i*0.01, 0.42, 0.1 - i*0.01), Color("a38463"), Vector3(0, 0, -0.08))
	var crown := Vector3(0.25, 1.7, 0)
	for k in 7:
		var a := k*TAU/7.0
		box(crown + Vector3(cos(a)*0.4, -0.08, sin(a)*0.4), Vector3(0.9, 0.04, 0.22), Color("4f9b5c"), Vector3(0, -a, -0.35))
	for k in 3: add("ball", crown + Vector3(cos(k*2.1)*0.12, -0.12, sin(k*2.1)*0.12), Vector3.ONE*0.09, Color("7a5a3a"))

func tree_eucalyptus(_foliage: Color) -> void:
	add("cylinder", Vector3(0, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color("e2dccd"))
	for at in [Vector3(0, 1.9, 0), Vector3(0.3, 1.5, 0.1), Vector3(-0.25, 1.6, -0.1)]:
		add("ball", at, Vector3(0.38, 0.32, 0.38), Color("8fb09a"))

# --- defence bosses (footprint about 2.8) ------------------------------------------

func boss(id: String) -> Array:
	call("boss_" + id)
	return take()

func boss_tank() -> void:
	var olive := Color("6f7d4c")
	var track := Color("3b4032")
	for z in [-1.15, 1.15]:
		box(Vector3(0, 0.45, z), Vector3(4.6, 0.8, 0.8), track)
		for i in 6: add("cylinder", Vector3(-1.9 + i*0.76, 0.45, z + signf(z)*0.42), Vector3(0.3, 0.06, 0.3), Color("59604a"), Vector3(PI/2, 0, 0))
		box(Vector3(0, 0.9, z), Vector3(4.4, 0.1, 0.95), olive.darkened(0.1))
	box(Vector3(0, 1.1, 0), Vector3(4.0, 0.7, 2.2), olive)
	box(Vector3(2.15, 0.95, 0), Vector3(0.6, 0.5, 2.1), olive.darkened(0.05), Vector3(0, 0, 0.6))
	add("cyl", Vector3(-0.2, 1.8, 0), Vector3(1.05, 0.7, 1.0), olive.lightened(0.06))
	add("hemi", Vector3(-0.2, 2.15, 0), Vector3(0.95, 0.3, 0.9), olive.lightened(0.06))
	beam(Vector3(0.7, 1.85, 0), Vector3(3.7, 1.95, 0), 0.26, olive.darkened(0.12), "cyl")
	add("cyl", Vector3(3.7, 1.95, 0), Vector3(0.2, 0.4, 0.2), track, Vector3(0, 0, PI/2))
	add("cyl", Vector3(-0.6, 2.45, 0.35), Vector3(0.3, 0.12, 0.3), olive.darkened(0.15))
	beam(Vector3(-0.9, 2.2, -0.5), Vector3(-1.1, 3.5, -0.6), 0.03, DARK)
	box(Vector3(-0.2, 1.9, 1.01), Vector3(0.35, 0.35, 0.04), Color("f1efe4"), Vector3(0, 0, PI/4))
	for at in [Vector3(1.2, 1.46, 0.6), Vector3(-1.4, 1.46, -0.5), Vector3(0.3, 2.3, -0.4)]:
		add("ball", at, Vector3(0.4, 0.05, 0.3), Color("4e5a38"))

func boss_heli() -> void:
	var body := Color("5f6d5c")
	add("smooth", Vector3(0.2, 1.4, 0), Vector3(1.7, 0.95, 0.95), body)
	add("hemi", Vector3(1.2, 1.4, 0), Vector3(0.8, 0.75, 0.7), GLASS, Vector3(0, 0, -PI/2))
	beam(Vector3(-1.1, 1.55, 0), Vector3(-3.3, 1.85, 0), 0.32, body, "cyl")
	box(Vector3(-3.3, 2.25, 0), Vector3(0.5, 0.9, 0.1), body.darkened(0.1), Vector3(0, 0, -0.3))
	add("cyl", Vector3(-3.3, 1.95, 0.12), Vector3(0.5, 0.04, 0.5), DARK, Vector3(PI/2, 0, 0))
	for z in [-0.75, 0.75]:
		box(Vector3(0.2, 0.2, z), Vector3(2.4, 0.08, 0.1), DARK)
		for x in [-0.5, 0.8]: beam(Vector3(x, 0.2, z), Vector3(x, 0.95, z*0.7), 0.06, DARK)
		box(Vector3(0.1, 1.2, z*1.35), Vector3(0.6, 0.08, 0.5), body)
		add("cyl", Vector3(0.2, 1.05, z*1.6), Vector3(0.14, 0.9, 0.14), Color("3f4a3c"), Vector3(0, 0, PI/2))
	add("cyl", Vector3(0.2, 2.1, 0), Vector3(0.14, 0.45, 0.14), DARK)
	for a in [0.4, 0.4 + PI/2]:
		box(Vector3(0.2, 2.35, 0), Vector3(5.6, 0.04, 0.26), DARK, Vector3(0, a, 0))
	add("cyl", Vector3(0.2, 2.4, 0), Vector3(0.25, 0.12, 0.25), body.darkened(0.2))
	box(Vector3(0.3, 1.55, 0.9), Vector3(0.4, 0.4, 0.04), Color("f1efe4"), Vector3(0, 0, PI/4))

func mech_body(main: Color, accent: Color, s: float) -> void:
	for x in [-0.55, 0.55]:
		box(Vector3(x, 0.15, 0.15)*s, Vector3(0.8, 0.3, 1.1)*s, DARK)
		box(Vector3(x, 0.85, 0)*s, Vector3(0.5, 1.1, 0.55)*s, main.darkened(0.1))
		add("smooth", Vector3(x, 1.45, 0)*s, Vector3(0.32, 0.3, 0.32)*s, accent)
		box(Vector3(x, 2.0, 0)*s, Vector3(0.55, 0.9, 0.6)*s, main)
	box(Vector3(0, 2.55, 0)*s, Vector3(1.6, 0.4, 0.9)*s, DARK)
	box(Vector3(0, 3.35, 0)*s, Vector3(2.0, 1.3, 1.3)*s, main)
	box(Vector3(0, 3.4, 0.62)*s, Vector3(1.3, 0.9, 0.1)*s, main.lightened(0.1))
	add("cyl", Vector3(0, 3.45, 0.68)*s, Vector3(0.28, 0.06, 0.28)*s, Color("7af0e0"), Vector3(PI/2, 0, 0))
	box(Vector3(0, 4.25, 0)*s, Vector3(0.9, 0.55, 0.8)*s, main.lightened(0.05))
	box(Vector3(0, 4.28, 0.41)*s, Vector3(0.7, 0.18, 0.05)*s, Color("ff5a4f"))
	for x in [-1.3, 1.3]:
		add("smooth", Vector3(x, 3.85, 0)*s, Vector3(0.55, 0.5, 0.55)*s, accent)
		box(Vector3(x, 3.1, 0)*s, Vector3(0.45, 1.1, 0.5)*s, main.darkened(0.08))
		add("cyl", Vector3(x, 2.35, 0.25)*s, Vector3(0.22, 0.9, 0.22)*s, DARK, Vector3(PI/2, 0, 0))
		for k in 4: add("cylinder", Vector3(x + cos(k*PI/2)*0.1, 2.35 + sin(k*PI/2)*0.1, 0.75)*s, Vector3(0.04, 0.3, 0.04)*s, Color("9aa4ad"), Vector3(PI/2, 0, 0))
	for x in [-0.55, 0.55]:
		box(Vector3(x, 4.0, -0.75)*s, Vector3(0.5, 0.7, 0.4)*s, main.darkened(0.15))
		for k in 4: add("cyl", Vector3(x - 0.12 + (k%2)*0.24, 3.85 + (k/2)*0.28, -0.52)*s, Vector3(0.08, 0.05, 0.08)*s, accent, Vector3(PI/2, 0, 0))

func boss_mech() -> void:
	mech_body(Color("8d99a6"), Color("d4553f"), 1.0)

func boss_titan() -> void:
	var gold := Color("e9c162")
	mech_body(Color("5b6b8a"), gold, 1.15)
	# Extra armour spikes, horns, a cape and a glowing core.
	for x in [-1.5, 1.5]:
		for k in 3: add("point", Vector3(x, 4.95 + k*0.05, -0.2 + k*0.25), Vector3(0.12, 0.5, 0.12), gold, Vector3(0, 0, -signf(x)*0.5))
	for x in [-0.35, 0.35]: add("point", Vector3(x, 5.45, 0), Vector3(0.1, 0.6, 0.1), gold, Vector3(0, 0, -signf(x)*0.4))
	add("smooth", Vector3(0, 3.95, 0.78), Vector3.ONE*0.3, Color("8af7ff"))
	box(Vector3(0, 3.0, -0.95), Vector3(2.0, 2.2, 0.1), Color("b53a3a"))

# --- minions and the alien saucer ----------------------------------------------------

func soldier() -> Array:
	add("cylinder", Vector3(0, 0.38, 0), Vector3(0.14, 0.4, 0.14), Color("5d6b43"))
	add("ball", Vector3(0, 0.68, 0), Vector3(0.14, 0.15, 0.14), Color("efd1b0"))
	add("hemi", Vector3(0, 0.72, 0), Vector3(0.17, 0.12, 0.17), Color("4a5636"))
	for x in [-0.08, 0.08]: box(Vector3(x, 0.12, 0), Vector3(0.09, 0.24, 0.13), Color("3b4430"))
	box(Vector3(0.12, 0.45, 0.1), Vector3(0.05, 0.05, 0.4), DARK, Vector3(0.3, 0, 0))
	return take()

func drone() -> Array:
	box(Vector3(0, 0.45, 0), Vector3(0.3, 0.12, 0.3), Color("5b6570"))
	for k in 4:
		var a := PI/4 + k*PI/2
		beam(Vector3(0, 0.46, 0), Vector3(cos(a)*0.3, 0.48, sin(a)*0.3), 0.04, DARK)
		add("cyl", Vector3(cos(a)*0.3, 0.52, sin(a)*0.3), Vector3(0.14, 0.02, 0.14), Color("9fb0bd"))
	add("ball", Vector3(0, 0.38, 0.16), Vector3.ONE*0.05, Color("ff5a4f"))
	return take()

# The player's mothership hovering above the hole, with a little pilot.
func saucer() -> Array:
	add("cyl", Vector3(0, 0, 0), Vector3(1.6, 0.18, 1.6), Color("c9d2dc"))
	add("hemi", Vector3(0, -0.05, 0), Vector3(1.25, 0.35, 1.25), Color("8793a3"), Vector3(PI, 0, 0))
	add("ring", Vector3(0, 0.02, 0), Vector3(1.62, 0.3, 1.62), Color("9aa6b5"))
	# A low glass collar lets the little green pilot peek out.
	add("hemi", Vector3(0, 0.08, 0), Vector3(0.8, 0.32, 0.8), Color("9ff0d8"))
	add("smooth", Vector3(0, 0.5, 0.05), Vector3(0.36, 0.33, 0.33), Color("7ed957"))
	for x in [-0.14, 0.14]: add("ball", Vector3(x, 0.56, 0.34), Vector3(0.09, 0.12, 0.05), Color("1f2a36"))
	for x in [-0.18, 0.18]:
		beam(Vector3(x, 0.75, 0), Vector3(x*1.6, 1.05, 0), 0.03, Color("7ed957"))
		add("ball", Vector3(x*1.6, 1.08, 0), Vector3.ONE*0.06, Color("ffe066"))
	for k in 10:
		var a := k*TAU/10.0
		add("ball", Vector3(cos(a)*1.45, 0.02, sin(a)*1.45), Vector3.ONE*0.1, Color("ffe066") if k % 2 == 0 else Color("7ef0c8"))
	add("cyl", Vector3(0, -0.4, 0), Vector3(0.35, 0.08, 0.35), Color("b8fff0"))
	return take()
