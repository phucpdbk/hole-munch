extends RefCounted

# Holiday props for the festival cities (campaign.gd HOLIDAYS), built from the toy
# primitives in models.gd at the size of the item they stand in for: a "tree"
# (footprint ~0.7, about two units tall), a "stand" in place of a bench (about a
# unit wide) and a "snack" in place of an opening cone (~0.4). festive.gd swaps
# the city's own trees, benches and cones for these, so a festival city holds
# exactly as much food as a plain one.
var m

func _init(models) -> void:
	m = models

func prop(theme: String, kind: String, variant: int) -> Array:
	var name := "%s_%s" % [theme, kind]
	if has_method(name): return call(name, variant)
	return []

func add(parts: Array, shape: String, at: Vector3, size: Vector3, color: String, rotation := Vector3.ZERO) -> void:
	parts.append(m.piece(shape, at, size, Color(color), rotation))

# A trunk and a crown of balls; each theme decorates it.
func crowned(parts: Array, trunk: String, leaves: Array, height := 1.9) -> void:
	add(parts, "cylinder", Vector3(0, height*0.3, 0), Vector3(0.12, height*0.6, 0.12), trunk)
	var spots := [Vector3(0, height*0.78, 0), Vector3(-0.38, height*0.66, 0.1), Vector3(0.36, height*0.68, -0.08), Vector3(0.05, height*0.62, 0.38), Vector3(-0.05, height*0.7, -0.36)]
	for i in spots.size(): add(parts, "ball", spots[i], Vector3.ONE*(0.42 if i == 0 else 0.34), leaves[i % leaves.size()])

func pot(parts: Array, color: String) -> void:
	add(parts, "cyl", Vector3(0, 0.2, 0), Vector3(0.42, 0.4, 0.42), color)
	add(parts, "cyl", Vector3(0, 0.41, 0), Vector3(0.45, 0.05, 0.45), "f2c94c")

# --- Tết: apricot blossom in a red pot, banh chung, lucky money -----------------
func tet_tree(variant: int) -> Array:
	var parts: Array = []
	pot(parts, "c8302c")
	crowned(parts, "7a4b2a", ["ffd23f", "ffc61a", "ffe066"] if variant == 0 else ["ff9fbf", "ffb7cf", "ff86ad"])
	for at in [Vector3(-0.4, 1.0, 0.3), Vector3(0.42, 1.1, 0.2), Vector3(0.1, 1.2, -0.42)]:
		add(parts, "box", at, Vector3(0.12, 0.18, 0.04), "e63946")
	return parts

func tet_stand(variant: int) -> Array:
	var parts: Array = []
	if variant == 0:
		# Three banh chung, two below and one on top, tied with bamboo strings.
		for at in [Vector3(-0.22, 0.17, 0), Vector3(0.22, 0.17, 0), Vector3(0, 0.51, 0)]:
			add(parts, "box", at, Vector3(0.4, 0.34, 0.4), "3f8f4a")
			add(parts, "box", at, Vector3(0.42, 0.36, 0.06), "e8d9a8")
			add(parts, "box", at, Vector3(0.06, 0.36, 0.42), "e8d9a8")
		return parts
	add(parts, "cylinder", Vector3(0, 0.7, 0), Vector3(0.05, 1.4, 0.05), "6b4226")
	for y in [1.05, 0.7]:
		add(parts, "ball", Vector3(0, y, 0.12), Vector3(0.24, 0.2, 0.24), "e63946")
		add(parts, "cylinder", Vector3(0, y + 0.2, 0.12), Vector3(0.1, 0.06, 0.1), "f2c94c")
	return parts

func tet_snack(_variant: int) -> Array:
	var parts: Array = []
	add(parts, "box", Vector3(0, 0.16, 0), Vector3(0.24, 0.32, 0.06), "e02828")
	add(parts, "box", Vector3(0, 0.2, 0.035), Vector3(0.12, 0.12, 0.01), "ffd23f")
	return parts

# --- Mid-Autumn: lantern trees, star lanterns, mooncakes -------------------------
func midautumn_tree(_variant: int) -> Array:
	var parts: Array = []
	crowned(parts, "6b4a2b", ["3f8f5a", "4fa36a"])
	for at in [Vector3(-0.42, 0.95, 0.25), Vector3(0.45, 1.0, 0.1), Vector3(0.0, 0.9, -0.45)]:
		add(parts, "ball", at, Vector3(0.14, 0.17, 0.14), "ff8a2a" if at.x < 0 else "ff4d4d")
	return parts

func midautumn_stand(variant: int) -> Array:
	var parts: Array = []
	add(parts, "cylinder", Vector3(0, 0.6, 0), Vector3(0.05, 1.2, 0.05), "c9a45a")
	var color := "e63946" if variant == 0 else "ffc61a"
	# A five-point star: two flat triangles turned against each other.
	add(parts, "prism", Vector3(0, 1.35, 0), Vector3(0.42, 0.1, 0.42), color, Vector3(PI/2, 0, 0))
	add(parts, "prism", Vector3(0, 1.35, 0), Vector3(0.42, 0.1, 0.42), color, Vector3(PI/2, PI, 0))
	add(parts, "ball", Vector3(0, 1.35, 0.05), Vector3.ONE*0.1, "fff1a8")
	return parts

func midautumn_snack(_variant: int) -> Array:
	var parts: Array = []
	add(parts, "cyl", Vector3(0, 0.08, 0), Vector3(0.2, 0.16, 0.2), "c8823e")
	add(parts, "cyl", Vector3(0, 0.165, 0), Vector3(0.12, 0.01, 0.12), "e0a868")
	return parts

# --- Valentine: heart topiaries, chocolate boxes, little hearts -----------------
func heart(parts: Array, at: Vector3, size: float, color: String) -> void:
	for side in [-1, 1]: add(parts, "ball", at + Vector3(side*size*0.5, size*0.3, 0), Vector3.ONE*size*0.6, color)
	add(parts, "box", at + Vector3(0, -size*0.15, 0), Vector3(size*0.85, size*0.85, size*0.7), color, Vector3(0, 0, PI/4))

func valentine_tree(variant: int) -> Array:
	var parts: Array = []
	pot(parts, "f4f4f4")
	add(parts, "cylinder", Vector3(0, 0.75, 0), Vector3(0.07, 0.8, 0.07), "5b3a29")
	heart(parts, Vector3(0, 1.45, 0), 0.62, "e8475f" if variant == 0 else "ff8fb1")
	return parts

func valentine_stand(variant: int) -> Array:
	var parts: Array = []
	add(parts, "box", Vector3(0, 0.22, 0), Vector3(0.95, 0.44, 0.7), "c0213a" if variant == 0 else "7a3b2e")
	add(parts, "box", Vector3(0, 0.22, 0), Vector3(0.12, 0.46, 0.72), "ffd6e0")
	add(parts, "box", Vector3(0, 0.22, 0), Vector3(0.97, 0.46, 0.12), "ffd6e0")
	heart(parts, Vector3(0, 0.56, 0), 0.26, "ff8fb1")
	return parts

func valentine_snack(_variant: int) -> Array:
	var parts: Array = []
	heart(parts, Vector3(0, 0.2, 0), 0.22, "ff3d6e")
	return parts

# --- Christmas: decorated pines, gift boxes, candy canes ------------------------
func christmas_tree(_variant: int) -> Array:
	var parts: Array = []
	add(parts, "cylinder", Vector3(0, 0.2, 0), Vector3(0.12, 0.4, 0.12), "6b4226")
	for i in 3:
		add(parts, "point", Vector3(0, 0.6 + i*0.45, 0), Vector3(0.7 - i*0.17, 0.75, 0.7 - i*0.17), "2f7d46")
	for at in [Vector3(0.4, 0.55, 0.3), Vector3(-0.35, 0.95, 0.25), Vector3(0.25, 1.35, -0.2), Vector3(-0.45, 0.5, -0.3)]:
		add(parts, "ball", at, Vector3.ONE*0.08, "e8423f" if at.y < 1.0 else "ffd23f")
	add(parts, "ball", Vector3(0, 2.0, 0), Vector3.ONE*0.13, "ffd23f")
	return parts

func christmas_stand(variant: int) -> Array:
	var parts: Array = []
	var colors := [["e8423f", "ffd23f"], ["2f7d46", "f4f4f4"], ["3a7bd5", "ffd23f"]]
	var pick: Array = colors[variant % colors.size()]
	add(parts, "box", Vector3(-0.2, 0.28, 0), Vector3(0.6, 0.56, 0.6), pick[0])
	add(parts, "box", Vector3(-0.2, 0.28, 0), Vector3(0.1, 0.58, 0.62), pick[1])
	add(parts, "box", Vector3(0.38, 0.18, 0.05), Vector3(0.4, 0.36, 0.4), pick[1])
	add(parts, "box", Vector3(0.38, 0.18, 0.05), Vector3(0.42, 0.38, 0.08), pick[0])
	return parts

func christmas_snack(_variant: int) -> Array:
	var parts: Array = []
	for i in 4: add(parts, "cylinder", Vector3(0, 0.05 + i*0.08, 0), Vector3(0.05, 0.08, 0.05), "e8423f" if i % 2 == 0 else "f4f4f4")
	add(parts, "ring", Vector3(0.07, 0.36, 0), Vector3(0.08, 0.06, 0.08), "e8423f", Vector3(PI/2, 0, 0))
	return parts

# --- Halloween: bare trees, jack-o'-lanterns, candy corn -----------------------
func halloween_tree(_variant: int) -> Array:
	var parts: Array = []
	add(parts, "cylinder", Vector3(0, 0.7, 0), Vector3(0.14, 1.4, 0.14), "3b2f3a")
	for arm in [[Vector3(-0.3, 1.2, 0), 0.7], [Vector3(0.3, 1.45, 0.05), -0.7], [Vector3(0.05, 1.3, -0.3), 0.6]]:
		add(parts, "cylinder", arm[0], Vector3(0.06, 0.7, 0.06), "3b2f3a", Vector3(arm[1]*0.4 if arm[0].z < 0 else 0, 0, arm[1]))
	add(parts, "ball", Vector3(0.35, 1.7, 0), Vector3(0.18, 0.14, 0.18), "7b4fa8")
	return parts

func halloween_stand(variant: int) -> Array:
	var parts: Array = []
	add(parts, "ball", Vector3(0, 0.4, 0), Vector3(0.55, 0.4, 0.55), "ff7a1a" if variant == 0 else "f2e7d0")
	add(parts, "cylinder", Vector3(0, 0.84, 0), Vector3(0.06, 0.14, 0.06), "4f7a2a")
	for x in [-0.18, 0.18]: add(parts, "prism", Vector3(x, 0.5, 0.52), Vector3(0.08, 0.04, 0.08), "2b1d14", Vector3(PI/2, 0, 0))
	add(parts, "box", Vector3(0, 0.3, 0.53), Vector3(0.3, 0.06, 0.04), "2b1d14")
	return parts

func halloween_snack(_variant: int) -> Array:
	var parts: Array = []
	add(parts, "cylinder", Vector3(0, 0.06, 0), Vector3(0.14, 0.12, 0.14), "fff6e0")
	add(parts, "frustum", Vector3(0, 0.17, 0), Vector3(0.13, 0.12, 0.13), "ff8c1a")
	add(parts, "point", Vector3(0, 0.3, 0), Vector3(0.08, 0.14, 0.08), "ffd23f")
	return parts

# --- Easter: blossom trees, painted eggs ----------------------------------------
func easter_tree(variant: int) -> Array:
	var parts: Array = []
	crowned(parts, "6b4a2b", ["ffd1dc", "fff0f5", "ffb7cf"] if variant == 0 else ["f4f4f4", "fff6c9", "d6f0ff"])
	return parts

func egg(parts: Array, at: Vector3, size: float, colors: Array) -> void:
	add(parts, "ball", at, Vector3(size, size*1.3, size), colors[0])
	add(parts, "cylinder", at + Vector3(0, size*0.25, 0), Vector3(size*1.01, size*0.18, size*1.01), colors[1])
	add(parts, "cylinder", at - Vector3(0, size*0.3, 0), Vector3(size*0.96, size*0.14, size*0.96), colors[2])

func easter_stand(variant: int) -> Array:
	var parts: Array = []
	var sets := [["ffd1dc", "8fd3ff", "fff59d"], ["c8f7c5", "ff9fbf", "b39ddb"], ["fff59d", "80deea", "ffab91"]]
	egg(parts, Vector3(0, 0.55, 0), 0.42, sets[variant % sets.size()])
	add(parts, "cyl", Vector3(0, 0.08, 0), Vector3(0.45, 0.16, 0.45), "d9b26f")
	return parts

func easter_snack(variant: int) -> Array:
	var parts: Array = []
	egg(parts, Vector3(0, 0.17, 0), 0.13, [["8fd3ff", "fff59d", "ff9fbf"], ["ff9fbf", "ffffff", "c8f7c5"]][variant % 2])
	return parts
