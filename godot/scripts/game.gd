extends Node3D

# Alien invasion: the player is a black hole dropped by a saucer. Swallow a city,
# grow, then swallow its landmark or defeat Earth's defence unit to conquer it.
const Models = preload("res://scripts/models.gd")
const Hud = preload("res://scripts/hud.gd")
const Traffic = preload("res://scripts/traffic.gd")
const DuckBoss = preload("res://scripts/duck_boss.gd")
const Smoke = preload("res://scripts/smoke.gd")
const Fx = preload("res://scripts/fx.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Weather = preload("res://scripts/weather.gd")
const Wardrobe = preload("res://scripts/wardrobe.gd")
const MapLayout = preload("res://scripts/map_layout.gd")
const Capture = preload("res://scripts/capture.gd")
const START_RADIUS := Campaign.START_RADIUS
const MAX_RADIUS := 8.5
const MIN_BOSS := 3.0
const MAX_BOSS := 5.6
const FINALE_BOSS := 0.6
const MODEL_BOSS := 2.8
const SPAWN := Vector3(0, 0, 9)
const BOSS_HOME := Vector3(0, 0.16, -1.8)
const EAT_RATIO := 0.85
const GROWTH := 0.65
const COMBO_WINDOW := 1.0
const BOSS_BONUS := 500
const STAR2_PCT := 0.75
const STAR3_PCT := 0.9
const MAX_FLOATERS := 8
const FLOATER_TIME := 0.9
const BOSS_FALL := 0.85
const BOSS_SLOWMO := 0.6
const SLOWMO_RATE := 0.35
const GROWTH_TIER := 0.32
const BIG_BITE := 0.8
const CAR_SPACING := 15.0
# Orthographic view: a closer camera frames the same area but lets the shadow
# map cover a shorter range at higher resolution.
const CAMERA_OFFSET := Vector3(10.8, 16.2, 13.8)
const LAMP_OFFSET := Transform3D(Basis(), Vector3(0, 1.68, 0))

var campaign = Campaign.new()
var level: Dictionary = Campaign.level_info(0)
var layout = MapLayout.make(3, 3)
var stats: Dictionary = campaign.stats()
var palette: Array = level.palette
var weather: Node3D
var wardrobe: Control
var world: Node3D
var sky_environment: Environment
var sunlight: DirectionalLight3D
var rim_shader: ShaderMaterial
var models = Models.new()
var traffic = Traffic.new()
var duck = DuckBoss.new()
var minions: Array[Dictionary] = []
var boss_radius := MIN_BOSS
var combo := 0
var combo_time := 0.0
var best_combo := 0
var eaten_points := 0
var total_points := 0
var growth_milestone := 1.0
var floaters: Array[Dictionary] = []
var rim: MeshInstance3D
var wall: MeshInstance3D
var craft_meshes := {}
var displayed_craft := -1
var saucer: MeshInstance3D
var beam: MeshInstance3D
var fx: Fx
var sfx: Sfx
var lamp_materials := {}
var pulse := 0.0
var tier := 0
var slowmo := 0.0
var last_tick := 0
var reward := 0
var items: Array[Dictionary] = []
var batches: Dictionary = {}
var ground_material: ShaderMaterial
var camera: Camera3D
var hole: Node3D
var hud: Control
var hole_position := SPAWN
var radius := START_RADIUS
var target_radius := START_RADIUS
var remaining := 100.0
var score := 0
var best := 0
var eaten := 0
var playing := false
var paused := false
var started := false
var mode := "menu"
var dragging := false
var touch_id := -1
var drag_origin := Vector2.ZERO
var drag_delta := Vector2.ZERO
var boss_index := -1
var elapsed := 0.0
var bite_time := 0.0
var test_mode := false
var capture_mode := false
var smoke: RefCounted
var camera_target := Vector3.ZERO

func _ready() -> void:
	get_tree().quit_on_go_back = false
	var args := OS.get_cmdline_user_args()
	test_mode = "--smoke" in args or "--campaign-smoke" in args
	capture_mode = "--capture" in args or "--campaign-capture" in args
	make_environment()
	if not test_mode and not capture_mode and FileAccess.file_exists("user://prototype_save.json"):
		campaign.restore(JSON.parse_string(FileAccess.get_file_as_string("user://prototype_save.json")))
	best = campaign.best
	weather = Weather.new()
	add_child(weather)
	make_hole()
	fx = Fx.new()
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	load_level(campaign.selected)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	hud.play_requested.connect(on_play)
	hud.pause_requested.connect(toggle_pause)
	hud.menu_requested.connect(go_menu)
	hud.levels_requested.connect(func(): open_panel("levels"))
	hud.shop_requested.connect(func(): open_panel("shop"))
	hud.styles_requested.connect(func(): open_panel("crafts"))
	wardrobe = Wardrobe.new()
	wardrobe.game = self
	layer.add_child(wardrobe)
	apply_style()
	hud.best = best
	reset_round()
	go_menu()
	if test_mode:
		smoke = load("res://scripts/campaign_smoke.gd").new() if "--campaign-smoke" in args else Smoke.new()
		smoke.run.call_deferred(self)
	elif capture_mode:
		smoke = Capture.new()
		smoke.run.call_deferred(self, "--campaign-capture" in args)

func is_landmark() -> bool:
	return Campaign.LANDMARKS.has(level.boss)

func load_level(index: int) -> void:
	campaign.selected = clampi(index, 0, Campaign.level_count()-1)
	level = Campaign.level_info(campaign.selected)
	layout = MapLayout.make(level.cols, level.rows)
	stats = campaign.stats()
	palette = level.palette
	items.clear()
	minions.clear()
	batches.clear()
	lamp_materials.clear()
	if is_instance_valid(world): world.free()
	world = Node3D.new()
	add_child(world)
	models.cache.clear()
	models.roofs = [Color(palette[6]), Color(palette[7]), Color(palette[6]).lightened(0.17), Color(palette[7]).darkened(0.1)]
	models.foliage = Color(palette[4])
	models.boss_style = level.boss
	models.region_style = level.style
	total_points = 0
	make_ground()
	make_city()
	make_batches()
	weather.configure(level.weather, sky_environment, sunlight, Color(palette[5]))
	reset_round()

func persist() -> void:
	campaign.best = best
	if not test_mode and not capture_mode: campaign.save_progress()

func apply_style() -> void:
	if not rim_shader:
		rim_shader = ShaderMaterial.new()
		rim_shader.shader = load("res://shaders/rim.gdshader")
		rim.material_override = rim_shader
	var style: Array = Campaign.SKINS[campaign.skin]
	rim_shader.set_shader_parameter("style", campaign.skin)
	rim_shader.set_shader_parameter("color_a", Color(style[1]))
	rim_shader.set_shader_parameter("color_b", Color(style[2]))
	fx.configure(campaign.effect, campaign.trail, Color(style[1]))
	if is_instance_valid(saucer) and displayed_craft != campaign.craft:
		if not craft_meshes.has(campaign.craft): craft_meshes[campaign.craft] = preload("res://scripts/fleet.gd").new().build(models,campaign.craft)
		saucer.mesh = craft_meshes[campaign.craft]
		displayed_craft = campaign.craft
		beam.material_override.albedo_color = Color(Color(preload("res://scripts/fleet.gd").COLORS[campaign.craft]),0.16)

func open_panel(tab: String) -> void:
	if mode != "menu": return
	clear_drag()
	mode = "customize"
	if tab in ["skins", "effects", "trails", "crafts"]:
		hole_position = Vector3(-4,0,-9)
		radius = 1.25
	hud.visible = false
	wardrobe.open(tab)

func close_panel() -> void:
	wardrobe.hide()
	hud.show()
	mode = "menu"
	fx.clear()
	stats = campaign.stats()
	reset_stats()
	persist()

func make_environment() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	sky_environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b3d2d3")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c7dceb")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sunlight = sun
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.light_color = Color("fff0da")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 42
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	camera.far = 200
	camera.current = true
	add_child(camera)

func make_ground() -> void:
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://shaders/ground.gdshader")
	var parts: Array = []
	var width: float = layout.half_x*2
	var depth: float = layout.half_z*2
	parts.append(models.piece("box", Vector3(0, -0.24, 0), Vector3(width, 0.48, depth), Color(palette[0])))
	parts.append(models.piece("box", Vector3(0, 0.01, 0), Vector3(width-2, 0.04, depth-2), Color(palette[1])))
	for x in layout.blocks_x:
		for z in layout.blocks_z:
			parts.append(models.piece("box", Vector3(x, 0.075, z), Vector3(14.8, 0.1, 14.8), Color(palette[2])))
			parts.append(models.piece("box", Vector3(x, 0.13, z), Vector3(12.7, 0.06, 12.7), Color(palette[3]) if x!=0 or z!=0 else Color(palette[3]).lightened(0.15)))
	for street in layout.streets_x:
		for i in range(int(-layout.half_z)+2, int(layout.half_z)-1, 3):
			parts.append(models.piece("box", Vector3(street, 0.04, i), Vector3(0.1, 0.015, 1.3), Color("c6d0c8")))
	for street in layout.streets_z:
		for i in range(int(-layout.half_x)+2, int(layout.half_x)-1, 3):
			parts.append(models.piece("box", Vector3(i, 0.04, street), Vector3(1.3, 0.015, 0.1), Color("c6d0c8")))
	# Zebra crossings and stop lines at each signalled crossing.
	for x in layout.crossings_x:
		for z in layout.crossings_z:
			for i in range(5):
				parts.append(models.piece("box", Vector3(x-1.2+i*0.6, 0.055, z+3.1), Vector3(0.3, 0.02, 1.45), Color("e3ddc8")))
			for lane in [1, -1]:
				parts.append(models.piece("box", Vector3(x - lane*(Traffic.BOX-0.72), 0.045, z+lane*0.85), Vector3(0.14, 0.015, 1.45), Color("eef0e6")))
				parts.append(models.piece("box", Vector3(x-lane*0.85, 0.045, z - lane*(Traffic.BOX-0.72)), Vector3(1.45, 0.015, 0.14), Color("eef0e6")))
	var ground := MeshInstance3D.new()
	ground.mesh = models.bake(parts, ground_material)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ground)

func add_item(kind: String, pos: Vector3, size: float, variant: int = 0, yaw: float = 0.0) -> Dictionary:
	var item := {"kind":kind, "position":pos, "origin":pos, "radius":size, "variant":variant,
		"yaw":yaw, "origin_yaw":yaw, "roll":0.0, "fall":-1.0, "eaten":false, "batch":kind+str(variant), "slot":0}
	items.append(item)
	return item

func make_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4819 + campaign.selected*137
	# Farmland on the outskirts of big maps in the more rural continents.
	var farms: bool = level.style in ["europe", "namerica", "oceania"] and layout.cols >= 5
	for x in layout.blocks_x:
		for z in layout.blocks_z:
			if x == 0 and z == 0: pass
			elif farms and layout.is_edge_block(x, z) and rng.randf() < 0.5: make_farm_block(x, z, rng)
			else:
				for dx in [-3.2, 3.2]:
					for dz in [-3.0, 3.0]:
						add_item("house", Vector3(x+dx, 0.16, z+dz), 1.5, rng.randi_range(0,3))
			for dx in [-5.7, 5.7]:
				for dz in [-5.7, 5.7]:
					add_item("tree", Vector3(x+dx, 0.16, z+dz), 0.68, int(dx > 0) ^ int(dz > 0))
			for dx in [-3.2, 3.2]:
				add_item("bench", Vector3(x+dx, 0.16, z+6.6), 0.55)
			for i in range(6):
				var walker := add_item("person", Vector3(x-5+i*2, 0.16, z+7.05), 0.22, i%4)
				Traffic.make_walker(walker, Vector2(0.75, 0.12), rng.randf_range(0.35, 0.6), rng.randf_range(0, TAU))
	make_traffic(rng)
	make_signals()
	# Accessible snacks connect the opening street to trees and cars. Cones sit on
	# the centre line so both traffic lanes stay clear.
	for i in range(18):
		add_item("cone", Vector3(-7.0+i*0.82, 0.07, 9.0), 0.2)
	for i in range(16):
		var walker := add_item("person", Vector3(-6.4+i*0.8, 0.16, 6.9), 0.22, i%4)
		Traffic.make_walker(walker, Vector2(0.28, 0.1), rng.randf_range(0.25, 0.4), rng.randf_range(0, TAU))
	make_boss()

func make_farm_block(x: float, z: float, rng: RandomNumberGenerator) -> void:
	for dx in [-3.2, 3.2]:
		for dz in [-3.0, 3.0]:
			var id: String = "tent_smallOpen" if dx < 0 and dz < 0 else "cow" if dx > 0 and dz < 0 else "pig" if dx < 0 else "chicken"
			var animal := add_item("farm_"+id, Vector3(x+dx,0.18,z+dz), Models.FARM_RADIUS[id], 0, rng.randf_range(0,TAU))
			if id != "tent_smallOpen": Traffic.make_walker(animal, Vector2(0.45,0.35), 0.3, rng.randf_range(0,TAU))
	for row in [-2, 0, 2]:
		for col in [-4, -2, 0, 2, 4]:
			var crop: String = "crops_cornStageD" if row < 0 else "crops_wheatStageB" if row == 0 else "pumpkin"
			add_item("farm_"+crop, Vector3(x+col,0.2,z+row), Models.FARM_RADIUS[crop])

# The boss size comes from the map's own food, so bigger maps need a bigger meal.
func make_boss() -> void:
	boss_index = items.size()
	var boss := add_item("boss", BOSS_HOME, MIN_BOSS)
	boss.is_boss = true
	var minion_kind: String = Campaign.MINIONS.get(level.boss, "")
	if minion_kind != "":
		for i in range(DuckBoss.MAX_DROPS):
			var minion := add_item(minion_kind, BOSS_HOME, 0.36)
			minion.hidden = true
			minion.bonus = true
			Traffic.make_walker(minion, Vector2(0.35, 0.22), 0.45, i * 0.9)
			minions.append(minion)
	var food_area := 0.0
	for item in items:
		if item.get("is_boss", false) or item.get("bonus", false): continue
		food_area += item.radius*item.radius
		total_points += base_points(item)
	var finale := 1.0 if int(level.slot) == Campaign.CITIES_PER_REGION-1 else 0.0
	boss_radius = clampf(EAT_RATIO*sqrt(START_RADIUS*START_RADIUS + float(level.share)*GROWTH*food_area), MIN_BOSS, MAX_BOSS + finale*FINALE_BOSS)
	boss.radius = boss_radius

# Both directions on each inner road. Starting spots avoid the signalled crossings.
func make_traffic(rng: RandomNumberGenerator) -> void:
	for road in layout.crossings_z: make_lanes("h", road, layout.half_x, layout.crossings_x, rng)
	for road in layout.crossings_x: make_lanes("v", road, layout.half_z, layout.crossings_z, rng)

func make_lanes(axis: String, road: float, wrap: float, crossings: Array[float], rng: RandomNumberGenerator) -> void:
	for lane in [1, -1]:
		var speed := rng.randf_range(2.2, 3.4)
		var along := -wrap + (4.0 if lane > 0 else 11.5)
		while along < wrap - 2.0:
			var start := along
			if crossings.all(func(c): return absf(start - c) > Traffic.BOX + 1.0):
				var car := add_item("car", Vector3(0, 0.08, 0), 0.82, rng.randi_range(0,3))
				Traffic.make_car(car, axis, road, lane, along, speed, wrap, crossings)
			along += CAR_SPACING

# One signal per road direction at each crossing; its lamp follows the pole, even
# while the pole is being swallowed.
func make_signals() -> void:
	for axis in ["h", "v"]:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lamp_materials[axis] = material
	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.13
	lamp_mesh.height = 0.26
	for cx in layout.crossings_x:
		for cz in layout.crossings_z:
			for axis in ["h", "v"]:
				var corner := Vector3(cx-1.95, 0.16, cz+1.95) if axis == "h" else Vector3(cx+1.95, 0.16, cz-1.95)
				var pole := add_item("signal", corner, 0.45)
				var lamp := MeshInstance3D.new()
				lamp.mesh = lamp_mesh
				lamp.material_override = lamp_materials[axis]
				lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				world.add_child(lamp)
				pole.lamp = lamp

func base_points(item: Dictionary) -> int:
	return maxi(5, int(item.radius*item.radius*65))

func make_batches() -> void:
	var grouped: Dictionary = {}
	for item in items:
		if not grouped.has(item.batch): grouped[item.batch] = []
		item.slot = grouped[item.batch].size()
		grouped[item.batch].append(item)
	for key in grouped:
		var group: Array = grouped[key]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = models.toy(group[0].kind, group[0].variant)
		multi.instance_count = group.size()
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		world.add_child(instance)
		batches[key] = multi
		for item in group: set_item_transform(item)

func set_item_transform(item: Dictionary) -> void:
	var scale_value := 0.0 if item.eaten or item.get("hidden", false) else Traffic.edge_scale(item)
	if item.get("is_boss", false): scale_value *= boss_radius/MODEL_BOSS
	var basis := Basis.from_euler(Vector3(0, item.yaw, item.roll)).scaled(Vector3.ONE*maxf(scale_value, 0.0001))
	set_item_basis(item, basis, scale_value > 0.001)

func set_item_basis(item: Dictionary, basis: Basis, visible := true) -> void:
	var transform := Transform3D(basis, item.position)
	batches[item.batch].set_instance_transform(item.slot, transform)
	if item.has("lamp"):
		item.lamp.transform = transform * LAMP_OFFSET
		item.lamp.visible = visible

# Living city: traffic, pedestrians and minions keep moving outside pause.
func animate_world(dt: float) -> void:
	traffic.update(items, dt)
	for axis in lamp_materials: lamp_materials[axis].albedo_color = traffic.lamp_color(axis)
	for item in items:
		if item.get("move", "") != "" and Traffic.is_active(item): set_item_transform(item)

func make_hole() -> void:
	hole = Node3D.new()
	add_child(hole)
	var shaft := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 0.78
	cylinder.height = 1.8
	cylinder.cap_top = false
	cylinder.radial_segments = 48
	shaft.mesh = cylinder
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("141c31")
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft.material_override = dark
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.add_child(shaft)
	wall = shaft
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.97
	torus.outer_radius = 1.12
	torus.rings = 48
	torus.ring_segments = 8
	ring.mesh = torus
	ring.position.y = 0.19
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hole.add_child(ring)
	rim = ring
	make_saucer()

# The alien mothership hovers above the hole and pulls the city down with a beam.
func make_saucer() -> void:
	saucer = MeshInstance3D.new()
	displayed_craft = -1
	craft_meshes.clear()
	saucer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(saucer)
	beam = MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.25
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 32
	beam.mesh = cone
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = Color(0.55, 1.0, 0.85, 0.16)
	beam.material_override = glow
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)

func reset_round() -> void:
	reset_stats()
	traffic.clock = 0.0
	for item in items:
		item.position = item.origin
		item.yaw = item.origin_yaw
		item.roll = 0.0
		item.fall = -1.0
		item.eaten = false
		if item.get("move", "") == "car":
			item.along = item.start_along
			item.velocity = item.speed
		if item.get("bonus", false):
			item.hidden = true
			item.home = item.origin
	duck.reset(items[boss_index])
	animate_world(0.0)
	for item in items: set_item_transform(item)

# The menu city is already fresh, so starting from the menu keeps traffic flowing.
func reset_stats() -> void:
	radius = float(stats.start_radius)
	target_radius = radius
	hole_position = SPAWN
	remaining = float(level.seconds) + float(stats.bonus_time)
	score = 0
	eaten = 0
	eaten_points = 0
	combo = 0
	combo_time = 0.0
	best_combo = 0
	growth_milestone = 1.0
	floaters.clear()
	pulse = 0.0
	bite_time = 0.0
	tier = 0
	slowmo = 0.0
	last_tick = 0
	reward = 0
	if fx: fx.clear()
	started = false
	paused = false
	camera_target = hole_position
	clear_drag()

func on_play() -> void:
	if mode == "result" and hud.won and campaign.selected < Campaign.level_count()-1:
		load_level(campaign.selected+1)
		persist()
	if mode == "paused":
		paused = false
	elif mode == "menu":
		stats = campaign.stats()
		reset_stats()
	else:
		reset_round()
	playing = true
	mode = "playing"

func go_menu() -> void:
	if mode in ["paused", "result"]: reset_round()
	playing = false
	paused = false
	mode = "menu"
	clear_drag()

func toggle_pause() -> void:
	if mode not in ["playing", "paused"]: return
	paused = not paused
	mode = "paused" if paused else "playing"
	clear_drag()

func clear_drag() -> void:
	dragging = false
	touch_id = -1
	drag_delta = Vector2.ZERO

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if mode == "playing" and not test_mode and not capture_mode: toggle_pause()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(wardrobe) and wardrobe.visible: close_panel()
		elif mode == "playing": toggle_pause()
		elif mode in ["paused", "result"]: go_menu()
		else: get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if wardrobe.visible: close_panel()
		else: toggle_pause()
	if mode != "playing": return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			dragging = true
			drag_origin = event.position
		elif not event.pressed and event.index == touch_id: clear_drag()
	elif event is InputEventScreenDrag and event.index == touch_id:
		update_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_origin = event.position
		if not dragging: clear_drag()
	elif event is InputEventMouseMotion and dragging and touch_id == -1:
		update_drag(event.position)

func update_drag(point: Vector2) -> void:
	drag_delta = point - drag_origin
	if drag_delta.length() > 62:
		drag_origin = point - drag_delta.normalized()*62
		drag_delta = point - drag_origin

func move_direction() -> Vector2:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if direction.length() > 0: return direction.normalized()
	return (drag_delta / 54.0).limit_length() if dragging and drag_delta.length() > 5 else Vector2.ZERO

func _process(delta: float) -> void:
	if not paused: elapsed += delta
	var dt := minf(delta, 0.05)
	# The boss catch plays in slow motion, as in the 2D game.
	if slowmo > 0 and not paused:
		slowmo -= dt
		dt *= SLOWMO_RATE
	if playing and not paused:
		step(dt, move_direction())
	elif mode in ["menu", "result"]:
		animate_world(dt)
		advance_falls(dt)
	fx.set_frozen(paused)
	if not paused: fx.update(delta)
	weather.update(delta, hole_position, paused)
	rim_shader.set_shader_parameter("clock", elapsed)
	if mode != "customize": fx.move_trail(hole_position, playing and not paused and move_direction().length() > 0.05)
	update_view(delta)
	update_hud()

func step(dt: float, input: Vector2) -> void:
	if input.length() > 0.05: started = true
	animate_world(dt)
	if not started: return
	remaining = maxf(0, remaining-dt)
	if remaining <= 10 and remaining > 0 and int(ceil(remaining)) != last_tick:
		last_tick = int(ceil(remaining))
		sfx.play("tick")
	var right := camera.global_basis.x
	var down := camera.global_basis.z
	right.y = 0
	down.y = 0
	var movement := (right.normalized()*input.x + down.normalized()*input.y).limit_length()
	hole_position += movement*(5.8+minf(radius,4.0)*0.45)*float(stats.speed)*dt
	hole_position.x = clampf(hole_position.x, -layout.move_x, layout.move_x)
	hole_position.z = clampf(hole_position.z, -layout.move_z, layout.move_z)
	radius = lerpf(radius, target_radius, 1.0-exp(-dt*8.0))
	bite_time = maxf(0, bite_time-dt*2.5)
	pulse = maxf(0, pulse-dt*2.0)
	combo_time = maxf(0, combo_time-dt)
	if combo_time <= 0: combo = 0
	update_floaters(dt)
	update_boss(dt)
	advance_falls(dt)
	if int(stats.magnet) > 0: pull_small_items(dt)
	for item in items:
		if item.eaten or item.get("hidden", false) or item.fall >= 0: continue
		if item.radius > radius*EAT_RATIO: continue
		# Like 2D: the centre must pass inside the rim, less a bit for bigger objects.
		var reach: float = radius - item.radius*0.4
		if Vector2(item.position.x-hole_position.x,item.position.z-hole_position.z).length() < reach:
			swallow(item)
	# A boss already sinking wins even if the clock runs out during its fall.
	if remaining <= 0 and playing and items[boss_index].fall < 0: finish(false)

# Magnet upgrade: small static props slide toward the hole, as in 2D.
func pull_small_items(dt: float) -> void:
	var magnet := int(stats.magnet)
	var reach := radius*(1.25 + magnet*0.15)
	var pull := (2.4 + magnet*1.2)*(1.0 + radius/4.0)*dt
	for item in items:
		if item.get("move", "") != "" or item.eaten or item.fall >= 0 or item.get("is_boss", false): continue
		if item.radius > radius*EAT_RATIO*0.6: continue
		var offset := Vector3(hole_position.x - item.position.x, 0, hole_position.z - item.position.z)
		var distance := offset.length()
		if distance > reach or distance < 0.01: continue
		item.position += offset/distance*minf(pull, distance)
		set_item_transform(item)

func update_boss(dt: float) -> void:
	if is_landmark(): return
	var boss: Dictionary = items[boss_index]
	var dropped: Dictionary = duck.update(boss, minions, hole_position, radius, dt)
	if not dropped.is_empty():
		var behind: Vector3 = boss.position - duck.direction*boss.radius*0.8
		dropped.hidden = false
		dropped.home = Vector3(behind.x, 0.16, behind.z)
		dropped.position = dropped.home
		set_item_transform(dropped)
	# The helicopter hovers and bobs above the plaza.
	if level.boss == "heli" and Traffic.is_active(boss):
		boss.position.y = BOSS_HOME.y + boss_radius*0.35 + sin(elapsed*2.2)*0.2
	if Traffic.is_active(boss): set_item_transform(boss)

func advance_falls(dt: float) -> void:
	for item in items:
		if not item.eaten and item.fall >= 0: update_fall(item, dt)

# Port of the 2D swallow: the object slides to the centre, tips over the rim,
# squashes, spins and shrinks while sinking into the dark shaft.
func update_fall(item: Dictionary, dt: float) -> void:
	item.fall = minf(1.0, item.fall + dt/item.fall_time)
	var p: float = item.fall
	var e := p*p
	item.position = item.fall_start.lerp(hole_position, p)
	item.position.y = item.fall_start.y - e*(item.radius*2.2+0.8)
	var size := maxf(0.001, 1.0-e*0.94)
	if item.get("is_boss", false): size *= boss_radius/MODEL_BOSS
	var wobble := sin(p*PI)
	var to_centre := Vector3(hole_position.x-item.fall_start.x, 0, hole_position.z-item.fall_start.z)
	var axis := Vector3.UP.cross(to_centre.normalized()) if to_centre.length() > 0.01 else Vector3.RIGHT
	var basis := Basis(axis, minf(1.0, p*2.2)*1.1) * Basis(Vector3.UP, item.yaw + item.spin*e*2.5)
	basis = basis.scaled(Vector3(size*(1+wobble*0.08), size*(1-wobble*0.35), size*(1+wobble*0.08)))
	set_item_basis(item, basis)
	if p >= 1:
		item.eaten = true
		set_item_transform(item)
		if item.get("is_boss", false) and playing: finish(true)

func swallow(item: Dictionary) -> void:
	var is_boss: bool = item.get("is_boss", false)
	item.fall = 0.0
	item.fall_start = item.position
	item.fall_time = BOSS_FALL if is_boss else 0.32 + minf(0.28, item.radius*0.11)
	item.spin = (-1.0 if item.position.x < hole_position.x else 1.0) * (0.7 if is_boss else 1.3)
	eaten += 1
	bite_time = maxf(bite_time, minf(0.65, item.radius/3.0))
	sfx.pop(item.radius)
	fx.puff(item.position, item.radius, radius)
	if is_boss:
		score += BOSS_BONUS
		add_floater(item.position, "+%d" % BOSS_BONUS, true)
		fx.burst(item.position, radius)
		slowmo = BOSS_SLOWMO
		sfx.play("boss")
		return
	combo += 1
	combo_time = COMBO_WINDOW
	best_combo = maxi(best_combo, combo)
	var points := roundi(base_points(item)*combo_multiplier(combo))
	score += points
	if not item.get("bonus", false): eaten_points += base_points(item)
	add_floater(item.position, "+%d" % points, false)
	if item.radius >= BIG_BITE: fx.ripple(hole_position, radius)
	grow(item.radius)

func grow(bite_radius: float) -> void:
	target_radius = minf(MAX_RADIUS, sqrt(target_radius*target_radius + bite_radius*bite_radius*GROWTH))
	var new_tier := int((target_radius-START_RADIUS)/GROWTH_TIER)
	if new_tier > tier:
		tier = new_tier
		pulse = 1.0
		sfx.play("grow")
	if target_radius/START_RADIUS >= growth_milestone*1.6:
		growth_milestone = target_radius/START_RADIUS
		add_floater(hole_position, "LỚN HƠN!", true)
		fx.ripple(hole_position, target_radius, Color("b7a2f1"))

static func combo_multiplier(count: int) -> float:
	return 3.0 if count >= 30 else 2.0 if count >= 16 else 1.5 if count >= 8 else 1.0

# Oldest popups give way when many bites land at once.
func add_floater(at: Vector3, text: String, big: bool) -> void:
	if floaters.size() >= MAX_FLOATERS: floaters.pop_front()
	floaters.append({"position":Vector3(at.x, 1.2, at.z), "text":text, "t":0.0, "big":big})

func update_floaters(dt: float) -> void:
	for floater in floaters: floater.t += dt
	floaters.assign(floaters.filter(func(floater): return floater.t < FLOATER_TIME))

func completion() -> float:
	return float(eaten_points)/float(total_points) if total_points > 0 else 0.0

func stars(won: bool) -> int:
	if not won: return 0
	var pct := completion()
	return 1 + int(pct >= STAR2_PCT) + int(pct >= STAR3_PCT)

func finish(won: bool) -> void:
	playing = false
	mode = "result"
	hud.won = won
	hud.stars = stars(won)
	best = maxi(best,score)
	hud.best = best
	floaters.clear()
	clear_drag()
	sfx.play("win" if won else "lose")
	# Coins pay for upgrades; only original map food counts, not combo points.
	reward = campaign.reward(won, hud.stars, eaten_points)
	campaign.coins += reward
	campaign.complete(hud.stars, score)
	persist()

func update_view(dt: float) -> void:
	# The menu frames the boss slightly low so the title does not cover it.
	var target := Vector3(0, boss_radius*0.7, 0.5) if mode == "menu" else hole_position
	camera_target = camera_target.lerp(target,1.0-exp(-dt*6.0))
	var look := camera_target + fx.shake_offset(elapsed)
	camera.position = look + CAMERA_OFFSET
	camera.look_at(look)
	var menu_zoom := 21.0 + boss_radius*1.7
	var zoom := 12.0 if mode == "customize" else menu_zoom if mode == "menu" else 21.0+radius*1.8
	camera.size = lerpf(camera.size, zoom, 1.0-exp(-dt*3.0))
	# Leave the right half free for the landscape wardrobe controls.
	var preview_offset := 5.8 if mode == "customize" and get_viewport().get_visible_rect().size.x > get_viewport().get_visible_rect().size.y else 0.0
	camera.h_offset = lerpf(camera.h_offset, preview_offset, 1.0-exp(-dt*6.0))
	# Keep shadows covering the view as the camera zooms out for big holes.
	sunlight.directional_shadow_max_distance = 16.0 + camera.size
	hole.position = hole_position
	hole.scale = Vector3(radius,1,radius)
	# The shaft deepens as the hole grows so big objects still sink out of sight.
	var depth := 1.8*maxf(1.0, radius*0.9)
	wall.scale = Vector3(1, depth/1.8, 1)
	wall.position.y = 0.1-depth/2
	# The rim pulses on each bite and more strongly on each growth step.
	rim.scale = Vector3.ONE*(1.0+pulse*0.08+bite_time*0.12)
	var hover := (1.8 if mode == "customize" else 3.4 + radius*0.9) + sin(elapsed*2.0)*0.15
	saucer.visible = mode != "customize" or wardrobe.tab == "crafts"
	beam.visible = saucer.visible
	saucer.position = hole_position + Vector3(0, hover, 0)
	saucer.scale = Vector3.ONE*(0.55 + radius*0.28)
	saucer.rotation.y = elapsed*0.8 if campaign.craft < 2 else 0.5+sin(elapsed*1.3)*0.16
	beam.position = hole_position + Vector3(0, hover*0.5, 0)
	beam.scale = Vector3(radius*(0.9 + bite_time*0.3), hover, radius*(0.9 + bite_time*0.3))
	for material in [ground_material, models.material]:
		material.set_shader_parameter("hole_center",Vector2(hole_position.x,hole_position.z))
		material.set_shader_parameter("hole_radius",radius)

func update_hud() -> void:
	hud.mode = mode
	hud.score = score
	hud.seconds = remaining
	hud.eaten = eaten
	hud.waiting = not started
	hud.growth = clampf((radius-float(stats.start_radius))/(boss_radius/EAT_RATIO-float(stats.start_radius)),0,1)
	hud.stick_active = dragging
	hud.stick_origin = drag_origin
	hud.stick_delta = drag_delta
	var target_name: String = Campaign.boss_name(level.boss)
	var verb := "Nuốt " if is_landmark() else "Hạ "
	hud.note = "Đủ lớn! " + verb + target_name.to_lower() + "!" if radius*EAT_RATIO >= boss_radius else ""
	hud.level_title = level.title
	hud.city = level.city
	hud.region_title = "%s · THÀNH PHỐ %d/%d" % [Campaign.REGIONS[level.region].name, int(level.slot)+1, Campaign.CITIES_PER_REGION]
	hud.weather_title = Campaign.WEATHER_NAMES[level.weather]
	hud.map_title = "%d×%d" % [level.cols, level.rows]
	hud.boss_title = target_name
	hud.landmark = is_landmark()
	hud.coins = campaign.coins
	hud.reward = reward
	hud.level_count = Campaign.level_count()
	hud.playtest = campaign.unlock_all_for_testing
	hud.has_next = campaign.selected < Campaign.level_count()-1
	hud.combo = combo
	hud.multiplier = combo_multiplier(combo)
	hud.best_combo = best_combo
	hud.completion = completion()
	hud.flash = fx.flash
	hud.floaters = floaters.map(func(floater): return {"screen":camera.unproject_position(floater.position),
		"text":floater.text, "t":floater.t/FLOATER_TIME, "big":floater.big})
	hud.sync()
