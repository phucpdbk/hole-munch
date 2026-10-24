extends SceneTree

# Bakes Meshy guardian mascots from assets/mascots_src into assets/mascots/<id>.scn,
# which mascot_rig.gd loads in place of the primitive rig:
#   <id>.glb          the (rigged) character; a model without a skeleton also works
#   <id>@<clip>.glb   one animation each, same skeleton: idle, walk, run, attack,
#                     hit, leap (tools/meshy/meshy.mjs downloads them this way)
# Every clip is copied into the character's AnimationPlayer under its state name,
# so mascot_rig.gd plays them by state name with no extra mapping. Textures
# are shrunk to 1024 px lossy WebP to keep the APK small.
#   Godot --headless --path . --script res://tools/bake_mascots.gd [-- onepillar namsan]
# Army foot units (army_soldiers.gd) bake the same way from assets/soldiers_src into
# assets/soldiers/, with 512 px textures since up to two dozen share the screen:
#   Godot --headless --path . --script res://tools/bake_mascots.gd -- soldiers [vn_soldier]
# Daily-game monsters bake from assets/monsters_src into assets/mascots/:
#   Godot --headless --path . --script res://tools/bake_mascots.gd -- monsters [gobbler]
const MeshyBake = preload("res://tools/meshy_bake.gd")
const LOOPING := ["idle", "walk", "run", "alert", "aim", "shoot", "panic"]
var SOURCE := "res://assets/mascots_src/"
var TARGET := "res://assets/mascots/"
var texture_size: int = MeshyBake.TEXTURE_SIZE

func _initialize() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if not ids.is_empty() and ids[0] == "soldiers":
		ids.pop_front()
		SOURCE = "res://assets/soldiers_src/"
		TARGET = "res://assets/soldiers/"
		texture_size = 512
	# Daily-game villains (the snake's monster) come from their own Meshy folder but
	# load like guardians, through mascot_rig.gd.
	elif not ids.is_empty() and ids[0] == "monsters":
		ids.pop_front()
		SOURCE = "res://assets/monsters_src/"
	if ids.is_empty():
		for file in DirAccess.get_files_at(SOURCE):
			if file.get_extension() == "glb" and not file.contains("@"): ids.append(file.get_basename())
	DirAccess.make_dir_recursive_absolute(TARGET)
	var failed := 0
	for id in ids:
		var error := bake(id)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)

func bake(id: String) -> Error:
	var root := load_scene(SOURCE + id + ".glb")
	if root == null: return ERR_INVALID_DATA
	root.name = id
	var clips := 0
	for file in DirAccess.get_files_at(SOURCE):
		if not file.begins_with(id + "@") or file.get_extension() != "glb": continue
		var clip := file.get_basename().trim_prefix(id + "@")
		if add_clip(root, SOURCE + file, clip): clips += 1
	print("  clips ", clips)
	shrink_textures(root)
	own(root, root)
	var scene := PackedScene.new()
	var error := scene.pack(root)
	root.free()
	if error != OK: return error
	return ResourceSaver.save(scene, TARGET + id + ".scn", ResourceSaver.FLAG_COMPRESS)

func load_scene(path: String) -> Node3D:
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	if document.append_from_file(ProjectSettings.globalize_path(path), state) != OK: return null
	return document.generate_scene(state) as Node3D

# Copies the first animation of an animation GLB into the character's player.
func add_clip(root: Node3D, path: String, clip: String) -> bool:
	var source := load_scene(path)
	if source == null: return false
	var source_player := find_player(source)
	var copied := false
	if source_player != null and not source_player.get_animation_list().is_empty():
		var animation: Animation = source_player.get_animation(source_player.get_animation_list()[0]).duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR if clip in LOOPING else Animation.LOOP_NONE
		var player := find_player(root)
		if player == null:
			player = AnimationPlayer.new()
			player.name = "AnimationPlayer"
			root.add_child(player)
		if not player.has_animation_library(""): player.add_animation_library("", AnimationLibrary.new())
		var library := player.get_animation_library("")
		if library.has_animation(clip): library.remove_animation(clip)
		library.add_animation(clip, animation)
		copied = true
	source.free()
	return copied

static func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_player(child)
		if found != null: return found
	return null

func shrink_textures(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material is BaseMaterial3D and material.albedo_texture != null:
				material.albedo_texture = compressed(material.albedo_texture.get_image())
	for child in node.get_children(): shrink_textures(child)

func compressed(source: Image) -> Texture2D:
	var image := source.duplicate()
	if image.is_compressed(): image.decompress()
	if image.get_width() > texture_size: image.resize(texture_size, texture_size, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var texture := PortableCompressedTexture2D.new()
	texture.keep_compressed_buffer = true
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.85)
	return texture

# PackedScene only saves nodes owned by the root.
static func own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		own(child, root)
