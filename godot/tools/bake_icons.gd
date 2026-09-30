extends SceneTree

# Renders POLYGON Icons (Synty, H:/Game/3DModels/POLYGON_Icons) into small PNG
# button icons with a dark outline, so the UI needs no 3D work at runtime.
# Extract the pack's OBJ + Textures folders first, then run (not headless, it renders):
#   Godot --path . --script res://tools/bake_icons.gd -- <_SourceFiles dir> [--sheet]
# ui_style.gd falls back to its vector icons when a PNG is missing.
const TARGET := "res://assets/icons/"
const SIZE := 128
const OUTLINE := Color("10202e")
# Game icon id -> POLYGON mesh name (SM_Icon_<name>.obj).
const ICONS := {
	"play":"Play_01", "pause":"Pause_01", "home":"Home_01", "replay":"Replay_01", "next":"Fast_Forward_01",
	"map":"Location_01", "globe":"Planet_01", "upgrade":"Wrench_Hammer_01", "wardrobe":"Clothes_Hat_01",
	"daily":"Calendar_01", "endless":"Hourglass_01", "close":"X_01", "left":"Arrow_05", "right":"Arrow_05",
	"coin":"Coin_02", "star":"Star_01", "trophy":"Trophy_01", "lock":"Padlock_01", "language":"Chat_01",
	"help":"QuestionMark_01", "clock":"Stopwatch_01", "shield":"Shield_01", "bomb":"Bomb_01",
	"magnet":"Magnet_01", "skull":"Skull_01", "target":"Crosshair_01", "fire":"Fire_01", "bolt":"Lightning_01",
	"medal":"Medal_02", "tick":"Tick_01", "flag":"Flag_01", "crown":"Crown_01", "food":"Food_Burger_01",
	"sun":"Weather_Sun_01", "rain":"Weather_Rain_01", "snow":"Weather_Snow_01", "wind":"Weather_Wind_01",
	"fog":"Weather_Cloud_01", "storm":"Weather_Lightning_01", "city":"Residential_01", "gem":"Gem_01",
	"heart":"Heart_01", "chest":"Chest_01", "megaphone":"Megaphone_01", "mountains":"Mountains_01",
}
# Some meshes need a turn to read well from the front (degrees around the view axis).
const ROLL := {"left":180.0}

var source := ""
var viewport: SubViewport
var holder: MeshInstance3D
var texture: ImageTexture

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the extracted POLYGON_Icons _SourceFiles directory.")
		quit(1)
		return
	source = args[0]
	var atlas := Image.load_from_file(source.path_join("Textures/PolygonIcons_Texture_01_A.png"))
	texture = ImageTexture.create_from_image(atlas)
	DirAccess.make_dir_recursive_absolute(TARGET)
	make_stage()
	bake_all.call_deferred("--sheet" in args)

func make_stage() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.72, 0.76, 0.82)
	environment.environment.ambient_light_energy = 0.9
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_energy = 1.05
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.35
	camera.position = Vector3(0, 0, 5)
	viewport.add_child(camera)
	holder = MeshInstance3D.new()
	viewport.add_child(holder)

func bake_all(sheet: bool) -> void:
	var names: Array = ICONS.keys()
	if sheet:
		names.clear()
		for file in DirAccess.get_files_at(source.path_join("OBJ")):
			if file.get_extension() == "obj": names.append(file.trim_prefix("SM_Icon_").get_basename())
	var images: Array[Image] = []
	for id in names:
		var mesh_name: String = id if sheet else ICONS[id]
		var mesh := load_obj(source.path_join("OBJ/SM_Icon_%s.obj" % mesh_name))
		if not mesh:
			push_error("missing " + mesh_name)
			continue
		holder.mesh = mesh
		holder.rotation_degrees = Vector3(10, -20, ROLL.get(id, 0.0))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := outlined(viewport.get_texture().get_image())
		if sheet: images.append(image)
		else: image.save_png(TARGET + id + ".png")
	if sheet: save_sheet(images, names)
	print("baked ", images.size() if sheet else names.size(), " icons")
	quit(0)

# OBJ (cm, Y up) -> one textured surface centred and scaled to a 2-unit box.
func load_obj(path: String) -> ArrayMesh:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file: return null
	var positions: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var normals: Array[Vector3] = []
	var corners: Array = []
	while not file.eof_reached():
		var parts := file.get_line().strip_edges().split(" ", false)
		if parts.is_empty(): continue
		match parts[0]:
			"v": positions.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"vt": uvs.append(Vector2(float(parts[1]), 1.0 - float(parts[2])))
			"vn": normals.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"f":
				var face: Array = []
				for k in range(1, parts.size()): face.append(parts[k].split("/"))
				for k in range(1, face.size() - 1): corners.append_array([face[0], face[k], face[k+1]])
	if positions.is_empty(): return null
	var box := AABB(positions[0], Vector3.ZERO)
	for p in positions: box = box.expand(p)
	var scale := 2.0 / maxf(box.size.x, maxf(box.size.y, box.size.z))
	var centre := box.get_center()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# OBJ winds counter-clockwise; Godot's front faces are clockwise.
	for i in range(0, corners.size(), 3):
		for corner in [corners[i], corners[i+2], corners[i+1]]:
			if corner.size() > 1 and corner[1] != "": st.set_uv(uvs[int(corner[1]) - 1])
			if corner.size() > 2 and corner[2] != "": st.set_normal(normals[int(corner[2]) - 1])
			st.add_vertex((positions[int(corner[0]) - 1] - centre) * scale)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.roughness = 0.6
	st.set_material(material)
	return st.commit()

# A 3 px dark rim keeps the coloured icons readable on any button.
func outlined(image: Image) -> Image:
	image.convert(Image.FORMAT_RGBA8)
	var result := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var near := 0.0
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if dx*dx + dy*dy > 10: continue
					near = maxf(near, image.get_pixel(clampi(x+dx, 0, SIZE-1), clampi(y+dy, 0, SIZE-1)).a)
			result.set_pixel(x, y, Color(OUTLINE, near))
	result.blend_rect(image, Rect2i(0, 0, SIZE, SIZE), Vector2i.ZERO)
	return result

# Contact sheet for picking icons: test-output/icon-sheet.png + index list.
func save_sheet(images: Array[Image], names: Array) -> void:
	var columns := 24
	var cell := 64
	var rows := ceili(images.size()/float(columns))
	var sheet := Image.create(columns*cell, rows*cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2a4258"))
	for i in images.size():
		var small := images[i]
		small.resize(cell, cell)
		sheet.blend_rect(small, Rect2i(0, 0, cell, cell), Vector2i((i%columns)*cell, (i/columns)*cell))
	DirAccess.make_dir_recursive_absolute("res://test-output")
	sheet.save_png("res://test-output/icon-sheet.png")
	var index := FileAccess.open("res://test-output/icon-sheet.txt", FileAccess.WRITE)
	for i in names.size(): index.store_line("%d,%d %s" % [i%columns, i/columns, names[i]])
