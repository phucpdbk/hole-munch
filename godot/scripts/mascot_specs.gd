extends RefCounted

# Guardian mascots: one per landmark, built from the toy primitives in models.gd.
# Each entry is [archetype, main colour, belly colour, accessory colour, accessory,
# attack]. shape() returns the parts grouped by pivot (body, head, arms, legs,
# tail) so mascot.gd can swing each group. Models face +z with a footprint of
# about one unit; the game scales them to the guardian's swallow radius.
const MASCOTS := {
	"onepillar":["dragon", "4caf7a", "f2d36b", "ff8fb1", "flower", "water"],
	"namsan":["robot", "6fa8dc", "f4f4f4", "e63946", "cap", "charge"],
	"khuevan":["bird", "e86a4a", "ffd27a", "ffd23f", "crown", "fire"],
	"watarun":["beast", "f2b84b", "fff1c9", "ffd23f", "crown", "stomp"],
	"taj":["bird", "3aa6a0", "f4e2b8", "f4f4f4", "turban", "water"],
	"pearl":["robot", "e45b8b", "c9d6e8", "7fd3ff", "none", "charge"],
	"fuji":["blob", "f6f6ff", "cfe3f7", "e63946", "bow", "stomp"],
	"tokyotower":["robot", "ff6a3d", "ffffff", "2b2d42", "cap", "fire"],
	"eiffel":["bird", "9aa3ad", "d8dde3", "2b2d42", "beret", "charge"],
	"brandenburg":["beast", "c9a24b", "f2e1b0", "ffd23f", "crown", "charge"],
	"bigben":["robot", "c9a86a", "3b3b3b", "2b2d42", "tophat", "stomp"],
	"alcala":["beast", "e0b060", "f6dfae", "ffd23f", "crown", "stomp"],
	"pisa":["blob", "f0e6d2", "c94f3d", "f4f4f4", "cap", "stomp"],
	"royalpalace":["bird", "ff8c1a", "ffffff", "ffd23f", "crown", "water"],
	"colosseum":["beast", "c8875a", "f0d2b0", "c9a24b", "helmet", "charge"],
	"stbasils":["blob", "e94b5a", "3fae8f", "ffd23f", "turban", "stomp"],
	"pyramid":["beast", "e8c87a", "f6e6bd", "2b5d8c", "crown", "stomp"],
	"cairotower":["bird", "3c7d6e", "f2d36b", "e63946", "none", "fire"],
	"sphinx":["beast", "d9b26f", "f4e2b8", "4a6fa5", "crown", "fire"],
	"kicc":["beast", "f0c040", "fbe7a6", "6b4226", "none", "charge"],
	"djenne":["blob", "c98a52", "f2e3c4", "f4f4f4", "none", "stomp"],
	"nationaltheatre":["bird", "e35d3b", "fbd36b", "2a9d8f", "cap", "water"],
	"baobab":["beast", "8b8d94", "d7c9b8", "e76f51", "bow", "stomp"],
	"tablemountain":["bird", "2d2d33", "f4f4f4", "e63946", "bow", "water"],
	"liberty":["blob", "5fbfa0", "e7f5ee", "ffd23f", "crown", "fire"],
	"willis":["robot", "4a4f5a", "ffd23f", "e63946", "cap", "charge"],
	"empire":["beast", "5b4636", "c9b8a6", "e63946", "none", "stomp"],
	"cntower":["beast", "8a5a3b", "f2e1c8", "e63946", "cap", "charge"],
	"needle":["robot", "d8e2ea", "ff6a3d", "2b2d42", "none", "fire"],
	"hollywood":["blob", "ffd23f", "e14a6d", "2b2d42", "tophat", "fire"],
	"chichen":["dragon", "3fa06b", "f2c14e", "e63946", "flower", "water"],
	"capitol":["bird", "6b4a2b", "f4f4f4", "2b2d42", "tophat", "charge"],
	"christ":["bird", "2a9d8f", "ffd166", "e63946", "flower", "water"],
	"masp":["robot", "e63946", "2b2d42", "ffd23f", "none", "stomp"],
	"machu":["beast", "f1e3d3", "c9a98a", "e63946", "cap", "charge"],
	"limacathedral":["blob", "f4d35e", "8f2d56", "c94f3d", "sombrero", "fire"],
	"obelisco":["blob", "8ecae6", "f6f6f6", "2b2d42", "tophat", "stomp"],
	"monserrate":["bird", "ffb703", "3a86ff", "e63946", "none", "water"],
	"sugarloaf":["beast", "9c6644", "f2cc8f", "ff8fb1", "bow", "charge"],
	"costanera":["robot", "8d99ae", "06d6a0", "ffd23f", "none", "fire"],
	"sydney":["bird", "f4f4f4", "ffd23f", "ffd23f", "none", "water"],
	"flinders":["robot", "f4a261", "264653", "2a9d8f", "cap", "charge"],
	"uluru":["beast", "c1440e", "f2a65a", "2b2d42", "none", "charge"],
	"belltower":["robot", "bfa36f", "5c4033", "2b2d42", "tophat", "stomp"],
	"skytower":["bird", "6c757d", "c9b79c", "ffd23f", "none", "charge"],
	"fijitemple":["dragon", "ff6b6b", "ffd166", "ff8fb1", "flower", "fire"],
	"moai":["blob", "8d8d8d", "b5b5b5", "c1440e", "none", "stomp"],
	"parliament":["beast", "9e9e9e", "f0f0f0", "2a9d8f", "cap", "stomp"],
}
const FALLBACK := ["blob", "7fb8a4", "f2efe4", "e63946", "none", "stomp"]
const INK := Color("1d2430")
const WHITE := Color("fbfbf6")
# Height of the head top above the head pivot, where accessories sit.
const HEAD_TOP := {"blob":0.5, "bird":0.6, "dragon":0.42, "robot":0.5, "beast":0.48}

static func spec(id: String) -> Dictionary:
	var row: Array = MASCOTS.get(id, FALLBACK)
	return {"archetype":row[0], "a":Color(row[1]), "b":Color(row[2]), "c":Color(row[3]), "accessory":row[4], "attack":row[5]}

# {"pivots":{group: Vector3}, "parts":{group: [model pieces]}}; pieces are local to their pivot.
static func shape(m, value: Dictionary) -> Dictionary:
	var a: Color = value.a
	var b: Color = value.b
	var result: Dictionary
	match value.archetype:
		"bird": result = bird(m, a, b)
		"dragon": result = dragon(m, a, b)
		"robot": result = robot(m, a, b)
		"beast": result = beast(m, a, b)
		_: result = blob(m, a, b)
	result.parts.head.append_array(accessory(m, value.accessory, value.c, HEAD_TOP.get(value.archetype, 0.5)))
	return result

static func eyes(m, y: float, z: float, spread: float, size: float) -> Array:
	var list: Array = []
	for x in [-spread, spread]:
		list.append(m.piece("ball", Vector3(x, y, z), Vector3.ONE*size, WHITE))
		list.append(m.piece("ball", Vector3(x*1.05, y, z + size*0.6), Vector3.ONE*size*0.52, INK))
	return list

static func blob(m, a: Color, b: Color) -> Dictionary:
	var parts := {"body":[], "head":[], "arm_l":[], "arm_r":[], "leg_l":[], "leg_r":[]}
	parts.body.append(m.piece("smooth", Vector3(0, 0.78, 0), Vector3(0.92, 0.78, 0.88), a))
	parts.body.append(m.piece("smooth", Vector3(0, 0.62, 0.42), Vector3(0.55, 0.45, 0.35), b))
	parts.head.append_array(eyes(m, 0.12, 0.66, 0.28, 0.17))
	parts.head.append(m.piece("box", Vector3(0, -0.14, 0.78), Vector3(0.24, 0.06, 0.05), INK))
	for x in [-0.55, 0.55]: parts.head.append(m.piece("ball", Vector3(x, -0.06, 0.6), Vector3(0.1, 0.06, 0.04), Color("ff8fa3")))
	for side in [["arm_l", 1.0], ["arm_r", -1.0]]:
		parts[side[0]].append(m.piece("ball", Vector3(0.1*side[1], -0.18, 0), Vector3(0.2, 0.3, 0.2), a.darkened(0.12)))
	for leg in ["leg_l", "leg_r"]: parts[leg].append(m.piece("ball", Vector3(0, -0.12, 0.08), Vector3(0.26, 0.15, 0.32), b.darkened(0.15)))
	return {"parts":parts, "pivots":{"body":Vector3.ZERO, "head":Vector3(0, 1.05, 0), "arm_l":Vector3(-0.84, 0.78, 0),
		"arm_r":Vector3(0.84, 0.78, 0), "leg_l":Vector3(-0.36, 0.24, 0.1), "leg_r":Vector3(0.36, 0.24, 0.1)}}

static func bird(m, a: Color, b: Color) -> Dictionary:
	var parts := {"body":[], "head":[], "arm_l":[], "arm_r":[], "leg_l":[], "leg_r":[], "tail":[]}
	var beak := Color("ffb030")
	parts.body.append(m.piece("smooth", Vector3(0, 0.95, 0), Vector3(0.64, 0.6, 0.72), a))
	parts.body.append(m.piece("smooth", Vector3(0, 0.86, 0.34), Vector3(0.44, 0.46, 0.34), b))
	parts.head.append(m.piece("smooth", Vector3(0, 0.25, 0.05), Vector3.ONE*0.42, a))
	parts.head.append(m.piece("point", Vector3(0, 0.16, 0.56), Vector3(0.14, 0.32, 0.14), beak, Vector3(PI/2, 0, 0)))
	parts.head.append_array(eyes(m, 0.34, 0.33, 0.17, 0.11))
	for side in [["arm_l", 1.0], ["arm_r", -1.0]]:
		parts[side[0]].append(m.piece("smooth", Vector3(0.06*side[1], -0.2, -0.02), Vector3(0.1, 0.42, 0.42), a.darkened(0.15)))
	for leg in ["leg_l", "leg_r"]:
		parts[leg].append(m.piece("cylinder", Vector3(0, -0.2, 0), Vector3(0.05, 0.42, 0.05), beak))
		parts[leg].append(m.piece("box", Vector3(0, -0.42, 0.08), Vector3(0.18, 0.05, 0.24), beak))
	parts.tail.append(m.piece("box", Vector3(0, 0.05, -0.18), Vector3(0.5, 0.08, 0.42), a.darkened(0.2), Vector3(-0.5, 0, 0)))
	return {"parts":parts, "pivots":{"body":Vector3.ZERO, "head":Vector3(0, 1.38, 0.15), "arm_l":Vector3(-0.62, 1.05, 0),
		"arm_r":Vector3(0.62, 1.05, 0), "leg_l":Vector3(-0.22, 0.45, 0), "leg_r":Vector3(0.22, 0.45, 0), "tail":Vector3(0, 0.85, -0.6)}}

static func dragon(m, a: Color, b: Color) -> Dictionary:
	var parts := {"body":[], "head":[], "arm_l":[], "arm_r":[], "leg_l":[], "leg_r":[], "leg_bl":[], "leg_br":[], "tail":[]}
	parts.body.append(m.piece("smooth", Vector3(0, 0.85, 0), Vector3(0.6, 0.55, 0.85), a))
	parts.body.append(m.piece("smooth", Vector3(0, 0.75, 0.22), Vector3(0.45, 0.4, 0.6), b))
	for z in [0.25, -0.1, -0.45]: parts.body.append(m.piece("point", Vector3(0, 1.38, z), Vector3(0.12, 0.26, 0.12), b))
	parts.head.append(m.piece("smooth", Vector3(0, 0.1, 0.1), Vector3(0.4, 0.36, 0.45), a))
	parts.head.append(m.piece("box", Vector3(0, -0.02, 0.48), Vector3(0.42, 0.24, 0.36), a.lightened(0.1)))
	for x in [-0.1, 0.1]: parts.head.append(m.piece("ball", Vector3(x, 0.06, 0.67), Vector3.ONE*0.04, INK))
	for x in [-0.2, 0.2]: parts.head.append(m.piece("point", Vector3(x, 0.42, -0.05), Vector3(0.08, 0.3, 0.08), b, Vector3(0, 0, -x*1.5)))
	parts.head.append_array(eyes(m, 0.22, 0.36, 0.2, 0.1))
	for side in [["arm_l", 1.0], ["arm_r", -1.0]]:
		parts[side[0]].append(m.piece("box", Vector3(-0.42*side[1], 0.22, 0), Vector3(0.9, 0.05, 0.6), b.darkened(0.1), Vector3(0, 0, 0.5*side[1])))
	for leg in ["leg_l", "leg_r", "leg_bl", "leg_br"]: parts[leg].append(m.piece("cylinder", Vector3(0, -0.22, 0), Vector3(0.14, 0.45, 0.14), a.darkened(0.12)))
	parts.tail.append(m.piece("point", Vector3(0, 0, -0.45), Vector3(0.25, 0.9, 0.25), a, Vector3(-PI/2, 0, 0)))
	parts.tail.append(m.piece("prism", Vector3(0, 0.02, -0.92), Vector3(0.2, 0.05, 0.2), b))
	return {"parts":parts, "pivots":{"body":Vector3.ZERO, "head":Vector3(0, 1.25, 0.55), "arm_l":Vector3(-0.5, 1.15, -0.1),
		"arm_r":Vector3(0.5, 1.15, -0.1), "leg_l":Vector3(-0.38, 0.45, 0.28), "leg_r":Vector3(0.38, 0.45, 0.28),
		"leg_bl":Vector3(-0.38, 0.45, -0.38), "leg_br":Vector3(0.38, 0.45, -0.38), "tail":Vector3(0, 0.72, -0.72)}}

static func robot(m, a: Color, b: Color) -> Dictionary:
	var parts := {"body":[], "head":[], "arm_l":[], "arm_r":[], "leg_l":[], "leg_r":[]}
	parts.body.append(m.piece("box", Vector3(0, 0.98, 0), Vector3(1.05, 0.82, 0.78), a))
	parts.body.append(m.piece("box", Vector3(0, 0.98, 0.4), Vector3(0.58, 0.42, 0.04), b))
	for x in [-0.15, 0.0, 0.15]: parts.body.append(m.piece("ball", Vector3(x, 0.86, 0.43), Vector3.ONE*0.05, Color("ff5a4e") if x == 0.0 else WHITE))
	parts.head.append(m.piece("box", Vector3(0, 0.25, 0), Vector3(0.75, 0.5, 0.65), a.lightened(0.1)))
	parts.head.append(m.piece("box", Vector3(0, 0.27, 0.33), Vector3(0.6, 0.18, 0.04), b))
	for x in [-0.15, 0.15]: parts.head.append(m.piece("ball", Vector3(x, 0.27, 0.36), Vector3.ONE*0.06, WHITE))
	parts.head.append(m.piece("cylinder", Vector3(0.22, 0.62, 0), Vector3(0.03, 0.3, 0.03), INK))
	parts.head.append(m.piece("ball", Vector3(0.22, 0.8, 0), Vector3.ONE*0.08, b))
	for side in [["arm_l", 1.0], ["arm_r", -1.0]]:
		parts[side[0]].append(m.piece("cylinder", Vector3(-0.04*side[1], -0.3, 0), Vector3(0.12, 0.6, 0.12), a.darkened(0.2)))
		parts[side[0]].append(m.piece("ball", Vector3(-0.04*side[1], -0.65, 0), Vector3.ONE*0.16, b))
	for leg in ["leg_l", "leg_r"]:
		parts[leg].append(m.piece("box", Vector3(0, -0.25, 0), Vector3(0.28, 0.55, 0.3), a.darkened(0.25)))
		parts[leg].append(m.piece("box", Vector3(0, -0.52, 0.08), Vector3(0.32, 0.1, 0.42), INK))
	return {"parts":parts, "pivots":{"body":Vector3.ZERO, "head":Vector3(0, 1.4, 0), "arm_l":Vector3(-0.66, 1.3, 0),
		"arm_r":Vector3(0.66, 1.3, 0), "leg_l":Vector3(-0.28, 0.57, 0), "leg_r":Vector3(0.28, 0.57, 0)}}

static func beast(m, a: Color, b: Color) -> Dictionary:
	var parts := {"body":[], "head":[], "leg_l":[], "leg_r":[], "leg_bl":[], "leg_br":[], "tail":[]}
	parts.body.append(m.piece("smooth", Vector3(0, 0.92, 0), Vector3(0.62, 0.5, 0.9), a))
	parts.body.append(m.piece("smooth", Vector3(0, 0.82, 0.12), Vector3(0.46, 0.38, 0.66), b))
	parts.head.append(m.piece("smooth", Vector3(0, 0.1, 0.1), Vector3.ONE*0.42, a))
	parts.head.append(m.piece("smooth", Vector3(0, -0.02, 0.42), Vector3(0.22, 0.17, 0.18), b))
	parts.head.append(m.piece("ball", Vector3(0, 0.05, 0.58), Vector3.ONE*0.07, INK))
	for x in [-0.26, 0.26]: parts.head.append(m.piece("point", Vector3(x, 0.45, 0), Vector3(0.12, 0.24, 0.1), a.darkened(0.12)))
	parts.head.append_array(eyes(m, 0.2, 0.38, 0.17, 0.09))
	for leg in ["leg_l", "leg_r", "leg_bl", "leg_br"]:
		parts[leg].append(m.piece("cylinder", Vector3(0, -0.25, 0), Vector3(0.14, 0.5, 0.14), a.darkened(0.1)))
		parts[leg].append(m.piece("ball", Vector3(0, -0.5, 0.04), Vector3(0.16, 0.08, 0.2), b))
	parts.tail.append(m.piece("cylinder", Vector3(0, 0.12, -0.22), Vector3(0.07, 0.6, 0.07), a, Vector3(-0.8, 0, 0)))
	parts.tail.append(m.piece("ball", Vector3(0, 0.36, -0.44), Vector3.ONE*0.12, b))
	return {"parts":parts, "pivots":{"body":Vector3.ZERO, "head":Vector3(0, 1.18, 0.62), "leg_l":Vector3(-0.36, 0.52, 0.4),
		"leg_r":Vector3(0.36, 0.52, 0.4), "leg_bl":Vector3(-0.36, 0.52, -0.4), "leg_br":Vector3(0.36, 0.52, -0.4), "tail":Vector3(0, 0.95, -0.82)}}

# Hats and trinkets on top of the head (pieces relative to the head pivot).
static func accessory(m, kind: String, c: Color, top: float) -> Array:
	var list: Array = []
	match kind:
		"beret":
			list.append(m.piece("cyl", Vector3(0.06, top + 0.02, 0), Vector3(0.44, 0.1, 0.44), c, Vector3(0, 0, -0.25)))
			list.append(m.piece("ball", Vector3(0.03, top + 0.1, 0), Vector3.ONE*0.05, c))
		"crown":
			list.append(m.piece("cyl", Vector3(0, top + 0.06, 0), Vector3(0.28, 0.14, 0.28), c))
			for i in 5:
				var angle := i*TAU/5
				list.append(m.piece("point", Vector3(cos(angle)*0.22, top + 0.2, sin(angle)*0.22), Vector3(0.07, 0.16, 0.07), c))
			list.append(m.piece("ball", Vector3(0, top + 0.06, 0.28), Vector3.ONE*0.05, Color("e63946")))
		"tophat":
			list.append(m.piece("cyl", Vector3(0, top, 0), Vector3(0.42, 0.04, 0.42), INK))
			list.append(m.piece("cyl", Vector3(0, top + 0.22, 0), Vector3(0.27, 0.42, 0.27), INK))
			list.append(m.piece("cyl", Vector3(0, top + 0.06, 0), Vector3(0.28, 0.07, 0.28), c if c != INK else Color("e63946")))
		"cap":
			list.append(m.piece("hemi", Vector3(0, top - 0.06, 0), Vector3(0.36, 0.28, 0.36), c))
			list.append(m.piece("box", Vector3(0, top - 0.04, 0.32), Vector3(0.34, 0.04, 0.3), c.darkened(0.2)))
		"flower":
			list.append(m.piece("ball", Vector3(0.2, top - 0.02, 0.1), Vector3.ONE*0.07, Color("ffd23f")))
			for i in 5:
				var angle := i*TAU/5
				list.append(m.piece("ball", Vector3(0.2 + cos(angle)*0.11, top - 0.02 + sin(angle)*0.11, 0.08), Vector3(0.08, 0.08, 0.04), c))
		"bow":
			for x in [-0.13, 0.13]: list.append(m.piece("ball", Vector3(x, top, 0), Vector3(0.13, 0.09, 0.06), c))
			list.append(m.piece("ball", Vector3(0, top, 0), Vector3.ONE*0.05, c.darkened(0.2)))
		"turban":
			list.append(m.piece("smooth", Vector3(0, top, 0), Vector3(0.4, 0.25, 0.4), c))
			list.append(m.piece("ball", Vector3(0, top + 0.02, 0.37), Vector3.ONE*0.06, Color("e63946")))
		"helmet":
			list.append(m.piece("hemi", Vector3(0, top - 0.14, 0), Vector3(0.44, 0.42, 0.44), c))
			list.append(m.piece("box", Vector3(0, top + 0.2, 0), Vector3(0.06, 0.18, 0.5), Color("c0392b")))
		"sombrero":
			list.append(m.piece("cyl", Vector3(0, top, 0), Vector3(0.66, 0.04, 0.66), c))
			list.append(m.piece("point", Vector3(0, top + 0.18, 0), Vector3(0.26, 0.36, 0.26), c))
	return list
