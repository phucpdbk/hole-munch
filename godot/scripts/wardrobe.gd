extends Control

# Full-screen panels opened from the menu: the invasion journey (a 3D map per
# continent, journey_map.gd), the upgrade shop, the hole's wardrobe and the
# language picker.
const Campaign = preload("res://scripts/campaign.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const I18n = preload("res://scripts/i18n.gd")
const JourneyMap = preload("res://scripts/journey_map.gd")
const Fleet = preload("res://scripts/fleet.gd")
const WARDROBE_TABS := ["crafts", "skins", "effects", "trails"]
const UPGRADE_ICONS := {"size":"gem", "speed":"bolt", "time":"clock", "magnet":"magnet", "greed":"coin"}
var game
var tab := "levels"
var controls: Array[Control] = []
var preview_time := 0.0
var font: Font = UiStyle.font(700)
var body_font: Font = UiStyle.body_font(700)
var page := 0
var journey: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	journey = JourneyMap.new()
	journey.game = game
	add_child(journey)
	hide()
	resized.connect(func(): if visible: rebuild())
	visibility_changed.connect(on_visibility)

func open(value: String) -> void:
	tab = value
	page = game.campaign.selected/Campaign.CITIES_PER_REGION
	show()
	rebuild()
	if tab == "levels":
		journey.game = game
		journey.open(game.campaign.selected)
		# The map covers the whole screen, so the city behind it need not render.
		get_viewport().disable_3d = true

func on_visibility() -> void:
	if visible: return
	journey.close()
	get_viewport().disable_3d = false

func button(label: String, rect: Rect2, action: Callable, selected := false, disabled := false, icon_kind := "") -> BaseButton:
	var b := UiButton.new()
	b.text = label
	b.position = rect.position
	b.size = rect.size
	b.disabled = disabled
	b.font_size = 17
	b.accent = UiStyle.GOLD if selected else Color("35546d")
	b.primary = selected
	if icon_kind != "": b.icon = UiStyle.icon(icon_kind)
	b.pressed.connect(action)
	add_child(b)
	controls.append(b)
	return b

func rebuild() -> void:
	for c in controls: c.queue_free()
	controls.clear()
	var w := size.x
	var h := size.y
	button("", Rect2(w-78, 18, 58, 56), game.close_panel, false, false, "close")
	if tab == "levels": journey.layout()
	elif tab == "shop": build_shop(w, h)
	elif tab == "language": build_language(w, h)
	else: build_wardrobe(w, h)
	queue_redraw()

# Journey paging kept here for callers (smoke checks, captures).
func turn_page(delta: int) -> void:
	journey.turn(clampi(page + delta, 0, Campaign.REGIONS.size()-1) - journey.page)
	page = journey.page

func choose_level(index: int) -> void:
	if not game.campaign.can_select(index): return
	game.load_level(index)
	game.close_panel()

# Journey card: load the city and start it straight away.
func play_level(index: int) -> void:
	if not game.campaign.can_select(index): return
	choose_level(index)
	game.on_play()

func shop_row_height() -> float:
	if size.x > size.y: return 100.0
	return minf(96, (size.y-300)/Campaign.UPGRADES.size())

func build_shop(w: float, _h: float) -> void:
	var row_h := shop_row_height()
	for i in Campaign.UPGRADES.size():
		var upgrade: Array = Campaign.UPGRADES[i]
		var id: String = upgrade[0]
		var maxed: bool = game.campaign.upgrades[id] >= int(upgrade[4])
		var cost: int = game.campaign.upgrade_cost(id)
		var rect := Rect2(w-150, 176+i*row_h, 122, row_h-16)
		if w > size.y: rect = Rect2(28+(i%2)*(w/2)+w/2-172,176+(i/2)*row_h+4,116,64)
		button(I18n.t("max") if maxed else str(cost), rect, func(): buy(id), not maxed and game.campaign.coins >= cost, maxed or game.campaign.coins < cost, "tick" if maxed else "coin")

func build_wardrobe(w: float, h: float) -> void:
	var left := w*0.46 if w > h else 28.0
	var area := w-left-28 if w > h else w-56
	for i in 4:
		var id: String = WARDROBE_TABS[i]
		button(I18n.t("tab_" + id), Rect2(left+i*(area+8)/4,96,(area-24)/4,48), func(): tab=id; rebuild(), tab==id)
	var count: int = Fleet.NAMES.size() if tab == "crafts" else Campaign.SKINS.size() if tab == "skins" else Campaign.EFFECTS.size() if tab == "effects" else Campaign.TRAILS.size()
	var current: int = game.campaign.craft if tab == "crafts" else game.campaign.skin if tab == "skins" else game.campaign.effect if tab == "effects" else game.campaign.trail
	for i in count:
		# Twelve hole skins need three columns to stay above the bottom edge.
		var columns := 3 if count > 8 else 2
		var cell := (area-8*(columns-1))/columns
		var b := button(choice_name(i), Rect2(left+(i%columns)*(cell+8),h-360+(i/columns)*62,cell,54), func(): equip(i), i==current, false, "tick" if i == current else "")
		b.font_size = 15

func choice_name(index: int) -> String:
	match tab:
		"crafts": return I18n.t("craft%d" % index)
		"skins": return Campaign.skin_name(index)
		"effects": return Campaign.effect_name(index)
	return Campaign.trail_name(index)

func build_language(w: float, h: float) -> void:
	var columns := 2 if w > h else 1
	var cell := minf(300.0, (w - 80)/columns)
	var left := (w - (cell*columns + 16*(columns-1)))/2
	for i in I18n.LANGS.size():
		var code: String = I18n.LANGS[i]
		var rect := Rect2(left + (i%columns)*(cell+16), 130 + (i/columns)*76, cell, 62)
		var b := button(I18n.NAMES[code], rect, func(): pick_language(code), code == I18n.lang, false, "tick" if code == I18n.lang else "")
		b.font_size = 20

func pick_language(code: String) -> void:
	game.set_language(code)
	rebuild()

func buy(id: String) -> void:
	if game.campaign.buy(id):
		game.sfx.play("grow")
		game.persist()
	rebuild()

func equip(index: int) -> void:
	if tab == "crafts": game.campaign.craft = index
	elif tab == "skins": game.campaign.skin = index
	elif tab == "effects": game.campaign.effect = index
	else: game.campaign.trail = index
	game.apply_style()
	game.persist()
	preview_time = 1.0
	rebuild()

func _process(dt: float) -> void:
	if not visible or tab in ["levels", "shop", "language"]: return
	preview_time += dt
	# Preview the chosen particles in place without starting a round.
	if preview_time > 1.1:
		preview_time = 0.0
		if tab == "effects": game.fx.puff(game.hole_position, 0.9, 1.0)
	if tab == "trails":
		game.fx.move_trail(game.hole_position+Vector3(sin(preview_time*TAU)*1.4,0,cos(preview_time*TAU)*1.4), true, game.radius)

func label_at(value: String, pos: Vector2, font_size: int, color := UiStyle.LIGHT, use_font: Font = null) -> void:
	UiStyle.text(self, value, pos, font_size, color, false, 0, use_font if use_font else font)

func title_at(value: String, pos: Vector2) -> void:
	UiStyle.text(self, value, pos, 30, UiStyle.LIGHT, false, 5, UiStyle.font(800))

func _draw() -> void:
	var full := tab in ["levels", "shop", "language"]
	draw_rect(Rect2(Vector2.ZERO,size), Color("11233aF2") if full else Color("162a4050"))
	if tab == "levels": return
	if not full: draw_rect(Rect2(size.x*0.44,0,size.x*0.56,size.y) if size.x>size.y else Rect2(0,size.y-390,size.x,390),Color("142840f2"))
	if tab == "shop": draw_shop()
	elif tab == "language": draw_language()
	else:
		var left := size.x*0.46 if size.x > size.y else 28.0
		title_at(I18n.t("collection"), Vector2(left, 64))
		label_at(I18n.t("tap_equip"), Vector2(left,size.y-70), 16, UiStyle.MUTED, body_font) if size.x>size.y else label_at(I18n.t("tap_equip"),Vector2(28,size.y-415),17)
		label_at(I18n.t("all_free"), Vector2(left,size.y-40), 15, UiStyle.MINT, body_font)

func draw_language() -> void:
	UiStyle.draw_icon(self, "language", Vector2(52, 62), 48)
	title_at(I18n.t("lang_title"), Vector2(88, 74))

func draw_shop() -> void:
	UiStyle.draw_icon(self, "upgrade", Vector2(50, 62), 46)
	title_at(I18n.t("shop_title"), Vector2(84, 74))
	UiStyle.draw_icon(self, "coin", Vector2(48, 120), 34)
	UiStyle.text(self, str(game.campaign.coins), Vector2(70, 130), 24, UiStyle.GOLD, false, 0, UiStyle.font(800))
	var row_h := shop_row_height()
	for i in Campaign.UPGRADES.size():
		var upgrade: Array = Campaign.UPGRADES[i]
		var level: int = game.campaign.upgrades[upgrade[0]]
		var y := 176 + i*row_h
		var x := 28.0
		var width := size.x - 40
		if size.x > size.y:
			y = 176+(i/2)*row_h
			x = 28+(i%2)*(size.x/2)
			width = size.x/2-28
		UiStyle.card(self, Rect2(x-8, y-8, width, row_h-8), Color("1f3852"), 18)
		UiStyle.draw_icon(self, UPGRADE_ICONS.get(upgrade[0], "upgrade"), Vector2(x+26, y+34), 46)
		label_at(I18n.t("up_" + upgrade[0]), Vector2(x+58,y+24), 19)
		label_at(I18n.t("up_%s_d" % upgrade[0]), Vector2(x+58,y+46), 13, UiStyle.MUTED, body_font)
		for k in int(upgrade[4]):
			draw_style_box(UiStyle.flat(UiStyle.MINT if k < level else Color("3a5367"), 4), Rect2(x+58+k*17, y+58, 13, 9))
	label_at(I18n.t("shop_tip"), Vector2(28,size.y-28), 15, UiStyle.MUTED, body_font)
