extends RefCounted

# Level catalog for design review (`--capture --catalog`, optional `--levels=0,4`).
# For every campaign city it shoots the menu (landmark), the guardian up close and
# the landmark mid-round, then writes test-output/catalog/catalog.js with the city's
# landmark, guardian, weather, map and goal data, plus the review page
# tools/catalog/index.html beside it. Open test-output/catalog/index.html.
const Campaign = preload("res://scripts/campaign.gd")
const Challenges = preload("res://scripts/challenges.gd")
const MapFeatures = preload("res://scripts/map_features.gd")
const MascotSpecs = preload("res://scripts/mascot_specs.gd")
const MascotRig = preload("res://scripts/mascot_rig.gd")
const CityProfiles = preload("res://scripts/city_profiles.gd")
const Landmarks = preload("res://scripts/landmarks.gd")
const OUT := "res://test-output/catalog/"
const PAGE := "res://tools/catalog/index.html"
const JPEG_QUALITY := 0.85

var g
var capture

func run(game, owner) -> void:
	g = game
	capture = owner
	DirAccess.make_dir_recursive_absolute(OUT)
	var picks: Array = range(Campaign.level_count())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--levels="): picks = Array(arg.trim_prefix("--levels=").split(",")).map(func(value): return int(value))
	var levels: Array = []
	for index in picks: levels.append(await shoot(index))
	var data := {"generated":Time.get_datetime_string_from_system(), "levels":levels,
		"weather_names":Campaign.WEATHER_NAMES}
	var file := FileAccess.open(OUT + "catalog.js", FileAccess.WRITE)
	file.store_string("window.CATALOG = " + JSON.stringify(data, "  ") + ";\n")
	file.close()
	DirAccess.copy_absolute(ProjectSettings.globalize_path(PAGE), ProjectSettings.globalize_path(OUT + "index.html"))
	print("catalog: %d levels -> %s" % [levels.size(), ProjectSettings.globalize_path(OUT + "index.html")])

func shoot(index: int) -> Dictionary:
	g.load_level(index)
	var stem := "%02d-%s" % [index+1, g.level.boss]
	g.go_menu()
	await capture.frames(30)
	await save(stem + "-menu")
	g.on_play()
	g.started = true
	g.defense.grace = INF
	var entry := describe(index)
	var guardian: Dictionary = g.mechanics.guardian
	if not guardian.is_empty():
		g.hole_position = Vector3(guardian.position.x + 1.0, 0, guardian.position.z + guardian.radius + 3.0)
		await capture.frames(50)
		await save(stem + "-guardian")
	# The guardian waits at its post (no AI) so it cannot walk in front of the landmark.
	var mascot = g.mechanics.mascot
	if mascot != null:
		guardian.position = Vector3(mascot.home.x, guardian.position.y, mascot.home.z)
		g.set_item_transform(guardian)
		mascot.item = {}
	var boss: Dictionary = g.mechanics.boss
	g.hole_position = Vector3(boss.origin.x + g.boss_radius + 5.0, 0, boss.origin.z)
	await capture.frames(50)
	await save(stem + "-landmark")
	if mascot != null: mascot.item = guardian
	entry.shots = {"menu":stem + "-menu.jpg", "guardian":stem + "-guardian.jpg" if not guardian.is_empty() else "",
		"landmark":stem + "-landmark.jpg"}
	return entry

func save(name: String) -> void:
	await g.get_tree().process_frame
	await RenderingServer.frame_post_draw
	g.get_viewport().get_texture().get_image().save_jpg(OUT + name + ".jpg", JPEG_QUALITY)

func describe(index: int) -> Dictionary:
	var level: Dictionary = g.level
	var boss: String = level.boss
	var spec := MascotSpecs.spec(boss)
	var mascot = g.mechanics.mascot
	var profile: Dictionary = CityProfiles.profile(boss)
	return {"index":index, "number":index+1, "region":Campaign.REGIONS[level.region].id,
		"region_name":Campaign.region_name(level.region), "city":level.city, "boss":boss,
		"landmark":Campaign.boss_name(boss), "landmark_source":landmark_source(boss),
		"weather":level.weather, "weather_name":Campaign.weather_name(level.weather),
		"cols":level.cols, "rows":level.rows, "seconds":roundi(level.seconds),
		"par":Campaign.PAR_SECONDS[index] if index < Campaign.PAR_SECONDS.size() else 0,
		"rival":level.rival, "share":snappedf(level.share, 0.01),
		"boss_radius":snappedf(g.boss_radius, 0.01),
		"goals":Challenges.goals(level).map(func(goal): return Challenges.label(goal)),
		"features":MapFeatures.counts(index),
		"guardian":{"archetype":spec.archetype, "attack":spec.attack, "accessory":spec.accessory,
			"colors":[spec.a.to_html(false), spec.b.to_html(false), spec.c.to_html(false)],
			"source":mascot.rig.source if mascot != null else "none",
			"model":MascotRig.model_path(boss),
			"radius":snappedf(g.mechanics.guardian.get("radius", 0.0), 0.01)},
		"city_style":{"style":profile.style, "towers":profile.towers, "tower":profile.tower,
			"walls":profile.walls, "roof":profile.roof},
		"palette":level.palette}

static func landmark_source(boss: String) -> String:
	if ResourceLoader.exists("res://assets/landmarks/%s.res" % boss): return "meshy"
	if Landmarks.CITY_SITES.has(boss): return "toy:" + str(Landmarks.CITY_SITES[boss][0])
	return "toy"
