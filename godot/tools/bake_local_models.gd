extends SceneTree

const MODELS = {
	"person0":["PolygonStarter/Prefabs/Characters/SM_Bean_Female_01.tscn",0.22],
	"person1":["PolygonStarter/Prefabs/Characters/SM_Bean_Town_Female_01.tscn",0.22],
	"person2":["PolygonStarter/Prefabs/Characters/SM_Bean_Cowboy_01.tscn",0.22],
	"house0":["PolygonFarm/Prefabs/Buildings/SM_Bld_Farmhouse_01.tscn",1.5],
	"house1":["PolygonFarm/Prefabs/Buildings/SM_Bld_Farmhouse_02.tscn",1.5],
	"house2":["PolygonFarm/Prefabs/Buildings/SM_Bld_Barn_02.tscn",1.5],
	"tree0":["PolygonFarm/Prefabs/Generic/SM_Generic_Tree_01.tscn",0.68],
	"tree1":["PolygonFarm/Prefabs/Generic/SM_Generic_Tree_02.tscn",0.68],
	"car0":["PolygonStarter/Prefabs/SM_PolygonCity_Veh_Car_Small_01.tscn",0.82],
	"car1":["PolygonFarm/Prefabs/Vehicles/SM_Veh_Pickup_01.tscn",0.82],
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/synty")
	for id in MODELS:
		var scene: PackedScene = load("res://assets/local_source/"+MODELS[id][0])
		if not scene: quit(1); return
		var node := scene.instantiate()
		var surfaces: Array = []
		collect(node,Transform3D.IDENTITY,surfaces)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var indices := PackedInt32Array()
		for surface in surfaces:
			var arrays: Array = surface.arrays
			var offset := vertices.size()
			for i in arrays[Mesh.ARRAY_VERTEX].size():
				vertices.append(surface.transform*arrays[Mesh.ARRAY_VERTEX][i])
				normals.append((surface.transform.basis.inverse().transposed()*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
				var color: Color = surface.color
				if surface.image and arrays[Mesh.ARRAY_TEX_UV] != null:
					var uv: Vector2 = arrays[Mesh.ARRAY_TEX_UV][i]
					var image: Image = surface.image
					color *= image.get_pixel(clampi(int(fposmod(uv.x,1)*image.get_width()),0,image.get_width()-1),clampi(int(fposmod(uv.y,1)*image.get_height()),0,image.get_height()-1))
				colors.append(Color(color,1.0).srgb_to_linear())
			if arrays[Mesh.ARRAY_INDEX] != null and arrays[Mesh.ARRAY_INDEX].size() > 0:
				for index in arrays[Mesh.ARRAY_INDEX]: indices.append(offset+index)
			else:
				for i in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(offset+i)
		var bounds := AABB(vertices[0],Vector3.ZERO)
		for v in vertices: bounds = bounds.expand(v)
		var center := bounds.get_center()
		center.y = bounds.position.y
		var footprint := 0.0
		for v in vertices: footprint = maxf(footprint,Vector2(v.x-center.x,v.z-center.z).length())
		var scale: float = MODELS[id][1]/footprint
		# Source vehicles face +Z; traffic uses +X as its forward axis.
		var turn := Basis(Vector3.UP,PI/2) if id.begins_with("car") else Basis.IDENTITY
		for i in vertices.size():
			vertices[i] = turn*(vertices[i]-center)*scale
			normals[i] = turn*normals[i]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=vertices
		arrays[Mesh.ARRAY_NORMAL]=normals
		arrays[Mesh.ARRAY_COLOR]=colors
		arrays[Mesh.ARRAY_INDEX]=indices
		var simplified := ImporterMesh.new()
		simplified.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
		simplified.generate_lods(60.0,75.0,[])
		var chosen := indices
		var target := maxi(600,indices.size()/15)
		for lod in simplified.get_surface_lod_count(0):
			var candidate := simplified.get_surface_lod_indices(0,lod)
			if candidate.size()/3 >= target and candidate.size() < chosen.size(): chosen = candidate
		arrays[Mesh.ARRAY_INDEX] = chosen
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var error := ResourceSaver.save(mesh,"res://assets/synty/"+id+".res",ResourceSaver.FLAG_COMPRESS)
		print(id," : ",indices.size()/3," -> ",chosen.size()/3," triangles; ",error_string(error))
		node.free()
		if error != OK: quit(1); return
	var ignore := FileAccess.open("res://assets/local_source/.gdignore",FileAccess.WRITE)
	ignore.close()
	quit()

func collect(node: Node, parent: Transform3D, surfaces: Array) -> void:
	var transform: Transform3D = parent*node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var material = node.get_active_material(i)
			var color := Color.WHITE
			var image: Image
			if material is BaseMaterial3D:
				color = material.albedo_color
				if material.albedo_texture: image = material.albedo_texture.get_image()
				if image and image.is_compressed(): image.decompress()
			surfaces.append({"arrays":node.mesh.surface_get_arrays(i),"transform":transform,"color":color,"image":image})
	for child in node.get_children(): collect(child,transform,surfaces)
