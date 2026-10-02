extends RefCounted

# Shared steps for baking Meshy GLBs into game-ready resources: read a GLB into
# one textured surface, normalise it, simplify it for mobile, and save the mesh
# plus a lossy WebP albedo. Used by bake_landmarks.gd and bake_crafts.gd.
const MIN_TRIANGLES := 3000
const TEXTURE_SIZE := 1024

# Loads a GLB and merges every surface. Returns {} on failure, else
# {vertices, normals, uvs, indices, image}.
static func load_glb(path: String) -> Dictionary:
	var state := GLTFState.new()
	var document := GLTFDocument.new()
	if document.append_from_file(ProjectSettings.globalize_path(path), state) != OK: return {}
	var root := document.generate_scene(state)
	var surfaces: Array = []
	collect(root, Transform3D.IDENTITY, surfaces)
	root.free()
	if surfaces.is_empty(): return {}
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
		elif surface.image != null and surface.image != image: push_warning(path + ": extra textures ignored")
	if image == null: return {}
	return {"vertices":vertices, "normals":normals, "uvs":uvs, "indices":indices, "image":image}

# Centre the model on x/z, scale its widest radius to `footprint` and turn it by
# `yaw_degrees`. `floor` puts its lowest point at y = 0; otherwise it is centred
# on y too (crafts hover).
static func normalize(data: Dictionary, footprint: float, yaw_degrees: float, floor := true) -> void:
	var vertices: PackedVector3Array = data.vertices
	var normals: PackedVector3Array = data.normals
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for v in vertices: bounds = bounds.expand(v)
	var center := bounds.get_center()
	if floor: center.y = bounds.position.y
	var widest := 0.0
	for v in vertices: widest = maxf(widest, Vector2(v.x - center.x, v.z - center.z).length())
	var scale := footprint / maxf(widest, 0.001)
	var turn := Basis(Vector3.UP, deg_to_rad(yaw_degrees))
	for i in vertices.size():
		vertices[i] = turn * (vertices[i] - center) * scale
		normals[i] = turn * normals[i]
	data.vertices = vertices
	data.normals = normals

# Saves <target>.res (mesh) and <target>_albedo.res (texture).
static func save(data: Dictionary, target: String, min_triangles := MIN_TRIANGLES) -> Error:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	# White vertex colours: the object shader multiplies COLOR by the texture.
	var colors := PackedColorArray()
	colors.resize(data.vertices.size())
	colors.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = simplify(arrays, data.indices, min_triangles)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var error := ResourceSaver.save(mesh, target + ".res", ResourceSaver.FLAG_COMPRESS)
	if error != OK: return error
	return save_texture(target + "_albedo.res", data.image)

static func simplify(arrays: Array, indices: PackedInt32Array, min_triangles: int) -> PackedInt32Array:
	var working := arrays.duplicate()
	working[Mesh.ARRAY_INDEX] = indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, working)
	importer.generate_lods(60.0, 75.0, [])
	var chosen := indices
	var target := maxi(min_triangles, indices.size() / 6)
	for lod in importer.get_surface_lod_count(0):
		var candidate := importer.get_surface_lod_indices(0, lod)
		if candidate.size() / 3 >= target and candidate.size() < chosen.size(): chosen = candidate
	print("  triangles ", indices.size() / 3, " -> ", chosen.size() / 3)
	return chosen

# Lossy WebP inside a .res keeps the assets small in the APK without an import step.
static func save_texture(path: String, source: Image) -> Error:
	var image := source.duplicate()
	if image.is_compressed(): image.decompress()
	if image.get_width() > TEXTURE_SIZE: image.resize(TEXTURE_SIZE, TEXTURE_SIZE, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	var texture := PortableCompressedTexture2D.new()
	# Without the kept buffer the saved resource holds no pixels outside the editor.
	texture.keep_compressed_buffer = true
	texture.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSY, false, 0.85)
	return ResourceSaver.save(texture, path)

static func collect(node: Node, parent: Transform3D, surfaces: Array) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var material = node.get_active_material(i)
			var image: Image
			if material is BaseMaterial3D and material.albedo_texture:
				image = material.albedo_texture.get_image()
			surfaces.append({"arrays":node.mesh.surface_get_arrays(i), "transform":transform, "image":image})
	for child in node.get_children(): collect(child, transform, surfaces)

# GLB ids in a source folder, or the ids given after `--` on the command line.
static func requested_ids(source: String) -> Array:
	var ids: Array = Array(OS.get_cmdline_user_args())
	if ids.is_empty():
		for file in DirAccess.get_files_at(source):
			# "<id>@<clip>.glb" files are animations of <id>, not models of their own.
			if file.get_extension() == "glb" and not file.contains("@"): ids.append(file.get_basename())
	return ids
