extends Node

# Local reminders on Android, through the NotificationScheduler addon
# (godot-mobile-plugins/godot-notification-scheduler, see README). Whenever the
# game goes to the background or closes, the pending reminders are cancelled
# and one is set for REMIND_HOUR on each of the next DAYS_AHEAD days, naming
# that day's challenge ("Today: Find the cow in Paris!"); the first one warns
# about the streak instead when there is one to lose. Nothing is sent when the
# player switched reminders off. The addon is found and loaded
# by path, so desktop, web and headless runs never parse it.
const I18n = preload("res://scripts/i18n.gd")
const CHANNEL := "daily"
const REMINDER_ID := 1
const REMIND_HOUR := 19
# A player who skips a day or two still hears about the next challenges.
const DAYS_AHEAD := 3
const Campaign = preload("res://scripts/campaign.gd")
const DailyGames = preload("res://scripts/daily_games.gd")
const ADDONS := "res://addons/"
const SCRIPT_NAME := "NotificationScheduler.gd"

var scheduler: Node
var ready_to_send := false

func _ready() -> void:
	if OS.get_name() != "Android": return
	var path := find_script(ADDONS, 3)
	if path == "": return
	scheduler = load(path).new()
	add_child(scheduler)
	scheduler.initialization_completed.connect(on_initialized)
	scheduler.initialize()

func available() -> bool:
	return scheduler != null

static func find_script(folder: String, depth: int) -> String:
	if depth < 0 or not DirAccess.dir_exists_absolute(folder): return ""
	# ResourceLoader, not FileAccess: exported scripts may be stored compiled.
	if ResourceLoader.exists(folder + SCRIPT_NAME): return folder + SCRIPT_NAME
	for child in DirAccess.get_directories_at(folder):
		var found := find_script(folder + child + "/", depth - 1)
		if found != "": return found
	return ""

func on_initialized() -> void:
	# NotificationChannel and NotificationData are the addon's own classes,
	# reached through its folder so this file parses without them.
	var folder: String = scheduler.get_script().resource_path.get_base_dir() + "/model/"
	if not ResourceLoader.exists(folder + "NotificationChannel.gd"): return
	var made = load(folder + "NotificationChannel.gd").new()
	made.set_id(CHANNEL).set_name(I18n.t("daily")).set_description(I18n.t("reminder_channel")).set_importance(3)
	ready_to_send = int(scheduler.create_notification_channel(made)) == OK

# Asked once, after the player's first win, never at launch.
func ask_permission() -> void:
	if available() and not scheduler.has_post_notifications_permission():
		scheduler.request_post_notifications_permission()

# Seconds from `now` (unix, local) until REMIND_HOUR o'clock on the next day.
static func delay_until_tomorrow(now: Dictionary) -> int:
	var seconds_today: int = int(now.hour)*3600 + int(now.minute)*60 + int(now.second)
	return 86400 - seconds_today + REMIND_HOUR*3600

# [title, body] for the reminder that fires on `date` ("YYYY-MM-DD"): that day's
# mini-game and city, or the streak warning on the first day of a live streak.
static func message(streak: int, date: String, first: bool) -> Array:
	if first and streak >= 2: return [I18n.t("remind_streak_t", streak), I18n.t("remind_streak_b")]
	var type := Campaign.daily_type(date)
	var city: String = Campaign.level_info(Campaign.daily_level(date)).city
	return [I18n.t("remind_today_t", [DailyGames.title(type), city]), DailyGames.goal_line(type)]

# The local date `days` after today.
static func date_after(days: int) -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_datetime_string(Campaign.today() + "T12:00:00")) + days*86400)

# Replaces the pending reminders; switched off or not ready, it only cancels.
func reschedule(enabled: bool, streak: int) -> void:
	if not available(): return
	for day in DAYS_AHEAD: scheduler.cancel(REMINDER_ID + day)
	if not enabled or not ready_to_send or not scheduler.has_post_notifications_permission(): return
	var folder: String = scheduler.get_script().resource_path.get_base_dir() + "/model/"
	var first_delay := delay_until_tomorrow(Time.get_datetime_dict_from_system())
	for day in DAYS_AHEAD:
		var lines := message(streak, date_after(day + 1), day == 0)
		var data = load(folder + "NotificationData.gd").new()
		data.set_id(REMINDER_ID + day).set_channel_id(CHANNEL).set_title(lines[0]).set_content(lines[1])
		data.set_small_icon_name("ic_default_notification").set_delay(first_delay + day*86400)
		scheduler.schedule(data)
