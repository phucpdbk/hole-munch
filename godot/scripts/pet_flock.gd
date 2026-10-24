extends Node3D

# Draws every pet of the snake daily (snake_trail.gd) from the flipbook frames
# tools/bake_critters.gd baked from the Meshy rigs: one MultiMesh per kind,
# clip and frame, so a line of dozens of pets costs a few draw calls and no
# skeleton or AnimationPlayer at all. Each frame the snake lists its pets
# (begin, add, finish); critters.gd picks the clip and frame by speed.
const Critter = preload("res://scripts/critters.gd")
const DIR := "res://assets/critters/"
const MAX_PER_BATCH := 80

var batches := {}
var used := {}
var lengths := {}

# True when every kind has its frames baked (the Meshy pets are in the build).
static func available() -> bool:
	for kind in Critter.KINDS:
		for clip in Critter.FLIP_FRAMES:
			if not ResourceLoader.exists(frame_path(kind, clip, 0)): return false
	return true

static func frame_path(kind: String, clip: String, frame: int) -> String:
	return "%s%s_%s_%d.res" % [DIR, kind, clip, frame]

func batch(key: String, kind: String, clip: String, frame: int) -> MultiMesh:
	if batches.has(key): return batches[key].multimesh
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = load(frame_path(kind, clip, frame))
	multi.instance_count = MAX_PER_BATCH
	multi.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	# No shadows: a pet's is a smudge at this zoom, and it would draw every batch twice.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	batches[key] = node
	return multi

func begin() -> void:
	used.clear()

func add(kind: String, clip: String, frame: int, transform_value: Transform3D) -> void:
	var key := "%s/%s/%d" % [kind, clip, frame]
	var count: int = used.get(key, 0)
	if count >= MAX_PER_BATCH: return
	batch(key, kind, clip, frame).set_instance_transform(count, transform_value)
	used[key] = count + 1

func finish() -> void:
	for key in batches:
		batches[key].multimesh.visible_instance_count = used.get(key, 0)

# A clip's length in seconds, kept on its frames by the bake.
func length(kind: String, clip: String) -> float:
	var key := kind + "/" + clip
	if not lengths.has(key): lengths[key] = float(load(frame_path(kind, clip, 0)).get_meta("length", 0.67))
	return lengths[key]
