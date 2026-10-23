extends Control

# Full-screen panels opened from the menu: the invasion journey (a 3D map per
# continent, journey_map.gd), the conquest album (album.gd), the upgrade shop,
# the hole's wardrobe and the settings panel (language and sound).
const Campaign = preload("res://scripts/campaign.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const I18n = preload("res://scripts/i18n.gd")
const JourneyMap = preload("res://scripts/journey_map.gd")
const Album = preload("res://scripts/album.gd")
const Cosmetics = preload("res://scripts/cosmetics.gd")
const LookCard = preload("res://scripts/look_card.gd")
const WARDROBE_TABS := ["crafts", "skins", "effects", "trails"]
# Panels that cover the whole screen (no 3D preview of the hole beside them).
const FULL_TABS := ["levels", "album", "shop", "language"]
const CARD_H := 130.0
const GAP := 10.0
const UPGRADE_ICONS := {"size":"gem", "speed":"bolt", "time":"clock", "magnet":"magnet", "greed":"coin"}
var game
var tab := "levels"
var controls: Array[Control] = []
var preview_time := 0.0
var font: Font = UiStyle.font(700)
var body_font: Font = UiStyle.body_font(700)
var page := 0
var look_page := 0
var journey: Control
var album: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	journey = JourneyMap.new()
	journey.game = game
	add_child(journey)
	album = Album.new()
	album.game = game
	add_child(album)
	hide()
	resized.connect(func(): if visible: rebuild())
	visibility_changed.connect(on_visibility)

func open(value: String) -> void:
	tab = value
	page = Campaign.region_of(game.campaign.selected)
	show()
	rebuild()
	if tab == "levels":
		journey.game = game
		journey.open(game.campaign.selected)
		# The map covers the whole screen, so the city behind it need not render.
		get_viewport().disable_3d = true
	elif tab == "album":
		album.game = game
		album.open(page)
		get_viewport().disable_3d = true

func on_visibility() -> void:
	if visible: return
	journey.close()
	album.hide()
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
	elif tab == "album": album.layout()
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
		button(I18n.t("tab_" + id), Rect2(left+i*(area+8)/4,96,(area-24)/4,48), func(): tab=id; look_page=0; rebuild(), tab==id)
	var grid := Rect2(left, 156, area, h-156-84) if w > h else Rect2(28, h-356, w-56, 280)
	var columns := clampi(int(grid.size.x/140), 2, 4)
	var rows := maxi(1, int((grid.size.y+GAP)/(CARD_H+GAP)))
	var order := look_order()
	var per_page := columns*rows
	var pages := ceili(order.size()/float(per_page))
	look_page = clampi(look_page, 0, pages-1)
	var cell := (grid.size.x-GAP*(columns-1))/columns
	for k in mini(per_page, order.size()-look_page*per_page):
		var i: int = order[look_page*per_page + k]
		var card := LookCard.new()
		card.position = grid.position + Vector2((k%columns)*(cell+GAP), (k/columns)*(CARD_H+GAP))
		card.size = Vector2(cell, CARD_H)
		var state := card_state(i)
		card.setup(tab, i, choice_name(i), state.label, state.enabled, state.equipped, func(): pick_look(i), state.icon)
		add_child(card)
		controls.append(card)
	if pages > 1:
		var arrows := Vector2(grid.end.x-100, grid.end.y+12) if w > h else Vector2(grid.end.x-100, grid.position.y-56)
		button("", Rect2(arrows, Vector2(46, 42)), func(): turn_look_page(-1), false, look_page == 0, "left")
		button("", Rect2(arrows+Vector2(54, 0), Vector2(46, 42)), func(): turn_look_page(1), false, look_page == pages-1, "right")

func look_order() -> Array:
	return Cosmetics.display_order(tab)

func turn_look_page(delta: int) -> void:
	look_page += delta
	rebuild()

# Button text and state for one card, following the 2D shop: Equipped, Equip or
# a coin price. Every look, saucers included, is bought with coins.
func card_state(index: int) -> Dictionary:
	var campaign = game.campaign
	if index == campaign.equipped(tab): return {"label":I18n.t("equipped"), "enabled":false, "equipped":true, "icon":"tick"}
	if campaign.owns(tab, index): return {"label":I18n.t("equip"), "enabled":true, "equipped":false, "icon":""}
	var cost := Cosmetics.price(tab, index)
	return {"label":str(cost), "enabled":campaign.coins >= cost, "equipped":false, "icon":"coin"}

# Tapping an owned look equips it; tapping an affordable one buys and equips it.
func pick_look(index: int) -> void:
	if not game.campaign.owns(tab, index):
		if not game.campaign.buy_look(tab, index): return
		game.sfx.play("grow")
	equip(index)

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
	var row := sound_row()
	var volume: float = game.campaign.volume
	button("-", Rect2(row.position, Vector2(56, row.size.y)), func(): change_volume(-0.1), false, volume <= 0.0).font_size = 28
	button("+", Rect2(row.end.x - 56, row.position.y, 56, row.size.y), func(): change_volume(0.1), false, volume >= 1.0).font_size = 28

# The volume stepper sits under the language buttons: [-] speaker + bar [+].
func sound_row() -> Rect2:
	var columns := 2 if size.x > size.y else 1
	var cell := minf(300.0, (size.x - 80)/columns)
	var width := cell*columns + 16*(columns-1)
	var rows := ceili(I18n.LANGS.size()/float(columns))
	return Rect2((size.x - width)/2, 130 + rows*76 + 44, width, 56)

func change_volume(delta: float) -> void:
	game.set_volume(game.campaign.volume + delta)
	game.sfx.play("click")
	rebuild()

func pick_language(code: String) -> void:
	game.set_language(code)
	rebuild()

func buy(id: String) -> void:
	if game.campaign.buy(id):
		game.sfx.play("grow")
		game.persist()
	rebuild()

func equip(index: int) -> void:
	if not game.campaign.equip(tab, index): return
	game.apply_style()
	game.persist()
	preview_time = 1.0
	rebuild()

func _process(dt: float) -> void:
	if not visible or tab in FULL_TABS: return
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
	var full := tab in FULL_TABS
	draw_rect(Rect2(Vector2.ZERO,size), Color("11233aF2") if full else Color("162a4050"))
	if tab in ["levels", "album"]: return
	if not full: draw_rect(Rect2(size.x*0.44,0,size.x*0.56,size.y) if size.x>size.y else Rect2(0,size.y-390,size.x,390),Color("142840f2"))
	if tab == "shop": draw_shop()
	elif tab == "language": draw_language()
	else:
		var left := size.x*0.46 if size.x > size.y else 28.0
		title_at(I18n.t("collection"), Vector2(left, 64))
		label_at(I18n.t("tap_equip"), Vector2(left,size.y-70), 16, UiStyle.MUTED, body_font) if size.x>size.y else label_at(I18n.t("tap_equip"),Vector2(28,size.y-415),17)
		label_at(I18n.t("looks_tip"), Vector2(left,size.y-40), 15, UiStyle.MINT, body_font)
		UiStyle.draw_icon(self, "coin", Vector2(size.x-196, 46), 30)
		UiStyle.text(self, str(game.campaign.coins), Vector2(size.x-176, 56), 22, UiStyle.GOLD, false, 0, UiStyle.font(800))

func draw_language() -> void:
	UiStyle.draw_icon(self, "settings", Vector2(52, 62), 44)
	title_at(I18n.t("settings_title"), Vector2(88, 74))
	label_at(I18n.t("language"), Vector2(sound_row().position.x, 118), 18, UiStyle.MUTED)
	var row := sound_row()
	var volume: float = game.campaign.volume
	label_at(I18n.t("sound"), row.position + Vector2(0, -12), 18, UiStyle.MUTED)
	var bar := Rect2(row.position.x + 66, row.position.y, row.size.x - 132, row.size.y)
	UiStyle.card(self, bar, Color("1f3852"), 16)
	UiStyle.draw_icon(self, "sound" if volume > 0.0 else "mute", bar.position + Vector2(28, bar.size.y/2), 30)
	var steps := 10
	var track := Rect2(bar.position.x + 52, bar.position.y + 20, bar.size.x - 116, 16)
	var step_w := (track.size.x - (steps-1)*3)/steps
	for k in steps:
		var on := k < roundi(volume*steps)
		draw_style_box(UiStyle.flat(UiStyle.MINT if on else Color("3a5367"), 4), Rect2(track.position.x + k*(step_w+3), track.position.y, step_w, track.size.y))
	UiStyle.text(self, "%d%%" % roundi(volume*100), Vector2(bar.end.x - 34, bar.position.y + 36), 16, UiStyle.LIGHT, true, 0, UiStyle.font(800))

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
