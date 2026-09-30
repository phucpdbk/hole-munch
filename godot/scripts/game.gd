extends Node3D

# Alien invasion: the player is a black hole dropped by a saucer. Swallow a city,
# grow, then swallow its landmark or defeat Earth's defence unit to conquer it.
const Models = preload("res://scripts/models.gd")
const Hud = preload("res://scripts/hud.gd")
const Traffic = preload("res://scripts/traffic.gd")
const DuckBoss = preload("res://scripts/duck_boss.gd")
const Mechanics = preload("res://scripts/mechanics.gd")
const HoleStyle = preload("res://scripts/hole_style.gd")
const Smoke = preload("res://scripts/smoke.gd")
const Fx = preload("res://scripts/fx.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Campaign = preload("res://scripts/campaign.gd")
const Weather = preload("res://scripts/weather.gd")
const Wardrobe = preload("res://scripts/wardrobe.gd")
const MapLayout = preload("res://scripts/map_layout.gd")
const Capture = preload("res://scripts/capture.gd")
const CityBlocks = preload("res://scripts/city_blocks.gd")
const CityProfiles = preload("res://scripts/city_profiles.gd")
const Challenges = preload("res://scripts/challenges.gd")
const Rival = preload("res://scripts/rival.gd")
const I18n = preload("res://scripts/i18n.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Intro = preload("res://scripts/intro.gd")
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
# Combo milestones buy time: [bites, seconds]. Past the last one, every
# COMBO_REPEAT more bites adds COMBO_REPEAT_SECONDS.
const COMBO_TIME = [[8, 2.0], [16, 3.0], [30, 5.0]]
const COMBO_REPEAT := 15
const COMBO_REPEAT_SECONDS := 3.0
const HIT_SECONDS := 2.0
const HIT_SHRINK := 0.94
# Landmark counter-attack starts once the hole is this close to fitting the boss.
const COUNTER_FROM := 4
const COUNTER_AT := 0.8
const RIVAL_BONUS := 300
# Rival pace per continent, tuned with `--rival-bench` so an unopposed rival
# takes the landmark around the time the clock runs out.
const RIVAL_SPEED := 0.74
const RIVAL_SPEED_STEP := 0.06
const RIVAL_CHEW_STEP := 0.16
const RIVAL_CHEW_MIN := 0.4
const ENDLESS_BITE_SECONDS := 0.2
const ENDLESS_BITE_CAP := 0.6
const BOSS_BONUS := 500
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
var city_blocks = CityBlocks.new()
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
# Seconds granted by combo milestones this round (the par route subtracts them).
var bonus_seconds := 0.0
var hole_velocity := Vector3.ZERO
# Run kind: "campaign", "daily" or "endless". Special runs remember the
# campaign city to return to.
var run_kind := "campaign"
var campaign_level := 0
var endless_stage := 0
var endless_rng := RandomNumberGenerator.new()
var endless_advance := false
var goal_list: Array = []
var goal_mask := 0
var defenders_eaten := 0
var rival_eaten := false
var counter_started := false
# The landmark fell; the round still runs until the clock ends or the map is bare.
var boss_down := false
# Pylons, pickups, hunger, bombs and weather handling (scripts/mechanics.gd).
var mechanics
var intro: Control
var hole_style
var shaft_shader: ShaderMaterial
# Coins per second left when the whole map is cleared early.
const CLEAR_COINS := 2
var lose_reason := ""
var record_note := ""
var rival: Node3D
var eaten_points := 0
var total_points := 0
var growth_milestone := 1.0
var floaters: Array[Dictionary] = []
var rim: MeshInstance3D
var wall: MeshInstance3D
var defense = preload("res://scripts/defense.gd").new()
var defense_visual = preload("res://scripts/defense_visual.gd").new()
var craft_meshes := {}
var displayed_craft := -1
var saucer: MeshInstance3D
var beam: MeshInstance3D
var rival_saucer: MeshInstance3D
var rival_beam: MeshInstance3D
var fx: Fx
var sfx: Sfx
var lamp_materials := {}
var pulse := 0.0
var tier := 0
var slowmo := 0.0
var last_tick := 0
var reward := 0
var items: Array[Dictionary] = []
var movers: Array = []
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
	UiStyle.install_theme()
	make_environment()
	if not test_mode and not capture_mode and FileAccess.file_exists("user://prototype_save.json"):
		campaign.restore(JSON.parse_string(FileAccess.get_file_as_string("user://prototype_save.json")))
	setup_language(args)
	best = campaign.best
	weather = Weather.new()
	add_child(weather)
	make_hole()
	rival = Rival.new()
	add_child(rival)
	mechanics = Mechanics.new()
	add_child(mechanics)
	add_child(defense_visual)
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
	hud.daily_requested.connect(start_daily)
	hud.endless_requested.connect(start_endless)
	hud.styles_requested.connect(func(): open_panel("crafts"))
	hud.help_requested.connect(show_story)
	hud.language_requested.connect(func(): open_panel("language"))
	wardrobe = Wardrobe.new()
	wardrobe.game = self
	layer.add_child(wardrobe)
	intro = Intro.new()
	layer.add_child(intro)
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
	elif "story" not in campaign.seen:
		show_story.call_deferred()

# Saved choice, else the phone's language; captures can force one with --lang=xx.
func setup_language(args: PackedStringArray) -> void:
	var forced := ""
	for arg in args:
		if arg.begins_with("--lang="): forced = arg.trim_prefix("--lang=")
	if forced != "": I18n.set_lang(forced)
	elif test_mode or capture_mode: I18n.set_lang("vi")
	else: I18n.set_lang(campaign.lang if campaign.lang != "" else I18n.system_lang())
	if campaign.lang == "" and not test_mode and not capture_mode: campaign.lang = I18n.lang

func set_language(code: String) -> void:
	I18n.set_lang(code)
	campaign.lang = I18n.lang
	persist()

# --- Intro and first-time tips (scripts/intro.gd) --------------------------------
func show_story() -> void:
	if mode != "menu" or intro.visible: return
	clear_drag()
	intro.open(Intro.story_pages(), mark_seen.bind(["story"]), true)

func mark_seen(ids: Array) -> void:
	for id in ids:
		if id not in campaign.seen: campaign.seen.append(id)
	persist()

# Cards for mechanics this city is the first to use. They are marked seen as
# they open, so the replayed on_play() starts the round.
func offer_tips() -> bool:
	if test_mode or capture_mode or run_kind != "campaign": return false
	var ids := Intro.pending_tips(level, campaign.seen)
	if ids.is_empty(): return false
	mark_seen(ids)
	intro.open(ids.map(func(id): return Intro.tip_page(id)), on_play)
	return true

func is_landmark() -> bool:
	return Campaign.LANDMARKS.has(level.boss)

func load_level(index: int) -> void:
	campaign.selected = clampi(index, 0, Campaign.level_count()-1)
	level = Campaign.level_info(campaign.selected)
	if run_kind == "daily": level.rival = true
	goal_list = Challenges.goals(level)
	layout = MapLayout.make(level.cols, level.rows)
	layout.vary_districts(campaign.selected)
	models.snow_material.set_shader_parameter("snow_amount",0.95 if level.weather == "snow" else 0.0)
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
	models.city_profile = CityProfiles.profile(level.boss)
	city_blocks.plan(layout, models.city_profile, has_farms(), 4819 + campaign.selected*137 + 1)
	total_points = 0
	make_ground()
	make_city()
	make_batches()
	weather.configure(level.weather, sky_environment, sunlight, Color(palette[5]))
	reset_round()

func persist() -> void:
	campaign.best = best
	if test_mode or capture_mode: return
	# A daily or endless city must not replace the saved campaign selection.
	var current: int = campaign.selected
	if run_kind != "campaign": campaign.selected = campaign_level
	campaign.save_progress()
	campaign.selected = current

func apply_style() -> void:
	if not rim_shader:
		rim_shader = ShaderMaterial.new()
		rim_shader.shader = load("res://shaders/rim.gdshader")
		rim.material_override = rim_shader
	var style: Array = Campaign.SKINS[campaign.skin]
	rim_shader.set_shader_parameter("style", campaign.skin)
	rim_shader.set_shader_parameter("color_a", Color(style[1]))
	rim_shader.set_shader_parameter("color_b", Color(style[2]))
	shaft_shader.set_shader_parameter("glow", Color(style[1]))
	if hole_style.style != campaign.skin: hole_style.build(models, campaign.skin)
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
			parts.append(models.piece("box", Vector3(x, 0.075, z), Vector3(layout.block_size(x,z).x, 0.1, layout.block_size(x,z).y), Color(palette[2])))
			parts.append(models.piece("box", Vector3(x, 0.13, z), Vector3(layout.block_size(x,z).x-2.1, 0.06, layout.block_size(x,z).y-2.1), inner_ground(x, z)))
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

# Grass courtyards, a paved downtown and a lighter landmark plaza.
func inner_ground(x: float, z: float) -> Color:
	if level.weather == "snow": return Color("dfe9ed")
	match city_blocks.district(x, z):
		"plaza": return Color(palette[3]).lightened(0.15)
		"downtown": return Color(palette[2]).darkened(0.06)
	return Color(palette[3])

# Farmland on the outskirts of big maps in the more rural continents.
func has_farms() -> bool:
	return level.style in ["europe", "namerica", "oceania"] and layout.cols >= 5

func add_item(kind: String, pos: Vector3, size: float, variant: int = 0, yaw: float = 0.0) -> Dictionary:
	var item := {"kind":kind, "position":pos, "origin":pos, "radius":size, "variant":variant,
		"yaw":yaw, "origin_yaw":yaw, "roll":0.0, "fall":-1.0, "eaten":false, "batch":kind+str(variant), "slot":0}
	items.append(item)
	return item

func make_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4819 + campaign.selected*137
	for x in layout.blocks_x:
		for z in layout.blocks_z:
			var block: Vector2 = layout.block_size(x,z)
			match city_blocks.district(x, z):
				"plaza", "farm":
					if x != 0 or z != 0: make_farm_block(x, z, rng)
					for dx in [-block.x/2+1.7, block.x/2-1.7]:
						for dz in [-block.y/2+1.7, block.y/2-1.7]:
							add_item("tree", Vector3(x+dx, 0.16, z+dz), 0.68, int(dx > 0) ^ int(dz > 0))
				_: city_blocks.fill(self, rng, x, z, block)
			for dx in [-3.2, 3.2]:
				add_item("bench", Vector3(x+dx, 0.16, z+block.y/2-0.8), 0.55)
			for i in range(6):
				var walker := add_item("person", Vector3(x-5+i*2, 0.16, z+block.y/2-0.35), 0.22, i%4)
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
	# Small squads guard the central plaza; eat them to silence their attacks.
	for i in Challenges.defender_count(campaign.selected):
		var road_x: float = layout.crossings_x[0] if i%2 == 0 else layout.crossings_x[-1]
		var road_z: float = layout.crossings_z[-1] if i < 3 else layout.crossings_z[0]
		var tank := i%3 == 0
		var guard := add_item("patrol_tank" if tank else "soldier",Vector3(road_x,0.16,road_z+i*0.5),1.5 if tank else 0.36)
		guard.defender = true
	make_reinforcements()
	make_boss()
	mechanics.setup(self, is_landmark(), 4819 + campaign.selected*137 + 7)

# Hidden squad that rolls in from the map edge when the landmark counter-attacks.
# Marked as bonus so it never changes the boss size or completion.
func make_reinforcements() -> void:
	if campaign.selected < COUNTER_FROM: return
	for i in 3:
		var road_x: float = layout.crossings_x[i%layout.crossings_x.size()]
		var edge: float = (layout.move_z-1.0)*(1.0 if i%2 == 0 else -1.0)
		var tank := i == 0
		var unit := add_item("patrol_tank" if tank else "soldier", Vector3(road_x,0.16,edge), 1.5 if tank else 0.36)
		unit.defender = true
		unit.bonus = true
		unit.reinforcement = true
		unit.hidden = true

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
	# Only cars, walkers and minions animate; the static street fronts are skipped.
	movers = items.filter(func(item): return item.get("move", "") != "")
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
	traffic.update(movers, dt)
	for axis in lamp_materials: lamp_materials[axis].albedo_color = traffic.lamp_color(axis)
	for item in movers:
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
	shaft_shader = ShaderMaterial.new()
	shaft_shader.shader = load("res://shaders/hole_shaft.gdshader")
	shaft.material_override = shaft_shader
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
	hole_style = HoleStyle.new()
	add_child(hole_style)
	make_saucer()

# The alien mothership hovers above the hole and pulls the city down with a beam.
func make_saucer() -> void:
	saucer = MeshInstance3D.new()
	displayed_craft = -1
	craft_meshes.clear()
	saucer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(saucer)
	beam = make_beam(Color(0.55, 1.0, 0.85, 0.16))
	# The rival hole has its own hostile ship (sibling nodes: the rival node is squashed).
	rival_saucer = MeshInstance3D.new()
	rival_saucer.mesh = preload("res://scripts/fleet.gd").new().rival(models)
	rival_saucer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rival_saucer)
	rival_beam = make_beam(Color(1.0, 0.35, 0.3, 0.16))

func make_beam(color: Color) -> MeshInstance3D:
	var ray := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.25
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 32
	ray.mesh = cone
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.albedo_color = color
	ray.material_override = glow
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ray)
	return ray

func reset_round() -> void:
	reset_stats()
	defense.roads_x = layout.crossings_x
	defense.roads_z = layout.crossings_z
	traffic.clock = 0.0
	for item in items:
		item.position = item.origin
		item.yaw = item.origin_yaw
		item.roll = 0.0
		item.fall = -1.0
		item.eaten = false
		item.erase("sink")
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
	bonus_seconds = 0.0
	hole_velocity = Vector3.ZERO
	growth_milestone = 1.0
	floaters.clear()
	pulse = 0.0
	bite_time = 0.0
	tier = 0
	slowmo = 0.0
	last_tick = 0
	reward = 0
	goal_mask = 0
	defenders_eaten = 0
	rival_eaten = false
	counter_started = false
	boss_down = false
	lose_reason = ""
	record_note = ""
	reset_hazards()
	mechanics.reset(level.weather, 991 + campaign.selected*31)
	if fx: fx.clear()
	started = false
	paused = false
	camera_target = hole_position
	clear_drag()

# Defence gets one continent harder in the daily challenge; the rival starts in
# the far corner, a little faster on later continents.
func reset_hazards() -> void:
	defense.reset(items, not is_landmark(), campaign.selected, 1 if run_kind == "daily" else 0)
	if not is_instance_valid(rival): return
	var region := int(level.region) + (1 if run_kind == "daily" else 0)
	var speed := RIVAL_SPEED + region*RIVAL_SPEED_STEP
	var chew := maxf(RIVAL_CHEW_MIN, 1.0 - region*RIVAL_CHEW_STEP)
	var corner := Vector3(layout.move_x*0.8, 0, -layout.move_z*0.8)
	rival.reset(bool(level.get("rival", false)), corner, START_RADIUS, speed, Vector2(layout.move_x, layout.move_z), chew)

func has_next_city() -> bool:
	return run_kind == "campaign" and campaign.can_select(campaign.selected+1)

func on_play() -> void:
	if intro.visible: return
	if mode == "result" and run_kind == "daily":
		start_daily()
		return
	if mode == "result" and run_kind == "endless":
		start_endless()
		return
	if mode == "result" and hud.won and has_next_city():
		load_level(campaign.selected+1)
		persist()
		# The next city is fresh, like a menu city, so tips can replay on_play().
		mode = "menu"
		stats = campaign.stats()
	if mode in ["menu", "result"] and offer_tips(): return
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
	if run_kind != "campaign":
		run_kind = "campaign"
		load_level(campaign_level)
	elif mode in ["paused", "result"]: reset_round()
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
	if endless_advance and playing and not paused and slowmo <= 0: advance_endless()
	if playing and not paused:
		step(dt, move_direction())
	elif mode in ["menu", "result"]:
		animate_world(dt)
		advance_falls(dt)
	fx.set_frozen(paused)
	if not paused: fx.update(delta)
	weather.update(delta, hole_position, paused)
	rim_shader.set_shader_parameter("clock", elapsed)
	shaft_shader.set_shader_parameter("clock", elapsed)
	if mode != "customize": fx.move_trail(hole_position, playing and not paused and move_direction().length() > 0.05, radius)
	update_view(delta)
	update_hud()

func step(dt: float, input: Vector2) -> void:
	if input.length() > 0.05: started = true
	animate_world(dt)
	if not started: return
	if defense.update(dt,hole_position,campaign.selected,hole_velocity): take_hit()
	remaining = maxf(0, remaining-dt)
	if defense.fired: sfx.play("shot")
	if remaining <= 10 and remaining > 0 and int(ceil(remaining)) != last_tick:
		last_tick = int(ceil(remaining))
		sfx.play("tick")
	var right := camera.global_basis.x
	var down := camera.global_basis.z
	right.y = 0
	down.y = 0
	var movement := (right.normalized()*input.x + down.normalized()*input.y).limit_length()
	var wanted: Vector3 = movement*(5.8+minf(radius,4.0)*0.45)*float(stats.speed)*defense.speed_multiplier()*mechanics.speed_multiplier()
	hole_velocity = mechanics.steer(wanted, dt, elapsed)
	hole_position += hole_velocity*dt
	hole_position.x = clampf(hole_position.x, -layout.move_x, layout.move_x)
	hole_position.z = clampf(hole_position.z, -layout.move_z, layout.move_z)
	radius = lerpf(radius, target_radius, 1.0-exp(-dt*8.0))
	bite_time = maxf(0, bite_time-dt*2.5)
	pulse = maxf(0, pulse-dt*2.0)
	combo_time = maxf(0, combo_time-dt)
	if combo_time <= 0: combo = 0
	update_floaters(dt)
	update_boss(dt)
	mechanics.update(self, dt)
	for unit in defense.units:
		if Traffic.is_active(unit.item): set_item_transform(unit.item)
	advance_falls(dt)
	if magnet_level() > 0: pull_small_items(dt)
	for item in items:
		if item.eaten or item.get("hidden", false) or item.fall >= 0: continue
		if item.radius > radius*EAT_RATIO or item.get("shielded", false): continue
		# Like 2D: the centre must pass inside the rim, less a bit for bigger objects.
		var reach: float = radius - item.radius*0.4
		if Vector2(item.position.x-hole_position.x,item.position.z-hole_position.z).length() < reach:
			swallow(item)
	update_counter()
	update_rival(dt)
	if not playing: return
	if boss_down and map_cleared(): finish(true)
	# A boss already sinking wins even if the clock runs out during its fall.
	elif remaining <= 0 and (boss_down or items[boss_index].fall < 0): finish(boss_down)

# Every piece of original map food is gone (bonus minions and reinforcements aside).
func map_cleared() -> bool:
	return not items.any(func(item): return not item.eaten and not item.get("bonus", false) and not item.get("optional", false))

func magnet_level() -> int:
	return int(stats.magnet) + mechanics.magnet_bonus()

# Near the end of a landmark city the landmark fights back: volleys of blasts
# around the hole and a reinforcement squad from the map edge.
func update_counter() -> void:
	if counter_started or campaign.selected < COUNTER_FROM or not is_landmark(): return
	if target_radius*EAT_RATIO < boss_radius*COUNTER_AT: return
	counter_started = true
	var boss: Dictionary = items[boss_index]
	boss.landmark = true
	defense.add_volley(boss, 3 + int(level.region)/2)
	for item in items:
		if item.get("reinforcement", false):
			item.hidden = false
			set_item_transform(item)
			defense.wake(item, 1.5)
	add_floater(boss.position, I18n.t("counter", Campaign.boss_name(level.boss).to_upper()), true)
	fx.ripple(boss.position, boss_radius, Color("ff7866"))
	sfx.play("shot")

func update_rival(dt: float) -> void:
	if not rival.active: return
	for item in rival.update(dt, items, items[boss_index], hole_position, radius):
		start_fall(item, rival.position)
		item.sink = "rival"
		rival.grow(item.radius)
	if rival.swallowed_by(hole_position, radius):
		eat_rival()
	elif rival.swallows(hole_position, radius):
		lose_reason = "eaten"
		finish(false)

func eat_rival() -> void:
	rival_eaten = true
	rival.active = false
	rival.visible = false
	score += RIVAL_BONUS
	add_floater(rival.position, I18n.t("ate_rival", RIVAL_BONUS), true)
	fx.burst(rival.position, radius)
	sfx.play("boss")
	grow(rival.radius)

# Magnet upgrade: small static props slide toward the hole, as in 2D.
func pull_small_items(dt: float) -> void:
	var magnet := magnet_level()
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
	if defense.is_aiming(boss): return
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
	var into_rival: bool = item.get("sink", "") == "rival"
	var centre: Vector3 = rival.position if into_rival else hole_position
	item.position = item.fall_start.lerp(centre, p)
	item.position.y = item.fall_start.y - e*(item.radius*2.2+0.8)
	var size := maxf(0.001, 1.0-e*0.94)
	if item.get("is_boss", false): size *= boss_radius/MODEL_BOSS
	var wobble := sin(p*PI)
	var to_centre := Vector3(centre.x-item.fall_start.x, 0, centre.z-item.fall_start.z)
	var axis := Vector3.UP.cross(to_centre.normalized()) if to_centre.length() > 0.01 else Vector3.RIGHT
	var basis := Basis(axis, minf(1.0, p*2.2)*1.1) * Basis(Vector3.UP, item.yaw + item.spin*e*2.5)
	basis = basis.scaled(Vector3(size*(1+wobble*0.08), size*(1-wobble*0.35), size*(1+wobble*0.08)))
	set_item_basis(item, basis)
	if p >= 1:
		item.eaten = true
		set_item_transform(item)
		if not item.get("is_boss", false) or not playing: return
		if into_rival:
			lose_reason = "rival"
			finish(false)
		elif run_kind == "endless": endless_advance = true
		else:
			boss_down = true
			add_floater(hole_position, I18n.t("clear_to_end"), true)

func start_fall(item: Dictionary, centre: Vector3) -> void:
	var is_boss: bool = item.get("is_boss", false)
	item.fall = 0.0
	item.fall_start = item.position
	item.fall_time = BOSS_FALL if is_boss else 0.32 + minf(0.28, item.radius*0.11)
	item.spin = (-1.0 if item.position.x < centre.x else 1.0) * (0.7 if is_boss else 1.3)

func swallow(item: Dictionary) -> void:
	var is_boss: bool = item.get("is_boss", false)
	start_fall(item, hole_position)
	item.sink = "player"
	if item.get("defender", false): defenders_eaten += 1
	if run_kind == "endless" and not is_boss:
		var extra := minf(ENDLESS_BITE_CAP, item.radius*ENDLESS_BITE_SECONDS)
		remaining += extra
		bonus_seconds += extra
	eaten += 1
	bite_time = maxf(bite_time, minf(0.65, item.radius/3.0))
	sfx.pop(item.radius)
	mechanics.fed()
	if item.get("bomb", false):
		mechanics.explode(self, item)
		return
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
	var extra := combo_seconds(combo)
	if extra > 0:
		remaining += extra
		bonus_seconds += extra
		add_floater(hole_position, I18n.t("combo_time", [combo, int(extra)]), true)
		sfx.play("grow")
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
		add_floater(hole_position, I18n.t("bigger"), true)
		fx.ripple(hole_position, target_radius, Color("b7a2f1"))

static func combo_seconds(count: int) -> float:
	for milestone in COMBO_TIME:
		if count == milestone[0]: return milestone[1]
	var last: int = COMBO_TIME[-1][0]
	if count > last and (count-last)%COMBO_REPEAT == 0: return COMBO_REPEAT_SECONDS
	return 0.0

# A hit costs time, breaks the combo and shrinks the hole a little.
func take_hit() -> void:
	remaining = maxf(0,remaining-HIT_SECONDS)
	combo = 0
	combo_time = 0.0
	target_radius = maxf(float(stats.start_radius), target_radius*HIT_SHRINK)
	add_floater(hole_position,I18n.t("hit"),true)
	fx.puff(hole_position,0.8,1.0)
	sfx.play("tick")

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

func finish(won: bool) -> void:
	playing = false
	mode = "result"
	hud.won = won
	best = maxi(best,score)
	hud.best = best
	floaters.clear()
	clear_drag()
	sfx.play("win" if won else "lose")
	goal_mask = Challenges.evaluate(goal_list, run_summary(won))
	hud.stars = Challenges.count(goal_mask)
	# Coins pay for upgrades; only original map food counts, not combo points.
	match run_kind:
		"daily":
			reward = campaign.reward(won, hud.stars, eaten_points, best_combo)
			var first_win: bool = campaign.record_daily(Campaign.today(), score, won)
			if first_win: reward = roundi(reward*Campaign.DAILY_COIN_BONUS)
			record_note = I18n.t("daily_first") if first_win else I18n.t("daily_best", int(campaign.daily.best))
		"endless":
			reward = campaign.endless_reward(score, endless_stage)
			record_note = (I18n.t("new_record") if campaign.record_endless(score, endless_stage) else I18n.t("record", int(campaign.endless.best))) + I18n.t("cities_taken", endless_stage)
		_:
			reward = campaign.reward(won, hud.stars, eaten_points, best_combo)
			campaign.complete_goals(goal_mask, score)
	# Clearing the whole map early pays for every second left on the clock.
	if won and run_kind != "endless" and map_cleared():
		var extra := int(remaining)*CLEAR_COINS
		reward += extra
		if record_note == "": record_note = I18n.t("early_clear", extra)
	campaign.coins += reward
	persist()

func run_summary(won: bool) -> Dictionary:
	return {"won":won, "completion":completion(), "best_combo":best_combo, "remaining":remaining,
		"hits":defense.hits, "defenders_eaten":defenders_eaten, "rival_eaten":rival_eaten}

# --- Daily challenge and endless survival ----------------------------------------
func begin_special(kind: String, index: int) -> void:
	if run_kind == "campaign": campaign_level = campaign.selected
	run_kind = kind
	load_level(index)
	stats = campaign.stats()
	reset_round()
	playing = true
	mode = "playing"

func start_daily() -> void:
	if mode not in ["menu", "result"]: return
	begin_special("daily", Campaign.daily_level(Campaign.today()))

func start_endless() -> void:
	if mode not in ["menu", "result"]: return
	endless_stage = 0
	endless_rng.randomize()
	begin_special("endless", Campaign.endless_level(0, endless_rng))
	remaining = Campaign.ENDLESS_START_SECONDS

# The landmark fell: carry score and time into a harder random city.
func advance_endless() -> void:
	endless_advance = false
	endless_stage += 1
	var carried := {"score":score, "remaining":remaining + Campaign.ENDLESS_STAGE_SECONDS,
		"eaten":eaten, "best_combo":best_combo}
	load_level(Campaign.endless_level(endless_stage, endless_rng))
	score = carried.score
	remaining = carried.remaining
	eaten = carried.eaten
	best_combo = carried.best_combo
	playing = true
	mode = "playing"
	add_floater(hole_position, I18n.t("endless_next", [endless_stage+1, int(Campaign.ENDLESS_STAGE_SECONDS)]), true)

func update_view(dt: float) -> void:
	# The menu frames the boss slightly low so the title does not cover it.
	var target := Vector3(0, boss_radius*0.7, 0.5) if mode == "menu" else hole_position
	camera_target = camera_target.lerp(target,1.0-exp(-dt*6.0))
	var look := camera_target + fx.shake_offset(elapsed)
	camera.position = look + CAMERA_OFFSET
	camera.look_at(look)
	var menu_zoom := 21.0 + boss_radius*1.7
	var zoom: float = 12.0 if mode == "customize" else menu_zoom if mode == "menu" else (21.0+radius*1.8)*mechanics.view_scale()
	camera.size = lerpf(camera.size, zoom, 1.0-exp(-dt*3.0))
	# Leave the right half free for the landscape wardrobe controls.
	var preview_offset := 5.8 if mode == "customize" and get_viewport().get_visible_rect().size.x > get_viewport().get_visible_rect().size.y else 0.0
	camera.h_offset = lerpf(camera.h_offset, preview_offset, 1.0-exp(-dt*6.0))
	# Keep shadows covering the view as the camera zooms out for big holes.
	sunlight.directional_shadow_max_distance = 16.0 + camera.size
	hole.position = hole_position
	hole.scale = Vector3(radius,1,radius)
	hole_style.sync(hole_position, radius, elapsed, hole_velocity, dt)
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
	saucer.rotation.y = elapsed*0.8 if campaign.craft < 5 else 0.5+sin(elapsed*1.3)*0.16
	beam.position = hole_position + Vector3(0, hover*0.5, 0)
	beam.scale = Vector3(radius*(0.9 + bite_time*0.3), hover, radius*(0.9 + bite_time*0.3))
	var rival_shown: bool = rival.active and mode in ["playing", "paused", "result"]
	rival.visible = rival_shown
	rival_saucer.visible = rival_shown
	rival_beam.visible = rival_shown
	if rival_shown:
		rival.sync_view(elapsed)
		# Same hover rule as the player's ship, half a beat out of phase, spinning the other way.
		var rival_hover: float = 3.4 + rival.radius*0.9 + sin(elapsed*2.0 + PI)*0.15
		rival_saucer.position = rival.position + Vector3(0, rival_hover, 0)
		rival_saucer.scale = Vector3.ONE*(0.55 + rival.radius*0.28)
		rival_saucer.rotation.y = -elapsed*1.1
		rival_beam.position = rival.position + Vector3(0, rival_hover*0.5, 0)
		rival_beam.scale = Vector3(rival.radius*0.9, rival_hover, rival.radius*0.9)
	for material in [ground_material, models.material, models.snow_material, models.landmark_material]:
		material.set_shader_parameter("hole_center",Vector2(hole_position.x,hole_position.z))
		material.set_shader_parameter("hole_radius",radius)
		material.set_shader_parameter("rival_center",Vector2(rival.position.x,rival.position.z))
		material.set_shader_parameter("rival_radius",rival.radius if rival_shown else 0.0)

func update_hud() -> void:
	defense_visual.update(defense,mode in ["playing","paused"])
	hud.defense_status = I18n.t("def_hit") if defense.slow > 0 else I18n.t("def_dodge") if not defense.strikes.is_empty() else I18n.t("def_count", defense.active_count())
	hud.strike_shapes.clear()
	if mode == "playing":
		for strike in defense.strikes:
			var points := PackedVector2Array()
			for i in 40:
				var a := i*TAU/40
				points.append(camera.unproject_position(strike.target+Vector3(cos(a)*strike.radius,0.12,sin(a)*strike.radius)))
			hud.strike_shapes.append({"points":points,"progress":1.0-strike.time/strike.duration})
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
	mechanics.sync_shield(self)
	if not started and mechanics.weather_note() != "": hud.note = mechanics.weather_note()
	elif mechanics.hungry: hud.note = I18n.t("hungry")
	elif boss_down: hud.note = I18n.t("boss_down", [target_name, roundi((1.0-completion())*100)])
	elif mechanics.shield_up() and radius*EAT_RATIO >= boss_radius: hud.note = I18n.t("break_pylons", mechanics.pylons.filter(func(p): return not p.eaten).size())
	else: hud.note = I18n.t("big_enough", target_name) if radius*EAT_RATIO >= boss_radius else ""
	var city_label: String = Campaign.city_name(level.boss, Campaign.REGIONS[level.region].cities[level.slot][0])
	hud.level_title = "%s · %s" % [city_label, target_name]
	hud.city = city_label
	hud.region_title = I18n.t("region_city", [Campaign.region_name(level.region), int(level.slot)+1, Campaign.CITIES_PER_REGION])
	hud.weather_title = Campaign.weather_name(level.weather)
	hud.weather_kind = level.weather
	hud.map_title = "%d×%d" % [level.cols, level.rows]
	hud.boss_title = target_name
	hud.landmark = is_landmark()
	hud.coins = campaign.coins
	hud.reward = reward
	hud.level_count = Campaign.level_count()
	hud.playtest = campaign.unlock_all_for_testing
	hud.has_next = has_next_city()
	hud.last_city = campaign.selected >= Campaign.level_count()-1
	hud.run_kind = run_kind
	hud.stage = endless_stage
	hud.lose_reason = lose_reason
	hud.record_note = record_note
	hud.goal_labels = goal_list.map(func(goal): return Challenges.label(goal))
	hud.goal_mask = goal_mask if mode == "result" else campaign.goals[campaign.selected] if run_kind == "campaign" else 0
	hud.rival_growth = clampf(rival.radius*EAT_RATIO/boss_radius, 0, 1) if rival.active else -1.0
	hud.daily_won = campaign.daily_record(Campaign.today()).won
	hud.endless_best = int(campaign.endless.best)
	var next_region: int = (campaign.selected+1)/Campaign.CITIES_PER_REGION
	hud.gate_note = "" if next_region >= Campaign.REGIONS.size() or campaign.region_open(next_region) else I18n.t("gate", [Campaign.stars_needed(next_region), Campaign.region_name(next_region), campaign.total_stars()])
	hud.combo = combo
	hud.multiplier = combo_multiplier(combo)
	hud.best_combo = best_combo
	hud.completion = completion()
	hud.flash = fx.flash
	hud.floaters = floaters.map(func(floater): return {"screen":camera.unproject_position(floater.position),
		"text":floater.text, "t":floater.t/FLOATER_TIME, "big":floater.big})
	hud.sync()
