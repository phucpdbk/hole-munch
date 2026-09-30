extends SceneTree

func _initialize() -> void:
	var campaign = preload("res://scripts/campaign.gd").new()
	var models = preload("res://scripts/models.gd").new()
	var fleet = preload("res://scripts/fleet.gd").new()
	for i in fleet.NAMES.size():
		var mesh: ArrayMesh = fleet.build(models,i)
		assert(mesh.get_surface_count() == 1, "Craft must use a single mesh surface")
		assert(mesh.get_aabb().size.length() > 1.0, "Craft geometry is empty")
		campaign.craft = i
		var restored = preload("res://scripts/campaign.gd").new()
		restored.restore(JSON.parse_string(JSON.stringify(campaign.data())))
		assert(restored.craft == i, "Craft selection did not survive save/load")
	campaign.restore({"version":4,"craft":999})
	assert(campaign.craft == 7)
	campaign.restore({"version":4,"craft":-5})
	assert(campaign.craft == 0)
	var legacy = preload("res://scripts/campaign.gd").new()
	legacy.restore({"version":4,"skin":3,"coins":164})
	assert(legacy.craft == 0 and legacy.skin == 3 and legacy.coins == 164)
	print("FLEET CHECKS: 8 meshes, save round trips, bounds and existing saves passed")
	quit()
