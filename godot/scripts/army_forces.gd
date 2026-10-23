extends RefCounted

# Which force each city fields and how it looks. Every country dresses its
# police, soldiers and vehicles in its own colours (uniform, cap band, patrol
# car livery, camouflage, one flag accent) - colours only, no real insignia.
# The force itself grows with the city index: police first, then soldiers,
# rocket troops, lock-on missile trucks, flak guns and tanks.

const COUNTRY := {
	"onepillar":"vn", "khuevan":"vn", "namsan":"kr", "watarun":"th", "taj":"in", "pearl":"cn",
	"fuji":"jp", "tokyotower":"jp", "eiffel":"fr", "brandenburg":"de", "bigben":"uk", "alcala":"es",
	"pisa":"it", "colosseum":"it", "royalpalace":"nl", "stbasils":"ru", "pyramid":"eg", "sphinx":"eg",
	"cairotower":"eg", "kicc":"ke", "djenne":"ml", "nationaltheatre":"ng", "baobab":"mg",
	"tablemountain":"za", "liberty":"us", "empire":"us", "willis":"us", "needle":"us", "hollywood":"us",
	"capitol":"us", "cntower":"ca", "chichen":"mx", "christ":"br", "masp":"br", "sugarloaf":"br",
	"machu":"pe", "limacathedral":"pe", "obelisco":"ar", "monserrate":"co", "costanera":"cl", "moai":"cl",
	"sydney":"au", "flinders":"au", "uluru":"au", "belltower":"au", "parliament":"au", "skytower":"nz",
	"fijitemple":"fj", "tetmai":"vn", "starlantern":"vn", "juliet":"it", "xmastree":"de", "jackolantern":"us",
	"easteregg":"au", "kanogate":"ng", "carnivalfloat":"br"}

# police uniform, cap, cap band | car body, lower body ("" = same), side stripe
# ("" = none), checker pair ([] = none), light bar | soldier camo, helmet,
# vehicle paint, flag accent. Optional "vest": a hi-vis vest over the uniform.
const LOOKS := {
	"vn": {"uniform":"6e7d3f", "cap":"6e7d3f", "band":"c8302c", "car":"eef1f4", "lower":"", "stripe":"1f4fa8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"55673a", "helmet":"4a5a32", "paint":"56663c", "accent":"da251d"},
	"kr": {"uniform":"1f2f4f", "cap":"1f2f4f", "band":"f2c230", "car":"f4f6f8", "lower":"", "stripe":"1f5fb8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"4f5d3b", "helmet":"414d30", "paint":"5a6a45", "accent":"cd2e3a"},
	"th": {"uniform":"7a5a3a", "cap":"7a5a3a", "band":"c03a2b", "car":"f2f2f2", "lower":"", "stripe":"8a1f2b", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"5f6b45", "helmet":"4f5a38", "paint":"5f6b45", "accent":"2d2a4a"},
	"in": {"uniform":"b9a46a", "cap":"b9a46a", "band":"c0392b", "car":"ffffff", "lower":"", "stripe":"c0392b", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"6b6a45", "helmet":"5a5938", "paint":"6b6a45", "accent":"ff9933"},
	"cn": {"uniform":"1d2b45", "cap":"1d2b45", "band":"f2c230", "car":"fafafa", "lower":"", "stripe":"1b4fa0", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"4e6040", "helmet":"405034", "paint":"4f6243", "accent":"de2910"},
	"jp": {"uniform":"23324f", "cap":"23324f", "band":"f2c230", "car":"ffffff", "lower":"1a1a1e", "stripe":"", "checker":[], "lights":["ff2a22", "ff2a22"], "camo":"556b4a", "helmet":"46593d", "paint":"5c6a52", "accent":"bc002d"},
	"fr": {"uniform":"1e2b55", "cap":"1e2b55", "band":"c8102e", "car":"f5f5f5", "lower":"", "stripe":"0055a4", "checker":[], "lights":["2f7bff", "2f7bff"], "camo":"5f6a4c", "helmet":"50593f", "paint":"6b6f55", "accent":"ef4135"},
	"de": {"uniform":"1f3d6e", "cap":"1f3d6e", "band":"e8e8e8", "car":"c9ced6", "lower":"", "stripe":"1f4fa8", "checker":[], "lights":["2f7bff", "2f7bff"], "camo":"5e6650", "helmet":"4e5642", "paint":"565e48", "accent":"ffce00"},
	"uk": {"uniform":"1a1d24", "cap":"1a1d24", "band":"f5f5f5", "car":"f5f5f5", "lower":"", "stripe":"", "checker":["ffd200", "1f4fa8"], "lights":["2f7bff", "2f7bff"], "camo":"6a6a48", "helmet":"58583b", "paint":"6b6b4d", "accent":"c8102e", "vest":"d9f02a"},
	"es": {"uniform":"1d2a4a", "cap":"1d2a4a", "band":"f1bf00", "car":"f5f5f5", "lower":"", "stripe":"1d3f8f", "checker":[], "lights":["2f7bff", "2f7bff"], "camo":"61644a", "helmet":"51543d", "paint":"646a4f", "accent":"aa151b"},
	"it": {"uniform":"15182a", "cap":"15182a", "band":"c8102e", "car":"1b2140", "lower":"", "stripe":"c8102e", "checker":[], "lights":["2f7bff", "2f7bff"], "camo":"5d6249", "helmet":"4d523c", "paint":"5d6249", "accent":"009246"},
	"nl": {"uniform":"1d2c55", "cap":"1d2c55", "band":"f36c21", "car":"f5f5f5", "lower":"", "stripe":"", "checker":["1f4fa8", "f36c21"], "lights":["2f7bff", "2f7bff"], "camo":"57604a", "helmet":"48503d", "paint":"57604a", "accent":"f36c21"},
	"ru": {"uniform":"4a5768", "cap":"4a5768", "band":"c8102e", "car":"f5f5f5", "lower":"", "stripe":"1f4fa8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"4d5a46", "helmet":"404b3a", "paint":"4f5c46", "accent":"0039a6"},
	"eg": {"uniform":"f0f0ec", "cap":"1a1a1a", "band":"c8102e", "car":"f5f5f5", "lower":"", "stripe":"1f4fa8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"b59c6a", "helmet":"a68d5c", "paint":"c2aa76", "accent":"c8102e"},
	"ke": {"uniform":"1f3360", "cap":"1f3360", "band":"c8102e", "car":"f0f0f0", "lower":"", "stripe":"1f4fa8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"8a7a52", "helmet":"7a6b46", "paint":"7d6f4c", "accent":"006600"},
	"ml": {"uniform":"4f5d36", "cap":"4f5d36", "band":"fcd116", "car":"f0f0f0", "lower":"", "stripe":"14b53a", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"b09a66", "helmet":"9f8a58", "paint":"bba273", "accent":"fcd116"},
	"ng": {"uniform":"141414", "cap":"141414", "band":"2c5aa0", "car":"f0f0f0", "lower":"1f3a7a", "stripe":"", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"5b6a3e", "helmet":"4c5933", "paint":"5d6b45", "accent":"008751"},
	"mg": {"uniform":"2a4a8a", "cap":"2a4a8a", "band":"c8102e", "car":"f0f0f0", "lower":"", "stripe":"2a6ab8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"6b6b48", "helmet":"5a5a3b", "paint":"6d6d4a", "accent":"007e3a"},
	"za": {"uniform":"1e2b4a", "cap":"1e2b4a", "band":"ffb612", "car":"f5f5f5", "lower":"", "stripe":"1f4fa8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"8b7d55", "helmet":"7a6d48", "paint":"8a7a52", "accent":"007749"},
	"us": {"uniform":"1b2236", "cap":"1b2236", "band":"c9a227", "car":"f5f5f5", "lower":"15161a", "stripe":"", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"a08f68", "helmet":"8a7a58", "paint":"9c8a62", "accent":"3c3b6e"},
	"ca": {"uniform":"b3262b", "cap":"6b4a2b", "band":"f2c230", "car":"f5f5f5", "lower":"", "stripe":"c8102e", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"56653f", "helmet":"485534", "paint":"5a6845", "accent":"d52b1e"},
	"mx": {"uniform":"1d2a4a", "cap":"1d2a4a", "band":"c9a227", "car":"f5f5f5", "lower":"", "stripe":"1f4fa8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"6b6d45", "helmet":"5a5c39", "paint":"6d6f48", "accent":"006847"},
	"br": {"uniform":"7b7f78", "cap":"3a3f3a", "band":"f2c230", "car":"f5f5f5", "lower":"", "stripe":"2a2f2a", "checker":[], "lights":["ff3b30", "ff3b30"], "camo":"5b6a45", "helmet":"4c5939", "paint":"5e6c48", "accent":"009c3b"},
	"pe": {"uniform":"5f6d47", "cap":"5f6d47", "band":"d91023", "car":"f5f5f5", "lower":"", "stripe":"2f6b3a", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"6a6b48", "helmet":"595a3b", "paint":"6d6e4a", "accent":"d91023"},
	"ar": {"uniform":"1d2a55", "cap":"1d2a55", "band":"74acdf", "car":"f5f5f5", "lower":"", "stripe":"74acdf", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"66684a", "helmet":"55573d", "paint":"66684a", "accent":"74acdf"},
	"co": {"uniform":"3f5a35", "cap":"3f5a35", "band":"fcd116", "car":"f5f5f5", "lower":"3f5a35", "stripe":"", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"586b40", "helmet":"495a35", "paint":"586b40", "accent":"fcd116"},
	"cl": {"uniform":"3b5b34", "cap":"3b5b34", "band":"d52b1e", "car":"2e4a2a", "lower":"", "stripe":"f5f5f5", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"5a6745", "helmet":"4b5739", "paint":"5a6745", "accent":"0039a6"},
	"au": {"uniform":"1d2a4a", "cap":"1d2a4a", "band":"f5f5f5", "car":"f5f5f5", "lower":"", "stripe":"", "checker":["1f4fa8", "f5f5f5"], "lights":["ff3b30", "2f7bff"], "camo":"8b7b55", "helmet":"7a6b48", "paint":"8d7c55", "accent":"00247d"},
	"nz": {"uniform":"1a2440", "cap":"1a2440", "band":"f5f5f5", "car":"f5f5f5", "lower":"", "stripe":"", "checker":["f2d21a", "1f4fa8"], "lights":["ff3b30", "2f7bff"], "camo":"4f5a40", "helmet":"414b35", "paint":"556045", "accent":"cc142b"},
	"fj": {"uniform":"2a6ab8", "cap":"1a2a4a", "band":"f5f5f5", "car":"f5f5f5", "lower":"", "stripe":"2a6ab8", "checker":[], "lights":["ff3b30", "2f7bff"], "camo":"5a6745", "helmet":"4b5739", "paint":"5a6745", "accent":"68bfe5"},
}

# Force bands by city index: police, soldiers, rocket troops, then vehicles
# (patrol cars, missile trucks, flak guns, tanks). Each vehicle anchors a squad
# at a crossing; the foot units spread round the squads.
const TIERS := [
	{"from":0, "police":24, "soldier":0, "rocket":0, "car":3, "missile":0, "flak":0, "tank":0},
	{"from":2, "police":14, "soldier":8, "rocket":0, "car":2, "missile":1, "flak":0, "tank":0},
	{"from":5, "police":10, "soldier":10, "rocket":2, "car":2, "missile":1, "flak":0, "tank":0},
	{"from":8, "police":6, "soldier":10, "rocket":3, "car":1, "missile":1, "flak":1, "tank":0},
	{"from":16, "police":4, "soldier":12, "rocket":4, "car":1, "missile":1, "flak":1, "tank":1},
	{"from":24, "police":2, "soldier":14, "rocket":5, "car":1, "missile":2, "flak":1, "tank":1},
	{"from":32, "police":0, "soldier":16, "rocket":6, "car":1, "missile":2, "flak":2, "tank":2},
	{"from":40, "police":0, "soldier":18, "rocket":7, "car":1, "missile":3, "flak":2, "tank":2},
]
const FOOT := ["police", "soldier", "rocket"]
const VEHICLES := ["car", "missile", "flak", "tank"]
const RADIUS := {"police":0.4, "soldier":0.42, "rocket":0.44, "car":0.85, "missile":1.25, "flak":1.05, "tank":1.45}
const MAX_FOOT_PER_SQUAD := 12

static func country(level: Dictionary) -> String:
	return COUNTRY.get(level.get("boss", ""), "vn")

static func look(level: Dictionary) -> Dictionary:
	return LOOKS[country(level)]

# The force for a city: unit counts, the country and the 0..1 pressure that
# sharpens every weapon.
static func force(level: Dictionary) -> Dictionary:
	var index := int(level.get("index", 0))
	var tier: Dictionary = TIERS[0]
	for band in TIERS:
		if index >= int(band.from): tier = band
	var result := tier.duplicate()
	result.erase("from")
	result.country = country(level)
	result.pressure = clampf(index/47.0, 0.0, 1.0)
	return result

# Squads hold crossings in a fixed per-city order; foot units line the four
# arms of their squad's crossing by the kerbs, so traffic runs down the middle.
static func place(g, force_spec: Dictionary) -> void:
	# Crossings next to a roadblock stay clear: a squad there would hide the
	# block and wall the street off.
	var posts: Array[Vector2] = []
	for post in g.layout.junctions():
		if g.features.barriers.all(func(b): return post.distance_to(Vector2(b.position.x, b.position.z)) > 6.0): posts.append(post)
	if posts.is_empty(): posts = g.layout.junctions()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113 + int(g.campaign.selected)*29
	for i in range(posts.size()-1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := posts[i]
		posts[i] = posts[j]
		posts[j] = swap
	var vehicles: Array[String] = []
	for kind in VEHICLES:
		for i in int(force_spec.get(kind, 0)): vehicles.append(kind)
	var foot: Array[String] = []
	for kind in FOOT:
		for i in int(force_spec.get(kind, 0)): foot.append(kind)
	var squads := maxi(1, vehicles.size())
	var filled: Array[int] = []
	filled.resize(squads)
	filled.fill(0)
	for s in squads:
		var post: Vector2 = posts[s % posts.size()]
		# A second squad on the same crossing parks a block arm away.
		if s >= posts.size(): post += Vector2(5.0, 0)
		if s < vehicles.size(): add_unit(g, vehicles[s], post, PI/4)
	for i in foot.size():
		var s := i % squads
		var slot := filled[s]
		if slot >= MAX_FOOT_PER_SQUAD: continue
		filled[s] += 1
		var post: Vector2 = posts[s % posts.size()] + (Vector2(5.0, 0) if s >= posts.size() else Vector2.ZERO)
		var arm: Vector2 = [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP][slot%4]
		var row := slot/4
		var side := Vector2(-arm.y, arm.x)*(1.25 if row%2 == 0 else -1.25)
		var at: Vector2 = post + arm*(2.4 + row*1.0) + side
		add_unit(g, foot[i], at, atan2(-arm.x, -arm.y))

static func add_unit(g, kind: String, at: Vector2, yaw: float) -> Dictionary:
	var item: Dictionary = g.add_item("army_" + kind, Vector3(at.x, 0.16 if kind in FOOT else 0.08, at.y), RADIUS[kind], 0, yaw)
	item.defender = true
	item.army = true
	item.unit = kind
	if kind != "car": item.gunner = true
	return item
