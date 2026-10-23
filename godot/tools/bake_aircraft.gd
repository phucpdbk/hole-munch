extends SceneTree

# Bakes the sky siege's Meshy air force (tools/meshy/aircraft.json: heli, jet,
# flak, blimp) from assets/aircraft_src into assets/aircraft/<kind>.res plus its
# albedo. Each is RADIUS[kind] wide; the flak truck stands on the ground, the
# rest are centred on their middle since they fly. Models face +z (nose first);
# YAW turns a bad bake round. sky_siege.gd shows these instead of its blocks.
# The helicopter's main rotor (every triangle in the top ROTOR_BAND of the
# model) is cut out into heli_rotor.res, centred on its hub, so the game can
# spin it; the hub's position is kept in the mesh's "hub" meta.
#   Godot --headless --path . --script res://tools/bake_aircraft.gd [-- heli jet]
const MeshyBake = preload("res://tools/meshy_bake.gd")
const SOURCE := "res://assets/aircraft_src/"
const TARGET := "res://assets/aircraft/"
const RADIUS := {"heli":1.0, "jet":1.0, "flak":0.85, "blimp":2.4}
const GROUNDED := ["flak"]
# Meshy built the flyers nose toward -x (checked by their height profile: low
# narrow nose, tall tail fins at +x); +90 turns the nose to +z.
const YAW := {"heli":90.0, "jet":90.0, "blimp":90.0}
# Small on screen, several at once: fewer triangles than a saucer.
const MIN_TRIANGLES := 1500
const ROTOR_BAND := 0.1
const ROTOR_TRIANGLES := 300

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TARGET)
	var failed := 0
	for id in MeshyBake.requested_ids(SOURCE):
		var data := MeshyBake.load_glb(SOURCE + id + ".glb")
		var error := ERR_INVALID_DATA
		if not data.is_empty():
			MeshyBake.normalize(data, float(RADIUS.get(id, 1.0)), float(YAW.get(id, 0.0)), id in GROUNDED)
			if id == "heli": error = save_heli(data)
			else: error = MeshyBake.save(data, TARGET + id, MIN_TRIANGLES)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)

# The body without its main rotor, then the rotor on its own around its hub.
func save_heli(data: Dictionary) -> Error:
	var vertices: PackedVector3Array = data.vertices
	var top := -INF
	for v in vertices: top = maxf(top, v.y)
	var cut := top - ROTOR_BAND
	var body := PackedInt32Array()
	var blades := PackedInt32Array()
	var hub := Vector3.ZERO
	var count := 0
	var indices: PackedInt32Array = data.indices
	for t in range(0, indices.size(), 3):
		var tri := [indices[t], indices[t + 1], indices[t + 2]]
		if tri.all(func(i): return vertices[i].y > cut):
			blades.append_array(tri)
			for i in tri:
				hub += vertices[i]
				count += 1
		else: body.append_array(tri)
	if blades.is_empty(): return MeshyBake.save(data, TARGET + "heli", MIN_TRIANGLES)
	hub = Vector3(hub.x/count, 0, hub.z/count)
	var error := MeshyBake.save(data.merged({"indices":body}, true), TARGET + "heli", MIN_TRIANGLES)
	if error != OK: return error
	var centred := PackedVector3Array()
	for v in vertices: centred.append(v - hub)
	error = MeshyBake.save(data.merged({"vertices":centred, "indices":blades}, true), TARGET + "heli_rotor", ROTOR_TRIANGLES)
	if error != OK: return error
	# The rotor uses heli_albedo.res; its own copy of the texture is not needed.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TARGET + "heli_rotor_albedo.res"))
	var rotor: ArrayMesh = load(TARGET + "heli_rotor.res")
	rotor.set_meta("hub", hub)
	return ResourceSaver.save(rotor, TARGET + "heli_rotor.res", ResourceSaver.FLAG_COMPRESS)
