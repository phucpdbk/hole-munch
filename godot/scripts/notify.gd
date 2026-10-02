extends Node

# One local reminder a day on Android, through the NotificationScheduler addon
# (godot-mobile-plugins/godot-notification-scheduler, see README). Whenever the
# game goes to the background or closes, the old reminder is cancelled and one
# new reminder is set for REMIND_HOUR the next day: "streak about to end" when
# there is a streak to lose, otherwise "a new daily challenge is open". Nothing
# is sent when the player switched reminders off. The addon is found and loaded
# by path, so desktop, web and headless runs never parse it.
const I18n = preload("res://scripts/i18n.gd")
const CHANNEL := "daily"
const REMINDER_ID := 1
const REMIND_HOUR := 19
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

static func message(streak: int) -> Array:
	if streak >= 2: return [I18n.t("remind_streak_t", streak), I18n.t("remind_streak_b")]
	return [I18n.t("remind_daily_t"), I18n.t("remind_daily_b")]

# Replaces the pending reminder; switched off or not ready, it only cancels.
func reschedule(enabled: bool, streak: int) -> void:
	if not available(): return
	scheduler.cancel(REMINDER_ID)
	if not enabled or not ready_to_send or not scheduler.has_post_notifications_permission(): return
	var folder: String = scheduler.get_script().resource_path.get_base_dir() + "/model/"
	var lines := message(streak)
	var data = load(folder + "NotificationData.gd").new()
	data.set_id(REMINDER_ID).set_channel_id(CHANNEL).set_title(lines[0]).set_content(lines[1]) \
		.set_small_icon_name("ic_default_notification").set_delay(delay_until_tomorrow(Time.get_datetime_dict_from_system()))
	scheduler.schedule(data)
