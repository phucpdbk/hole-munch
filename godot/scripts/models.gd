class_name ToyModels
extends RefCounted

# Bake each toy into one vertex-colored mesh. Repeated toys share a MultiMesh.
# No scene node, physics body, material or per-frame texture upload per toy.
var shapes: Dictionary = {}
var cache: Dictionary = {}
var material: Material
var snow_material: ShaderMaterial
# Carries the texture of the level's Meshy landmark (one landmark per level).
var landmark_material: ShaderMaterial
const ROOFS = [Color("ec8777"), Color("81b7cb"), Color("e7be78"), Color("a999cc")]
var roofs: Array = ROOFS.duplicate()
var foliage := Color("75ab87")
var boss_style := "eiffel"
var region_style := "europe"
const CityProfiles = preload("res://scripts/city_profiles.gd")
const StreetModels = preload("res://scripts/street_models.gd")
var city_profile: Dictionary = CityProfiles.profile(CityProfiles.DEFAULT)
const Landmarks = preload("res://scripts/landmarks.gd")
const RegionModels = preload("res://scripts/region_models.gd")
const Campaign = preload("res://scripts/campaign.gd")
const FARM_RADIUS = {"cow":1.0,"pig":0.72,"chicken":0.28,"tree_oak":0.72,"fence_simple":0.65,"crops_cornStageD":0.4,"crops_wheatStageB":0.3,"tent_smallOpen":1.6,"pumpkin":0.3}

func _init() -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	shapes.box = box
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 6
	shapes.ball = ball
	# Smooth spheres for the large, close-up boss so its silhouette and shadow stay round.
	var smooth_ball := SphereMesh.new()
	smooth_ball.radius = 1.0
	smooth_ball.height = 2.0
	smooth_ball.radial_segments = 32
	smooth_ball.rings = 16
	shapes.smooth = smooth_ball
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.0
	cylinder.radial_segments = 12
	shapes.cylinder = cylinder
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 4
	shapes.roof = cone
	var point := CylinderMesh.new()
	point.top_radius = 0.0; point.bottom_radius = 1.0; point.height = 1.0; point.radial_segments = 24
	shapes.point = point
	# Extra primitives for detailed landmarks, regional buildings and bosses.
	var smooth_cylinder := CylinderMesh.new()
	smooth_cylinder.top_radius = 1.0; smooth_cylinder.bottom_radius = 1.0; smooth_cylinder.height = 1.0
	smooth_cylinder.radial_segments = 24
	shapes.cyl = smooth_cylinder
	var hemi := SphereMesh.new()
	hemi.radius = 1.0; hemi.height = 1.0; hemi.is_hemisphere = true
	hemi.radial_segments = 24; hemi.rings = 8
	shapes.hemi = hemi
	var prism := CylinderMesh.new()
	prism.top_radius = 1.0; prism.bottom_radius = 1.0; prism.height = 1.0; prism.radial_segments = 3
	shapes.prism = prism
	var ring := TorusMesh.new()
	ring.inner_radius = 0.8; ring.outer_radius = 1.0; ring.rings = 24; ring.ring_segments = 6
	shapes.ring = ring
	var frustum := CylinderMesh.new()
	frustum.top_radius = 0.6; frustum.bottom_radius = 1.0; frustum.height = 1.0; frustum.radial_segments = 4
	shapes.frustum = frustum
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/objects.gdshader")
	snow_material = material.duplicate()
	landmark_material = material.duplicate()

func piece(shape: String, pos: Vector3, size: Vector3, color: Color, rotation := Vector3.ZERO) -> Dictionary:
	# Scale in the primitive's local axes before rotating (slanted tower beams,
	# clock faces and roof panels must not be stretched in world axes).
	var basis := Basis.from_euler(rotation) * Basis.from_scale(size)
	return {"mesh": shapes[shape], "transform": Transform3D(basis, pos), "color": color}

func bake(parts: Array, use_material: Material = null) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for p in parts:
		var arrays: Array = p.mesh.get_mesh_arrays()
		var offset := vertices.size()
		var transform: Transform3D = p.transform
		var normal_basis := transform.basis.inverse().transposed()
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			vertices.append(transform * arrays[Mesh.ARRAY_VERTEX][i])
			normals.append((normal_basis * arrays[Mesh.ARRAY_NORMAL][i]).normalized())
			colors.append(p.color.srgb_to_linear())
		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(index + offset)
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_NORMAL] = normals
	result[Mesh.ARRAY_COLOR] = colors
	result[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result)
	mesh.surface_set_material(0, use_material if use_material else material)
	return mesh

func toy(kind: String, variant: int = 0) -> ArrayMesh:
	var key := kind + str(variant)
	if cache.has(key):
		return cache[key]
	if kind in ["house","tree","car","person"]:
		var id := kind+str(variant % (3 if kind in ["house","person"] else 2))
		var path := "res://assets/synty/"+id+".res"
		if ResourceLoader.exists(path):
			var mesh: ArrayMesh = load(path).duplicate()
			mesh.surface_set_material(0,snow_material if kind in ["house","tree"] else material)
			cache[key] = mesh
			return mesh
	var parts: Array = []
	var color: Color = roofs[variant % roofs.size()]
	if kind.begins_with("farm_"):
		cache[key] = farm_mesh(kind.trim_prefix("farm_"))
		return cache[key]
	if kind in ["shop", "tower"]:
		var street = StreetModels.new(self)
		cache[key] = bake(street.shop(city_profile, variant) if kind == "shop" else street.tower(city_profile, variant), snow_material)
		return cache[key]
	var region = RegionModels.new(self)
	match kind:
		"patrol_tank":
			cache[key] = fit_footprint(bake(region.boss("tank")), 1.5)
			return cache[key]
		"boss":
			# Landmarks and defence units are scaled to the level radius at runtime.
			var baked := meshy_landmark(boss_style)
			if baked:
				cache[key] = baked
				return baked
			var boss_parts: Array = Landmarks.new().build(self, boss_style) if Campaign.LANDMARKS.has(boss_style) else region.boss(boss_style)
			cache[key] = fit_footprint(bake(boss_parts), 2.8)
			return cache[key]
		"saucer":
			cache[key] = bake(region.saucer())
			return cache[key]
		"bomb":
			# Gas canister: red drum, yellow hazard band, dark fuse cap.
			parts.append(piece("cyl", Vector3(0, 0.4, 0), Vector3(0.36, 0.72, 0.36), Color("d8453b")))
			parts.append(piece("cyl", Vector3(0, 0.45, 0), Vector3(0.38, 0.14, 0.38), Color("ffd24a")))
			parts.append(piece("cyl", Vector3(0, 0.83, 0), Vector3(0.12, 0.12, 0.12), Color("2d2d33")))
		"duck":
			# Daily stampede: a chunky yellow duck that faces +z.
			parts.append(piece("ball", Vector3(0, 0.32, -0.05), Vector3(0.36, 0.28, 0.44), Color("ffd84a")))
			parts.append(piece("ball", Vector3(0, 0.64, 0.24), Vector3.ONE*0.2, Color("ffe066")))
			parts.append(piece("box", Vector3(0, 0.6, 0.47), Vector3(0.16, 0.06, 0.16), Color("ff9a3c")))
			parts.append(piece("ball", Vector3(0, 0.38, -0.46), Vector3(0.14, 0.12, 0.14), Color("f2c230")))
			for x in [-0.08, 0.08]:
				parts.append(piece("ball", Vector3(x, 0.7, 0.4), Vector3.ONE*0.035, Color("1d2430")))
				parts.append(piece("box", Vector3(x*1.4, 0.04, 0.05), Vector3(0.12, 0.06, 0.18), Color("ff9a3c")))
		"coin":
			# Daily coin rain: a standing gold coin with a darker rim.
			parts.append(piece("cyl", Vector3(0, 0.42, 0), Vector3(0.36, 0.08, 0.36), Color("e0a526"), Vector3(PI/2, 0, 0)))
			parts.append(piece("cyl", Vector3(0, 0.42, 0), Vector3(0.27, 0.1, 0.27), Color("ffd95a"), Vector3(PI/2, 0, 0)))
		"gold":
			# Daily gold rush: bars, a treasure chest and a golden statue.
			match variant:
				0:
					parts.append(piece("frustum", Vector3(0, 0.14, 0), Vector3(0.36, 0.28, 0.22), Color("f2c23a"), Vector3(0, PI/4, 0)))
					parts.append(piece("frustum", Vector3(0.05, 0.4, 0), Vector3(0.3, 0.24, 0.18), Color("ffd95a"), Vector3(0, PI/4, 0)))
				1:
					parts.append(piece("box", Vector3(0, 0.35, 0), Vector3(1.3, 0.7, 0.85), Color("8a5a2b")))
					parts.append(piece("cyl", Vector3(0, 0.72, 0), Vector3(0.43, 1.3, 0.43), Color("a06a34"), Vector3(0, 0, PI/2)))
					parts.append(piece("box", Vector3(0, 0.45, 0), Vector3(1.34, 0.12, 0.9), Color("ffd24a")))
					parts.append(piece("box", Vector3(0, 0.5, 0.44), Vector3(0.22, 0.26, 0.06), Color("ffe58a")))
					for i in 5: parts.append(piece("ball", Vector3(-0.4 + i*0.2, 0.98, 0.05*(i%2)), Vector3.ONE*0.14, Color("ffd95a")))
				_:
					parts.append(piece("cyl", Vector3(0, 0.25, 0), Vector3(1.1, 0.5, 1.1), Color("c79a3a")))
					parts.append(piece("ball", Vector3(0, 1.3, 0), Vector3(0.62, 0.85, 0.5), Color("f2c23a")))
					parts.append(piece("ball", Vector3(0, 2.35, 0), Vector3.ONE*0.42, Color("ffd95a")))
					parts.append(piece("roof", Vector3(0, 2.95, 0), Vector3(0.4, 0.5, 0.4), Color("ffe58a")))
					for x in [-0.7, 0.7]: parts.append(piece("ball", Vector3(x, 1.75, 0), Vector3(0.18, 0.5, 0.18), Color("f2c23a"), Vector3(0, 0, -x)))
		"barrier":
			# Roadblock: striped concrete barriers and a warning sign.
			for x in [-1.2, 0.0, 1.2]:
				parts.append(piece("frustum", Vector3(x, 0.4, 0), Vector3(0.62, 0.8, 0.5), Color("d8d6cf"), Vector3(0, PI/4, 0)))
				parts.append(piece("box", Vector3(x, 0.55, 0), Vector3(0.9, 0.16, 0.66), Color("e8553d")))
			parts.append(piece("cylinder", Vector3(0, 1.3, -0.1), Vector3(0.05, 1.0, 0.05), Color("5d6f7c")))
			parts.append(piece("box", Vector3(0, 1.75, -0.1), Vector3(1.0, 0.5, 0.06), Color("ffcf3a")))
			parts.append(piece("box", Vector3(0, 1.75, -0.07), Vector3(0.8, 0.1, 0.04), Color("2d2d33")))
		"soldier": parts = region.soldier()
		"drone": parts = region.drone()
		"house": parts = region.house(region_style, color, variant)
		"tree": parts = region.tree(region_style, foliage, variant)
		"car":
			parts.append(piece("box", Vector3(0, 0.38, 0), Vector3(1.5, 0.42, 0.77), color))
			parts.append(piece("box", Vector3(-0.1, 0.72, 0), Vector3(0.8, 0.36, 0.66), Color("accfd9")))
			parts.append(piece("box", Vector3(-0.1, 0.93, 0), Vector3(0.86, 0.1, 0.75), color))
			for x in [-0.48, 0.48]:
				for z in [-0.38, 0.38]:
					parts.append(piece("cylinder", Vector3(x, 0.23, z), Vector3(0.23, 0.14, 0.23), Color("354355"), Vector3(PI/2, 0, 0)))
			parts.append(piece("box", Vector3(0.77, 0.44, 0), Vector3(0.06, 0.14, 0.58), Color("fff0b3")))
		"person":
			parts.append(piece("cylinder", Vector3(0, 0.38, 0), Vector3(0.14, 0.4, 0.14), color))
			parts.append(piece("ball", Vector3(0, 0.7, 0), Vector3(0.16, 0.17, 0.16), Color("efd1b0")))
			for x in [-0.08, 0.08]:
				parts.append(piece("box", Vector3(x, 0.12, 0), Vector3(0.09, 0.24, 0.13), Color("435568")))
		"cone":
			parts.append(piece("box", Vector3(0, 0.065, 0), Vector3(0.43, 0.13, 0.43), Color("bd7f59")))
			parts.append(piece("roof", Vector3(0, 0.3, 0), Vector3(0.23, 0.5, 0.23), Color("f4aa70")))
		"bench":
			parts.append(piece("box", Vector3(0, 0.38, 0), Vector3(1.15, 0.12, 0.46), Color("c49a75")))
			parts.append(piece("box", Vector3(0, 0.7, -0.2), Vector3(1.15, 0.5, 0.1), Color("d3aa81")))
			for x in [-0.4, 0.4]:
				parts.append(piece("box", Vector3(x, 0.2, 0), Vector3(0.1, 0.4, 0.38), Color("506974")))
		"signal":
			parts.append(piece("cylinder", Vector3(0, 0.7, 0), Vector3(0.06, 1.4, 0.06), Color("5d6f7c")))
			parts.append(piece("box", Vector3(0, 1.42, 0), Vector3(0.3, 0.42, 0.26), Color("2d3b48")))
			parts.append(piece("box", Vector3(0, 0.03, 0), Vector3(0.3, 0.06, 0.3), Color("5d6f7c")))
	cache[key] = bake(parts)
	if kind in ["house","tree"]: cache[key].surface_set_material(0,snow_material)
	return cache[key]

# Shrink a baked mesh so its ground footprint fits the swallow radius.
# Baked by tools/bake_landmarks.gd from Meshy GLBs; null falls back to primitives.
func meshy_landmark(id: String) -> ArrayMesh:
	var path := "res://assets/landmarks/" + id + ".res"
	var texture_path := "res://assets/landmarks/" + id + "_albedo.res"
	if not ResourceLoader.exists(path) or not ResourceLoader.exists(texture_path): return null
	var mesh: ArrayMesh = load(path).duplicate()
	landmark_material.set_shader_parameter("albedo_tex", load(texture_path))
	mesh.surface_set_material(0, landmark_material)
	return mesh

func fit_footprint(mesh: ArrayMesh, limit: float) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var footprint := 0.0
	for v in vertices: footprint = maxf(footprint, Vector2(v.x,v.z).length())
	if footprint <= limit: return mesh
	for i in vertices.size(): vertices[i] *= limit/footprint
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,material)
	return mesh

func farm_mesh(id: String, scale_value := 1.0) -> ArrayMesh:
	var source: ArrayMesh = load("res://assets/farm/"+id+".res")
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size(): vertices[i] *= scale_value
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if id == "chicken":
		# The source chick has no eye material. Add two tiny baked eyes, also
		# visible on the giant version, without extra draw calls or scene nodes.
		var eye := SphereMesh.new()
		eye.radius = 0.019; eye.height = 0.038; eye.radial_segments = 8; eye.rings = 4
		var eye_arrays := eye.get_mesh_arrays()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for x in [-0.063,0.063]:
			var offset := vertices.size()
			for i in eye_arrays[Mesh.ARRAY_VERTEX].size():
				vertices.append((eye_arrays[Mesh.ARRAY_VERTEX][i]+Vector3(x,0.46,0.195))*scale_value)
				normals.append(eye_arrays[Mesh.ARRAY_NORMAL][i])
				colors.append(Color("26394a").srgb_to_linear())
			for i in eye_arrays[Mesh.ARRAY_INDEX]: indices.append(offset+i)
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
		# Godot may synthesize tangents when reading a mesh. This material has
		# no normal map, and the old tangent array predates the appended eyes.
		arrays[Mesh.ARRAY_TANGENT] = null
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	result.surface_set_material(0,material)
	return result
