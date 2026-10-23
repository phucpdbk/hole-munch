extends SceneTree

# Bakes the sky siege's Meshy air force (tools/meshy/aircraft.json: heli, jet,
# flak, blimp) from assets/aircraft_src into assets/aircraft/<kind>.res plus its
# albedo. Each is RADIUS[kind] wide; the flak truck stands on the ground, the
# rest are centred on their middle since they fly. Models face +z (nose first);
# YAW turns a bad bake round. sky_siege.gd shows these instead of its blocks.
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

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(TARGET)
	var failed := 0
	for id in MeshyBake.requested_ids(SOURCE):
		var data := MeshyBake.load_glb(SOURCE + id + ".glb")
		var error := ERR_INVALID_DATA
		if not data.is_empty():
			MeshyBake.normalize(data, float(RADIUS.get(id, 1.0)), float(YAW.get(id, 0.0)), id in GROUNDED)
			error = MeshyBake.save(data, TARGET + id, MIN_TRIANGLES)
		print(id, " : ", error_string(error))
		if error != OK: failed += 1
	quit(1 if failed > 0 else 0)
