extends Control

# Invasion journey: one 3D continent per page, rendered in its own world. Land is
# extruded from Natural Earth outlines (world_map_data.gd); every campaign stop
# stands on a plinth with its 3D landmark, joined by a dotted route, and the
# player's craft hovers over the selected city. A card on the right describes
# the selected stop and starts it. Opened by wardrobe.gd for the "levels" tab.
const Campaign = preload("res://scripts/campaign.gd")
const Challenges = preload("res://scripts/challenges.gd")
const WorldMapData = preload("res://scripts/world_map_data.gd")
const Landmarks = preload("res://scripts/landmarks.gd")
const Fleet = preload("res://scripts/fleet.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const I18n = preload("res://scripts/i18n.gd")
const MAP_WIDTH := 30.0
const LAND_HEIGHT := 0.45
const PLINTH_RADIUS := 1.35
const PLINTH_HEIGHT := 0.36
const LANDMARK_HEIGHT := 4.2
const LANDMARK_FOOTPRINT := 1.35
const STOP_SPACING := 3.1
const SAUCER_SCALE := 0.95
const MAX_RENDER_SCALE := 2.0
const ROUTE_STEP := 0.55
const TREES := 46
const OCEAN := Color("3483b3")
const SHALLOW := Color("6cc2d6")
const CARD_WIDTH := 290.0
const HEADER := 88.0
const WEATHER_ICONS := {"clear":"sun", "sun":"sun", "rain":"rain", "snow":"snow", "wind":"wind", "fog":"fog", "storm":"storm"}

var game
var page := 0
var selected := 0
var clock := 0.0
var models
var viewport: SubViewport
var view: TextureRect
var overlay: Control
var camera: Camera3D
var map_root: Node3D
var saucer: MeshInstance3D
var saucer_craft := -1
var saucer_target := Vector3.ZERO
var stops: Array = []
# Size of stops relative to the continent: tall continents are framed from further
# away, so their landmarks and plinths grow to stay readable.
var unit := 1.0
var mesh_cache := {}
var materials := {}
var play_button: BaseButton
var prev_button: BaseButton
var next_button: BaseButton
var drag_start := Vector2.ZERO
var dragging := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	models = preload("res://scripts/models.gd").new()
	make_stage()
	view = TextureRect.new()
	view.texture = viewport.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_SCALE
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(on_map_input)
	add_child(view)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_overlay)
	add_child(overlay)
	play_button = make_button("play", UiStyle.GOLD, true)
	play_button.pressed.connect(func(): if game: game.wardrobe.play_level(selected))
	prev_button = make_button("left", Color("35546d"))
	prev_button.pressed.connect(func(): turn(-1))
	next_button = make_button("right", Color("35546d"))
	next_button.pressed.connect(func(): turn(1))
	resized.connect(layout)
	hide()

func make_button(icon_kind: String, accent: Color, primary := false) -> BaseButton:
	var button := UiButton.new()
	button.icon = UiStyle.icon(icon_kind)
	button.accent = accent
	button.primary = primary
	add_child(button)
	return button

func make_stage() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	# Same 2x MSAA as the city view; the map stays open while players browse.
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = OCEAN.darkened(0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9dcec")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = env
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 0.9
	sun.light_color = Color("fff1dc")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.05
	sun.shadow_blur = 1.4
	viewport.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 34
	viewport.add_child(camera)
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	ocean.mesh = plane
	ocean.material_override = flat_material(OCEAN)
	viewport.add_child(ocean)
	saucer = MeshInstance3D.new()
	viewport.add_child(saucer)

func flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material

func vertex_material() -> StandardMaterial3D:
	if materials.has("vertex"): return materials.vertex
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	materials.vertex = material
	return material

# Landmark material: the game's object shader with the hole moved far away.
func landmark_material(texture: Texture2D, locked: bool) -> ShaderMaterial:
	var key := "%s%s" % [texture.resource_path if texture else "plain", locked]
	if materials.has(key): return materials[key]
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/objects.gdshader")
	material.set_shader_parameter("hole_center", Vector2(1e5, 1e5))
	material.set_shader_parameter("hole_radius", 0.0)
	material.set_shader_parameter("grey", 1.0 if locked else 0.0)
	if texture: material.set_shader_parameter("albedo_tex", texture)
	materials[key] = material
	return material

# --- opening and paging ----------------------------------------------------------------

func open(level_index: int) -> void:
	page = level_index/Campaign.CITIES_PER_REGION
	selected = level_index
	show()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	layout()
	build_page()

func close() -> void:
	hide()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func turn(delta: int) -> void:
	var target := clampi(page + delta, 0, Campaign.REGIONS.size()-1)
	if target == page: return
	page = target
	var current: int = game.campaign.selected if game else 0
	selected = current if current/Campaign.CITIES_PER_REGION == page else page*Campaign.CITIES_PER_REGION
	build_page()

func select(level_index: int) -> void:
	selected = level_index
	saucer_target = stop_top(level_index%Campaign.CITIES_PER_REGION)
	if game: game.sfx.play("grow")
	refresh()

func layout() -> void:
	var map := map_rect()
	view.position = map.position
	view.size = map.size
	overlay.position = Vector2.ZERO
	overlay.size = size
	# Sharp on high-DPI phones, but capped so the map never renders above 2x.
	var scale := minf(MAX_RENDER_SCALE, get_tree().root.get_final_transform().get_scale().x) if is_inside_tree() else 1.0
	viewport.size = Vector2i(maxi(64, int(map.size.x*scale)), maxi(64, int(map.size.y*scale)))
	var card := card_rect()
	play_button.position = Vector2(card.position.x + 18, card.end.y - 76)
	play_button.size = Vector2(card.size.x - 36, 60)
	play_button.font_size = 22
	prev_button.position = Vector2(map.position.x + 12, map.end.y - 66)
	prev_button.size = Vector2(60, 54)
	next_button.position = Vector2(map.end.x - 72, map.end.y - 66)
	next_button.size = Vector2(60, 54)
	if visible and not stops.is_empty(): frame_camera()
	refresh()

func map_rect() -> Rect2:
	if size.x > size.y: return Rect2(16, HEADER, size.x - CARD_WIDTH - 40, size.y - HEADER - 16)
	return Rect2(16, HEADER, size.x - 32, size.y*0.5)

func card_rect() -> Rect2:
	if size.x > size.y: return Rect2(size.x - CARD_WIDTH - 16, HEADER, CARD_WIDTH, size.y - HEADER - 16)
	var top := HEADER + size.y*0.5 + 12
	return Rect2(16, top, size.x - 32, size.y - top - 16)

func refresh() -> void:
	if not game: return
	var open_level: bool = game.campaign.can_select(selected)
	play_button.disabled = not open_level
	play_button.text = I18n.t("play") if open_level else locked_label(selected)
	play_button.icon = UiStyle.icon("play" if open_level else "lock")
	prev_button.disabled = page == 0
	next_button.disabled = page >= Campaign.REGIONS.size()-1
	queue_redraw()
	overlay.queue_redraw()

func locked_label(index: int) -> String:
	var region: int = index/Campaign.CITIES_PER_REGION
	if game.campaign.region_open(region): return I18n.t("locked")
	return I18n.t("need_stars", Campaign.stars_needed(region))

# --- building the continent ---------------------------------------------------------------

func build_page() -> void:
	if is_instance_valid(map_root): map_root.free()
	map_root = Node3D.new()
	viewport.add_child(map_root)
	var region: Dictionary = Campaign.REGIONS[page]
	var data: Dictionary = WorldMapData.REGIONS[region.id]
	var palette: Array = region.palette
	var half := map_half(data)
	unit = clampf(maxf(half.x, half.y*1.45)/15.0, 1.0, 1.8)
	var land := projected_land(data)
	build_shallows(land)
	build_land(land, Color(palette[3]), Color(palette[2]))
	build_trees(land, Color(palette[4]), page)
	place_stops(data, land)
	build_route()
	for slot in stops.size(): build_stop(slot)
	saucer_target = stop_top(selected%Campaign.CITIES_PER_REGION)
	saucer.position = saucer_target
	update_saucer_mesh()
	frame_camera()
	refresh()

func to_map(point: Vector2, data: Dictionary) -> Vector2:
	var box: Array = data.box
	var k := MAP_WIDTH/(float(box[2]) - float(box[0]))
	var centre := Vector2((float(box[0]) + float(box[2]))/2, (float(box[1]) + float(box[3]))/2)
	# Map x = east, map y = south (it becomes +z, toward the camera).
	return Vector2(point.x - centre.x, centre.y - point.y)*k

func map_half(data: Dictionary) -> Vector2:
	var box: Array = data.box
	var k := MAP_WIDTH/(float(box[2]) - float(box[0]))
	return Vector2(float(box[2]) - float(box[0]), float(box[3]) - float(box[1]))*k/2

func projected_land(data: Dictionary) -> Array:
	var result: Array = []
	for ring in data.land:
		var polygon := PackedVector2Array()
		for i in range(0, ring.size(), 2): polygon.append(to_map(Vector2(ring[i], ring[i+1]), data))
		result.append(polygon)
	return result

# Emits a triangle facing `normal` (Godot's front faces wind clockwise).
func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	if (b - a).cross(c - a).dot(normal) > 0:
		var swap := b
		b = c
		c = swap
	# Vertex colours are linear, like models.bake().
	var linear := color.srgb_to_linear()
	for v in [a, b, c]:
		st.set_color(linear)
		st.set_normal(normal)
		st.add_vertex(v)

func add_mesh(st: SurfaceTool, material: Material, shadows := true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = st.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(instance)
	return instance

func fill(st: SurfaceTool, polygon: PackedVector2Array, y: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, indices.size(), 3):
		var a := polygon[indices[i]]
		var b := polygon[indices[i+1]]
		var c := polygon[indices[i+2]]
		tri(st, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), Vector3(c.x, y, c.y), Vector3.UP, color)

func build_shallows(land: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in land:
		for ring in Geometry2D.offset_polygon(polygon, 0.55, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(ring): fill(st, ring, 0.02, SHALLOW)
	add_mesh(st, vertex_material(), false)

func build_land(land: Array, top: Color, side: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon in land:
		fill(st, polygon, LAND_HEIGHT, top)
		for i in polygon.size():
			var p: Vector2 = polygon[i]
			var q: Vector2 = polygon[(i+1)%polygon.size()]
			var edge := q - p
			if edge.length() < 0.001: continue
			var out := Vector2(edge.y, -edge.x).normalized()
			if Geometry2D.is_point_in_polygon((p + q)/2 + out*0.02, polygon): out = -out
			var normal := Vector3(out.x, 0, out.y)
			var a := Vector3(p.x, 0, p.y)
			var b := Vector3(q.x, 0, q.y)
			var lift := Vector3(0, LAND_HEIGHT, 0)
			tri(st, a, b, b + lift, normal, side)
			tri(st, a, b + lift, a + lift, normal, side)
	add_mesh(st, vertex_material())

# A sprinkle of tiny cone trees on the land, seeded per continent.
func build_trees(land: Array, leaf: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7713 + seed_value*31
	var half := map_half(WorldMapData.REGIONS[Campaign.REGIONS[page].id])
	var parts: Array = []
	var placed := 0
	for attempt in TREES*12:
		if placed >= TREES: break
		var at := Vector2(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y))
		if not land.any(func(polygon): return Geometry2D.is_point_in_polygon(at, polygon)): continue
		var height := rng.randf_range(0.35, 0.6)
		parts.append(models.piece("cylinder", Vector3(at.x, LAND_HEIGHT + 0.06, at.y), Vector3(0.05, 0.12, 0.05), Color("7a5a3c")))
		parts.append(models.piece("roof", Vector3(at.x, LAND_HEIGHT + 0.12 + height/2, at.y), Vector3(0.22, height, 0.22), leaf.darkened(rng.randf_range(0.05, 0.3))))
		placed += 1
	if parts.is_empty(): return
	var instance := MeshInstance3D.new()
	instance.mesh = models.bake(parts, vertex_material())
	map_root.add_child(instance)

# Real coordinates, pushed apart so neighbouring cities (Giza and Cairo, Tokyo
# and Mount Fuji) keep room for their landmarks.
func place_stops(data: Dictionary, land: Array) -> void:
	stops.clear()
	var half := map_half(data) - Vector2(1.4, 1.2)
	var points: Array = []
	for p in data.stops:
		var at := to_map(Vector2(p[0], p[1]), data)
		points.append(Vector2(clampf(at.x, -half.x, half.x), clampf(at.y, -half.y, half.y)))
	for pass_index in 80:
		for i in points.size():
			for j in range(i+1, points.size()):
				var gap: Vector2 = points[j] - points[i]
				var distance := gap.length()
				if distance >= STOP_SPACING*unit: continue
				var push := (gap.normalized() if distance > 0.001 else Vector2.RIGHT.rotated(i + j))*(STOP_SPACING*unit - distance)/2
				points[i] -= push
				points[j] += push
		for i in points.size(): points[i] = Vector2(clampf(points[i].x, -half.x, half.x), clampf(points[i].y, -half.y, half.y))
	for i in points.size():
		var on_land: bool = land.any(func(polygon): return Geometry2D.is_point_in_polygon(points[i], polygon))
		stops.append({"at":points[i], "ground":LAND_HEIGHT if on_land else 0.0})

func stop_top(slot: int) -> Vector3:
	if slot >= stops.size(): return Vector3.ZERO
	var stop: Dictionary = stops[slot]
	return Vector3(stop.at.x, stop.ground + PLINTH_HEIGHT + (LANDMARK_HEIGHT + 0.9)*unit, stop.at.y)

func stop_base(slot: int) -> Vector3:
	var stop: Dictionary = stops[slot]
	return Vector3(stop.at.x, stop.ground + PLINTH_HEIGHT, stop.at.y)

func level_of(slot: int) -> int:
	return page*Campaign.CITIES_PER_REGION + slot

func build_stop(slot: int) -> void:
	var stop: Dictionary = stops[slot]
	var index := level_of(slot)
	var info := Campaign.level_info(index)
	var locked: bool = not game.campaign.can_select(index) if game else false
	var conquered: bool = game.campaign.medals[index] > 0 if game else false
	var parts: Array = []
	var ground: float = stop.ground
	if ground == 0.0:
		# Ocean stops (Rapa Nui, Fiji) get a little sand island.
		parts.append(models.piece("cyl", Vector3(stop.at.x, LAND_HEIGHT/2, stop.at.y), Vector3(1.5*unit, LAND_HEIGHT, 1.5*unit), Color(Campaign.REGIONS[page].palette[2])))
		ground = LAND_HEIGHT
		stop.ground = ground
	var rim := Color("f6cb70") if conquered else Color("dfe8ef") if not locked else Color("7d8a96")
	parts.append(models.piece("cyl", Vector3(stop.at.x, ground + PLINTH_HEIGHT/2, stop.at.y), Vector3(PLINTH_RADIUS*unit, PLINTH_HEIGHT, PLINTH_RADIUS*unit), Color("3c5368")))
	parts.append(models.piece("cyl", Vector3(stop.at.x, ground + PLINTH_HEIGHT + 0.01, stop.at.y), Vector3(PLINTH_RADIUS*unit*0.94, 0.04, PLINTH_RADIUS*unit*0.94), rim))
	var plinth := MeshInstance3D.new()
	plinth.mesh = models.bake(parts, vertex_material())
	map_root.add_child(plinth)
	var landmark := MeshInstance3D.new()
	var entry: Dictionary = landmark_mesh(info.boss)
	landmark.mesh = entry.mesh
	landmark.material_override = landmark_material(entry.texture, locked)
	landmark.position = Vector3(stop.at.x, ground + PLINTH_HEIGHT + 0.02, stop.at.y)
	landmark.scale = Vector3.ONE*entry.scale*unit
	landmark.rotation.y = -PI/4
	map_root.add_child(landmark)
	stop.landmark = landmark

# Normalised landmark: Meshy bake when present, else the primitive model.
func landmark_mesh(id: String) -> Dictionary:
	if mesh_cache.has(id): return mesh_cache[id]
	var mesh: ArrayMesh
	var texture: Texture2D = null
	var path := "res://assets/landmarks/%s.res" % id
	var texture_path := "res://assets/landmarks/%s_albedo.res" % id
	if ResourceLoader.exists(path) and ResourceLoader.exists(texture_path):
		mesh = load(path)
		texture = load(texture_path)
	else:
		mesh = models.bake(Landmarks.new().build(models, id))
	var box := mesh.get_aabb()
	var footprint := maxf(maxf(absf(box.position.x), absf(box.end.x)), maxf(absf(box.position.z), absf(box.end.z)))
	var scale := minf(LANDMARK_HEIGHT/maxf(box.end.y, 0.01), LANDMARK_FOOTPRINT/maxf(footprint, 0.01))
	mesh_cache[id] = {"mesh":mesh, "texture":texture, "scale":scale}
	return mesh_cache[id]

# Dotted arcs from each stop to the next: gold where the player already passed.
func build_route() -> void:
	var parts: Array = []
	for slot in stops.size() - 1:
		var a := Vector3(stops[slot].at.x, LAND_HEIGHT + 0.08, stops[slot].at.y)
		var b := Vector3(stops[slot+1].at.x, LAND_HEIGHT + 0.08, stops[slot+1].at.y)
		var passed: bool = game.campaign.medals[level_of(slot)] > 0 if game else false
		var color := Color("ffd66b") if passed else Color("f4f8fb")
		var count := maxi(2, int(a.distance_to(b)/ROUTE_STEP))
		for k in range(1, count):
			var t := float(k)/count
			if absf(t - 0.5) > 0.5 - PLINTH_RADIUS*unit/a.distance_to(b): continue
			var at := a.lerp(b, t) + Vector3(0, sin(t*PI)*minf(1.6, a.distance_to(b)*0.18), 0)
			parts.append(models.piece("ball", at, Vector3.ONE*0.09, color))
	if parts.is_empty(): return
	var instance := MeshInstance3D.new()
	instance.mesh = models.bake(parts, vertex_material())
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map_root.add_child(instance)

func update_saucer_mesh() -> void:
	var craft: int = game.campaign.craft if game else 0
	if craft == saucer_craft: return
	saucer_craft = craft
	saucer.mesh = Fleet.new().build(models, craft)
	saucer.material_override = vertex_material()

# Tilted perspective view that keeps the whole continent and its landmarks in frame.
func frame_camera() -> void:
	if stops.is_empty(): return
	var half := map_half(WorldMapData.REGIONS[Campaign.REGIONS[page].id])
	var pitch := deg_to_rad(56.0)
	var direction := Vector3(0, sin(pitch), cos(pitch))
	var target := Vector3(0, 0, half.y*0.08)
	var points: Array = [Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y), Vector3(-half.x, 0, half.y), Vector3(half.x, 0, half.y)]
	for slot in stops.size(): points.append(stop_top(slot))
	var low := 5.0
	var high := 200.0
	var screen := Vector2(viewport.size)
	var margin := Vector2(0.04, 0.06)*screen
	for step in 24:
		var distance := (low + high)/2
		camera.look_at_from_position(target + direction*distance, target)
		var inside := true
		for p in points:
			var at := camera.unproject_position(p)
			if at.x < margin.x or at.y < margin.y or at.x > screen.x - margin.x or at.y > screen.y - margin.y*2.2:
				inside = false
				break
		if inside: high = distance
		else: low = distance
	camera.look_at_from_position(target + direction*high, target)

# --- per frame ------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible or stops.is_empty(): return
	clock += delta
	saucer.position = saucer.position.lerp(saucer_target, 1.0 - exp(-delta*5.0)) + Vector3(0, sin(clock*2.4)*0.004, 0)
	saucer.rotation.y = clock*0.9
	saucer.scale = Vector3.ONE*SAUCER_SCALE*unit
	var slot := selected%Campaign.CITIES_PER_REGION
	for i in stops.size():
		var landmark: MeshInstance3D = stops[i].get("landmark")
		if not landmark: continue
		var bounce := 1.0 + (sin(clock*3.0)*0.04 if i == slot else 0.0)
		landmark.scale = Vector3.ONE*mesh_cache[Campaign.level_info(level_of(i)).boss].scale*unit*bounce
	overlay.queue_redraw()

func screen_of(point: Vector3) -> Vector2:
	var map := map_rect()
	return map.position + camera.unproject_position(point)*map.size/Vector2(viewport.size)

func on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_start = event.position
			dragging = true
			return
		if not dragging: return
		dragging = false
		var swipe: Vector2 = event.position - drag_start
		if absf(swipe.x) > 90 and absf(swipe.x) > absf(swipe.y)*1.5:
			turn(-1 if swipe.x > 0 else 1)
			return
		tap(view.position + event.position)

func tap(point: Vector2) -> void:
	var best := -1
	var best_distance := 56.0
	for slot in stops.size():
		for probe in [stop_base(slot), stop_base(slot) + Vector3(0, LANDMARK_HEIGHT*unit*0.5, 0)]:
			var distance := screen_of(probe).distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = slot
	if best < 0: return
	var index := level_of(best)
	if index == selected and game.campaign.can_select(index): game.wardrobe.play_level(index)
	else: select(index)

# --- 2D layers --------------------------------------------------------------------------------

func _draw() -> void:
	if not game: return
	var region_name := Campaign.region_name(page)
	var testing: bool = game.campaign.unlock_all_for_testing
	UiStyle.text(self, I18n.t("journey"), Vector2(28, 40), 16, UiStyle.MINT)
	UiStyle.text(self, region_name, Vector2(28, 76), 30, UiStyle.LIGHT, false, 5, UiStyle.font(800))
	var info := I18n.t("test_all_open", Campaign.level_count()) if testing else I18n.t("total_stars", [game.campaign.total_stars(), Campaign.REGION_STAR_GATE])
	var left := 40.0 + UiStyle.text_width(region_name, 30, UiStyle.font(800))
	UiStyle.text(self, I18n.t("taken_n", [game.campaign.region_progress(page), Campaign.CITIES_PER_REGION]), Vector2(left, 60), 16, UiStyle.GOLD)
	UiStyle.text(self, info, Vector2(left, 80), 13, UiStyle.GOLD if testing else UiStyle.MUTED, false, 0, UiStyle.body_font(700))
	var map := map_rect()
	draw_style_box(UiStyle.flat(Color(0.02, 0.05, 0.1, 0.4), 22), Rect2(map.position + Vector2(0, 5), map.size))
	draw_card()

func draw_card() -> void:
	var card := card_rect()
	UiStyle.card(self, card, Color("1b3048f5"), 22)
	var index := selected
	var info := Campaign.level_info(index)
	var x := card.position.x + 20
	var y := card.position.y + 22
	var badge := "%d / %d" % [info.slot + 1, Campaign.CITIES_PER_REGION]
	UiStyle.card(self, Rect2(x, y, UiStyle.text_width(badge, 14) + 24, 28), Color("2c4f73"), 14)
	UiStyle.text(self, badge, Vector2(x + 12, y + 20), 14, UiStyle.LIGHT)
	y += 64
	var title := Campaign.boss_name(info.boss)
	var title_size := 26
	var title_font := UiStyle.font(800)
	while title_size > 15 and UiStyle.text_width(title, title_size, title_font) > card.size.x - 40: title_size -= 1
	UiStyle.text(self, title, Vector2(x, y), title_size, UiStyle.GOLD, false, 5, title_font)
	y += 26
	UiStyle.text(self, "%s · %s" % [info.city, Campaign.region_name(page)], Vector2(x, y), 15, UiStyle.MUTED, false, 0, UiStyle.body_font(700))
	y += 20
	var rows: Array = [[WEATHER_ICONS.get(info.weather, "sun"), Campaign.weather_name(info.weather)],
		["clock", I18n.t("seconds", int(info.seconds))], ["city", "%d×%d" % [info.cols, info.rows]]]
	if info.rival: rows.append(["skull", I18n.t("rival_city")])
	for i in rows.size():
		var at := Vector2(x + (i%2)*(card.size.x - 40)/2, y + (i/2)*38)
		UiStyle.draw_icon(self, rows[i][0], at + Vector2(15, 17), 30)
		UiStyle.text(self, rows[i][1], at + Vector2(36, 23), 15, UiStyle.LIGHT, false, 0, UiStyle.body_font(700))
	y += ceili(rows.size()/2.0)*38 + 18
	UiStyle.text(self, I18n.t("goals"), Vector2(x, y), 14, UiStyle.MINT)
	y += 8
	var goals := Challenges.goals(info)
	var mask: int = game.campaign.goals[index]
	for i in goals.size():
		var done := mask & (1 << i) != 0
		UiStyle.draw_icon(self, "star", Vector2(x + 12, y + 16 + i*28), 24, Color.WHITE if done else Color(0.3, 0.38, 0.46, 0.9))
		UiStyle.text(self, Challenges.label(goals[i]), Vector2(x + 32, y + 22 + i*28), 15, UiStyle.GOLD if done else UiStyle.LIGHT, false, 0, UiStyle.body_font(700))

func draw_overlay() -> void:
	if stops.is_empty() or not game: return
	var map := map_rect()
	for slot in stops.size():
		var index := level_of(slot)
		var base := screen_of(stop_base(slot))
		if not map.has_point(base): continue
		var locked: bool = not game.campaign.can_select(index)
		var chosen := index == selected
		var center := base + Vector2(0, 22)
		overlay.draw_circle(center, 15, Color("f6cb70") if chosen else Color("1b3048"))
		overlay.draw_arc(center, 15, 0, TAU, 24, Color(1, 1, 1, 0.7), 2, true)
		if locked: UiStyle.draw_icon(overlay, "lock", center, 24)
		else: UiStyle.text(overlay, str(slot + 1), center + Vector2(0, 7), 17, UiStyle.INK if chosen else UiStyle.LIGHT, true, 0, UiStyle.font(800))
		var medals: int = game.campaign.medals[index]
		if medals > 0:
			for k in 3:
				UiStyle.draw_icon(overlay, "star", center + Vector2((k-1)*16, 24), 18, Color.WHITE if k < medals else Color(0.2, 0.26, 0.32, 0.9))
		if chosen:
			var info := Campaign.level_info(index)
			var top := screen_of(stop_top(slot)) - Vector2(0, 34)
			var width := UiStyle.text_width(info.city, 16) + 26
			UiStyle.card(overlay, Rect2(top.x - width/2, top.y - 22, width, 30), Color("1b3048ee"), 15)
			UiStyle.text(overlay, info.city, top, 16, UiStyle.LIGHT, true)
	for i in Campaign.REGIONS.size():
		var dot := Vector2(map.get_center().x + (i - 2.5)*20, map.end.y - 22)
		overlay.draw_circle(dot, 6 if i == page else 4.5, UiStyle.GOLD if i == page else Color(1, 1, 1, 0.45))
