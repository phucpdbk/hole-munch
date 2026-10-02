extends Control

# Story intro (first launch, or the ? button) and "new!" cards that introduce a
# mechanic the first time a city uses it: weather, orbs, bombs, hunger, the
# landmark counter-attack, the rival hole, continent finales and new continents.
# game.gd decides when to open it; seen ids are saved in campaign.seen.
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const I18n = preload("res://scripts/i18n.gd")
const Campaign = preload("res://scripts/campaign.gd")
const STORY := [["globe", "story1"], ["food", "story2"], ["shield", "story3"], ["target", "story4"]]
# First city index where each always-on mechanic gets its card.
const FEATURE_FROM := {"pickup":1, "bomb":2, "hunger":3, "counter":4, "gold":2, "roadblock":3, "shortcut":5, "danger":6, "guardian":0}
const FEATURE_ICON := {"pickup":"magnet", "bomb":"bomb", "hunger":"food", "counter":"megaphone",
	"rival":"skull", "finale":"crown", "region":"globe",
	"guardian":"shield", "gold":"gem", "roadblock":"lock", "shortcut":"map", "danger":"shield",
	"daily_stampede":"target", "daily_coinrain":"coin", "daily_goldrush":"chest"}
const WEATHER_TIPS := ["rain", "snow", "fog", "wind", "storm"]
const MAX_TIPS := 1
const CARD_DIR := "res://assets/landmark_cards/"

var pages: Array = []
var pictures := {}
var index := 0
var done_callback := Callable()
var story := false
var clock := 0.0
var pop := 1.0
var body_label: Label
var next_button: BaseButton
var skip_button: BaseButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_override("font", UiStyle.body_font(700))
	body_label.add_theme_font_size_override("font_size", 18)
	body_label.add_theme_color_override("font_color", Color("dbe7f0"))
	body_label.add_theme_constant_override("line_spacing", 2)
	body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body_label)
	next_button = UiButton.new()
	next_button.accent = UiStyle.GOLD
	next_button.primary = true
	next_button.pressed.connect(advance)
	add_child(next_button)
	skip_button = UiButton.new()
	skip_button.accent = Color("35546d")
	skip_button.pressed.connect(close)
	add_child(skip_button)
	resized.connect(layout)
	hide()

# --- what to show ------------------------------------------------------------------

static func story_pages() -> Array:
	var list: Array = []
	for entry in STORY:
		list.append({"icon":entry[0], "title":I18n.t(entry[1] + "_t"), "body":I18n.t(entry[1] + "_b")})
	return list

# Ids of the not-yet-seen cards for a city, most important first.
static func pending_tips(level: Dictionary, seen: Array) -> Array:
	var ids: Array = []
	var index: int = level.index
	if int(level.slot) == 0 and int(level.region) > 0: ids.append("region_" + str(Campaign.REGIONS[level.region].id))
	if level.weather in WEATHER_TIPS: ids.append("weather_" + str(level.weather))
	if level.get("rival", false): ids.append("rival")
	for id in FEATURE_FROM:
		if index >= FEATURE_FROM[id]: ids.append(id)
	if int(level.slot) == Campaign.CITIES_PER_REGION-1: ids.append("finale")
	return ids.filter(func(id): return id not in seen).slice(0, MAX_TIPS)

# A one-off card that introduces the city's landmark with a funny line; game.gd
# shows it only on a start with no new mechanic to explain.
static func landmark_tip(level: Dictionary, seen: Array) -> Array:
	var id := "lm_" + str(level.boss)
	return [] if id in seen or not I18n.has("lmfun_" + str(level.boss)) else [id]

static func tip_page(id: String) -> Dictionary:
	if id.begins_with("lm_"):
		var boss := id.trim_prefix("lm_")
		var city := ""
		for region in Campaign.REGIONS:
			for entry in region.cities:
				if entry[1] == boss: city = entry[0]
		var page := {"tag":Campaign.city_name(boss, city), "icon":"flag", "title":Campaign.boss_name(boss), "body":I18n.t("lmfun_" + boss)}
		# Meshy concept art (tools/make-landmark-cards.mjs); the flag icon stands in until it exists.
		var picture := CARD_DIR + boss + ".png"
		if ResourceLoader.exists(picture): page.picture = picture
		return page
	var page := {"tag":I18n.t("new_tag")}
	if id.begins_with("promo_"):
		page.merge({"icon":"crown", "title":I18n.t("tip_promo_t"), "body":I18n.t("tip_promo_b")})
	elif id.begins_with("weather_"):
		var kind := id.trim_prefix("weather_")
		page.merge({"icon":kind, "title":I18n.t("tip_%s_t" % kind), "body":I18n.t("tip_%s_b" % kind)})
	elif id.begins_with("region_"):
		var region := 0
		for i in Campaign.REGIONS.size():
			if "region_" + str(Campaign.REGIONS[i].id) == id: region = i
		page.merge({"icon":"globe", "title":I18n.t("tip_region_t", Campaign.region_name(region)), "body":I18n.t("tip_region_b")})
	else:
		page.merge({"icon":FEATURE_ICON.get(id, "help"), "title":I18n.t("tip_%s_t" % id), "body":I18n.t("tip_%s_b" % id)})
	return page

# --- flow -----------------------------------------------------------------------------

func open(list: Array, on_done := Callable(), is_story := false) -> void:
	if list.is_empty():
		if on_done.is_valid(): on_done.call()
		return
	pages = list
	index = 0
	done_callback = on_done
	story = is_story
	show()
	show_page()

func show_page() -> void:
	pop = 0.0
	clock = 0.0
	var last := index >= pages.size()-1
	next_button.text = I18n.t("lets_go" if story else "got_it") if last else I18n.t("next")
	next_button.icon = UiStyle.icon("play" if last else "right")
	skip_button.text = I18n.t("skip")
	skip_button.visible = pages.size() > 1 and not last
	body_label.text = pages[index].body
	layout()
	queue_redraw()

func advance() -> void:
	if index < pages.size()-1:
		index += 1
		show_page()
	else: close()

func close() -> void:
	hide()
	var callback := done_callback
	done_callback = Callable()
	if callback.is_valid(): callback.call()

# --- drawing ------------------------------------------------------------------------

func card_rect() -> Rect2:
	var width := minf(660.0, size.x - 48)
	var height := minf(340.0, size.y - 48)
	return Rect2((size.x - width)/2, (size.y - height)/2, width, height)

func layout() -> void:
	var card := card_rect()
	var art := minf(190.0, card.size.x*0.32)
	var left := card.position.x + art + 44
	body_label.position = Vector2(left, card.position.y + 118)
	body_label.size = Vector2(card.end.x - left - 28, card.size.y - 200)
	next_button.position = Vector2(card.end.x - 212, card.end.y - 78)
	next_button.size = Vector2(186, 58)
	next_button.font_size = 20
	skip_button.position = Vector2(left, card.end.y - 72)
	skip_button.size = Vector2(130, 50)
	skip_button.font_size = 16

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	pop = minf(1.0, pop + delta*4.0)
	queue_redraw()

func _draw() -> void:
	if pages.is_empty(): return
	var page: Dictionary = pages[index]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.12, 0.72))
	var card := card_rect()
	# Pop-in: the card settles from slightly lower down.
	var ease_in := 1.0 - pow(1.0 - pop, 3.0)
	card.position.y += (1.0 - ease_in)*24
	UiStyle.card(self, card, Color("1b3048"), 28)
	var art := minf(190.0, card.size.x*0.32)
	var art_center := Vector2(card.position.x + 26 + art/2, card.get_center().y - 6)
	draw_circle(art_center, art*0.5, Color("243f5c"))
	draw_circle(art_center, art*0.42, Color("2c4f73"))
	draw_arc(art_center, art*0.5, 0, TAU, 48, Color(UiStyle.MINT, 0.35), 3, true)
	var bob := sin(clock*2.6)*6
	if page.has("picture"):
		# Keep a reference: a texture freed right after _draw renders as a white box.
		if not pictures.has(page.picture): pictures[page.picture] = load(page.picture)
		var picture_size := art*1.12*(0.8 + 0.2*ease_in)
		draw_texture_rect(pictures[page.picture], Rect2(art_center + Vector2(0, bob) - Vector2.ONE*picture_size/2, Vector2.ONE*picture_size), false)
	else:
		UiStyle.draw_icon(self, page.icon, art_center + Vector2(0, bob), art*0.62*(0.8 + 0.2*ease_in))
	var left := card.position.x + art + 44
	var tag: String = page.get("tag", "%d / %d" % [index+1, pages.size()])
	var tag_width := UiStyle.text_width(tag, 15) + 28
	UiStyle.card(self, Rect2(left, card.position.y + 26, tag_width, 30), Color("f06a5a") if page.has("tag") else Color("2c4f73"), 15)
	UiStyle.text(self, tag, Vector2(left + 14, card.position.y + 47), 15, UiStyle.LIGHT)
	var title_size := 30
	var room := card.end.x - left - 28
	while title_size > 18 and UiStyle.text_width(page.title, title_size, UiStyle.font(800)) > room: title_size -= 1
	UiStyle.text(self, page.title, Vector2(left, card.position.y + 98), title_size, UiStyle.GOLD, false, 5, UiStyle.font(800))
	if pages.size() > 1:
		for i in pages.size():
			var dot := Vector2(card.position.x + 26 + art/2 + (i - (pages.size()-1)/2.0)*18, card.end.y - 30)
			draw_circle(dot, 5 if i == index else 4, UiStyle.GOLD if i == index else Color("4a6680"))
