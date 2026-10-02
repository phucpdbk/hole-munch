extends RefCounted

# Three goals per city, one star each. Goal 0 is always conquering the city; the
# other two rotate through the pool so every city asks for a different skill.
# Goals only count on a won round, and stars are kept per goal across replays.
const FIRST = ["clean", "combo", "fast"]
const SECOND = ["nohit", "hunter", "spotless"]
const CLEAN_PCT := 0.75
const SPOTLESS_PCT := 0.9
const FAST_SHARE := 0.2

const I18n = preload("res://scripts/i18n.gd")

# Returns [{"id", "value"}] for a level; label() words a goal in the current language.
static func goals(info: Dictionary) -> Array:
	var index: int = info.index
	var list: Array = [{"id":"win", "value":0}]
	list.append(make(FIRST[index%FIRST.size()], info))
	var second: String = "rival" if info.get("rival", false) else SECOND[(index/FIRST.size())%SECOND.size()]
	list.append(make(second, info))
	return list

static func make(id: String, info: Dictionary) -> Dictionary:
	var index: int = info.index
	match id:
		"clean": return {"id":id, "value":CLEAN_PCT}
		"spotless": return {"id":id, "value":SPOTLESS_PCT}
		"combo": return {"id":id, "value":12 + index/2}
		"fast": return {"id":id, "value":int(ceilf(float(info.seconds)*FAST_SHARE/5.0)*5.0)}
		"hunter": return {"id":id, "value":mini(defender_count(index), 2 + index/12)}
		"nohit", "rival": return {"id":id, "value":0}
	return {"id":"win", "value":0}

static func label(goal: Dictionary) -> String:
	match goal.id:
		"clean", "spotless": return I18n.t("g_clean", roundi(goal.value*100))
		"combo", "fast", "hunter": return I18n.t("g_" + goal.id, int(goal.value))
		"nohit", "rival": return I18n.t("g_" + goal.id)
	return I18n.t("g_win")

# Mirrors the guard squad size placed by game.gd.
static func defender_count(index: int) -> int:
	return mini(8, 3 + index/8)

# run: {won, completion, best_combo, remaining, hits, defenders_eaten, rival_eaten}
static func met(goal: Dictionary, run: Dictionary) -> bool:
	if not run.won: return false
	match goal.id:
		"win": return true
		"clean", "spotless": return run.completion >= goal.value
		"combo": return run.best_combo >= goal.value
		"fast": return run.remaining >= goal.value
		"hunter": return run.defenders_eaten >= goal.value
		"nohit": return run.hits == 0
		"rival": return run.rival_eaten
	return false

# How far this round got toward a goal, in numbers that read in every language
# ("50%/75%", "9/12"); empty for the win itself.
static func progress_text(goal: Dictionary, run: Dictionary) -> String:
	match goal.id:
		"clean", "spotless": return "%d%%/%d%%" % [roundi(run.completion*100), roundi(goal.value*100)]
		"combo": return "%d/%d" % [run.best_combo, goal.value]
		"fast": return "%ds/%ds" % [int(run.remaining) if run.won else 0, goal.value]
		"hunter": return "%d/%d" % [run.defenders_eaten, goal.value]
		"nohit": return "%d/0" % run.hits
		"rival": return "%d/1" % int(run.rival_eaten)
	return ""

# Bit i set when goal i was met this round.
static func evaluate(list: Array, run: Dictionary) -> int:
	var mask := 0
	for i in list.size():
		if met(list[i], run): mask |= 1 << i
	return mask

static func count(mask: int) -> int:
	var total := 0
	for i in 3:
		if mask & (1 << i): total += 1
	return total
