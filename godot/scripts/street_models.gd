extends RefCounted

# Terraced shophouses and high-rise towers, styled by the level's landmark city
# (see city_profiles.gd). Shops face local +z (the street); neighbours touch, so
# a row reads as one continuous street front. Everything returns primitive parts
# for ToyModels.bake().
const DEPTH := 1.6
const GROUND := 0.95
const FLOOR := 0.62
const TOWER_SIZE := 3.0
const WINDOW := Color("9cc8d6")
const SHOP_GLASS := Color("5d7f91")
const DOOR := Color("3f3a36")
const IRON := Color("2f3438")
const WOOD := Color("7a4a30")
const LETTER := Color("fbf6e4")
# w: street frontage; floors: upper floors per variant. Other keys pick the
# ground-floor sign, awning, window, balcony, roof and small regional extras.
const STYLES = {
	"tube": {"w":1.45, "floors":[3,4,2], "roof":"flat", "win":"tall", "balcony":"iron", "sign":"band", "awning":"slope", "extras":["tank","plants","ac"]},
	"asia_city": {"w":1.9, "floors":[3,4,2], "roof":"flat", "win":"square", "sign":"vertical", "awning":"slope", "extras":["ac","sign_bands"]},
	"machiya": {"w":1.8, "floors":[1,1,1], "roof":"gable", "win":"lattice", "sign":"noren", "awning":"eave", "extras":["lantern"]},
	"mughal": {"w":1.8, "floors":[1,2,1], "roof":"flat", "win":"arch", "balcony":"jharokha", "sign":"band", "awning":"cloth", "extras":["chhatri"]},
	"haussmann": {"w":2.0, "floors":[4,4,3], "roof":"mansard", "win":"tall", "balcony":"iron", "sign":"band", "awning":"stripe", "extras":["cornice","chimney"]},
	"altbau": {"w":2.0, "floors":[3,4,3], "roof":"hip", "win":"tall", "balcony":"iron", "sign":"band", "awning":"slope", "extras":["cornice"]},
	"brick": {"w":1.8, "floors":[2,3,2], "roof":"gable", "win":"tall", "sign":"painted", "extras":["chimney","cornice"]},
	"canal": {"w":1.45, "floors":[3,4,3], "roof":"stepped", "win":"tall", "sign":"band", "extras":["hoist"]},
	"mediterranean": {"w":1.9, "floors":[2,3,2], "roof":"hip", "win":"tall", "balcony":"iron", "sign":"band", "awning":"stripe", "extras":["shutters","plants"]},
	"russian": {"w":2.1, "floors":[2,3,3], "roof":"hip", "win":"tall", "sign":"band", "extras":["pilasters","cornice"]},
	"arab": {"w":1.9, "floors":[2,3,1], "roof":"flat", "win":"arch", "balcony":"mashrabiya", "sign":"band", "awning":"cloth", "extras":["dish","dome"]},
	"african": {"w":1.9, "floors":[0,1,0], "roof":"tin", "win":"square", "sign":"board", "awning":"veranda", "extras":[]},
	"sahel": {"w":1.9, "floors":[0,1,0], "roof":"flat", "win":"square", "sign":"", "awning":"cloth", "extras":["toron"]},
	"capedutch": {"w":1.8, "floors":[1,1,2], "roof":"flat", "win":"tall", "sign":"band", "extras":["cornice","curved_gable"]},
	"brownstone": {"w":1.9, "floors":[3,4,3], "roof":"flat", "win":"tall", "sign":"band", "awning":"slope", "extras":["fire_escape","cornice","water_tower"]},
	"stucco": {"w":2.1, "floors":[1,2,1], "roof":"flat", "win":"band", "sign":"band", "awning":"slope", "extras":["billboard"]},
	"colonial": {"w":1.9, "floors":[1,1,2], "roof":"tile", "win":"tall", "balcony":"wood", "sign":"band", "extras":["shutters"]},
	"victorian": {"w":1.9, "floors":[1,2,1], "roof":"flat", "win":"tall", "balcony":"lace", "sign":"band", "extras":["cornice"]},
	"island": {"w":1.9, "floors":[0,0,1], "roof":"tin", "win":"square", "sign":"board", "awning":"veranda", "extras":["plants"]},
}

var m
var parts: Array = []

func _init(models) -> void:
	m = models

static func style_of(profile: Dictionary) -> Dictionary:
	return STYLES.get(profile.style, STYLES.haussmann)

# Swallow radius grows with the building height, so low stalls come first.
static func shop_radius(profile: Dictionary, variant: int) -> float:
	return 0.95 + 0.07*int(style_of(profile).floors[variant % 3])

static func tower_radius(variant: int) -> float:
	return 2.0 if variant == 0 else 2.4

func add(shape: String, at: Vector3, size: Vector3, color: Color, rotate := Vector3.ZERO) -> void:
	parts.append(m.piece(shape, at, size, color, rotate))

func box(at: Vector3, size: Vector3, color: Color, rotate := Vector3.ZERO) -> void:
	add("box", at, size, color, rotate)

func beam(a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var delta := b - a
	add("box", (a + b)*0.5, Vector3(width, delta.length(), width), color, Quaternion(Vector3.UP, delta.normalized()).get_euler())

func take() -> Array:
	var result := parts
	parts = []
	return result

func letters(center: Vector3, width: float, count := 3) -> void:
	for i in count:
		box(center + Vector3((i - (count-1)/2.0)*width/count, 0, 0.03), Vector3(width*0.55/count, 0.06, 0.02), LETTER)

# --- shophouses -------------------------------------------------------------------

func shop(profile: Dictionary, variant: int) -> Array:
	var s := style_of(profile)
	var v := variant % 3
	var w: float = s.w - 0.05
	var floors: int = s.floors[v]
	var wall := Color(profile.walls[v])
	var sign := Color(profile.signs[v])
	var roof := Color(profile.roof)
	var trim := wall.darkened(0.2) if wall.get_luminance() > 0.55 else wall.lightened(0.45)
	var top := GROUND + floors*FLOOR
	box(Vector3(0, top/2, 0), Vector3(w, top, DEPTH), wall)
	box(Vector3(0, 0.05, DEPTH/2 + 0.01), Vector3(w, 0.1, 0.04), trim.darkened(0.25))
	shopfront(s, w, sign, trim, roof)
	for f in floors: upper_floor(s, w, GROUND + f*FLOOR, f, v, profile, trim)
	roof_top(s.roof, w, top, roof, wall, trim)
	for extra in s.get("extras", []): shop_extra(extra, w, top, v, sign, trim)
	return take()

func shopfront(s: Dictionary, w: float, sign: Color, trim: Color, roof: Color) -> void:
	var front := DEPTH/2
	var frame := sign if s.sign == "painted" else trim
	box(Vector3(-w*0.1, 0.47, front + 0.015), Vector3(w*0.64, 0.66, 0.03), frame)
	box(Vector3(-w*0.1, 0.47, front + 0.03), Vector3(w*0.58, 0.58, 0.03), SHOP_GLASS)
	box(Vector3(-w*0.1, 0.47, front + 0.05), Vector3(0.03, 0.58, 0.02), frame)
	box(Vector3(w*0.33, 0.4, front + 0.02), Vector3(w*0.2, 0.72, 0.04), DOOR)
	# Goods on display behind the glass.
	for i in 3: box(Vector3(-w*0.3 + i*w*0.2, 0.28, front + 0.05), Vector3(w*0.12, 0.14, 0.02), sign.lightened(0.3 + i*0.15))
	match s.sign:
		"band", "painted", "vertical":
			box(Vector3(0, GROUND - 0.1, front + 0.04), Vector3(w*0.94, 0.2, 0.06), sign)
			letters(Vector3(0, GROUND - 0.1, front + 0.04), w*0.7)
			if s.sign == "vertical":
				box(Vector3(w/2 - 0.12, GROUND + FLOOR, front + 0.2), Vector3(0.08, FLOOR*1.5, 0.34), sign.lightened(0.12))
				for i in 3: box(Vector3(w/2 - 0.07, GROUND + FLOOR*(0.55 + i*0.45), front + 0.2), Vector3(0.02, 0.14, 0.18), LETTER)
		"board":
			box(Vector3(0, GROUND + 0.2, front + 0.08), Vector3(w*0.8, 0.28, 0.05), sign)
			letters(Vector3(0, GROUND + 0.2, front + 0.08), w*0.6, 4)
		"noren":
			box(Vector3(w*0.33, 0.66, front + 0.07), Vector3(w*0.26, 0.26, 0.02), sign)
	awning(s.get("awning", ""), w, sign, roof)

func awning(kind: String, w: float, sign: Color, roof: Color) -> void:
	var front := DEPTH/2
	match kind:
		"slope":
			box(Vector3(0, GROUND - 0.3, front + 0.25), Vector3(w*0.9, 0.04, 0.5), sign.lightened(0.18), Vector3(0.35, 0, 0))
		"stripe":
			for i in 4: box(Vector3(-w*0.34 + i*w*0.227, GROUND - 0.3, front + 0.25), Vector3(w*0.227, 0.04, 0.5), sign if i % 2 == 0 else Color("f4f1e8"), Vector3(0.35, 0, 0))
			# A café table on the pavement.
			add("cyl", Vector3(-w*0.25, 0.25, front + 0.6), Vector3(0.14, 0.04, 0.14), Color("e8e4da"))
			add("cylinder", Vector3(-w*0.25, 0.13, front + 0.6), Vector3(0.025, 0.25, 0.025), IRON)
		"cloth":
			box(Vector3(0, GROUND - 0.22, front + 0.35), Vector3(w*0.86, 0.03, 0.7), sign.lightened(0.25), Vector3(0.18, 0, 0))
			for x in [-w*0.4, w*0.4]: add("cylinder", Vector3(x, 0.33, front + 0.68), Vector3(0.025, 0.66, 0.025), WOOD)
		"veranda":
			box(Vector3(0, GROUND + 0.02, front + 0.4), Vector3(w, 0.05, 0.8), roof)
			for x in [-w/2 + 0.08, w/2 - 0.08]: add("cylinder", Vector3(x, GROUND/2, front + 0.74), Vector3(0.04, GROUND, 0.04), WOOD)
		"eave":
			box(Vector3(0, GROUND + 0.05, front + 0.18), Vector3(w, 0.05, 0.42), roof, Vector3(0.4, 0, 0))

func upper_floor(s: Dictionary, w: float, y0: float, f: int, v: int, profile: Dictionary, trim: Color) -> void:
	var front := DEPTH/2
	var mid := y0 + FLOOR*0.5
	var count := 2 if w < 1.7 else 3
	var extras: Array = s.get("extras", [])
	var shutter := Color(profile.signs[0]).darkened(0.15)
	for i in count:
		var x := (i - (count-1)/2.0)*w/count
		var ww := w*0.55/count
		# The camera sees fronts on two sides of a block and backs on the other two.
		box(Vector3(x, mid, -front - 0.015), Vector3(ww, FLOOR*0.45, 0.03), WINDOW.darkened(0.1))
		if s.win == "band": continue
		match s.win:
			"tall": box(Vector3(x, mid, front + 0.015), Vector3(ww, FLOOR*0.62, 0.03), WINDOW)
			"square": box(Vector3(x, mid, front + 0.015), Vector3(ww*1.1, FLOOR*0.45, 0.03), WINDOW)
			"arch":
				box(Vector3(x, mid - 0.04, front + 0.015), Vector3(ww, FLOOR*0.5, 0.03), WINDOW)
				add("cyl", Vector3(x, mid + FLOOR*0.21, front + 0.015), Vector3(ww/2, 0.03, ww/2), WINDOW, Vector3(PI/2, 0, 0))
			"lattice":
				box(Vector3(x, mid, front + 0.015), Vector3(ww*1.3, FLOOR*0.5, 0.03), Color("3a2a20"))
				for k in 4: box(Vector3(x - ww*0.5 + k*ww*0.33, mid, front + 0.035), Vector3(0.025, FLOOR*0.5, 0.02), Color("c9a878"))
		box(Vector3(x, mid - FLOOR*0.33, front + 0.03), Vector3(ww + 0.06, 0.03, 0.06), trim)
		if "shutters" in extras:
			for side in [-1, 1]: box(Vector3(x + side*(ww*0.5 + 0.05), mid, front + 0.025), Vector3(0.08, FLOOR*0.6, 0.02), shutter)
	if s.win == "band":
		box(Vector3(0, mid, front + 0.015), Vector3(w*0.86, FLOOR*0.42, 0.03), WINDOW)
		for k in 4: box(Vector3(-w*0.43 + k*w*0.287, mid, front + 0.035), Vector3(0.03, FLOOR*0.42, 0.02), trim)
	balcony(s.get("balcony", ""), w, y0, f, trim, Color(profile.signs[v]))
	floor_extras(extras, w, y0, f, v, profile)

func floor_extras(extras: Array, w: float, y0: float, f: int, v: int, profile: Dictionary) -> void:
	var front := DEPTH/2
	if "sign_bands" in extras and (f + v) % 2 == 0:
		box(Vector3(0, y0 + 0.04, front + 0.03), Vector3(w*0.9, 0.12, 0.04), Color(profile.signs[(v + f + 1) % 3]))
		letters(Vector3(0, y0 + 0.04, front + 0.03), w*0.7, 4)
	if "ac" in extras and (f + v) % 2 == 1:
		box(Vector3(w*0.36, y0 + FLOOR*0.25, front + 0.09), Vector3(0.24, 0.16, 0.14), Color("e9ebe8"))
	if "fire_escape" in extras:
		box(Vector3(-w*0.05, y0 + 0.02, front + 0.17), Vector3(w*0.64, 0.03, 0.3), IRON)
		box(Vector3(-w*0.05, y0 + 0.17, front + 0.31), Vector3(w*0.64, 0.02, 0.02), IRON)
		beam(Vector3(w*0.2, y0 + 0.02, front + 0.17), Vector3(-w*0.25, y0 - FLOOR + 0.04, front + 0.17), 0.03, IRON)
	if "plants" in extras and f % 2 == 0:
		add("ball", Vector3(-w*0.3, y0 + 0.14, front + 0.12), Vector3(0.12, 0.1, 0.1), Color("5f9e4f"))

func balcony(kind: String, w: float, y0: float, f: int, trim: Color, sign: Color) -> void:
	var front := DEPTH/2
	match kind:
		"iron":
			if f % 2 != 0: return
			box(Vector3(0, y0 + 0.02, front + 0.12), Vector3(w*0.82, 0.04, 0.24), trim)
			box(Vector3(0, y0 + 0.14, front + 0.23), Vector3(w*0.82, 0.16, 0.02), IRON)
		"wood":
			if f != 0: return
			box(Vector3(0, y0 + 0.02, front + 0.15), Vector3(w*0.7, 0.04, 0.3), WOOD)
			for k in 6: box(Vector3(-w*0.33 + k*w*0.132, y0 + 0.14, front + 0.29), Vector3(0.025, 0.22, 0.025), WOOD)
			box(Vector3(0, y0 + 0.25, front + 0.29), Vector3(w*0.7, 0.03, 0.03), WOOD)
		"lace":
			if f != 0: return
			# Iron-lace verandah over the pavement: posts, balcony rail and a tin roof.
			for x in [-w/2 + 0.06, w/2 - 0.06]: add("cylinder", Vector3(x, (y0 + FLOOR*0.8)/2, front + 0.72), Vector3(0.03, y0 + FLOOR*0.8, 0.03), IRON)
			box(Vector3(0, y0, front + 0.38), Vector3(w, 0.05, 0.76), Color("8a8f96"))
			box(Vector3(0, y0 + 0.16, front + 0.74), Vector3(w, 0.2, 0.02), Color("eef0ea"))
			box(Vector3(0, y0 + FLOOR*0.82, front + 0.38), Vector3(w, 0.04, 0.8), sign.lightened(0.2), Vector3(0.2, 0, 0))
		"mashrabiya":
			if f % 2 != 0: return
			box(Vector3(0, y0 + FLOOR*0.45, front + 0.16), Vector3(w*0.55, FLOOR*0.72, 0.32), WOOD)
			for k in 3: box(Vector3(0, y0 + FLOOR*(0.25 + k*0.2), front + 0.33), Vector3(w*0.5, 0.025, 0.02), Color("c9a878"))
		"jharokha":
			if f != 0: return
			box(Vector3(0, y0 + FLOOR*0.42, front + 0.16), Vector3(w*0.42, FLOOR*0.62, 0.32), trim)
			add("hemi", Vector3(0, y0 + FLOOR*0.73, front + 0.16), Vector3(w*0.2, 0.16, 0.17), trim.lightened(0.1))

# 45° gable along the street: a wall-coloured end filler plus two roof panels.
func gable(w: float, top: float, roof: Color, wall: Color) -> void:
	var half := DEPTH/2
	box(Vector3(0, top, 0), Vector3(w - 0.02, half*sqrt(2.0), half*sqrt(2.0)), wall, Vector3(PI/4, 0, 0))
	for side in [-1, 1]:
		box(Vector3(0, top + half/2 + 0.03, side*half/2), Vector3(w + 0.06, 0.05, half*sqrt(2.0) + 0.16), roof, Vector3(side*PI/4, 0, 0))

func roof_top(kind: String, w: float, top: float, roof: Color, wall: Color, trim: Color) -> void:
	match kind:
		"flat":
			box(Vector3(0, top + 0.01, 0), Vector3(w*0.97, 0.02, DEPTH*0.95), roof)
			box(Vector3(0, top + 0.07, DEPTH/2 - 0.03), Vector3(w, 0.14, 0.06), trim)
		"gable": gable(w, top, roof, wall)
		"mansard":
			box(Vector3(0, top + 0.28, -0.05), Vector3(w, 0.56, DEPTH - 0.4), roof)
			box(Vector3(0, top + 0.02, DEPTH/2 - 0.1), Vector3(w, 0.04, 0.3), trim)
			for x in [-w*0.25, w*0.25]:
				box(Vector3(x, top + 0.3, DEPTH/2 - 0.28), Vector3(0.3, 0.32, 0.2), wall)
				box(Vector3(x, top + 0.3, DEPTH/2 - 0.17), Vector3(0.18, 0.2, 0.02), WINDOW)
		"hip", "tile":
			var reach := Vector2(w/2 + 0.08, DEPTH/2 + 0.08).length()
			add("roof", Vector3(0, top, 0), Vector3(reach, 0.55 if kind == "hip" else 0.36, reach), roof, Vector3(0, PI/4, 0))
		"stepped":
			box(Vector3(0, top, 0), Vector3(w/2*sqrt(2.0), w/2*sqrt(2.0), DEPTH - 0.1), roof, Vector3(0, 0, PI/4))
			for k in 3: box(Vector3(0, top + 0.15 + k*0.28, DEPTH/2 - 0.04), Vector3(w*(1.0 - k*0.3), 0.3, 0.1), wall)
			add("ball", Vector3(0, top + 0.98, DEPTH/2 - 0.04), Vector3.ONE*0.07, trim)
			box(Vector3(0, top + 0.28, DEPTH/2 + 0.02), Vector3(0.2, 0.22, 0.02), WINDOW)
		"tin":
			box(Vector3(0, top + 0.16, 0), Vector3(w + 0.1, 0.05, DEPTH + 0.2), roof, Vector3(-0.2, 0, 0))
			for k in 4: box(Vector3(-w*0.36 + k*w*0.24, top + 0.19, 0), Vector3(0.03, 0.03, DEPTH + 0.2), roof.darkened(0.2), Vector3(-0.2, 0, 0))

func shop_extra(extra: String, w: float, top: float, v: int, sign: Color, trim: Color) -> void:
	var front := DEPTH/2
	match extra:
		"tank":
			add("cyl", Vector3(-w*0.15, top + 0.24, -0.35), Vector3(0.16, 0.55, 0.16), Color("d8dde2"), Vector3(0, 0, PI/2))
			box(Vector3(-w*0.15, top + 0.07, -0.35), Vector3(0.5, 0.12, 0.24), IRON)
		"water_tower":
			if v != 0: return
			for k in 4: add("cylinder", Vector3(w*0.15 + (k%2 - 0.5)*0.3, top + 0.2, -0.3 + (k/2 - 0.5)*0.3), Vector3(0.02, 0.4, 0.02), IRON)
			add("cyl", Vector3(w*0.15, top + 0.62, -0.3), Vector3(0.24, 0.45, 0.24), Color("8a5a3c"))
			add("point", Vector3(w*0.15, top + 0.95, -0.3), Vector3(0.27, 0.22, 0.27), Color("5a4a3c"))
		"chimney": box(Vector3(w*0.3, top + 0.55, -0.3), Vector3(0.18, 0.55, 0.25), Color("9c5a45"))
		"cornice": box(Vector3(0, top - 0.06, front + 0.05), Vector3(w, 0.1, 0.1), trim)
		"pilasters":
			for x in [-w/2 + 0.07, w/2 - 0.07]: box(Vector3(x, (top + GROUND)/2, front + 0.02), Vector3(0.09, top - GROUND, 0.04), trim)
		"dish": add("hemi", Vector3(w*0.25, top + 0.16, -0.25), Vector3(0.15, 0.06, 0.15), Color("ececec"), Vector3(0.8, 0, 0))
		"dome":
			if v == 1: add("hemi", Vector3(-w*0.2, top + 0.02, -0.2), Vector3(0.36, 0.36, 0.36), trim)
		"chhatri":
			if v == 1: return
			for k in 4: add("cylinder", Vector3(w*0.25 + (k%2 - 0.5)*0.3, top + 0.2, -0.3 + (k/2 - 0.5)*0.3), Vector3(0.03, 0.4, 0.03), trim)
			add("hemi", Vector3(w*0.25, top + 0.4, -0.3), Vector3(0.24, 0.24, 0.24), Color("f3ead6"))
		"toron":
			for i in 4: box(Vector3(-w*0.36 + i*w*0.24, top - 0.25, front + 0.12), Vector3(0.04, 0.04, 0.24), WOOD)
			for i in 3: add("point", Vector3(-w*0.3 + i*w*0.3, top + 0.2, front - 0.05), Vector3(0.08, 0.3, 0.08), trim)
		"hoist": box(Vector3(0, top + 0.9, front + 0.12), Vector3(0.05, 0.05, 0.26), WOOD)
		"lantern": add("ball", Vector3(w*0.08, GROUND - 0.2, front + 0.13), Vector3(0.09, 0.12, 0.09), Color("d63a2f"))
		"billboard":
			if v != 1: return
			for x in [-w*0.3, w*0.3]: box(Vector3(x, top + 0.3, -0.2), Vector3(0.05, 0.6, 0.05), IRON)
			box(Vector3(0, top + 0.78, -0.2), Vector3(w*0.92, 0.55, 0.05), sign.lightened(0.15))
			letters(Vector3(0, top + 0.78, -0.2), w*0.7, 4)
		"curved_gable":
			add("cyl", Vector3(0, top + 0.08, front - 0.03), Vector3(w*0.28, 0.06, w*0.28), trim, Vector3(PI/2, 0, 0))

# --- towers (footprint 3 × 3) -------------------------------------------------------

func tower(profile: Dictionary, variant: int) -> Array:
	var v := variant % 2
	var height := 5.0 if v == 0 else 8.0
	var accent := Color(profile.signs[v])
	var wall := Color(profile.walls[0]).lerp(Color("e6e2da"), 0.55)
	match profile.tower[v]:
		"glass": glass_tower(height, v, accent)
		"concrete": concrete_tower(height, wall, accent)
		"deco": deco_tower(height)
		"pagoda": pagoda_tower(height)
		"stone": stone_tower(3.4 if v == 0 else 4.4, v, Color(profile.roof))
		"hotel": hotel_tower(height, accent)
		_: adobe_tower(height, Color(profile.walls[v]))
	return take()

# Window strips on the two faces the camera sees.
func facade_rows(center: Vector3, size: Vector3, pitch: float, color: Color, fill := 0.45) -> void:
	for r in int(size.y/pitch):
		var y := center.y - size.y/2 + (r + 0.55)*pitch
		box(Vector3(center.x, y, center.z + size.z/2 + 0.015), Vector3(size.x*0.86, pitch*fill, 0.03), color)
		box(Vector3(center.x + size.x/2 + 0.015, y, center.z), Vector3(0.03, pitch*fill, size.z*0.86), color)

func podium(color: Color) -> void:
	box(Vector3(0, 0.45, 0), Vector3(TOWER_SIZE, 0.9, TOWER_SIZE), color)
	box(Vector3(0, 0.42, TOWER_SIZE/2 + 0.02), Vector3(TOWER_SIZE*0.7, 0.6, 0.03), SHOP_GLASS)
	box(Vector3(TOWER_SIZE/2 + 0.02, 0.42, 0), Vector3(0.03, 0.6, TOWER_SIZE*0.7), SHOP_GLASS)

func glass_tower(height: float, v: int, accent: Color) -> void:
	var glass := Color("6f9dbd") if v == 0 else Color("5f86a8")
	podium(Color("cfc8bb"))
	var shaft_height := height - 0.9
	var lower := shaft_height if v == 0 else shaft_height*0.68
	box(Vector3(0, 0.9 + lower/2, 0), Vector3(2.6, lower, 2.6), glass)
	facade_rows(Vector3(0, 0.9 + lower/2, 0), Vector3(2.6, lower, 2.6), 0.45, Color("dfe8ee"), 0.1)
	var roof_y := 0.9 + lower
	if v == 1:
		var upper := shaft_height - lower
		box(Vector3(0, roof_y + upper/2, 0), Vector3(1.9, upper, 1.9), glass.lightened(0.08))
		facade_rows(Vector3(0, roof_y + upper/2, 0), Vector3(1.9, upper, 1.9), 0.45, Color("dfe8ee"), 0.1)
		roof_y += upper
		add("cylinder", Vector3(0, roof_y + 0.8, 0), Vector3(0.04, 1.6, 0.04), Color("c9d0d6"))
	box(Vector3(0, roof_y + 0.15, 0), Vector3(1.2, 0.3, 1.0), Color("c8d0d6"))
	box(Vector3(0, roof_y + 0.02, 0.9), Vector3(1.6, 0.04, 0.5), accent)

func concrete_tower(height: float, wall: Color, accent: Color) -> void:
	var size := Vector3(3.0, height, 2.4)
	box(Vector3(0, height/2, 0), size, wall)
	facade_rows(Vector3(0, height/2, 0), size, 0.5, Color("6f8796"), 0.36)
	for r in range(1, int(height/0.5)):
		box(Vector3(0, r*0.5, size.z/2 + 0.1), Vector3(size.x*0.9, 0.05, 0.2), wall.darkened(0.12))
	box(Vector3(1.05, height/2, size.z/2 + 0.04), Vector3(0.28, height, 0.05), accent)
	for x in [-0.8, 0.2]: add("cyl", Vector3(x, height + 0.25, -0.3), Vector3(0.28, 0.5, 0.28), Color("9aa4ad"))
	box(Vector3(0.8, height + 0.3, 0.3), Vector3(0.6, 0.6, 0.6), wall.darkened(0.08))

func deco_tower(height: float) -> void:
	var stone := Color("d9cfb8")
	var y := 0.0
	for tier in [[3.0, height*0.5], [2.2, height*0.26], [1.4, height*0.12]]:
		var size := Vector3(tier[0], tier[1], tier[0])
		box(Vector3(0, y + size.y/2, 0), size, stone)
		for k in 4:
			var t: float = (k + 0.5)/4.0 - 0.5
			box(Vector3(t*size.x*0.8, y + size.y/2, size.z/2 + 0.015), Vector3(size.x*0.1, size.y*0.9, 0.03), Color("6f8796"))
			box(Vector3(size.x/2 + 0.015, y + size.y/2, t*size.z*0.8), Vector3(0.03, size.y*0.9, size.z*0.1), Color("6f8796"))
		y += size.y
	add("point", Vector3(0, y + height*0.07, 0), Vector3(0.3, height*0.14, 0.3), Color("c9ccd0"))

func pagoda_tower(height: float) -> void:
	var gold := Color("c9a45a")
	var y := 0.0
	var width := 2.8
	for tier in 4:
		var tier_height := height*0.22
		box(Vector3(0, y + tier_height/2, 0), Vector3(width, tier_height, width), Color("7a9fb8"))
		facade_rows(Vector3(0, y + tier_height/2, 0), Vector3(width, tier_height, width), 0.4, Color("dfe8ee"), 0.1)
		y += tier_height
		add("roof", Vector3(0, y, 0), Vector3(width*0.82, 0.3, width*0.82), gold, Vector3(0, PI/4, 0))
		width -= 0.45
	add("point", Vector3(0, y + 0.6, 0), Vector3(0.18, 1.2, 0.18), gold)

func stone_tower(height: float, v: int, roof: Color) -> void:
	var stone := Color("e8dcc4")
	var size := Vector3(TOWER_SIZE, height, TOWER_SIZE)
	box(Vector3(0, height/2, 0), size, stone)
	facade_rows(Vector3(0, height/2 + 0.2, 0), Vector3(size.x, height - 0.4, size.z), 0.62, WINDOW, 0.42)
	box(Vector3(0, 0.45, size.z/2 + 0.02), Vector3(2.2, 0.7, 0.03), SHOP_GLASS)
	box(Vector3(0, height - 0.05, size.z/2 + 0.05), Vector3(size.x, 0.12, 0.1), stone.darkened(0.15))
	if v == 0:
		box(Vector3(0, height + 0.3, 0), Vector3(size.x - 0.3, 0.6, size.z - 0.3), roof)
	else:
		add("hemi", Vector3(0.6, height, 0.6), Vector3(0.9, 1.0, 0.9), roof)
		add("point", Vector3(0.6, height + 1.2, 0.6), Vector3(0.12, 0.5, 0.12), Color("d4b25a"))

func hotel_tower(height: float, accent: Color) -> void:
	var white := Color("f2f2ee")
	var size := Vector3(3.0, height, 2.0)
	box(Vector3(0, height/2, 0), size, white)
	for r in range(1, int(height/0.45)):
		box(Vector3(0, r*0.45, size.z/2 + 0.12), Vector3(size.x*0.94, 0.12, 0.24), Color("8fc3d6") if r % 2 == 0 else white.darkened(0.06))
		box(Vector3(size.x/2 + 0.015, r*0.45 + 0.2, 0), Vector3(0.03, 0.18, size.z*0.8), WINDOW)
	box(Vector3(0, height + 0.25, 0.4), Vector3(1.8, 0.4, 0.06), accent)
	letters(Vector3(0, height + 0.25, 0.4), 1.4, 5)

func adobe_tower(height: float, wall: Color) -> void:
	var size := Vector3(2.8, height, 2.8)
	var dark := Color("5d4a3a")
	box(Vector3(0, height/2, 0), size, wall)
	for r in int(height/0.6):
		var y := 0.4 + r*0.6
		for k in 3:
			var t: float = (k + 0.5)/3.0 - 0.5
			box(Vector3(t*size.x*0.75, y, size.z/2 + 0.015), Vector3(0.3, 0.3, 0.03), dark)
			add("cyl", Vector3(t*size.x*0.75, y + 0.15, size.z/2 + 0.015), Vector3(0.15, 0.03, 0.15), dark, Vector3(PI/2, 0, 0))
			box(Vector3(size.x/2 + 0.015, y, t*size.z*0.75), Vector3(0.03, 0.3, 0.3), dark)
	box(Vector3(0, height + 0.08, size.z/2 - 0.04), Vector3(size.x, 0.16, 0.08), wall.darkened(0.12))
	add("hemi", Vector3(-0.5, height, -0.5), Vector3(0.6, 0.6, 0.6), Color("e8d8b8"))
