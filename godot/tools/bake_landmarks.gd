extends SceneTree

# Bakes Meshy GLBs from assets/landmarks_src into game-ready landmark meshes:
# one textured surface, ground at y = 0, footprint normalized to the boss size,
# simplified for mobile. models.gd prefers these over the primitive landmarks.
#   Godot --headless --path . --script res://tools/bake_landmarks.gd [-- eiffel taj]
const MeshyBake = preload("res://tools/meshy_bake.gd")
const SOURCE := "res://assets/landmarks_src/"
const TARGET := "res://assets/landmarks/"
const FOOTPRINT := 2.6
# Per-landmark yaw fix (degrees) when Meshy's front does not face the camera (+z).
const YAW := {}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TARGET)
	var failed := 0
	for id in MeshyBake.requested_ids(SOURCE):
		var error := bake(id)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)

func bake(id: String) -> Error:
	var data := MeshyBake.load_glb(SOURCE + id + ".glb")
	if data.is_empty(): return ERR_INVALID_DATA
	MeshyBake.normalize(data, FOOTPRINT, float(YAW.get(id, 0.0)))
	return MeshyBake.save(data, TARGET + id)
