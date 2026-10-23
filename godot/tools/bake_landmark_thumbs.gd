extends SceneTree

# Renders every landmark (campaign.gd LANDMARKS: the Meshy bake when present,
# else the primitive toy from landmarks.gd) into
# assets/thumbs/landmark_<id>.png for the conquest album (album.gd). The album
# tints the same picture black for cities not yet taken. Re-run after baking new
# Meshy landmarks. Not headless, it renders:
#   Godot --path . --script res://tools/bake_landmark_thumbs.gd [-- id,id]
const Campaign = preload("res://scripts/campaign.gd")
const TARGET := "res://assets/thumbs/"
const SIZE := 160

var viewport: SubViewport
var camera: Camera3D
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	holder = MeshInstance3D.new()
	viewport.add_child(holder)
	bake_all.call_deferred()

func bake_all() -> void:
	var only: Array = []
	for arg in OS.get_cmdline_user_args(): only.append_array(arg.split(","))
	var ids: Array = Campaign.LANDMARKS.keys().filter(func(id): return only.is_empty() or id in only)
	for id in ids:
		var models = load("res://scripts/models.gd").new()
		models.boss_style = id
		# Keep the hole far away: the object shader screens out towers near it.
		for material in [models.material, models.landmark_material]:
			material.set_shader_parameter("hole_center", Vector2(900, 900))
		holder.mesh = models.toy("boss")
		holder.rotation_degrees = Vector3(0, -25, 0)
		frame(holder.get_aabb())
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(TARGET + "landmark_%s.png" % id)
	print("baked ", ids.size(), " landmark thumbnails")
	quit(0)

# Aim the camera at the part above the ground (the shader clips below y = 0)
# and size it to the taller or wider side, so every landmark fills the square.
func frame(box: AABB) -> void:
	var low := maxf(box.position.y, 0.0)
	var high := box.end.y
	var width := Vector2(box.size.x, box.size.z).length()
	var center := holder.transform * box.get_center()
	var middle := Vector3(center.x, (low + high)/2, center.z)
	camera.size = maxf(high - low, width*0.85)*1.08
	camera.look_at_from_position(middle + Vector3(0, 0.45, 1).normalized()*30, middle)
