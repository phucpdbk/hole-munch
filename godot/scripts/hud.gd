extends Control

signal play_requested
signal retry_requested
signal pause_requested
signal menu_requested
signal levels_requested
signal styles_requested
signal shop_requested
signal daily_requested
signal endless_requested
signal help_requested
signal language_requested
signal revive_requested
signal give_up_requested
signal double_requested
signal update_requested
signal board_requested
signal reminder_requested
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const I18n = preload("res://scripts/i18n.gd")
const Ads = preload("res://scripts/ads.gd")
const Minimap = preload("res://scripts/minimap.gd")
const Campaign = preload("res://scripts/campaign.gd")
var minimap := {}
var daily_button: BaseButton
var endless_button: BaseButton
var help_button: BaseButton
var language_button: BaseButton
var revive_button: BaseButton
var give_up_button: BaseButton
var double_button: BaseButton
var revive_left := 0.0
var revive_seconds := 15
var can_double := false
var update_button: BaseButton
# Play Games daily leaderboard (Android with the addon).
var board_button: BaseButton
var board_ready := false
# The daily reminder switch (Android with the notification addon); faded when off.
var reminder_button: BaseButton
var reminder_ready := false
var reminders_on := true
var update_ready := false
var last_city := false
var run_kind := "campaign"
var stage := 0
var lose_reason := ""
var record_note := ""
var goal_labels: Array = []
var goal_mask := 0
# Result screen: per-goal progress ("50%/75%"), where the coins came from, and
# the closest journey reward ({slot, index, track, need, have} or {}).
var goal_progress: Array = []
var coin_parts := ""
var next_reward: Dictionary = {}
var retry_button: BaseButton
var rival_growth := -1.0
var daily_won := false
var daily_left := 3
# Days in a row with a finished daily round (0 once the streak has lapsed).
var streak := 0
var daily_title := ""
var daily_goal := ""
var daily_icon := "daily"
var daily_count := 0
var daily_target := 1
# Carry-in powers from the daily mini-game: {"magnet":n, "speed":n, "time":n}.
var items := {}
const ITEM_ICONS := {"magnet":"magnet", "speed":"bolt", "time":"clock"}
var endless_best := 0
var gate_note := ""
var level_title := ""
var city := ""
var region_title := ""
var map_title := ""
var landmark := true
var coins := 0
var reward := 0
var shop_button: BaseButton
var weather_title := ""
var weather_kind := "clear"
var boss_title := ""
var has_next := true
var level_count := 12
var playtest := false
var levels_button: BaseButton
var styles_button: BaseButton
var strike_shapes: Array = []
var defense_status := ""
var mode := "menu"
var last_layout_mode := ""
var score := 0
var best := 0
var seconds := 110.0
var growth := 0.0
# Hearts left on the landmark's guardian (0 when it is gone or there is none).
var guardian_hp := 0
var guardian_max := 0
var eaten := 0
var won := false
var waiting := true
var stick_active := false
var stick_origin := Vector2.ZERO
var stick_delta := Vector2.ZERO
var progress := 0.0
var note := ""
var stars := 0
var combo := 0
var multiplier := 1.0
var best_combo := 0
var completion := 0.0
var floaters: Array = []
var flash := 0.0
var play_button: BaseButton
var pause_button: BaseButton
var menu_button: BaseButton
var font: Font = UiStyle.font(700)
var title_font: Font = UiStyle.font(800)
var body_font: Font = UiStyle.body_font(700)
const INK = UiStyle.INK
const LIGHT = UiStyle.LIGHT
const MUTED = UiStyle.MUTED
const GOLD = UiStyle.GOLD
const WEATHER_ICONS := {"clear":"sun", "sun":"sun", "rain":"rain", "snow":"snow", "wind":"wind", "fog":"fog", "storm":"storm"}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_button = make_button("play", Color("f6cb70"), true)
	play_button.pressed.connect(func(): play_requested.emit())
	retry_button = make_button("replay", Color("2f7d8c"))
	retry_button.pressed.connect(func(): retry_requested.emit())
	pause_button = make_button("pause", Color("2a4660"))
	pause_button.pressed.connect(func(): pause_requested.emit())
	menu_button = make_button("home", Color("35546d"))
	menu_button.pressed.connect(func(): menu_requested.emit())
	levels_button = make_button("map", Color("2f7d8c"))
	levels_button.pressed.connect(func(): levels_requested.emit())
	shop_button = make_button("upgrade", Color("6a55a8"))
	shop_button.pressed.connect(func(): shop_requested.emit())
	styles_button = make_button("wardrobe", Color("b85a7a"))
	styles_button.pressed.connect(func(): styles_requested.emit())
	daily_button = make_button("daily", Color("a8474f"))
	daily_button.pressed.connect(func(): daily_requested.emit())
	endless_button = make_button("endless", Color("2f7a68"))
	endless_button.pressed.connect(func(): endless_requested.emit())
	help_button = make_button("help", Color("35546d"))
	help_button.pressed.connect(func(): help_requested.emit())
	language_button = make_button("language", Color("35546d"))
	language_button.pressed.connect(func(): language_requested.emit())
	revive_button = make_button("clock", Color("f6cb70"), true)
	revive_button.pressed.connect(func(): revive_requested.emit())
	give_up_button = make_button("close", Color("35546d"))
	give_up_button.pressed.connect(func(): give_up_requested.emit())
	double_button = make_button("coin", Color("6a55a8"))
	double_button.pressed.connect(func(): double_requested.emit())
	update_button = make_button("megaphone", Color("2f9e5b"))
	update_button.pressed.connect(func(): update_requested.emit())
	board_button = make_button("trophy", Color("2f7d8c"))
	board_button.pressed.connect(func(): board_requested.emit())
	reminder_button = make_button("megaphone", Color("35546d"))
	reminder_button.pressed.connect(func(): reminder_requested.emit())
	resized.connect(layout)
	layout()

func make_button(icon_kind: String, bg: Color, primary := false) -> BaseButton:
	var button := UiButton.new()
	button.icon = UiStyle.icon(icon_kind)
	button.accent = bg
	button.primary = primary
	button.font_size = 20
	add_child(button)
	return button

func place(button: BaseButton, rect: Rect2, font_size := 18) -> void:
	button.position = rect.position
	button.size = rect.size
	button.font_size = font_size

func layout() -> void:
	if not is_instance_valid(play_button): return
	var w := size.x
	var h := size.y
	place(pause_button, Rect2(w - 84, 36, 58, 58))
	place(help_button, Rect2(w - 296, 26, 50, 50))
	place(language_button, Rect2(w - 238, 26, 50, 50))
	place(update_button, Rect2(w - 532, 26, 170, 50), 14)
	place(reminder_button, Rect2(w - 354, 26, 50, 50))
	# Bottom right in the menu; on a daily result, beside the home button.
	var corner := mode == "menu"
	place(board_button, Rect2(w - 448, h - 84, 420, 56) if corner else Rect2(w/2 - 264, h - 232, 528, 52), 15)
	var offer_width := minf(440.0, w-48)
	place(revive_button, Rect2(w/2-offer_width/2, h/2+10, offer_width, 64), 22)
	place(give_up_button, Rect2(w/2-110, h/2+88, 220, 48), 16)
	if w > h and can_double and mode == "result" and board_ready and run_kind == "daily":
		# Share the row: the ad offer on the left, the leaderboard on the right.
		place(double_button, Rect2(w/2-264, h-232, 260, 52), 14)
		place(board_button, Rect2(w/2+4, h-232, 260, 52), 14)
	elif w > h: place(double_button, Rect2(w/2-210, h-232, 420, 52), 17)
	else: place(double_button, Rect2(44, h-500, w-88, 52), 16)
	if w > h:
		var left := 36.0 if mode == "menu" else w/2-264
		var width := 364.0 if mode == "menu" else 528.0
		place(play_button, Rect2(left, h-168, width, 64), 26)
		if retry_wanted():
			place(retry_button, Rect2(left, h-168, width*0.42, 64), 17)
			place(play_button, Rect2(left + width*0.42 + 8, h-168, width*0.58 - 8, 64), 24)
		place(menu_button, Rect2(left, h-94, width, 54), 19)
		for i in 3:
			place([levels_button, shop_button, styles_button][i], Rect2(36+i*124, h-94, 116, 56), 15)
		for i in 2:
			place([daily_button, endless_button][i], Rect2(36+i*186, h-232, 178, 52), 16)
		return
	place(play_button, Rect2(44, h - 172, w - 88, 66), 26)
	place(retry_button, Rect2(44, h - 246, w - 88, 56), 18)
	place(menu_button, Rect2(44, h - 94, w - 88, 52), 19)
	var third := (w-88-16)/3
	for i in 3:
		place([levels_button, shop_button, styles_button][i], Rect2(44 + i*(third+8), h-94, third, 56), 14)
	for i in 2:
		place([daily_button, endless_button][i], Rect2(44 + i*((w-88)/2+4), h-340, (w-88)/2-4, 52), 15)

# A won campaign city with a star still missing offers a replay of that city.
func retry_wanted() -> bool:
	return mode == "result" and run_kind == "campaign" and won and stars < 3 and has_next

func sync() -> void:
	var layout_key := mode + str(retry_wanted()) + str(can_double) + str(board_ready)
	if last_layout_mode != layout_key:
		layout()
		last_layout_mode = layout_key
	retry_button.visible = retry_wanted()
	retry_button.text = I18n.t("retry_stars")
	# A daily result with no tries left only goes home.
	play_button.visible = mode not in ["playing", "revive"] and not (mode == "result" and run_kind == "daily" and daily_left <= 0)
	revive_button.visible = mode == "revive"
	give_up_button.visible = mode == "revive"
	double_button.visible = can_double
	update_button.visible = mode == "menu" and update_ready
	var daily_result := mode == "result" and run_kind == "daily"
	board_button.visible = board_ready and (mode == "menu" or daily_result)
	board_button.text = I18n.t("leaderboard")
	reminder_button.visible = mode == "menu" and reminder_ready
	reminder_button.modulate.a = 1.0 if reminders_on else 0.45
	update_button.text = I18n.t("update_ready")
	revive_button.text = I18n.t("ad_revive", revive_seconds)
	give_up_button.text = I18n.t("ad_give_up")
	double_button.text = I18n.t("ad_double", reward)
	var next_level: bool = mode == "result" and won and has_next
	play_button.text = I18n.t("resume") if mode == "paused" else I18n.t("next_city") if next_level else I18n.t("replay") if mode == "result" else I18n.t("play")
	if mode == "result" and run_kind == "daily": play_button.text = I18n.t("replay_left", daily_left)
	play_button.icon = UiStyle.icon("next" if next_level else "replay" if mode == "result" else "play")
	menu_button.text = I18n.t("home")
	levels_button.text = I18n.t("map")
	shop_button.text = I18n.t("upgrades")
	styles_button.text = I18n.t("wardrobe")
	daily_button.text = I18n.t("daily") + (" ★" if daily_won else "") + " %d/3" % daily_left
	daily_button.disabled = daily_left <= 0
	endless_button.text = I18n.t("endless") + (" · %d" % endless_best if endless_best > 0 else "")
	for button in [daily_button, endless_button, levels_button, styles_button, shop_button, help_button, language_button]:
		button.visible = mode == "menu"
	menu_button.visible = mode in ["paused", "result"]
	pause_button.visible = mode == "playing"
	queue_redraw()

func panel(rect: Rect2, color: Color, radius: int = 20) -> void:
	UiStyle.card(self, rect, color, radius)

func text_at(text: String, pos: Vector2, font_size: int, color: Color, centered := false, outline := 0) -> void:
	UiStyle.text(self, text, pos, font_size, color, centered, outline, font)

func _draw() -> void:
	var w := size.x
	var h := size.y
	# White flash when the boss is swallowed.
	if flash > 0: draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash*0.55))
	if mode == "revive":
		draw_revive()
		return
	if w > h and mode == "menu":
		draw_landscape_menu()
		return
	if w > h and mode in ["paused", "result"]:
		draw_landscape_result()
		return
	if mode == "menu": draw_portrait_menu()
	elif mode == "playing": draw_playing()
	else: draw_portrait_result()

func draw_coins(right: float, top: float) -> void:
	var label := str(coins)
	var width := UiStyle.text_width(label, 20, title_font) + 64
	panel(Rect2(right - width, top, width, 44), Color("1b3048ee"), 22)
	UiStyle.draw_icon(self, "coin", Vector2(right - width + 24, top + 22), 34)
	UiStyle.text(self, label, Vector2(right - width + 46, top + 31), 20, GOLD, false, 0, title_font)

func draw_title(pos: Vector2, font_size: int, centered := false) -> void:
	UiStyle.text(self, "HOLE MUNCH", pos + Vector2(0, 4), font_size, Color(0.02, 0.06, 0.12, 0.5), centered, 0, title_font)
	UiStyle.text(self, "HOLE MUNCH", pos, font_size, LIGHT, centered, 6, title_font)

func level_line() -> String:
	return I18n.t("level_line", [weather_title, int(seconds), map_title])

func draw_landscape_menu() -> void:
	var h := size.y
	panel(Rect2(20, 24, 400, h-48), Color("142840f2"), 26)
	text_at(I18n.t("tagline"), Vector2(38, 62), 15, UiStyle.MINT)
	draw_title(Vector2(36, 112), 46)
	text_at(level_title, Vector2(38, 150), 21, GOLD, false, 0)
	text_at(region_title, Vector2(38, 180), 16, LIGHT)
	UiStyle.draw_icon(self, WEATHER_ICONS.get(weather_kind, "sun"), Vector2(50, 204), 26)
	UiStyle.text(self, level_line(), Vector2(68, 210), 15, MUTED, false, 0, body_font)
	var target := I18n.t("take_target", boss_title.to_upper()) + (I18n.t("with_rival") if rival_growth >= 0 else "")
	UiStyle.draw_icon(self, "flag", Vector2(50, 234), 26)
	UiStyle.text(self, target, Vector2(68, 240), 15, LIGHT, false, 0, body_font)
	draw_goals(Vector2(38, 268), 14, false, 364)
	if gate_note != "" and has_next == false and not last_city: UiStyle.text(self, gate_note, Vector2(38, 290), 13, Color("ffb3a6"), false, 0, body_font)
	draw_coins(size.x - 28, 28)
	draw_items(size.x - 28, 80)
	draw_daily_caption()

# Today's mini-game, written just above the daily button.
func draw_daily_caption() -> void:
	var at := daily_button.position + Vector2(4, -8)
	UiStyle.draw_icon(self, daily_icon if daily_left > 0 else "lock", at + Vector2(9, -6), 20)
	UiStyle.text(self, daily_title, at + Vector2(24, 0), 13, UiStyle.MINT if daily_left > 0 else MUTED, false, 4, body_font)
	# The daily streak sits at the right end of the same line: a flame and the days.
	if streak > 0:
		var label := I18n.t("streak_days", streak)
		var right := daily_button.position.x + daily_button.size.x
		var width := UiStyle.text_width(label, 13, body_font)
		UiStyle.draw_icon(self, "fire", Vector2(right - width - 12, at.y - 6), 20)
		UiStyle.text(self, label, Vector2(right - width, at.y), 13, GOLD, false, 4, body_font)

# Carry-in powers waiting for the next campaign round.
func draw_items(right: float, top: float) -> void:
	var owned: Array = ITEM_ICONS.keys().filter(func(kind): return int(items.get(kind, 0)) > 0)
	if owned.is_empty(): return
	var width := owned.size()*62.0 + 8
	panel(Rect2(right - width, top, width, 40), Color("1b3048ee"), 20)
	for i in owned.size():
		var x := right - width + 8 + i*62
		UiStyle.draw_icon(self, ITEM_ICONS[owned[i]], Vector2(x + 16, top + 20), 28)
		UiStyle.text(self, "×%d" % int(items[owned[i]]), Vector2(x + 32, top + 27), 16, LIGHT, false, 0, title_font)

func draw_portrait_menu() -> void:
	var w := size.x
	var h := size.y
	text_at(I18n.t("tagline"), Vector2(w/2, 75), 14, UiStyle.MINT, true)
	draw_coins(w - 18, 12)
	draw_items(w - 18, 62)
	draw_daily_caption()
	draw_title(Vector2(w/2, 153), 52, true)
	panel(Rect2(w/2-173, 165, 346, 36), Color("223649dc"), 16)
	text_at(level_title, Vector2(w/2, 190), 18, LIGHT, true)
	panel(Rect2(24, h-276, w-48, 250), Color("223649f5"), 28)
	text_at(region_title, Vector2(w/2, h-240), 15, GOLD, true)
	UiStyle.text(self, level_line(), Vector2(w/2, h-214), 15, MUTED, true, 0, body_font)
	UiStyle.text(self, I18n.t("eat_then_take", boss_title), Vector2(w/2, h-188), 15, LIGHT, true, 0, body_font)

func draw_playing() -> void:
	var w := size.x
	var h := size.y
	for strike in strike_shapes:
		draw_colored_polygon(strike.points, Color(1.0,0.16,0.12,0.16+strike.progress*0.28))
		var outline: PackedVector2Array = strike.points.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, Color("ff7866"), 3.0, true)
	if defense_status != "":
		panel(Rect2(w/2+24, 36, 230, 40), Color("3b2836ed"), 14)
		text_at(defense_status, Vector2(w/2+139, 62), 15, Color("ffbb9c"), true)
	panel(Rect2(24, 36, 132, 68), Color("1b3048ed"), 20)
	text_at(I18n.t("score"), Vector2(42, 58), 13, MUTED)
	UiStyle.text(self, str(score), Vector2(42, 92), 28, LIGHT, false, 0, title_font)
	panel(Rect2(w/2-104, 36, 116, 68), Color("1b3048ed"), 20)
	UiStyle.draw_icon(self, "clock", Vector2(w/2-80, 70), 30)
	UiStyle.text(self, "%d:%02d" % [int(ceil(seconds))/60, int(ceil(seconds))%60], Vector2(w/2-26, 82), 28, Color("ffad94") if seconds < 15 else LIGHT, true, 0, title_font)
	panel(Rect2(w-176, 36, 84, 68), Color("1b3048ed"), 20)
	text_at(I18n.t("cleared"), Vector2(w-134, 58), 13, MUTED, true)
	UiStyle.text(self, "%d%%" % int(completion*100), Vector2(w-134, 90), 23, LIGHT, true, 0, title_font)
	Minimap.draw(self, Vector2(w-32, 118), minimap)
	if combo >= 2: draw_combo()
	draw_floaters()
	panel(Rect2(24, h-115, w-48, 88), Color("1b3048ed"), 20)
	# The daily mini-game tracks catches instead of growth toward the landmark.
	var daily_round := run_kind == "daily"
	var share := clampf(float(daily_count)/maxf(1.0, daily_target), 0, 1) if daily_round else growth
	UiStyle.draw_icon(self, daily_icon if daily_round else "flag", Vector2(58, h-88), 30)
	text_at(daily_goal if daily_round else I18n.t("take_target", boss_title.to_upper()), Vector2(80, h-80), 17, LIGHT)
	var value := "%d/%d" % [daily_count, daily_target] if daily_round else "%d%%" % int(growth*100)
	UiStyle.text(self, value, Vector2(w-(110 if daily_round else 92), h-80), 19, GOLD, false, 0, title_font)
	# The guardian's hearts sit left of the percentage: it takes that many bites.
	if not daily_round and guardian_max > 0:
		for i in guardian_max:
			var at := Vector2(w-118-(guardian_max-1-i)*26, h-88)
			if i < guardian_hp: UiStyle.draw_icon(self, "heart", at, 22, Color("ff6b7d"))
			else: draw_circle(at, 7.0, Color("465d6b"))
	panel(Rect2(44, h-63, w-88, 10), Color("465d6b"), 5)
	panel(Rect2(44, h-63, maxf(10, (w-88)*share), 10), GOLD if daily_round else Color("b7a2f1"), 5)
	if rival_growth >= 0:
		panel(Rect2(44, h-47, maxf(8, (w-88)*rival_growth), 6), Color("ff5a4e"), 3)
		text_at(I18n.t("rival_pct", int(rival_growth*100)), Vector2(w-110, h-34), 12, Color("ffb3a6"))
	var run_label := run_title()
	if run_label != "": text_at(run_label, Vector2(w/2-44, 126), 15, UiStyle.MINT, true, 4)
	if waiting:
		panel(Rect2(w/2-176, h/2+88, 352, 48), Color("1b3048df"), 20)
		text_at(I18n.t("drag_to_start"), Vector2(w/2, h/2+119), 19, LIGHT, true)
	elif note != "":
		text_at(note, Vector2(w/2, 186), 20, LIGHT, true, 6)
	if stick_active:
		draw_circle(stick_origin, 54, Color(1,1,1,0.13))
		draw_arc(stick_origin, 54, 0, TAU, 32, Color(1,1,1,0.65), 2, true)
		draw_circle(stick_origin+stick_delta.limit_length(54), 22, Color("fff9edb0"))

func draw_portrait_result() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("172b4180"))
	panel(Rect2(24, h-440, w-48, 414), Color("1b3048f5"), 28)
	if mode == "result":
		for i in range(3): draw_star(Vector2(w/2+(i-1)*62, h-390), 26, i < stars)
	UiStyle.text(self, result_title(), Vector2(w/2, h-320), 32, GOLD, true, 5, title_font)
	UiStyle.text(self, I18n.t("result_line", [score, eaten, int(completion*100), best_combo]), Vector2(w/2, h-280), 16, LIGHT, true, 0, body_font)
	draw_goals(Vector2(w/2, h-252), 15)
	if mode == "result": text_at(I18n.t("coins_line", [reward, coins]), Vector2(w/2, h-222), 17, GOLD, true)
	UiStyle.text(self, result_sub(), Vector2(w/2, h-194), 15, MUTED, true, 0, body_font)

func draw_landscape_result() -> void:
	if mode == "result" and run_kind == "campaign" and not goal_progress.is_empty() and size.x >= 820:
		draw_campaign_result()
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("0f1e3080"))
	panel(Rect2(w/2-300, 24, 600, h-48), Color("1b3048f5"), 26)
	if mode == "result":
		for i in 3: draw_star(Vector2(w/2+(i-1)*70, 76), 30, i < stars)
	UiStyle.text(self, result_title(), Vector2(w/2, 142), 32, GOLD, true, 6, title_font)
	UiStyle.text(self, I18n.t("result_line", [score, eaten, int(completion*100), best_combo]), Vector2(w/2, 176), 17, LIGHT, true, 0, body_font)
	draw_goals(Vector2(w/2, 206), 16)
	if mode == "result":
		var line := I18n.t("coins_line", [reward, coins])
		var width := UiStyle.text_width(line, 19, font)
		UiStyle.draw_icon(self, "coin", Vector2(w/2 - width/2 - 20, 237), 30)
		text_at(line, Vector2(w/2 + 6, 244), 19, GOLD, true)
	UiStyle.text(self, result_sub(), Vector2(w/2, 276), 15, MUTED, true, 0, body_font)
	if mode == "result" and gate_note != "" and run_kind == "campaign" and won and not has_next and not last_city:
		UiStyle.text(self, gate_note, Vector2(w/2, 300), 15, Color("ffb3a6"), true, 0, body_font)

# Campaign result: what each goal still needs on the left, where the coins came
# from and the next journey reward on the right, so a missed star reads as a
# reason to replay rather than a dead end.
func draw_campaign_result() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("0f1e3080"))
	panel(Rect2(w/2-380, 24, 760, h-48), Color("1b3048f5"), 26)
	for i in 3: draw_star(Vector2(w/2+(i-1)*64, 66), 26, i < stars)
	UiStyle.text(self, result_title(), Vector2(w/2, 122), 28, GOLD, true, 6, title_font)
	UiStyle.text(self, I18n.t("result_line", [score, eaten, int(completion*100), best_combo]), Vector2(w/2, 152), 15, LIGHT, true, 0, body_font)
	var left := w/2 - 350
	for i in goal_labels.size():
		var done := goal_mask & (1 << i) != 0
		var y := 190.0 + i*28
		UiStyle.draw_icon(self, "star", Vector2(left + 10, y - 5), 20, Color.WHITE if done else Color(0.3, 0.38, 0.46, 0.9))
		UiStyle.text(self, str(goal_labels[i]), Vector2(left + 28, y), 15, GOLD if done else LIGHT, false, 0, body_font)
		var progress := str(goal_progress[i]) if i < goal_progress.size() else ""
		# Goals only count on a win, so a lost round shows its numbers muted.
		var tint: Color = UiStyle.MINT if done else Color("ffb3a6") if won else MUTED
		if progress != "": UiStyle.text(self, progress, Vector2(w/2 - 70, y), 15, tint, false, 0, title_font)
	var right := w/2 + 10
	var line := I18n.t("coins_line", [reward, coins])
	UiStyle.draw_icon(self, "coin", Vector2(right + 14, 184), 26)
	text_at(line, Vector2(right + 32, 191), 18, GOLD)
	if coin_parts != "": UiStyle.text(self, coin_parts, Vector2(right, 215), 12, MUTED, false, 0, body_font)
	draw_next_reward(Rect2(right, 232, 330, 28))
	UiStyle.text(self, result_sub(), Vector2(w/2, 290), 14, MUTED, true, 0, body_font)
	if gate_note != "" and won and not has_next and not last_city:
		UiStyle.text(self, gate_note, Vector2(w/2, 304), 13, Color("ffb3a6"), true, 0, body_font)

# The closest journey reward: its name, a progress bar and the count.
func draw_next_reward(rect: Rect2) -> void:
	if next_reward.is_empty(): return
	var have: int = next_reward.have
	var need: int = next_reward.need
	var name := I18n.t("next_reward", reward_name(next_reward))
	UiStyle.text(self, name, rect.position + Vector2(0, 10), 13, LIGHT, false, 0, body_font)
	var count := I18n.t("reward_stars" if next_reward.track == "stars" else "reward_landmarks", [have, need])
	UiStyle.text(self, count, rect.position + Vector2(rect.size.x - UiStyle.text_width(count, 13, body_font), 10), 13, GOLD, false, 0, body_font)
	panel(Rect2(rect.position + Vector2(0, 18), Vector2(rect.size.x, 8)), Color("465d6b"), 4)
	panel(Rect2(rect.position + Vector2(0, 18), Vector2(maxf(8.0, rect.size.x*clampf(float(have)/maxf(1.0, need), 0, 1)), 8)), GOLD, 4)

static func reward_name(entry: Dictionary) -> String:
	match str(entry.slot):
		"skins": return Campaign.skin_name(entry.index)
		"effects": return Campaign.effect_name(entry.index)
	return Campaign.trail_name(entry.index)

# Time ran out near the landmark: one rewarded-ad rescue with a short countdown.
func draw_revive() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("0f1e30a0"))
	var width := minf(520.0, w-32)
	panel(Rect2(w/2-width/2, h/2-150, width, 310), Color("1b3048f5"), 26)
	UiStyle.draw_icon(self, "clock", Vector2(w/2, h/2-108), 54)
	UiStyle.text(self, I18n.t("ad_revive_t"), Vector2(w/2, h/2-50), 30, GOLD, true, 6, title_font)
	var growth_label := "%s · %d%%" % [I18n.t("take_target", boss_title.to_upper()), int(growth*100)]
	UiStyle.text(self, growth_label, Vector2(w/2, h/2-20), 16, LIGHT, true, 0, body_font)
	# Countdown ring around the clock icon.
	var share := clampf(revive_left/Ads.REVIVE_WINDOW, 0, 1)
	draw_arc(Vector2(w/2, h/2-108), 34, -PI/2, -PI/2 + TAU*share, 40, GOLD, 4, true)
	UiStyle.text(self, I18n.t("ad_revive_sub", int(ceil(revive_left))), Vector2(w/2, h/2+150), 13, MUTED, true, 0, body_font)

func run_title() -> String:
	if run_kind == "daily": return daily_title
	if run_kind == "endless": return I18n.t("endless_city", stage+1)
	return ""

func result_title() -> String:
	if mode == "paused": return I18n.t("paused")
	if lose_reason == "eaten": return I18n.t("eaten_by_rival")
	if lose_reason == "rival": return I18n.t("rival_took", city.to_upper())
	if run_kind == "endless": return I18n.t("time_up_cities", stage)
	if run_kind == "daily": return I18n.t("dg_won" if won else "dg_lost", [daily_count, daily_target])
	return I18n.t("conquered", city.to_upper()) if won else I18n.t("pushed_back")

func result_sub() -> String:
	if mode == "paused": return I18n.t("sub_paused")
	if record_note != "": return record_note
	if won and last_city: return I18n.t("sub_earth")
	if won and playtest: return I18n.t("sub_test")
	if won and has_next: return I18n.t("sub_next_open")
	if won: return I18n.t("sub_need_stars")
	if lose_reason != "": return I18n.t("sub_rival_tip")
	return I18n.t("sub_tip")

# Goal list: a gold star and gold text when met, muted otherwise.
func draw_goals(pos: Vector2, font_size: int, centered := true, max_width := 560.0) -> void:
	var parts: Array = []
	for i in goal_labels.size():
		parts.append({"text":str(goal_labels[i]), "done":goal_mask & (1 << i) != 0})
	var gap := font_size*1.9
	var icon := font_size*1.3
	var total := goals_width(parts, font_size)
	# Long goal names in some languages: shrink until the row fits.
	while total - gap > max_width and font_size > 10:
		font_size -= 1
		gap = font_size*1.2
		icon = font_size*1.3
		total = goals_width(parts, font_size, gap)
	var x := pos.x - (total - gap)/2 if centered else pos.x
	for part in parts:
		UiStyle.draw_icon(self, "star", Vector2(x + icon/2, pos.y - font_size*0.35), icon, Color.WHITE if part.done else Color(0.3, 0.38, 0.46, 0.9))
		x += icon + 4
		UiStyle.text(self, part.text, Vector2(x, pos.y), font_size, GOLD if part.done else MUTED, false, 0, body_font)
		x += body_font.get_string_size(part.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + gap

func goals_width(parts: Array, font_size: int, gap := -1.0) -> float:
	if gap < 0: gap = font_size*1.9
	var total := 0.0
	for part in parts: total += font_size*1.3 + 4 + body_font.get_string_size(part.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + gap
	return total

func draw_combo() -> void:
	panel(Rect2(24, 112, 160, 38), GOLD, 18)
	UiStyle.draw_icon(self, "fire", Vector2(46, 131), 28)
	var label := I18n.t("combo", combo)
	if multiplier > 1.0: label += "  ×%s" % ("%.1f" % multiplier).trim_suffix(".0")
	UiStyle.text(self, label, Vector2(114, 139), 18, INK, true, 0, title_font)

# Score popups rise and fade above the swallowed object.
func draw_floaters() -> void:
	for floater in floaters:
		var t: float = floater.t
		var font_size := 30 if floater.big else 20
		var pos: Vector2 = floater.screen - Vector2(0, t*46)
		var color := GOLD if floater.big else LIGHT
		color.a = 1.0 - t*t
		UiStyle.text(self, floater.text, pos, font_size, color, true, 6, title_font)

func draw_star(center: Vector2, radius: float, filled: bool) -> void:
	UiStyle.draw_icon(self, "star", center, radius*2.3, Color.WHITE if filled else Color(0.24, 0.31, 0.38, 0.95))
