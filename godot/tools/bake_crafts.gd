extends SceneTree

# Bakes Meshy saucer GLBs from assets/crafts_src (named by craft index, 0.glb to
# 7.glb, see fleet.gd NAMES) into assets/crafts/<index>.res plus its albedo:
# centred on its own middle (the craft hovers), widest radius CRAFT_RADIUS like
# the primitive crafts. fleet.gd prefers these over the primitive crafts.
#   Godot --headless --path . --script res://tools/bake_crafts.gd [-- 0 3]
const MeshyBake = preload("res://tools/meshy_bake.gd")
const SOURCE := "res://assets/crafts_src/"
const TARGET := "res://assets/crafts/"
const CRAFT_RADIUS := 1.6
# Crafts are small on screen; keep fewer triangles than a landmark.
const MIN_TRIANGLES := 1500
# Per-craft yaw fix (degrees) when Meshy's front does not face the camera (+z).
const YAW := {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TARGET)
	var failed := 0
	for id in MeshyBake.requested_ids(SOURCE):
		var data := MeshyBake.load_glb(SOURCE + id + ".glb")
		var error := ERR_INVALID_DATA
		if not data.is_empty():
			MeshyBake.normalize(data, CRAFT_RADIUS, float(YAW.get(id, 0.0)), false)
			error = MeshyBake.save(data, TARGET + id, MIN_TRIANGLES)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)
