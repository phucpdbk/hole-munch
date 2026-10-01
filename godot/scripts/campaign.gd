extends RefCounted
const Challenges = preload("res://scripts/challenges.gd")
const Cosmetics = preload("res://scripts/cosmetics.gd")
const I18n = preload("res://scripts/i18n.gd")

# All 48 city objectives are landmarks; military units are independent defenders.
const REGIONS = [
	{"id":"asia", "name":"CHÂU Á",
		"palette":["7c9c8c", "5d6970", "ddd3b3", "a9c48f", "e9a3bd", "c9e0dd", "c4574b", "3f8f86"],
		"weather":["clear", "rain", "fog", "sun", "clear", "wind", "snow", "storm"],
		"cities":[["Hà Nội", "onepillar"], ["Seoul", "namsan"], ["Hà Nội", "khuevan"], ["Bangkok", "watarun"],
			["Agra", "taj"], ["Thượng Hải", "pearl"], ["Shizuoka", "fuji"], ["Tokyo", "tokyotower"]]},
	{"id":"europe", "name":"CHÂU ÂU",
		"palette":["8f9a8c", "666d77", "e3d6bf", "b3c490", "7fae78", "c6d8e6", "c9674f", "3e6f95"],
		"weather":["clear", "wind", "rain", "fog", "sun", "rain", "clear", "snow"],
		"cities":[["Paris", "eiffel"], ["Berlin", "brandenburg"], ["London", "bigben"], ["Madrid", "alcala"],
			["Pisa", "pisa"], ["Amsterdam", "royalpalace"], ["Rome", "colosseum"], ["Moskva", "stbasils"]]},
	{"id":"africa", "name":"CHÂU PHI",
		"palette":["c9ae7b", "8c7f70", "e8cf9c", "d6c07f", "8fa65c", "f0dcb0", "c27a4a", "e0b35e"],
		"weather":["sun", "clear", "wind", "sun", "clear", "storm", "sun", "wind"],
		"cities":[["Giza", "pyramid"], ["Cairo", "cairotower"], ["Giza", "sphinx"], ["Nairobi", "kicc"],
			["Djenné", "djenne"], ["Lagos", "nationaltheatre"], ["Madagascar", "baobab"], ["Cape Town", "tablemountain"]]},
	{"id":"namerica", "name":"BẮC MỸ",
		"palette":["8e9c9a", "5f6773", "dfdad0", "a8bf94", "6f9f6b", "bcd6ea", "d06a5b", "5b86b5"],
		"weather":["clear", "snow", "wind", "rain", "fog", "sun", "clear", "storm"],
		"cities":[["New York", "liberty"], ["Chicago", "willis"], ["New York", "empire"], ["Toronto", "cntower"],
			["Seattle", "needle"], ["Los Angeles", "hollywood"], ["Mexico", "chichen"], ["Washington", "capitol"]]},
	{"id":"samerica", "name":"NAM MỸ",
		"palette":["7fa386", "5f6b6a", "e6d9b5", "9cc47d", "4f9b5c", "c3e3dc", "e0704f", "f0b843"],
		"weather":["sun", "rain", "fog", "clear", "wind", "storm", "sun", "rain"],
		"cities":[["Rio", "christ"], ["São Paulo", "masp"], ["Cusco", "machu"], ["Lima", "limacathedral"],
			["Buenos Aires", "obelisco"], ["Bogotá", "monserrate"], ["Rio", "sugarloaf"], ["Santiago", "costanera"]]},
	{"id":"oceania", "name":"CHÂU ĐẠI DƯƠNG",
		"palette":["81b7c5", "6c8591", "eadfbd", "b9c7a4", "5ea77d", "b4dce7", "e38a64", "4aa0b8"],
		"weather":["clear", "wind", "sun", "rain", "clear", "storm", "fog", "sun"],
		"cities":[["Sydney", "sydney"], ["Melbourne", "flinders"], ["Uluru", "uluru"], ["Perth", "belltower"],
			["Auckland", "skytower"], ["Fiji", "fijitemple"], ["Rapa Nui", "moai"], ["Canberra", "parliament"]]},
]
const CITIES_PER_REGION := 8
const LANDMARKS = {
	"namsan":"THÁP NAMSAN",
	"watarun":"CHÙA WAT ARUN",
	"pearl":"THÁP ĐÔNG PHƯƠNG",
	"tokyotower":"THÁP TOKYO",
	"brandenburg":"CỔNG BRANDENBURG",
	"alcala":"CỔNG ALCALÁ",
	"royalpalace":"CUNG ĐIỆN HOÀNG GIA",
	"stbasils":"NHÀ THỜ THÁNH BASIL",
	"cairotower":"THÁP CAIRO",
	"kicc":"THÁP KICC",
	"nationaltheatre":"NHÀ HÁT QUỐC GIA",
	"tablemountain":"NÚI BÀN",
	"willis":"THÁP WILLIS",
	"cntower":"THÁP CN",
	"hollywood":"BIỂN HOLLYWOOD",
	"capitol":"ĐIỆN CAPITOL",
	"masp":"BẢO TÀNG MASP",
	"limacathedral":"NHÀ THỜ LIMA",
	"monserrate":"ĐỒI MONSERRATE",
	"costanera":"THÁP COSTANERA",
	"flinders":"GA FLINDERS",
	"belltower":"THÁP CHUÔNG PERTH",
	"fijitemple":"ĐỀN SRI SIVA",
	"parliament":"NHÀ QUỐC HỘI",
"onepillar":"CHÙA MỘT CỘT", "khuevan":"KHUÊ VĂN CÁC", "taj":"TAJ MAHAL", "fuji":"NÚI PHÚ SĨ",
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
	# Decorated skins from the 2D game (scripts/hole_style.gd adds the ornaments).
	["Giáng sinh", "2f7d46", "e8423f"], ["La bàn", "27857d", "f2d68a"],
	["Vương miện", "8d6533", "ffd76a"], ["Sao chổi", "6651a9", "9fe8ff"],
	["Chất nhờn độc", "4fd400", "b8ff5c"],
]
# Same order as the 2D shop; prices and rewards live in cosmetics.gd.
const EFFECTS = ["Bụi", "Pháo giấy", "Trái tim", "Ngôi sao", "Mưa xu", "Pixel", "Bông tuyết"]
const TRAILS = ["Không", "Bong bóng", "Lấp lánh", "Tuyết", "Lửa", "Cầu vồng"]
# [id, name, effect, base cost, max level], ported from the 2D stat upgrades.
const UPGRADES = [
	["size", "KÍCH THƯỚC", "+0,05 bán kính khởi đầu", 160, 6],
	["speed", "TỐC ĐỘ", "+4% tốc độ di chuyển", 140, 8],
	["time", "THỜI GIAN", "+1 giây mỗi màn", 200, 5],
	["magnet", "LỰC HÚT", "Hút đồ nhỏ về phía hố", 300, 5],
	["greed", "THU XU", "+8% xu nhận được", 240, 8],
]
const COST_GROWTH := 1.75
const TIME_PER_UPGRADE := 1.0
# Best combo raises the coin reward by 1% per bite, up to +60%.
const COMBO_COIN_CAP := 60
const START_RADIUS := 0.86

var selected := 0
var unlocked := 0
var medals: Array[int] = []
var craft := 0
var skin := 0
var effect := 0
var trail := 0
# Bought looks per slot (indices); journey rewards are owned without being listed.
var owned := {"skins":[0], "effects":[0], "trails":[0]}
var best := 0
var coins := 0
var upgrades := {}
# Per-level bitmask of met goals (see challenges.gd); medals are their counts.
var goals: Array[int] = []
# Today's challenge: {"date":"YYYY-MM-DD", "type":mini-game, "attempts":used,
# "best":score, "won":bool}.
var daily := {}
# Carry-in powers won in daily mini-games, used up at the next campaign round.
var items := {"magnet":0, "speed":0, "time":0}
# Endless survival records.
var endless := {"best":0, "stage":0}
# Intro pages and feature tips already shown (see intro.gd), and the UI language.
var seen: Array[String] = []
var lang := ""
var unlock_all_for_testing := bool(ProjectSettings.get_setting("application_custom/testing/unlock_all_levels", false))

static func level_count() -> int:
	return REGIONS.size()*CITIES_PER_REGION

# Display names follow the chosen language (i18n_strings.gd); the Vietnamese
# tables above stay as the source of ids.
static func boss_name(id: String) -> String:
	if LANDMARKS.has(id): return I18n.t("lm_" + id)
	if DEFENSES.has(id): return I18n.t("def_" + id)
	return id

static func city_name(boss: String, fallback: String) -> String:
	return I18n.t("c_" + boss) if I18n.has("c_" + boss) else fallback

static func region_name(region_index: int) -> String:
	return I18n.t("reg_" + str(REGIONS[region_index].id))

static func weather_name(kind: String) -> String:
	return I18n.t("w_" + kind)

static func skin_name(index: int) -> String:
	return I18n.t("skin%d" % index)

static func effect_name(index: int) -> String:
	return I18n.t("fx%d" % index)

static func trail_name(index: int) -> String:
	return I18n.t("trail%d" % index)

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
	var city_label := city_name(city[1], city[0])
	return {"index":index, "region":region_index, "slot":slot, "city":city_label, "boss":city[1],
		"title":"%s · %s" % [city_label, boss_name(city[1])],
		"weather":region.weather[slot], "palette":region.palette, "style":region.id,
		"cols":grid[0], "rows":grid[1],
		"seconds":level_seconds(index, blocks, progress),
		"rival":has_rival(index),
		# Share of the map's food the hole must eat before the boss fits. Dense
		# street fronts hold about four times the food of the old detached houses.
		"share":lerpf(0.2, 0.3, progress)}

# Par times: how long the real-time greedy test route (smoke.gd) needs per city.
# timer gives generous slack early and less later; regenerate with --campaign-smoke
# (it prints each route) after changing map contents.
const PAR_SECONDS: Array[int] = [16, 21, 15, 13, 17, 15, 17, 23, 20, 16, 15, 15, 38, 20, 23, 20, 19, 19, 16, 25, 20, 22, 22, 20, 21, 23, 18, 16, 24, 23, 16, 21, 17, 22, 29, 23, 17, 20, 29, 33, 18, 18, 36, 22, 21, 33, 20, 27]

# Timer = par × slack, never below a floor. The par route plays like a sharp
# player who knows the whole map and takes the landmark the moment it fits, so
# the slack covers steering, dodging, the guardian fight and learning the map,
# and leaves time to keep eating after the landmark falls. Nothing
# adds time in campaign or daily rounds, so this is the whole budget.
const TIME_SLACK_START := 5.0
const TIME_SLACK_END := 3.0
const TIME_FLOOR_START := 75.0
const TIME_FLOOR_END := 45.0

static func level_seconds(index: int, blocks: int, progress: float) -> float:
	if index >= PAR_SECONDS.size(): return 35.0 + blocks*20.0
	var timer := maxf(lerpf(TIME_FLOOR_START, TIME_FLOOR_END, progress), PAR_SECONDS[index]*lerpf(TIME_SLACK_START, TIME_SLACK_END, progress))
	return ceilf(timer/5.0)*5.0

# A rival hole races the player from the second continent: in every third city
# at first, then in every city of the last two continents.
const RIVAL_FROM := 9
const RIVAL_EVERYWHERE := 32

static func has_rival(index: int) -> bool:
	return index >= RIVAL_EVERYWHERE or (index >= RIVAL_FROM and index%CITIES_PER_REGION%3 == 1)

# Stars needed (in total) to enter each continent after the first.
const REGION_STAR_GATE := 14

static func stars_needed(region_index: int) -> int:
	return region_index*REGION_STAR_GATE

func _init() -> void:
	medals.resize(level_count())
	medals.fill(0)
	goals.resize(level_count())
	goals.fill(0)
	for u in UPGRADES: upgrades[u[0]] = 0

func total_stars() -> int:
	var total := 0
	for stars in medals: total += stars
	return total

func region_open(region_index: int) -> bool:
	return unlock_all_for_testing or total_stars() >= stars_needed(region_index)

func can_select(index: int) -> bool:
	return index >= 0 and index < level_count() and (unlock_all_for_testing or (index <= unlocked and region_open(index/CITIES_PER_REGION)))

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

# --- Cosmetic shop (cosmetics.gd) --------------------------------------------
func cities_taken() -> int:
	var total := 0
	for i in goals.size():
		if i < unlocked or goals[i] != 0: total += 1
	return total

func reward_progress(track: String) -> int:
	return total_stars() if track == "stars" else cities_taken()

func reward_earned(slot: String, index: int) -> bool:
	var reward := Cosmetics.reward_for(slot, index)
	return not reward.is_empty() and reward_progress(reward[2]) >= int(reward[3])

func owns(slot: String, index: int) -> bool:
	return index in owned[slot] or reward_earned(slot, index)

func buy_look(slot: String, index: int) -> bool:
	if owns(slot, index) or Cosmetics.reward_only(slot, index): return false
	var cost := Cosmetics.price(slot, index)
	if coins < cost: return false
	coins -= cost
	owned[slot] = owned[slot] + [index]
	return true

func equipped(slot: String) -> int:
	return skin if slot == "skins" else effect if slot == "effects" else trail

func equip(slot: String, index: int) -> bool:
	if index < 0 or index >= Cosmetics.count(slot) or not owns(slot, index): return false
	if slot == "skins": skin = index
	elif slot == "effects": effect = index
	else: trail = index
	return true

# Small per-level effects help without trivialising the boss: a fully grown
# size upgrade (+0.30) still cannot eat street buildings from the start.
const SIZE_PER_UPGRADE := 0.05
const SPEED_PER_UPGRADE := 0.04
const GREED_PER_UPGRADE := 0.08
# Map food pays coins per this many points; stars and the win itself pay the rest,
# so good play earns upgrades faster than grinding the same city.
const POINTS_PER_COIN_WIN := 80.0
const POINTS_PER_COIN_LOSS := 200.0

func stats() -> Dictionary:
	return {"start_radius":START_RADIUS + upgrades.size*SIZE_PER_UPGRADE, "speed":1.0 + upgrades.speed*SPEED_PER_UPGRADE,
		"bonus_time":upgrades.time*TIME_PER_UPGRADE, "magnet":upgrades.magnet, "coin_mul":1.0 + upgrades.greed*GREED_PER_UPGRADE}

func reward(won: bool, stars: int, eaten_points: int, best_combo := 0) -> int:
	var base := eaten_points/POINTS_PER_COIN_WIN + stars*15 + 10 + selected*2 if won else eaten_points/POINTS_PER_COIN_LOSS
	var combo_mul := 1.0 + mini(best_combo, COMBO_COIN_CAP)/100.0
	return roundi(base*combo_mul*stats().coin_mul)

func data() -> Dictionary:
	# A temporary preview selection must not become a permanent unlock.
	return {"version":7, "selected":mini(selected,unlocked), "unlocked":unlocked, "medals":medals, "goals":goals,
		"craft":craft, "skin":skin, "effect":effect, "trail":trail, "owned":owned.duplicate(true), "best":best, "coins":coins, "upgrades":upgrades.duplicate(),
		"daily":daily.duplicate(), "items":items.duplicate(), "endless":endless.duplicate(), "seen":seen.duplicate(), "lang":lang}

func restore(value: Variant) -> void:
	if not value is Dictionary: return
	restore_settings(value)
	# Never trust a partially written or manually edited save.
	for field in ["craft", "skin", "effect", "trail", "best", "coins"]:
		if value.get(field) is float or value.get(field) is int:
			set(field, maxi(0, int(value[field])))
	craft = mini(craft, preload("res://scripts/fleet.gd").NAMES.size()-1)
	skin = mini(skin, SKINS.size()-1)
	effect = mini(effect, EFFECTS.size()-1)
	trail = mini(trail, TRAILS.size()-1)
	restore_owned(value)
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
	# Version 4 kept star counts only; they become the first goals of each city.
	var saved_goals = value.get("goals", [])
	for i in medals.size():
		goals[i] = (1 << medals[i]) - 1
		if saved_goals is Array and i < saved_goals.size() and (saved_goals[i] is float or saved_goals[i] is int):
			goals[i] = clampi(int(saved_goals[i]), 0, 7)
		medals[i] = Challenges.count(goals[i])
	var saved_upgrades = value.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for u in UPGRADES:
			var level = saved_upgrades.get(u[0], 0)
			if level is float or level is int: upgrades[u[0]] = clampi(int(level), 0, u[4])
	restore_records(value)
	# Rewards depend on progress, so equipped looks are checked once it is loaded.
	for slot in Cosmetics.SLOTS:
		if not owns(slot, equipped(slot)): equip(slot, 0)

# Every look was free before version 6: keep what was equipped as owned. Later
# saves list bought indices, which must be in range and are never duplicated.
func restore_owned(value: Dictionary) -> void:
	if int(value.get("version", 0)) < 6:
		effect = Cosmetics.OLD_EFFECTS[mini(effect, Cosmetics.OLD_EFFECTS.size()-1)]
		trail = Cosmetics.OLD_TRAILS[mini(trail, Cosmetics.OLD_TRAILS.size()-1)]
		for slot in Cosmetics.SLOTS:
			if equipped(slot) not in owned[slot]: owned[slot] = owned[slot] + [equipped(slot)]
		return
	var saved = value.get("owned", {})
	if not saved is Dictionary: return
	for slot in Cosmetics.SLOTS:
		var list = saved.get(slot, [])
		if not list is Array: continue
		for item in list:
			if not (item is float or item is int): continue
			var index := int(item)
			if index >= 0 and index < Cosmetics.count(slot) and index not in owned[slot]:
				owned[slot] = owned[slot] + [index]

# Language and seen tips survive every save version, including migrations.
func restore_settings(value: Dictionary) -> void:
	if value.get("lang") is String and value.lang in I18n.LANGS: lang = value.lang
	var saved_seen = value.get("seen", [])
	if not saved_seen is Array: return
	for id in saved_seen:
		if id is String and id.length() <= 32 and id not in seen: seen.append(id)

func restore_records(value: Dictionary) -> void:
	var saved_daily = value.get("daily", {})
	if saved_daily is Dictionary and saved_daily.get("date") is String and saved_daily.date.length() <= 10:
		var record := {"date":saved_daily.date, "type":daily_type(saved_daily.date), "attempts":0, "best":0,
			"won":saved_daily.get("won", false) == true}
		for field in ["best", "attempts"]:
			var number = saved_daily.get(field, 0)
			if number is float or number is int: record[field] = maxi(0, int(number))
		record.attempts = mini(record.attempts, DAILY_ATTEMPTS)
		daily = record
	var saved_items = value.get("items", {})
	if saved_items is Dictionary:
		for kind in items:
			var count = saved_items.get(kind, 0)
			if count is float or count is int: items[kind] = clampi(int(count), 0, MAX_ITEMS)
	var saved_endless = value.get("endless", {})
	if saved_endless is Dictionary:
		for field in ["best", "stage"]:
			if saved_endless.get(field) is float or saved_endless.get(field) is int:
				endless[field] = maxi(0, int(saved_endless[field]))

# Legacy entry point: the first `stars` goals were met.
func complete(stars: int, score: int) -> void:
	complete_goals((1 << clampi(stars, 0, 3)) - 1, score)

# Stars are kept per goal, so different replays can collect different stars.
func complete_goals(mask: int, score: int) -> void:
	best = maxi(best, score)
	if selected > unlocked: return
	if mask & 1 == 0: return
	goals[selected] |= mask & 7
	medals[selected] = Challenges.count(goals[selected])
	unlocked = maxi(unlocked, mini(selected+1, level_count()-1))

# --- Daily challenge -------------------------------------------------------------
# One city and one mini-game per calendar day, the same for everyone, three tries.
# Reaching the mini-game's target the first time that day pays a bonus and a
# carry-in power for the campaign (daily_games.gd has the games themselves).
const DAILY_COIN_BONUS := 1.5
const DAILY_TYPES := ["stampede", "coinrain", "goldrush"]
const DAILY_ATTEMPTS := 3
const MAX_ITEMS := 9
const POWER_KINDS := ["magnet", "speed", "time"]

static func today() -> String:
	return Time.get_date_string_from_system()

static func daily_level(date: String) -> int:
	return absi(hash("hole-munch-" + date)) % level_count()

static func daily_type(date: String) -> String:
	return DAILY_TYPES[absi(hash("type-" + date)) % DAILY_TYPES.size()]

# The power a first daily win hands out, also fixed per day.
static func daily_power(date: String) -> String:
	return POWER_KINDS[absi(hash("power-" + date)) % POWER_KINDS.size()]

func daily_record(date: String) -> Dictionary:
	if daily.get("date", "") == date: return daily
	return {"date":date, "type":daily_type(date), "attempts":0, "best":0, "won":false}

func daily_attempts_left(date: String) -> int:
	return maxi(0, DAILY_ATTEMPTS - int(daily_record(date).attempts))

# Spends one of today's tries; false when none are left.
func use_daily_attempt(date: String) -> bool:
	if daily_attempts_left(date) <= 0: return false
	var record := daily_record(date).duplicate()
	record.attempts = int(record.attempts) + 1
	daily = record
	return true

# Returns true for the first win of that day, which also grants the day's power.
func record_daily(date: String, score: int, won: bool) -> bool:
	var record := daily_record(date)
	var first_win: bool = won and not record.won
	daily = {"date":date, "type":record.type, "attempts":record.attempts, "best":maxi(int(record.best), score), "won":record.won or won}
	if first_win:
		var power := daily_power(date)
		items[power] = mini(MAX_ITEMS, int(items[power]) + 1)
	return first_win

# Takes one of each carry-in power for a campaign round; returns the kinds used.
func use_items() -> Array:
	var used: Array = []
	for kind in POWER_KINDS:
		if int(items[kind]) > 0:
			items[kind] = int(items[kind]) - 1
			used.append(kind)
	return used

# --- Endless survival -----------------------------------------------------------
# Each conquered city leads to a random city one step harder.
const ENDLESS_START_SECONDS := 60.0
const ENDLESS_STAGE_SECONDS := 30.0

static func endless_level(stage: int, rng: RandomNumberGenerator) -> int:
	var region := mini(stage/2, REGIONS.size()-1)
	return region*CITIES_PER_REGION + rng.randi_range(0, CITIES_PER_REGION-2)

# Returns true when this run beats the saved record.
func record_endless(score: int, stage: int) -> bool:
	var record: bool = score > int(endless.best)
	endless = {"best":maxi(int(endless.best), score), "stage":maxi(int(endless.stage), stage)}
	return record

func endless_reward(score: int, stage: int) -> int:
	return roundi((score/120.0 + stage*20)*stats().coin_mul)

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
