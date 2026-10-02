extends RefCounted

# Prize seasons: the top players of a season's daily-challenge leaderboard win a
# real saucer model. Each season has its own Play Games leaderboard (all-time
# span), so its final ranks stay readable after it ends; daily rounds played
# inside the season also submit there (game.gd).
#
# Nothing shows until a season is listed here with a leaderboard id, and the
# contact address and rules page are filled in: running a prize draw needs
# official rules (eligibility, shipping regions, dates, how winners are picked
# and contacted) and, on Google Play, a statement that Google is not a sponsor.
# Example entry:
#   {"id":"2026-11", "start":"2026-11-02", "end":"2026-11-29",
#    "leaderboard":"CgkI...", "winners":3}
const SEASONS: Array[Dictionary] = []
const RULES_URL := "https://phucpdbk.github.io/hole-munch/contest-rules.html"
# Where winners send their claim code; set before the first season starts.
const CONTACT := ""
# Days after a season ends during which winners see their claim code.
const CLAIM_DAYS := 14

static func ready_to_run() -> bool:
	return CONTACT != "" and RULES_URL != ""

# The season running on `date` ("YYYY-MM-DD"), or {}.
static func active_season(date: String, seasons: Array = SEASONS) -> Dictionary:
	for season in seasons:
		if str(season.start) <= date and date <= str(season.end) and str(season.get("leaderboard", "")) != "": return season
	return {}

# The latest season that ended within CLAIM_DAYS of `date`, or {}.
static func claim_season(date: String, seasons: Array = SEASONS) -> Dictionary:
	var unix := Time.get_unix_time_from_datetime_string(date + "T12:00:00")
	var found: Dictionary = {}
	for season in seasons:
		var ended := Time.get_unix_time_from_datetime_string(str(season.end) + "T12:00:00")
		if unix > ended and unix - ended <= CLAIM_DAYS*86400 and (found.is_empty() or str(season.end) > str(found.end)): found = season
	return found

# A short code the winner quotes when claiming; it ties the claim to their Play
# Games player id and the season without exposing the id itself.
static func claim_code(player_id: String, season_id: String) -> String:
	return ("%s:%s" % [player_id, season_id]).sha256_text().substr(0, 8).to_upper()

static func winner(rank: int, season: Dictionary) -> bool:
	return rank > 0 and rank <= int(season.get("winners", 0))

# mailto: link for the claim, with the code and season in the subject.
static func claim_link(code: String, season: Dictionary, player_name: String) -> String:
	var subject := "Hole Munch prize %s %s" % [str(season.id), code]
	var body := "Season: %s\nCode: %s\nPlay Games name: %s\n" % [str(season.id), code, player_name]
	return "mailto:%s?subject=%s&body=%s" % [CONTACT, subject.uri_encode(), body.uri_encode()]
