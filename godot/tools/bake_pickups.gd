extends SceneTree

# Bakes Meshy power-up GLBs from assets/pickups_src (named by pickup kind, see
# mechanics.gd PICKUPS: time, magnet, speed, freeze) into
# assets/pickups/<kind>.res plus its albedo, centred on its own middle (it
# floats and spins) and PICKUP_RADIUS wide. mechanics.gd shows these inside the
# coloured halo instead of the plain orb.
#   Godot --headless --path . --script res://tools/bake_pickups.gd [-- time magnet]
const MeshyBake = preload("res://tools/meshy_bake.gd")
const SOURCE := "res://assets/pickups_src/"
const TARGET := "res://assets/pickups/"
const PICKUP_RADIUS := 0.55
# Small on screen: fewer triangles than a saucer.
const MIN_TRIANGLES := 1200

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TARGET)
	var failed := 0
	for id in MeshyBake.requested_ids(SOURCE):
		var data := MeshyBake.load_glb(SOURCE + id + ".glb")
		var error := ERR_INVALID_DATA
		if not data.is_empty():
			MeshyBake.normalize(data, PICKUP_RADIUS, 0.0, false)
			error = MeshyBake.save(data, TARGET + id, MIN_TRIANGLES)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)
