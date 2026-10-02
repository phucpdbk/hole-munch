extends Node3D

# How a guardian mascot looks and moves. Three sources, best first:
#   1. A Meshy model with an AnimationPlayer: res://assets/mascots/<id>.scn from
#      tools/bake_mascots.gd (clips named idle, walk, run, attack, hit, leap), or a
#      hand-made <id>.glb whose clip names CLIP_OVERRIDES maps. A missing clip
#      falls back to procedural motion.
#   2. A Meshy model without a skeleton: the whole body bobs, leans, squashes and
#      jumps, which works for any shape (four-legged guardians included).
#   3. The toy primitive rig from mascot_specs.gd, whose limb pivots also swing.
# Every model is normalised to a one-unit footprint standing on y = 0, facing +z,
# and the game scales this node to the guardian's swallow radius.
const MascotSpecs = preload("res://scripts/mascot_specs.gd")
const MODEL_DIR := "res://assets/mascots/"
const FOOTPRINT := 1.0
const DEFAULT_CLIPS := {"idle":"idle", "walk":"walk", "run":"run", "attack":"attack", "hit":"hit", "leap":"leap"}
# Per-landmark fixes for hand-made models: {"id": {"walk":"Walking", "yaw":180}}.
const CLIP_OVERRIDES := {}

var source := "primitive"
var body: Node3D
var pivots := {}
var player: AnimationPlayer
var clips := {}
var current_clip := ""
var winged := false
var clock := 0.0
var stride := 0.0

static func model_path(id: String) -> String:
	for extension in ["scn", "glb", "tscn"]:
		var path: String = MODEL_DIR + id + "." + extension
		if ResourceLoader.exists(path): return path
	return ""

func build(models, spec: Dictionary) -> void:
	winged = spec.get("archetype", "") in ["bird", "dragon"]
	body = Node3D.new()
	add_child(body)
	var path := model_path(str(spec.get("id", "")))
	var scene = load(path) if path != "" else null
	if scene is PackedScene:
		build_meshy(scene.instantiate(), str(spec.id))
	else:
		build_primitive(models, spec)

func build_primitive(models, spec: Dictionary) -> void:
	source = "primitive"
	var shape: Dictionary = MascotSpecs.shape(models, spec)
	for group in shape.parts:
		if shape.parts[group].is_empty(): continue
		var pivot := Node3D.new()
		pivot.position = shape.pivots.get(group, Vector3.ZERO)
		body.add_child(pivot)
		var mesh := MeshInstance3D.new()
		mesh.mesh = models.bake(shape.parts[group])
		pivot.add_child(mesh)
		pivots[group] = pivot

func build_meshy(model: Node3D, id: String) -> void:
	var settings := clip_settings(id)
	var holder := Node3D.new()
	holder.rotation.y = deg_to_rad(float(settings.get("yaw", 0.0)))
	body.add_child(holder)
	holder.add_child(model)
	normalise(holder, model)
	player = find_player(model)
	source = "animated" if player != null else "static"
	if player == null: return
	for state in DEFAULT_CLIPS:
		var wanted := str(settings.get(state, DEFAULT_CLIPS[state]))
		if player.has_animation(wanted): clips[state] = wanted

# Scale the model to a one-unit footprint and stand it on the ground, centred.
func normalise(holder: Node3D, model: Node3D) -> void:
	var box := bounds(model, Transform3D.IDENTITY)
	if box.size.x <= 0.0 or box.size.z <= 0.0: return
	var scale_value := FOOTPRINT/maxf(box.size.x, box.size.z)
	model.scale = Vector3.ONE*scale_value
	var centre := box.get_center()*scale_value
	model.position = Vector3(-centre.x, -box.position.y*scale_value, -centre.z)
	holder.position = Vector3.ZERO

func bounds(node: Node, parent: Transform3D) -> AABB:
	var transform := parent
	if node is Node3D: transform = parent*(node as Node3D).transform
	var box := AABB()
	var found := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = transform*(node as MeshInstance3D).mesh.get_aabb()
		found = true
	for child in node.get_children():
		var inner := bounds(child, transform)
		if inner.size == Vector3.ZERO: continue
		box = box.merge(inner) if found else inner
		found = true
	return box

static func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_player(child)
		if found != null: return found
	return null

static func clip_settings(id: String) -> Dictionary:
	return CLIP_OVERRIDES.get(id, {})

# pose: {state, moving, crouch, lunge, squash, air, hurt, run_speed}
func animate(dt: float, pose: Dictionary) -> void:
	clock += dt
	var moving: float = pose.moving
	var running := moving > 0.1
	if running: stride += dt*(6.0 + moving*1.2)
	var crouch: float = pose.crouch
	var squash: float = pose.squash
	var air: float = pose.air
	var hurt: float = pose.hurt
	var bob := absf(sin(stride))*0.1 if running else sin(clock*2.6)*0.035
	var shrink := crouch*0.22 + squash*0.25
	position = Vector3(0, bob - crouch*0.08, pose.lunge*0.35)
	scale = Vector3(1.0 + shrink*0.6, 1.0 - shrink + air*0.12, 1.0 + shrink*0.6)
	# Lean into a run, shake while winding up, tumble when bitten.
	rotation = Vector3(-crouch*0.12 + (0.12 if running else 0.0) - air*0.3, sin(clock*30.0)*hurt*0.35, sin(clock*40.0)*0.04*crouch + sin(clock*22.0)*hurt*0.25)
	visible = hurt <= 0.0 or fmod(clock, 0.16) < 0.11
	if source == "animated": play_state(pose)
	elif source == "primitive": swing_limbs(pose, running)

func play_state(pose: Dictionary) -> void:
	var state: String = pose.state
	var wanted := "idle"
	if pose.hurt > 0.0: wanted = "hit"
	elif state == "leap": wanted = "leap"
	elif state in ["windup", "charge"]: wanted = "attack"
	elif pose.moving > 3.0: wanted = "run"
	elif pose.moving > 0.1: wanted = "walk"
	if not clips.has(wanted): wanted = "run" if wanted == "leap" and clips.has("run") else "idle"
	if not clips.has(wanted) or clips[wanted] == current_clip: return
	current_clip = clips[wanted]
	player.play(current_clip, 0.15)

func swing_limbs(pose: Dictionary, running: bool) -> void:
	var crouch: float = pose.crouch
	var air: float = pose.air
	var swing := sin(stride)*0.8 if running else 0.0
	for group in pivots:
		var pivot: Node3D = pivots[group]
		match group:
			"leg_l", "leg_br": pivot.rotation.x = swing - air*0.6
			"leg_r", "leg_bl": pivot.rotation.x = -swing - air*0.6
			"arm_l", "arm_r":
				var sign := 1.0 if group == "arm_l" else -1.0
				if winged:
					var busy := running or crouch > 0.0 or air > 0.0
					var flap := sin(clock*(16.0 if busy else 3.0))*(0.7 if busy else 0.15)
					pivot.rotation = Vector3(0, 0, sign*(flap + crouch*0.6))
				else:
					pivot.rotation = Vector3(-crouch*2.2 - swing*sign*0.6 - air*2.4, 0, sign*(0.1 + sin(clock*2.0)*0.05))
			"head": pivot.rotation = Vector3(-crouch*0.25 + pose.lunge*0.3, sin(clock*1.3)*0.25*(1.0 - crouch), 0)
			"tail": pivot.rotation = Vector3(0, sin(clock*(9.0 if running else 3.5))*0.45, 0)
