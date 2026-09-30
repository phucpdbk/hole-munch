extends RefCounted

# Alien invasion campaign: six continents, eight cities each. Odd city slots end
# with a landmark to swallow; even slots with an Earth defence unit, and every
# continent closes with a giant titan. Weather is visual only.
const REGIONS = [
	{"id":"asia", "name":"CHÂU Á",
		"palette":["7c9c8c", "5d6970", "ddd3b3", "a9c48f", "e9a3bd", "c9e0dd", "c4574b", "3f8f86"],
		"weather":["clear", "rain", "fog", "sun", "clear", "wind", "snow", "storm"],
		"cities":[["Hà Nội", "onepillar"], ["Seoul", "tank"], ["Hà Nội", "khuevan"], ["Bangkok", "heli"],
			["Agra", "taj"], ["Thượng Hải", "mech"], ["Shizuoka", "fuji"], ["Tokyo", "titan"]]},
	{"id":"europe", "name":"CHÂU ÂU",
		"palette":["8f9a8c", "666d77", "e3d6bf", "b3c490", "7fae78", "c6d8e6", "c9674f", "3e6f95"],
		"weather":["clear", "wind", "rain", "fog", "sun", "rain", "clear", "snow"],
		"cities":[["Paris", "eiffel"], ["Berlin", "tank"], ["London", "bigben"], ["Madrid", "heli"],
			["Pisa", "pisa"], ["Amsterdam", "mech"], ["Rome", "colosseum"], ["Moskva", "titan"]]},
	{"id":"africa", "name":"CHÂU PHI",
		"palette":["c9ae7b", "8c7f70", "e8cf9c", "d6c07f", "8fa65c", "f0dcb0", "c27a4a", "e0b35e"],
		"weather":["sun", "clear", "wind", "sun", "clear", "storm", "sun", "wind"],
		"cities":[["Giza", "pyramid"], ["Cairo", "tank"], ["Giza", "sphinx"], ["Nairobi", "heli"],
			["Djenné", "djenne"], ["Lagos", "mech"], ["Madagascar", "baobab"], ["Cape Town", "titan"]]},
	{"id":"namerica", "name":"BẮC MỸ",
		"palette":["8e9c9a", "5f6773", "dfdad0", "a8bf94", "6f9f6b", "bcd6ea", "d06a5b", "5b86b5"],
		"weather":["clear", "snow", "wind", "rain", "fog", "sun", "clear", "storm"],
		"cities":[["New York", "liberty"], ["Chicago", "tank"], ["New York", "empire"], ["Toronto", "heli"],
			["Seattle", "needle"], ["Los Angeles", "mech"], ["Mexico", "chichen"], ["Washington", "titan"]]},
	{"id":"samerica", "name":"NAM MỸ",
		"palette":["7fa386", "5f6b6a", "e6d9b5", "9cc47d", "4f9b5c", "c3e3dc", "e0704f", "f0b843"],
		"weather":["sun", "rain", "fog", "clear", "wind", "storm", "sun", "rain"],
		"cities":[["Rio", "christ"], ["São Paulo", "tank"], ["Cusco", "machu"], ["Lima", "heli"],
			["Buenos Aires", "obelisco"], ["Bogotá", "mech"], ["Rio", "sugarloaf"], ["Santiago", "titan"]]},
	{"id":"oceania", "name":"CHÂU ĐẠI DƯƠNG",
		"palette":["81b7c5", "6c8591", "eadfbd", "b9c7a4", "5ea77d", "b4dce7", "e38a64", "4aa0b8"],
		"weather":["clear", "wind", "sun", "rain", "clear", "storm", "fog", "sun"],
		"cities":[["Sydney", "sydney"], ["Melbourne", "tank"], ["Uluru", "uluru"], ["Perth", "heli"],
			["Auckland", "skytower"], ["Fiji", "mech"], ["Rapa Nui", "moai"], ["Canberra", "titan"]]},
]
const CITIES_PER_REGION := 8
const LANDMARKS = {"onepillar":"CHÙA MỘT CỘT", "khuevan":"KHUÊ VĂN CÁC", "taj":"TAJ MAHAL", "fuji":"NÚI PHÚ SĨ",
	"eiffel":"THÁP EIFFEL", "bigben":"BIG BEN", "pisa":"THÁP NGHIÊNG PISA", "colosseum":"ĐẤU TRƯỜNG LA MÃ",
	"pyramid":"KIM TỰ THÁP", "sphinx":"TƯỢNG NHÂN SƯ", "djenne":"ĐẠI THÁNH ĐƯỜNG", "baobab":"CÂY BAOBAB",
	"liberty":"TƯỢNG NỮ THẦN TỰ DO", "empire":"TÒA NHÀ EMPIRE STATE", "needle":"THÁP SPACE NEEDLE", "chichen":"KIM TỰ THÁP MAYA",
	"christ":"TƯỢNG CHÚA CỨU THẾ", "machu":"MACHU PICCHU", "obelisco":"ĐÀI TƯỞNG NIỆM OBELISCO", "sugarloaf":"NÚI SUGARLOAF",
	"sydney":"NHÀ HÁT SYDNEY", "uluru":"ĐÁ ULURU", "skytower":"THÁP SKY TOWER", "moai":"TƯỢNG MOAI"}
# Earth's defence units flee the hole and leave small minions behind.
const DEFENSES = {"tank":"XE TĂNG", "heli":"TRỰC THĂNG", "mech":"ROBOT CHIẾN ĐẤU", "titan":"SIÊU ROBOT TITAN"}
const MINIONS = {"tank":"soldier", "heli":"soldier", "mech":"drone", "titan":"drone"}
# Map grid grows with the campaign; each continent's finale uses the next size up.
const GRIDS = [[3, 3], [5, 3], [5, 5], [5, 7]]
const WEATHER_NAMES = {"clear":"Trời trong", "sun":"Nắng vàng", "wind":"Gió / lá bay", "rain":"Mưa", "fog":"Sương mù", "snow":"Tuyết", "storm":"Giông"}
const SKINS = [
	["Tím cổ điển", "ad99ee", "ded2ff"], ["Kẹo xoắn", "ff83b4", "fff0d2"],
	["Dung nham", "ff6538", "ffd45b"], ["Băng giá", "78cde3", "efffff"],
	["Thiên hà", "7770d6", "eb98dd"], ["Neon", "62ead3", "e7ff9d"],
	["Vàng kim", "e6b95a", "fff2ba"], ["Cầu vồng", "eaa0cd", "93dfcc"],
]
const EFFECTS = ["Bụi mềm", "Giấy màu", "Tinh thể", "Đốm lửa"]
const TRAILS = ["Không vệt", "Bong bóng", "Lấp lánh", "Cầu vồng"]
# [id, name, effect, base cost, max level], ported from the 2D stat upgrades.
const UPGRADES = [
	["size", "KÍCH THƯỚC", "+0,08 bán kính khởi đầu", 80, 8],
	["speed", "TỐC ĐỘ", "+5% tốc độ di chuyển", 70, 10],
	["time", "THỜI GIAN", "+4 giây mỗi màn", 100, 10],
	["magnet", "LỰC HÚT", "Hút đồ nhỏ về phía hố", 150, 5],
	["greed", "THU XU", "+10% xu nhận được", 120, 10],
]
const COST_GROWTH := 1.6
const START_RADIUS := 0.86

var selected := 0
var unlocked := 0
var medals: Array[int] = []
var craft := 0
var skin := 0
var effect := 0
var trail := 0
var best := 0
var coins := 0
var upgrades := {}
var unlock_all_for_testing := bool(ProjectSettings.get_setting("application_custom/testing/unlock_all_levels", false))

static func level_count() -> int:
	return REGIONS.size()*CITIES_PER_REGION

static func boss_name(id: String) -> String:
	return LANDMARKS.get(id, DEFENSES.get(id, id))

# Everything a level needs, derived from its place in the campaign.
static func level_info(index: int) -> Dictionary:
	var region_index := index/CITIES_PER_REGION
	var slot := index%CITIES_PER_REGION
	var region: Dictionary = REGIONS[region_index]
	var city: Array = region.cities[slot]
	var progress := float(index)/float(level_count()-1)
	# Regular cities top out at 5×5; continent finales use the next size up.
	var tier := mini(GRIDS.size()-1, mini(2, index/12) + (1 if slot == CITIES_PER_REGION-1 else 0))
	var grid: Array = GRIDS[tier]
	var blocks: int = grid[0]*grid[1]
	return {"index":index, "region":region_index, "slot":slot, "city":city[0], "boss":city[1],
		"title":"%s · %s" % [city[0], boss_name(city[1]).capitalize()],
		"weather":region.weather[slot], "palette":region.palette, "style":region.id,
		"cols":grid[0], "rows":grid[1],
		"seconds":level_seconds(index, blocks, progress),
		# Share of the map's food the hole must eat before the boss fits.
		"share":lerpf(0.18, 0.45, progress)}

# Par times: how long the deterministic greedy test route needs per city. The
# timer gives generous slack early and less later; regenerate with --campaign-smoke
# (it prints each route) after changing map contents.
const PAR_SECONDS: Array[int] = [68, 64, 61, 69, 70, 65, 68, 101, 66, 62, 68, 62, 104, 96, 101, 122, 102, 98, 91, 102, 107, 97, 104, 105, 100, 105, 106, 110, 106, 104, 103, 109, 97, 103, 110, 99, 105, 105, 101, 110, 106, 98, 104, 101, 117, 114, 102, 108]

static func level_seconds(index: int, blocks: int, progress: float) -> float:
	if index >= PAR_SECONDS.size(): return 35.0 + blocks*20.0
	return ceilf(PAR_SECONDS[index]*lerpf(1.8, 1.35, progress)/5.0)*5.0

func _init() -> void:
	medals.resize(level_count())
	medals.fill(0)
	for u in UPGRADES: upgrades[u[0]] = 0

func can_select(index: int) -> bool:
	return index >= 0 and index < level_count() and (unlock_all_for_testing or index <= unlocked)

func upgrade_cost(id: String) -> int:
	for u in UPGRADES:
		if u[0] == id: return roundi(u[3]*pow(COST_GROWTH, upgrades[id]))
	return 0

func upgrade_max(id: String) -> int:
	for u in UPGRADES:
		if u[0] == id: return u[4]
	return 0

func buy(id: String) -> bool:
	if not upgrades.has(id) or upgrades[id] >= upgrade_max(id): return false
	var cost := upgrade_cost(id)
	if coins < cost: return false
	coins -= cost
	upgrades[id] += 1
	return true

# Small per-level effects help without trivialising the boss, as in 2D.
func stats() -> Dictionary:
	return {"start_radius":START_RADIUS + upgrades.size*0.08, "speed":1.0 + upgrades.speed*0.05,
		"bonus_time":upgrades.time*4.0, "magnet":upgrades.magnet, "coin_mul":1.0 + upgrades.greed*0.1}

func reward(won: bool, stars: int, eaten_points: int) -> int:
	var base := eaten_points/40.0 + stars*15 + 10 + selected*2 if won else eaten_points/100.0
	return roundi(base*stats().coin_mul)

func data() -> Dictionary:
	# A temporary preview selection must not become a permanent unlock.
	return {"version":4, "selected":mini(selected,unlocked), "unlocked":unlocked, "medals":medals,
		"craft":craft, "skin":skin, "effect":effect, "trail":trail, "best":best, "coins":coins, "upgrades":upgrades.duplicate()}

func restore(value: Variant) -> void:
	if not value is Dictionary: return
	# Never trust a partially written or manually edited save.
	for field in ["craft", "skin", "effect", "trail", "best", "coins"]:
		if value.get(field) is float or value.get(field) is int:
			set(field, maxi(0, int(value[field])))
	craft = mini(craft, preload("res://scripts/fleet.gd").NAMES.size()-1)
	skin = mini(skin, SKINS.size()-1)
	effect = mini(effect, EFFECTS.size()-1)
	trail = mini(trail, TRAILS.size()-1)
	var saved = value.get("medals", [])
	if int(value.get("version", 0)) < 4:
		# The invasion campaign replaces the old city/landmark/farm levels. Earlier
		# stars become coins so returning players can start with upgrades.
		if saved is Array:
			for stars in saved:
				if stars is float or stars is int: coins += clampi(int(stars), 0, 3)*25
		return
	for field in ["unlocked", "selected"]:
		if value.get(field) is float or value.get(field) is int:
			set(field, maxi(0, int(value[field])))
	unlocked = mini(unlocked, level_count()-1)
	selected = mini(selected, unlocked)
	if saved is Array:
		for i in mini(saved.size(), medals.size()):
			if saved[i] is float or saved[i] is int: medals[i] = clampi(int(saved[i]), 0, 3)
	var saved_upgrades = value.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for u in UPGRADES:
			var level = saved_upgrades.get(u[0], 0)
			if level is float or level is int: upgrades[u[0]] = clampi(int(level), 0, u[4])

func complete(stars: int, score: int) -> void:
	best = maxi(best, score)
	if selected > unlocked: return
	if stars <= 0: return
	medals[selected] = maxi(medals[selected], stars)
	unlocked = maxi(unlocked, mini(selected+1, level_count()-1))

func region_progress(region_index: int) -> int:
	var count := 0
	for i in CITIES_PER_REGION:
		if medals[region_index*CITIES_PER_REGION+i] > 0: count += 1
	return count

func save_progress() -> void:
	var file := FileAccess.open("user://prototype_save.tmp", FileAccess.WRITE)
	if not file: return
	file.store_string(JSON.stringify(data()))
	file.close()
	DirAccess.rename_absolute("user://prototype_save.tmp", "user://prototype_save.json")
