extends SceneTree

# Contact sheet of every baked army soldier clip (assets/soldiers/<id>.scn):
# one row per clip, frames at 0..100% of its length, written to
# test-output/soldier-<id>.png. Needs a window (no --headless):
#   Godot --path . --script res://tools/preview_soldiers.gd [-- vn_soldier]
const FRAMES := 5
const CELL := 220

func _initialize() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty(): ids = ["vn_soldier", "vn_police"]
	root.size = Vector2i(CELL*FRAMES, CELL)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.9, 0.6, 0)
	root.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("cfd8dc")
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	root.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 22.0
	root.add_child(camera)
	camera.look_at_from_position(Vector3(1.2, 1.1, 2.6), Vector3(0, 0.6, 0))
	for id in ids: await sheet(id, camera)
	quit()

func sheet(id: String, camera: Camera3D) -> void:
	var model: Node3D = load("res://assets/soldiers/%s.scn" % id).instantiate()
	root.add_child(model)
	var player: AnimationPlayer = find_player(model)
	var clips: PackedStringArray = player.get_animation_list()
	var image := Image.create(CELL*FRAMES, CELL*clips.size(), false, Image.FORMAT_RGBA8)
	await process_frame
	var bounds := measure(model)
	print("height ", bounds.y)
	camera.look_at_from_position(Vector3(0.9, 1.0, 2.2), Vector3(0, 0.6, 0))
	for row in clips.size():
		var clip: String = clips[row]
		if OS.has_environment("CLIPS") and not clip in OS.get_environment("CLIPS").split(","): continue
		var length := player.get_animation(clip).length
		for frame in FRAMES:
			player.play(clip)
			player.seek(length*frame/float(FRAMES - 1), true)
			player.pause()
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			var side := mini(shot.get_width(), shot.get_height())
			shot = shot.get_region(Rect2i((shot.get_width() - side)/2, (shot.get_height() - side)/2, side, side))
			shot.resize(CELL, CELL)
			image.blit_rect(shot, Rect2i(0, 0, CELL, CELL), Vector2i(frame*CELL, row*CELL))
		print("%s %d %s %.2fs" % [id, row, clip, length])
	image.save_png("res://test-output/soldier-%s.png" % id)
	model.free()

# x: widest half-extent, y: height of the character's meshes.
func measure(model: Node3D) -> Vector2:
	var top := 0.0
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		top = maxf(top, box.end.y)
	return Vector2(top*0.5, maxf(top, 0.5))

static func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_player(child)
		if found != null: return found
	return null
