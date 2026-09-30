extends SceneTree

# Bakes Meshy GLBs from assets/landmarks_src into game-ready landmark meshes:
# one textured surface, ground at y = 0, footprint normalized to the boss size,
# simplified for mobile. models.gd prefers these over the primitive landmarks.
#   Godot --headless --path . --script res://tools/bake_landmarks.gd [-- eiffel taj]
const SOURCE := "res://assets/landmarks_src/"
const TARGET := "res://assets/landmarks/"
const FOOTPRINT := 2.6
const MIN_TRIANGLES := 3000
const TEXTURE_SIZE := 1024
# Per-landmark yaw fix (degrees) when Meshy's front does not face the camera (+z).
const YAW := {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TARGET)
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		for file in DirAccess.get_files_at(SOURCE):
			if file.get_extension() == "glb": ids.append(file.get_basename())
	var failed := 0
	for id in ids:
		var error := bake(id)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)

func bake(id: String) -> Error:
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	var error := document.append_from_file(ProjectSettings.globalize_path(SOURCE + id + ".glb"), state)
	if error != OK: return error
	var root := document.generate_scene(state)
	var surfaces: Array = []
	collect(root, Transform3D.IDENTITY, surfaces)
	root.free()
	if surfaces.is_empty(): return ERR_INVALID_DATA
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var image: Image
	for surface in surfaces:
		var arrays: Array = surface.arrays
		var offset := vertices.size()
		var normal_basis: Basis = surface.transform.basis.inverse().transposed()
		var source_uvs = arrays[Mesh.ARRAY_TEX_UV]
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			vertices.append(surface.transform * arrays[Mesh.ARRAY_VERTEX][i])
			normals.append((normal_basis * arrays[Mesh.ARRAY_NORMAL][i]).normalized())
			uvs.append(source_uvs[i] if source_uvs != null else Vector2.ZERO)
		var source_indices = arrays[Mesh.ARRAY_INDEX]
		if source_indices != null and source_indices.size() > 0:
			for index in source_indices: indices.append(offset + index)
		else:
			for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(offset + i)
		if image == null and surface.image != null: image = surface.image
		elif surface.image != null and surface.image != image: push_warning(id + ": extra textures ignored")
	if image == null: return ERR_FILE_MISSING_DEPENDENCIES
	normalize(id, vertices, normals)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	# White vertex colours: the object shader multiplies COLOR by the texture.
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = simplify(arrays, indices)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	error = ResourceSaver.save(mesh, TARGET + id + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK: return error
	return save_texture(id, image)

func normalize(id: String, vertices: PackedVector3Array, normals: PackedVector3Array) -> void:
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for v in vertices: bounds = bounds.expand(v)
	var center := bounds.get_center()
	center.y = bounds.position.y
	var footprint := 0.0
	for v in vertices: footprint = maxf(footprint, Vector2(v.x - center.x, v.z - center.z).length())
	var scale := FOOTPRINT / maxf(footprint, 0.001)
	var turn := Basis(Vector3.UP, deg_to_rad(float(YAW.get(id, 0.0))))
	for i in vertices.size():
		vertices[i] = turn * (vertices[i] - center) * scale
		normals[i] = turn * normals[i]

func simplify(arrays: Array, indices: PackedInt32Array) -> PackedInt32Array:
	var working := arrays.duplicate()
	working[Mesh.ARRAY_INDEX] = indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, working)
	importer.generate_lods(60.0, 75.0, [])
	var chosen := indices
	var target := maxi(MIN_TRIANGLES, indices.size() / 6)
	for lod in importer.get_surface_lod_count(0):
		var candidate := importer.get_surface_lod_indices(0, lod)
		if candidate.size() / 3 >= target and candidate.size() < chosen.size(): chosen = candidate
	print("  triangles ", indices.size() / 3, " -> ", chosen.size() / 3)
	return chosen

# Lossy WebP inside a .res keeps 48 landmarks small in the APK without an import step.
func save_texture(id: String, source: Image) -> Error:
	var image := source.duplicate()
	if image.is_compressed(): image.decompress()
	if image.get_width() > TEXTURE_SIZE: image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var texture := PortableCompressedTexture2D.new()
	# Without the kept buffer the saved resource holds no pixels outside the editor.
	texture.keep_compressed_buffer = true
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.85)
	return ResourceSaver.save(texture, TARGET + id + "_albedo.res")

func collect(node: Node, parent: Transform3D, surfaces: Array) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var material = node.get_active_material(i)
			var image: Image
			if material is BaseMaterial3D and material.albedo_texture:
				image = material.albedo_texture.get_image()
			surfaces.append({"arrays":node.mesh.surface_get_arrays(i), "transform":transform, "image":image})
	for child in node.get_children(): collect(child, transform, surfaces)
