extends Node

# Google Play Games leaderboard for the daily challenge.
# The GodotPlayGameServices addon (v3.4.0, Android Gradle build, see README) is
# loaded by path at runtime, so desktop, web and headless runs never parse it
# and simply report available() == false: every button that needs it hides.
#
# Leaderboard ids come from Project Settings (they are public ids, not secrets):
#   application_custom/play_games/daily_leaderboard
signal rank_loaded(leaderboard_id: String, rank: int)
signal player_loaded(player_id: String, display_name: String)

const ADDON := "res://addons/GodotPlayGameServices/scripts/"
const DAILY_SETTING := "application_custom/play_games/daily_leaderboard"
# PlayGamesLeaderboardVariant enums, mirrored so this file parses without the addon.
const TIME_SPAN_DAILY := 0
const TIME_SPAN_ALL_TIME := 2
const COLLECTION_PUBLIC := 0

var leaderboards: Node
var players: Node
var signed_in := false
var player_id := ""
var player_name := ""
# Last rank seen per leaderboard id (0 = unknown).
var ranks := {}

func _ready() -> void:
	if OS.get_name() != "Android" or not ResourceLoader.exists(ADDON + "leaderboards/leaderboards_client.gd"): return
	var core := get_node_or_null("/root/GodotPlayGameServices")
	if core == null or int(core.initialize()) != 0: return
	leaderboards = load(ADDON + "leaderboards/leaderboards_client.gd").new()
	players = load(ADDON + "players/players_client.gd").new()
	var sign_in: Node = load(ADDON + "sign_in/sign_in_client.gd").new()
	for client in [leaderboards, players, sign_in]: add_child(client)
	sign_in.user_authenticated.connect(on_authenticated)
	leaderboards.score_loaded.connect(on_score_loaded)
	players.current_player_loaded.connect(on_player_loaded)
	sign_in.is_authenticated()

func available() -> bool:
	return leaderboards != null

static func daily_id() -> String:
	return str(ProjectSettings.get_setting(DAILY_SETTING, ""))

func on_authenticated(value: bool) -> void:
	signed_in = value
	if value: players.load_current_player(false)

func on_player_loaded(player) -> void:
	if player == null: return
	player_id = str(player.player_id)
	player_name = str(player.display_name)
	player_loaded.emit(player_id, player_name)

func on_score_loaded(leaderboard_id: String, score) -> void:
	var rank := int(score.rank) if score != null else 0
	ranks[leaderboard_id] = rank
	rank_loaded.emit(leaderboard_id, rank)

func submit(leaderboard_id: String, score: int) -> void:
	if not available() or not signed_in or leaderboard_id == "" or score <= 0: return
	leaderboards.submit_score(leaderboard_id, score)

# Asks for the player's rank; rank_loaded arrives later (today's, or all-time).
func load_rank(leaderboard_id: String, today_only: bool) -> void:
	if not available() or not signed_in or leaderboard_id == "": return
	leaderboards.load_player_score(leaderboard_id, TIME_SPAN_DAILY if today_only else TIME_SPAN_ALL_TIME, COLLECTION_PUBLIC)

func open_board(leaderboard_id: String) -> void:
	if not available() or leaderboard_id == "": return
	leaderboards.show_leaderboard(leaderboard_id)
