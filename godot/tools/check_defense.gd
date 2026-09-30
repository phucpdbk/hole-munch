extends SceneTree

func unit(boss := false) -> Dictionary:
	return {"position":Vector3.ZERO,"eaten":false,"fall":-1.0,"hidden":false,"defender":not boss,"is_boss":boss,"kind":"boss" if boss else "soldier","radius":2.8 if boss else 0.36,"yaw":0.0}

func _initialize() -> void:
	var d = preload("res://scripts/defense.gd").new()
	var soldier := unit()
	d.reset([soldier],false,0)
	for i in 90: assert(not d.update(0.1,Vector3.ZERO,0))
	assert(d.strikes.is_empty(),"Opening grace must be safe")
	d.grace = 0
	d.units[0].cooldown = 0
	d.update(0.01,Vector3.ZERO,0)
	assert(d.strikes.size() == 1)
	var shot: Dictionary = d.strikes[0]
	shot.time = shot.flight
	assert(d.projectile_position(shot).distance_to(shot.start) < 0.001)
	shot.time = 0
	assert(d.projectile_position(shot).distance_to(shot.target+Vector3(0,0.15,0)) < 0.001)
	shot.time = shot.duration
	var target: Vector3 = d.strikes[0].target
	for i in 15: assert(not d.update(0.1,Vector3(8,0,0),0),"Moving out should dodge")
	assert(target == Vector3.ZERO and d.hits == 0,"Warning must not chase the player")
	d.units[0].cooldown = 0
	d.update(0.01,Vector3.ZERO,0)
	for i in 15: d.update(0.1,Vector3.ZERO,0)
	assert(d.hits == 1 and d.speed_multiplier() < 1,"Standing in warning should slow player")
	d.units[0].cooldown = 0
	d.update(0.01,Vector3.ZERO,0)
	soldier.fall = 0.0
	d.update(0.1,Vector3.ZERO,0)
	assert(d.strikes.is_empty() and d.active_count() == 0,"Swallowing cancels a defender's attack")
	d.reset([unit(),unit(),unit(),unit(true)],true,47)
	d.grace = 0
	for u in d.units: u.cooldown = 0
	d.update(0.01,Vector3.ZERO,47)
	assert(d.strikes.size() == 3,"Warnings must be capped")
	for i in 16: d.update(0.1,Vector3.ZERO,47)
	assert(d.hits == 1,"Overlapping blasts must not stack damage")
	d.reset([],false,0)
	assert(d.hits == 0 and d.slow == 0 and d.strikes.is_empty(),"Retry resets all combat state")
	var patrol := unit()
	patrol.position = Vector3(-9,0,9)
	d.reset([patrol],false,0)
	d.roads_x.assign([-9.0,9.0])
	d.roads_z.assign([-9.0,9.0])
	d.grace = 0
	for u in d.units: u.cooldown = 999.0
	for i in 10: d.update(0.1,Vector3(9,0,-9),0)
	assert(patrol.position.x > -9 and is_equal_approx(patrol.position.z,9),"Reinforcements approach along roads")
	print("DEFENSE CHECKS: grace, dodge, hit, cancellation, cap, immunity and reset passed")
	quit()
