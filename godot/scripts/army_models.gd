extends "res://scripts/region_models.gd"

# Army units in a country's colours (army_forces.gd LOOKS). Foot units face +z
# like the soldier minion; vehicles face +x like the traffic car, and the gun
# vehicles turn to the saucer at runtime.
const S := 1.9
const SKIN := Color("efd1b0")
const TYRE := Color("2b3138")

func unit(kind: String, look: Dictionary) -> Array:
	match kind:
		"police":
			base(look)
			police(look)
		"soldier":
			base(look)
			soldier_body(look, false)
		"rocket":
			base(look)
			soldier_body(look, true)
		"car": patrol_car(look)
		"missile": missile_truck(look)
		"flak": flak_gun(look)
		"tank": tank(look)
	return take()

func c(look: Dictionary, key: String) -> Color:
	return Color(look[key])

# Peaked cap with the country's band, sidearm raised at the sky.
# A flag-coloured base under every foot unit: easy to spot, and it tells the
# countries apart at gameplay zoom.
func base(look: Dictionary) -> void:
	add("cyl", Vector3(0, 0.025, 0), Vector3(0.52, 0.05, 0.52), c(look, "accent"))
	add("cyl", Vector3(0, 0.03, 0), Vector3(0.4, 0.05, 0.4), c(look, "accent").lightened(0.25))

func police(look: Dictionary) -> void:
	var uniform := c(look, "uniform")
	add("cylinder", Vector3(0, 0.38, 0)*S, Vector3(0.14, 0.4, 0.14)*S, uniform)
	if look.has("vest"): add("cylinder", Vector3(0, 0.44, 0)*S, Vector3(0.15, 0.22, 0.15)*S, c(look, "vest"))
	box(Vector3(0, 0.5, 0.075)*S, Vector3(0.2, 0.06, 0.02)*S, c(look, "band"))
	add("ball", Vector3(0, 0.68, 0)*S, Vector3(0.14, 0.15, 0.14)*S, SKIN)
	add("cyl", Vector3(0, 0.77, 0)*S, Vector3(0.2, 0.06, 0.2)*S, c(look, "cap"))
	add("cyl", Vector3(0, 0.745, 0)*S, Vector3(0.155, 0.035, 0.155)*S, c(look, "band"))
	box(Vector3(0, 0.735, 0.1)*S, Vector3(0.14, 0.02, 0.08)*S, DARK)
	for x in [-0.08, 0.08]: box(Vector3(x, 0.12, 0)*S, Vector3(0.09, 0.24, 0.13)*S, uniform.darkened(0.25))
	box(Vector3(0.1, 0.56, 0.13)*S, Vector3(0.05, 0.06, 0.34)*S, DARK, Vector3(-0.85, 0, 0))

# Camo, helmet and a flag-coloured shoulder patch; a rifle or a launcher tube.
func soldier_body(look: Dictionary, launcher: bool) -> void:
	var camo := c(look, "camo")
	add("cylinder", Vector3(0, 0.38, 0)*S, Vector3(0.15, 0.4, 0.15)*S, camo)
	box(Vector3(0, 0.44, 0.08)*S, Vector3(0.16, 0.16, 0.04)*S, camo.darkened(0.2))
	box(Vector3(-0.085, 0.52, 0)*S, Vector3(0.03, 0.07, 0.07)*S, c(look, "accent"))
	add("ball", Vector3(0, 0.68, 0)*S, Vector3(0.14, 0.15, 0.14)*S, SKIN)
	add("hemi", Vector3(0, 0.72, 0)*S, Vector3(0.18, 0.13, 0.18)*S, c(look, "helmet"))
	for x in [-0.08, 0.08]: box(Vector3(x, 0.12, 0)*S, Vector3(0.09, 0.24, 0.13)*S, camo.darkened(0.3))
	if launcher:
		# Tube on the right shoulder, tilted up toward the sky.
		add("cylinder", Vector3(0.12, 0.72, 0.05)*S, Vector3(0.09, 0.62, 0.09)*S, c(look, "paint").darkened(0.15), Vector3(0.75, 0, 0))
		add("cyl", Vector3(0.12, 0.93, 0.29)*S, Vector3(0.1, 0.06, 0.1)*S, DARK, Vector3(0.75, 0, 0))
	else:
		box(Vector3(0.1, 0.56, 0.13)*S, Vector3(0.05, 0.06, 0.4)*S, DARK, Vector3(-0.85, 0, 0))

func wheels(xs: Array, half_width: float, size: float) -> void:
	for x in xs:
		for z in [-half_width, half_width]:
			add("cylinder", Vector3(x, size*0.5, z), Vector3(size, 0.16, size), TYRE, Vector3(PI/2, 0, 0))

# Patrol car livery: body, two-tone lower half, a side stripe or a checker band.
func patrol_car(look: Dictionary) -> void:
	var body := c(look, "car")
	var lower: Color = body if look.lower == "" else c(look, "lower")
	box(Vector3(0, 0.33, 0), Vector3(1.6, 0.26, 0.8), lower)
	box(Vector3(0, 0.52, 0), Vector3(1.6, 0.16, 0.8), body)
	if look.stripe != "": box(Vector3(0, 0.44, 0), Vector3(1.62, 0.09, 0.82), c(look, "stripe"))
	if not look.checker.is_empty():
		for i in 8:
			for row in 2:
				box(Vector3(-0.7 + i*0.2, 0.4 + row*0.1, 0), Vector3(0.2, 0.1, 0.82), Color(look.checker[(i + row) % 2]))
	box(Vector3(-0.1, 0.72, 0), Vector3(0.84, 0.3, 0.68), Color("accfd9"))
	box(Vector3(-0.1, 0.9, 0), Vector3(0.9, 0.08, 0.76), body)
	box(Vector3(-0.22, 0.99, 0.17), Vector3(0.22, 0.1, 0.3), Color(look.lights[0]))
	box(Vector3(-0.22, 0.99, -0.17), Vector3(0.22, 0.1, 0.3), Color(look.lights[1]))
	wheels([-0.5, 0.5], 0.39, 0.23)
	box(Vector3(0.81, 0.44, 0), Vector3(0.06, 0.12, 0.6), Color("fff0b3"))

# Six-wheel truck with a twin missile rack raised over the bed.
func missile_truck(look: Dictionary) -> void:
	var paint := c(look, "paint")
	box(Vector3(0, 0.45, 0), Vector3(2.4, 0.3, 1.0), paint.darkened(0.15))
	box(Vector3(0.85, 0.85, 0), Vector3(0.6, 0.55, 0.95), paint)
	box(Vector3(1.16, 0.92, 0), Vector3(0.04, 0.26, 0.8), GLASS)
	box(Vector3(0.85, 1.14, 0), Vector3(0.62, 0.04, 0.97), c(look, "accent"))
	box(Vector3(-0.35, 0.68, 0), Vector3(1.4, 0.16, 0.9), paint)
	box(Vector3(-0.35, 0.95, 0), Vector3(1.3, 0.12, 0.7), paint.darkened(0.25), Vector3(0, 0, 0.5))
	for z in [-0.2, 0.2]:
		add("cylinder", Vector3(-0.3, 1.2, z), Vector3(0.2, 1.5, 0.2), Color("eef0f2"), Vector3(0, 0, -PI/2 + 0.5))
		add("roof", Vector3(0.49, 1.63, z), Vector3(0.2, 0.3, 0.2), Color("d8453b"), Vector3(0, 0, -PI/2 + 0.5))
	wheels([-0.85, -0.25, 0.75], 0.5, 0.36)

# Twin-barrel anti-aircraft gun on a low tracked base.
func flak_gun(look: Dictionary) -> void:
	var paint := c(look, "paint")
	box(Vector3(0, 0.3, 0), Vector3(1.8, 0.4, 1.2), paint.darkened(0.2))
	for z in [-0.62, 0.62]: box(Vector3(0, 0.22, z), Vector3(1.9, 0.3, 0.16), TYRE)
	add("cyl", Vector3(0, 0.62, 0), Vector3(0.9, 0.3, 0.9), paint)
	box(Vector3(0.1, 0.92, 0), Vector3(0.6, 0.4, 0.7), paint.lightened(0.05))
	box(Vector3(-0.1, 1.14, 0), Vector3(0.3, 0.06, 0.72), c(look, "accent"))
	for z in [-0.18, 0.18]:
		add("cylinder", Vector3(0.6, 1.4, z), Vector3(0.09, 1.3, 0.09), DARK, Vector3(0, 0, -0.75))

# Tank: hull, tracks, turret and a long barrel raised toward the sky.
func tank(look: Dictionary) -> void:
	var paint := c(look, "paint")
	box(Vector3(0, 0.4, 0), Vector3(2.2, 0.45, 1.3), paint)
	for z in [-0.72, 0.72]:
		box(Vector3(0, 0.25, z), Vector3(2.3, 0.4, 0.22), TYRE)
		for x in [-0.8, -0.27, 0.27, 0.8]: add("cylinder", Vector3(x, 0.24, z*1.04), Vector3(0.3, 0.06, 0.3), DARK, Vector3(PI/2, 0, 0))
	add("hemi", Vector3(-0.1, 0.62, 0), Vector3(0.75, 0.45, 0.7), paint.lightened(0.06))
	box(Vector3(-0.1, 0.8, -0.45), Vector3(0.3, 0.08, 0.06), c(look, "accent"))
	add("cylinder", Vector3(0.75, 1.05, 0), Vector3(0.12, 1.4, 0.12), paint.darkened(0.3), Vector3(0, 0, -1.05))
