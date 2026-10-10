extends Node3D

# A Meshy-made army foot unit (assets/soldiers/<id>.scn, made with
# `tools/meshy/meshy.mjs soldiers` and baked by `tools/bake_mascots.gd soldiers`):
# it stands alert, holds an aim pose with its rifle up while the saucer is in
# reach, and panics when the hole closes in. Countries without a model keep the
# primitive toy batch (army_models.gd). The node's scale is the item radius
# (game.gd model_scale), so the model inside is sized against it.
const MODELS := {"vn": {"police":"vn_police", "soldier":"vn_soldier", "rocket":"vn_soldier"}}
const SOURCE_HEIGHT := 1.2
const HEIGHT := 1.75
const GUN := Color("2b2f33")

var player: AnimationPlayer
var state := ""

static func model_id(country: String, unit: String) -> String:
	return MODELS.get(country, {}).get(unit, "")

# Gives every army foot unit of the city's country its Meshy model.
static func dress(g, country: String, look: Dictionary) -> void:
	for item in g.items:
		if not item.get("army", false) or item.has("node"): continue
		var id := model_id(country, item.unit)
		if id == "" or not ResourceLoader.exists("res://assets/soldiers/%s.scn" % id): continue
		var soldier = load("res://scripts/army_soldiers.gd").new()
		g.world.add_child(soldier)
		soldier.build(item, id, look)
		item.node = soldier

func build(item: Dictionary, id: String, look: Dictionary) -> void:
	var model: Node3D = load("res://assets/soldiers/%s.scn" % id).instantiate()
	var inner: float = HEIGHT/(SOURCE_HEIGHT*float(item.radius))
	model.scale = Vector3.ONE*inner
	add_child(model)
	player = find_player(model)
	add_base(Color(look.accent), inner)
	add_weapon(model, item.unit == "rocket", Color(look.paint))
	animate("alert")

# The flag-coloured base the toy units stand on, so both kinds read the same.
func add_base(color: Color, inner: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3*inner
	disc.bottom_radius = 0.3*inner
	disc.height = 0.04*inner
	disc.radial_segments = 16
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	disc.material = material
	var base := MeshInstance3D.new()
	base.mesh = disc
	base.position.y = 0.02*inner
	add_child(base)

# A rifle (or a launcher tube) held in the right hand; the hand bone's +Y runs
# toward the fingers, so the barrel follows the forearm into the aim pose.
func add_weapon(model: Node3D, launcher: bool, paint: Color) -> void:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return
	var skeleton: Skeleton3D = skeletons[0]
	if skeleton.find_bone("RightHand") < 0: return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "RightHand"
	skeleton.add_child(attachment)
	var gun := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = paint.darkened(0.2) if launcher else GUN
	if launcher:
		var tube := CylinderMesh.new()
		tube.top_radius = 0.045
		tube.bottom_radius = 0.045
		tube.height = 0.55
		tube.radial_segments = 8
		tube.material = material
		gun.mesh = tube
	else:
		var box := BoxMesh.new()
		box.size = Vector3(0.035, 0.42, 0.06)
		box.material = material
		gun.mesh = box
	gun.position = Vector3(0, 0.12, 0.03)
	attachment.add_child(gun)

# alert (idle stance), aim (rifle up, held still) or panic.
func animate(mode: String) -> void:
	if mode == state or player == null: return
	state = mode
	match mode:
		"aim":
			player.play("aim")
			player.seek(0.0, true)
			player.pause()
		"panic": player.play("panic", 0.2)
		_: player.play("alert", 0.25)

static func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_player(child)
		if found != null: return found
	return null
