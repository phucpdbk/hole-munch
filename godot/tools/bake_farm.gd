extends SceneTree

# Converts the selected flat-color CC0 toys to one surface each. Source scenes
# stay out of runtime; no skeletons, animations, materials per toy or UV uploads.
const ASSETS = {"cow":1.0,"pig":0.72,"chicken":0.28,"tree_oak":0.72,
	"fence_simple":0.65,"crops_cornStageD":0.4,"crops_wheatStageB":0.3,"tent_smallOpen":1.6,"pumpkin":0.3}

func _initialize() -> void:
	for name in ASSETS:
		var scene = load("res://assets/farm/source/"+name+".fbx")
		if not scene is PackedScene:
			push_error("Missing scene: " + name); quit(1); return
		var node: Node3D = scene.instantiate()
		var surfaces: Array = []
		collect(node, Transform3D.IDENTITY, surfaces)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		var bounds := AABB()
		var first := true
		for surface in surfaces:
			if "--inspect" in OS.get_cmdline_user_args(): print(name, " material ", surface.name, " color ", surface.color)
			var arrays: Array = surface.arrays
			var offset := vertices.size()
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				var v: Vector3 = surface.transform * arrays[Mesh.ARRAY_VERTEX][i]
				if first: bounds = AABB(v,Vector3.ZERO); first = false
				else: bounds = bounds.expand(v)
				vertices.append(v)
				normals.append((surface.transform.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
				var color: Color = surface.color
				if name == "chicken": color = Color("f0d27a") if surface.name == "Material.001" else Color("df9853")
				elif surface.name in ["leafsGreen","grass","green"]: color = Color("83a979")
				elif surface.name in ["woodBark","wood","woodDark"]: color = Color("b09272")
				elif name == "crops_wheatStageB": color = Color("d4b875")
				if arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() > i: color *= arrays[Mesh.ARRAY_COLOR][i]
				colors.append(color.srgb_to_linear())
			if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
				for index in arrays[Mesh.ARRAY_INDEX]: indices.append(offset+index)
			else:
				for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(offset+i)
		if first: push_error("Empty model: "+name); node.free(); quit(1); return
		var scale: float = ASSETS[name]*2.0/maxf(bounds.size.x,bounds.size.z)
		var center := bounds.get_center(); center.y = bounds.position.y
		for i in vertices.size(): vertices[i] = (vertices[i]-center)*scale
		if name == "chicken":
			var facing := Basis(Vector3.UP,-PI/2)
			for i in vertices.size():
				vertices[i] = facing*vertices[i]
				normals[i] = facing*normals[i]
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_INDEX]=indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var error := ResourceSaver.save(mesh,"res://assets/farm/"+name+".res",ResourceSaver.FLAG_COMPRESS)
		print(name, ": ", indices.size()/3, " triangles; ", vertices.size(), " vertices; ", error_string(error))
		node.free()
		if error != OK: quit(1); return
	quit()

func collect(node: Node, parent: Transform3D, result: Array) -> void:
	var transform: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var mat = node.get_active_material(i)
			var color := Color.WHITE
			if mat is BaseMaterial3D:
				color = mat.albedo_color
				if mat.albedo_texture: push_warning("Texture needs manual review: "+str(mat.albedo_texture.resource_path))
			result.append({"arrays":node.mesh.surface_get_arrays(i),"transform":transform,"color":color,"name":mat.resource_name if mat else "none"})
	for child in node.get_children(): collect(child,transform,result)
