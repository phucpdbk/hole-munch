extends SceneTree

# Bakes the snake daily's Meshy pets (assets/critters_src, from
# `tools/meshy/meshy.mjs critters all`) into flipbook frames, so the game runs
# no skeleton or AnimationPlayer for them: each clip is posed at FRAMES evenly
# spaced times and frozen into a static mesh with
# bake_mesh_from_current_skeleton_pose, then simplified to about TRIANGLES.
# Every frame of an animal shares one 256 px lossy albedo and the same
# normalisation (critters.gd HEIGHT tall, standing on y = 0, facing +z), so
# the frames line up.
#   assets/critters/<id>_<clip>_<n>.res   meta "length": the clip's seconds
#   assets/critters/<id>_albedo.res
# Not headless: skins only register with a skeleton under a real renderer.
#   Godot --path . --script res://tools/bake_critters.gd [-- puppy kitten]
const Critter = preload("res://scripts/critters.gd")
const SOURCE := "res://assets/critters_src/"
const TARGET := "res://assets/critters/"
const FRAMES := {"idle":4, "walk":6, "run":6}
const TEXTURE_SIZE := 256
const TRIANGLES := 1200

func _initialize() -> void:
	bake_all.call_deferred()

func bake_all() -> void:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty(): ids = Critter.KINDS.duplicate()
	DirAccess.make_dir_recursive_absolute(TARGET)
	var failed := 0
	for id in ids:
		var error: Error = await bake(id)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)

func bake(id: String) -> Error:
	var root := load_scene(SOURCE + id + ".glb")
	if root == null: return ERR_FILE_NOT_FOUND
	get_root().add_child(root)
	for clip in FRAMES:
		if not add_clip(root, SOURCE + id + "@" + clip + ".glb", clip): return ERR_FILE_MISSING_DEPENDENCIES
	var player := find_player(root)
	var skinned := find_skinned(root)
	if player == null or skinned == null: return ERR_INVALID_DATA
	var skeleton := skinned.get_node_or_null(skinned.skeleton) as Skeleton3D
	var material := StandardMaterial3D.new()
	var source_material := skinned.mesh.surface_get_material(0)
	if source_material is BaseMaterial3D and source_material.albedo_texture != null:
		var texture := compressed(source_material.albedo_texture.get_image())
		var error := ResourceSaver.save(texture, TARGET + id + "_albedo.res", ResourceSaver.FLAG_COMPRESS)
		if error != OK: return error
		material.albedo_texture = load(TARGET + id + "_albedo.res")
	# One normalisation for every frame, taken from the first idle pose.
	var fit := Transform3D()
	var fitted := false
	for clip in FRAMES:
		var animation := player.get_animation(clip)
		for frame in FRAMES[clip]:
			player.play(clip)
			player.seek(animation.length*frame/FRAMES[clip], true)
			if skeleton: skeleton.force_update_all_bone_transforms()
			await process_frame
			var posed := skinned.bake_mesh_from_current_skeleton_pose()
			if not fitted:
				fit = normaliser(posed.get_aabb())
				fitted = true
			var mesh := framed(posed, fit, material)
			mesh.set_meta("length", animation.length)
			var error := ResourceSaver.save(mesh, "%s%s_%s_%d.res" % [TARGET, id, clip, frame], ResourceSaver.FLAG_COMPRESS)
			if error != OK: return error
	root.queue_free()
	await process_frame
	return OK

# Scales a pose to Critter.HEIGHT, centred on x/z with its feet on y = 0.
func normaliser(box: AABB) -> Transform3D:
	var scale := Critter.HEIGHT/maxf(box.size.y, 0.001)
	var centre := box.get_center()
	centre.y = box.position.y
	return Transform3D(Basis.from_scale(Vector3.ONE*scale), -centre*scale)

# The posed mesh moved by `fit`, with white vertex colours and the shared material.
func framed(posed: ArrayMesh, fit: Transform3D, material: Material) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in posed.get_surface_count():
		var arrays := posed.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			vertices[i] = fit*vertices[i]
			normals[i] = (fit.basis*normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		arrays[Mesh.ARRAY_INDEX] = simplified(arrays)
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, compacted(arrays))
		result.surface_set_material(surface, material)
	return result

# The coarsest generated LOD that keeps at least TRIANGLES: a pet is a few dozen
# pixels tall on screen, and a line can hold dozens of them.
func simplified(arrays: Array) -> PackedInt32Array:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(60.0, 75.0, [])
	var chosen := indices
	for lod in importer.get_surface_lod_count(0):
		var candidate := importer.get_surface_lod_indices(0, lod)
		if candidate.size()/3 >= TRIANGLES and candidate.size() < chosen.size(): chosen = candidate
	return chosen

# Drops the vertices the simplified indices no longer use.
func compacted(arrays: Array) -> Array:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var remap := {}
	var order := PackedInt32Array()
	for index in indices:
		if not remap.has(index):
			remap[index] = order.size()
			order.append(index)
	var result := arrays.duplicate()
	for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_COLOR]:
		var source = arrays[slot]
		if source == null: continue
		var kept = source.duplicate()
		kept.resize(order.size())
		for i in order.size(): kept[i] = source[order[i]]
		result[slot] = kept
	var reindexed := PackedInt32Array()
	reindexed.resize(indices.size())
	for i in indices.size(): reindexed[i] = remap[indices[i]]
	result[Mesh.ARRAY_INDEX] = reindexed
	return result

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
		animation.loop_mode = Animation.LOOP_LINEAR
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

static func find_skinned(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D and node.skin != null: return node
	for child in node.get_children():
		var found := find_skinned(child)
		if found != null: return found
	return null

func compressed(source: Image) -> Texture2D:
	var image := source.duplicate()
	if image.is_compressed(): image.decompress()
	if image.get_width() > TEXTURE_SIZE: image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var texture := PortableCompressedTexture2D.new()
	texture.keep_compressed_buffer = true
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.85)
	return texture
