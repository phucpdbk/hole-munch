extends Control

# Conquest album (menu → ALBUM, wardrobe.gd tab "album"): one page per continent
# with every stop on its route, festival cities included. A conquered city shows
# its landmark (tools/bake_landmark_thumbs.gd), city, landmark name and the
# stars of each goal; a city not yet taken is a dark silhouette with a lock.
# Test mode reveals every card (its stars still come from the test save).
# Tapping a revealed card opens the landmark's fun-fact card (intro.gd).
const Campaign = preload("res://scripts/campaign.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const I18n = preload("res://scripts/i18n.gd")
const Intro = preload("res://scripts/intro.gd")
const THUMB := "res://assets/thumbs/landmark_%s.png"
const TOP := 104.0
const GAP := 10.0
const SILHOUETTE := Color(0.03, 0.07, 0.12, 0.92)
# Portrait screens are 960 wide (project stretch), so the album lays out at this
# width and scales up, keeping text and cards at a readable phone size.
const PORTRAIT_WIDTH := 540.0
var game
var region := 0
var tabs: Array[BaseButton] = []
var thumbs := {}
# [{rect, index}] of the cards drawn on the current page, for taps.
var cards: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for i in Campaign.REGIONS.size():
		var tab := UiButton.new()
		tab.pressed.connect(func(): pick(i))
		add_child(tab)
		tabs.append(tab)
	hide()

func open(start_region := 0) -> void:
	region = clampi(start_region, 0, Campaign.REGIONS.size()-1)
	show()
	layout()

func pick(value: int) -> void:
	region = value
	if is_instance_valid(game): game.sfx.play("click")
	layout()

# --- what the album knows -------------------------------------------------------

static func revealed(campaign, index: int) -> bool:
	return campaign.is_conquered(index) or campaign.unlock_all_for_testing

# Conquered stops and all stops on a continent's route.
static func region_count(campaign, region_index: int) -> Vector2i:
	var stops := Campaign.route(region_index)
	return Vector2i(stops.filter(func(i): return campaign.is_conquered(i)).size(), stops.size())

static func city_label(index: int) -> String:
	return str(Campaign.level_info(index).city)

static func boss_of(index: int) -> String:
	return str(Campaign.level_info(index).boss)

# --- layout -------------------------------------------------------------------------

func portrait() -> bool:
	return size.x <= size.y

func tab_rect(i: int) -> Rect2:
	var columns := 3 if portrait() else Campaign.REGIONS.size()
	var width := (size.x - 56 - GAP*(columns-1))/columns
	return Rect2(28 + (i%columns)*(width+GAP), TOP + (i/columns)*(50+GAP), width, 50)

func grid_rect() -> Rect2:
	var top := tab_rect(tabs.size()-1).end.y + 14
	return Rect2(28, top, size.x - 56, size.y - top - 20)

# Up to 5 columns in landscape (two rows), 2-4 in portrait.
func grid_columns(count: int) -> int:
	if portrait(): return clampi(int(size.x/170), 2, 4)
	return mini(5, ceili(count/2.0))

func layout() -> void:
	if not is_instance_valid(game): return
	var view: Vector2 = get_parent().size if get_parent() is Control else get_viewport_rect().size
	var zoom := view.x/PORTRAIT_WIDTH if view.x < view.y and view.x > PORTRAIT_WIDTH else 1.0
	position = Vector2.ZERO
	scale = Vector2.ONE*zoom
	size = view/zoom
	for i in tabs.size():
		var count := region_count(game.campaign, i)
		var tab := tabs[i]
		var rect := tab_rect(i)
		tab.position = rect.position
		tab.size = rect.size
		tab.text = "%s %d/%d" % [Campaign.region_name(i), count.x, count.y]
		tab.font_size = 15
		while tab.font_size > 10 and UiStyle.text_width(tab.text, tab.font_size) > rect.size.x - 18: tab.font_size -= 1
		tab.primary = i == region
		tab.accent = UiStyle.GOLD if i == region else Color("35546d")
	place_cards()
	queue_redraw()

func place_cards() -> void:
	cards.clear()
	var stops := Campaign.route(region)
	var grid := grid_rect()
	var columns := grid_columns(stops.size())
	var rows := ceili(stops.size()/float(columns))
	var cell_w := (grid.size.x - GAP*(columns-1))/columns
	var cell := Vector2(cell_w, minf(cell_w*1.3, (grid.size.y - GAP*(rows-1))/rows))
	for k in stops.size():
		var at := grid.position + Vector2((k%columns)*(cell.x+GAP), (k/columns)*(cell.y+GAP))
		cards.append({"rect":Rect2(at, cell), "index":stops[k]})

func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	if not tap: return
	for card in cards:
		if card.rect.has_point(event.position): tap_card(card.index)

func tap_card(index: int) -> void:
	if not revealed(game.campaign, index): return
	var boss := boss_of(index)
	if not I18n.has("lmfun_" + boss): return
	game.sfx.play("click")
	game.intro.open([Intro.tip_page("lm_" + boss)])

# --- drawing ------------------------------------------------------------------------

func thumb(boss: String) -> Texture2D:
	# Keep a reference: a texture freed right after _draw renders as a white box.
	if not thumbs.has(boss): thumbs[boss] = load(THUMB % boss) if ResourceLoader.exists(THUMB % boss) else null
	return thumbs[boss]

func _draw() -> void:
	if not is_instance_valid(game): return
	var campaign = game.campaign
	UiStyle.draw_icon(self, "city", Vector2(48, 50), 40)
	var title := I18n.t("album_title")
	var title_size := 30
	while title_size > 18 and UiStyle.text_width(title, title_size, UiStyle.font(800)) > size.x - 190: title_size -= 1
	UiStyle.text(self, title, Vector2(78, 62), title_size, UiStyle.LIGHT, false, 5, UiStyle.font(800))
	if campaign.unlock_all_for_testing:
		UiStyle.text(self, "TEST MODE", Vector2(80, 26), 13, Color("ff6b6b"), false, 0, UiStyle.font(800))
	var taken := 0
	for i in Campaign.level_count():
		if campaign.is_conquered(i): taken += 1
	var stars_max := Campaign.level_count()*3
	var line := I18n.t("album_count", [taken, Campaign.level_count()])
	UiStyle.text(self, line, Vector2(30, 90), 16, UiStyle.MINT, false, 0, UiStyle.body_font(800))
	var star_x := 30 + UiStyle.text_width(line, 16, UiStyle.body_font(800)) + 22
	UiStyle.draw_icon(self, "star", Vector2(star_x, 84), 20)
	UiStyle.text(self, "%d/%d" % [campaign.total_stars(), stars_max], Vector2(star_x + 14, 90), 16, UiStyle.GOLD, false, 0, UiStyle.font(800))
	# Overall progress bar to the right of the counts, up to the close button.
	var bar_x := star_x + 14 + UiStyle.text_width("%d/%d" % [campaign.total_stars(), stars_max], 16, UiStyle.font(800)) + 18
	var bar := Rect2(bar_x, 80, size.x - 100 - bar_x, 10)
	if bar.size.x > 40:
		draw_style_box(UiStyle.flat(Color("2a4258"), 5), bar)
		draw_style_box(UiStyle.flat(UiStyle.MINT, 5), Rect2(bar.position, Vector2(maxf(10.0, bar.size.x*taken/Campaign.level_count()), bar.size.y)))
	for card in cards: draw_card(card.rect, card.index)
	if cards.size() > 0 and taken == 0 and not campaign.unlock_all_for_testing:
		var last: Rect2 = cards[-1].rect
		UiStyle.text(self, I18n.t("album_tip"), Vector2(size.x/2, minf(size.y - 24, last.end.y + 28)), 15, UiStyle.MUTED, true, 0, UiStyle.body_font(700))

func draw_card(rect: Rect2, index: int) -> void:
	var campaign = game.campaign
	var open: bool = revealed(campaign, index)
	var mask: int = campaign.goals[index]
	var full := (mask & 7) == 7
	var edge := UiStyle.GOLD if full else Color(UiStyle.PANEL_EDGE, 0.5)
	draw_style_box(UiStyle.flat(Color("1f3852e6") if open else Color("172b40e6"), 16, 3 if full else 1, edge), rect)
	var boss := boss_of(index)
	var text_room := 62.0
	var art_side := minf(rect.size.x - 20, rect.size.y - text_room - 14)
	var art_center := Vector2(rect.get_center().x, rect.position.y + 8 + art_side/2)
	draw_circle(art_center, art_side*0.46, Color("243f5c") if open else Color("1b3147"))
	var picture := thumb(boss)
	var art := Rect2(art_center - Vector2.ONE*art_side/2, Vector2.ONE*art_side)
	if picture: draw_texture_rect(picture, art, false, Color.WHITE if open else SILHOUETTE)
	else: UiStyle.draw_icon(self, "flag", art_center, art_side*0.5, Color.WHITE if open else SILHOUETTE)
	if not open: UiStyle.draw_icon(self, "lock", art_center + Vector2(0, art_side*0.12), minf(34.0, art_side*0.36), Color(1, 1, 1, 0.75))
	if Campaign.is_holiday(index):
		var tag := I18n.t("festival_tag")
		var tag_w := UiStyle.text_width(tag, 12) + 16
		UiStyle.card(self, Rect2(rect.position + Vector2(8, 8), Vector2(tag_w, 22)), Color("f06a5a"), 11)
		UiStyle.text(self, tag, rect.position + Vector2(16, 24), 12, UiStyle.LIGHT)
	var name_y := rect.end.y - text_room + 14
	var city := city_label(index)
	var landmark := Campaign.boss_name(boss) if open else "???"
	UiStyle.text(self, city, Vector2(rect.get_center().x, name_y), fit(city, 16, rect.size.x - 12), UiStyle.LIGHT if open else UiStyle.MUTED, true)
	UiStyle.text(self, landmark, Vector2(rect.get_center().x, name_y + 18), fit(landmark, 12, rect.size.x - 12, UiStyle.body_font(700)), UiStyle.MUTED, true, 0, UiStyle.body_font(700))
	for k in 3:
		var at := Vector2(rect.get_center().x + (k-1)*24, rect.end.y - 16)
		UiStyle.draw_icon(self, "star", at, 20, Color.WHITE if mask & (1 << k) else Color(0.25, 0.33, 0.42, 0.9))

func fit(value: String, start: int, room: float, use_font: Font = null) -> int:
	var font_size := start
	while font_size > 9 and UiStyle.text_width(value, font_size, use_font) > room: font_size -= 1
	return font_size
