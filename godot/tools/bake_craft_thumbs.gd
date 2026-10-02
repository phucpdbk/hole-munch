extends SceneTree

# Renders every craft (fleet.gd: the Meshy bake when present, else primitives)
# into assets/thumbs/craft_<index>.png for the wardrobe cards (look_card.gd).
# Re-run after baking new Meshy saucers. Not headless, it renders:
#   Godot --path . --script res://tools/bake_craft_thumbs.gd
const Fleet = preload("res://scripts/fleet.gd")
const TARGET := "res://assets/thumbs/"
const SIZE := 128

var viewport: SubViewport
var holder: MeshInstance3D

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TARGET)
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
	environment.environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.4
	camera.look_at_from_position(Vector3(0, 3.2, 4.4), Vector3(0, 1.0, 0))
	viewport.add_child(camera)
	holder = MeshInstance3D.new()
	viewport.add_child(holder)
	bake_all.call_deferred()

func bake_all() -> void:
	var models = load("res://scripts/models.gd").new()
	for index in Fleet.NAMES.size():
		holder.mesh = Fleet.new().build(models, index)
		holder.rotation_degrees = Vector3(0, -25, 0)
		holder.scale = Vector3.ONE
		holder.position = Vector3(0, 1.0, 0)
		# Rockets stand tall: shrink them and lean them a little to fit the square.
		# The object shader clips everything below y = 0 (the ground), so every
		# craft sits above it and the camera aims at its middle.
		if index >= 5:
			holder.rotation_degrees = Vector3(0, -25, -20)
			holder.scale = Vector3.ONE*0.62
			holder.position = Vector3(0, 1.7, 0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(TARGET + "craft_%d.png" % index)
	print("baked ", Fleet.NAMES.size(), " craft thumbnails")
	quit(0)
