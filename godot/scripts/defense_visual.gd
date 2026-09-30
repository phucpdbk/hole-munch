extends Node3D

# Fixed pools: no new scene nodes or meshes while firing.
var shells: Array[MeshInstance3D] = []
var tails: Array[MeshInstance3D] = []
var flashes: Array[MeshInstance3D] = []
var blasts: Array[MeshInstance3D] = []

func _ready() -> void:
	var ball := SphereMesh.new()
	ball.radius = 0.16
	ball.height = 0.32
	ball.radial_segments = 8
	ball.rings = 4
	var tracer := CylinderMesh.new()
	tracer.top_radius = 0.055
	tracer.bottom_radius = 0.09
	tracer.height = 1.0
	tracer.radial_segments = 6
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.0
	ring.rings = 24
	ring.ring_segments = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffd96a")
	for i in preload("res://scripts/defense.gd").MAX_STRIKES:
		for entry in [[shells,ball],[tails,tracer],[flashes,ball],[blasts,ring]]:
			var mesh := MeshInstance3D.new()
			mesh.mesh = entry[1]
			mesh.material_override = glow
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.visible = false
			add_child(mesh)
			entry[0].append(mesh)

func update(defense, active: bool) -> void:
	for pool in [shells,tails,flashes,blasts]:
		for mesh in pool: mesh.visible = false
	if not active: return
	for i in defense.strikes.size():
		var shot: Dictionary = defense.strikes[i]
		if shot.time > shot.flight: continue
		var pos: Vector3 = defense.projectile_position(shot)
		var direction: Vector3 = (pos-shot.start).normalized()
		shells[i].position = pos
		shells[i].scale = Vector3.ONE*(1.5 if shot.heavy else 1.0)
		shells[i].show()
		if direction.length_squared() > 0.01:
			tails[i].transform = Transform3D(Basis(Quaternion(Vector3.UP,direction)).scaled(Vector3(1,0.9,1)),pos-direction*0.45)
			tails[i].show()
		if shot.flight-shot.time < 0.16:
			flashes[i].position = shot.start
			flashes[i].scale = Vector3.ONE*(3.0 if shot.heavy else 2.0)
			flashes[i].show()
	for i in defense.impacts.size():
		var impact: Dictionary = defense.impacts[i]
		blasts[i].position = impact.position+Vector3(0,0.2,0)
		blasts[i].scale = Vector3.ONE*impact.radius*(1.0-impact.time/0.4)
		blasts[i].show()
