extends Control

# Full-screen panels opened from the menu: the invasion journey (one page per
# continent), the upgrade shop and the hole's wardrobe.
const Campaign = preload("res://scripts/campaign.gd")
var game
var tab := "levels"
var controls: Array[Control] = []
var preview_time := 0.0
var font: Font = ThemeDB.fallback_font
var page := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	resized.connect(func(): if visible: rebuild())

func open(value: String) -> void:
	tab = value
	page = game.campaign.selected/Campaign.CITIES_PER_REGION
	show()
	rebuild()

func button(label: String, rect: Rect2, action: Callable, selected := false, disabled := false) -> void:
	var b := Button.new()
	b.text = label
	b.position = rect.position
	b.size = rect.size
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = disabled
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color("23394b") if selected else Color("fff9ed"))
	b.add_theme_color_override("font_disabled_color", Color("82909f"))
	preload("res://scripts/ui_style.gd").button(b, Color("f1cd84") if selected else Color("7397b9"), selected)
	b.pressed.connect(action)
	add_child(b)
	controls.append(b)

func rebuild() -> void:
	for c in controls: c.queue_free()
	controls.clear()
	var w := size.x
	var h := size.y
	button("ĐÓNG", Rect2(w-113,42,85,44), game.close_panel)
	if tab == "levels": build_journey(w, h)
	elif tab == "shop": build_shop(w, h)
	else: build_wardrobe(w, h)
	queue_redraw()

func build_journey(w: float, h: float) -> void:
	if w > h:
		var width := (w-80)/4
		for slot in Campaign.CITIES_PER_REGION:
			var i: int = page*Campaign.CITIES_PER_REGION+slot
			var info := Campaign.level_info(i)
			var locked: bool = not game.campaign.can_select(i)
			var stars := "★".repeat(game.campaign.medals[i])
			button("%d · %s\n%s" % [slot+1,info.city,"Chưa mở" if locked else stars if stars != "" else Campaign.boss_name(info.boss).capitalize()],Rect2(28+(slot%4)*(width+8),190+(slot/4)*98,width,86),func(): choose_level(i),i==game.campaign.selected,locked)
		button("← CHÂU TRƯỚC",Rect2(28,h-95,150,48),func(): turn_page(-1),false,page==0)
		button("CHÂU SAU →",Rect2(w-178,h-95,150,48),func(): turn_page(1),false,page>=Campaign.REGIONS.size()-1)
		return
	var row_h := minf(96, (h-380)/4)
	for slot in Campaign.CITIES_PER_REGION:
		var i: int = page*Campaign.CITIES_PER_REGION + slot
		var locked: bool = not game.campaign.can_select(i)
		var info := Campaign.level_info(i)
		var stars := "★".repeat(game.campaign.medals[i])
		var kind: String = Campaign.boss_name(info.boss).capitalize()
		var label := "%d · %s\n%s" % [slot+1, info.city, "Chưa mở" if locked else stars if stars != "" else kind]
		button(label, Rect2(28+(slot%2)*(w-44)/2, 200+(slot/2)*row_h, (w-68)/2, row_h-10), func(): choose_level(i), i == game.campaign.selected, locked)
	button("← CHÂU TRƯỚC", Rect2(28,h-135,150,48), func(): turn_page(-1), false, page == 0)
	button("CHÂU SAU →", Rect2(w-178,h-135,150,48), func(): turn_page(1), false, page >= Campaign.REGIONS.size()-1)

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
		if w > size.y: rect = Rect2(28+(i%2)*(w/2)+w/2-166,176+(i/2)*row_h,110,72)
		button("ĐẦY" if maxed else "%d XU" % cost, rect, func(): buy(id), false, maxed or game.campaign.coins < cost)

func build_wardrobe(w: float, h: float) -> void:
	var left := w*0.46 if w > h else 28.0
	var area := w-left-28 if w > h else w-56
	for i in 4:
		var id: String = ["crafts","skins","effects","trails"][i]
		button(["VẬT THỂ BAY","HỐ","KHI NUỐT","VỆT ĐI"][i], Rect2(left+i*(area+8)/4,120,(area-24)/4,44), func(): tab=id; rebuild(), tab==id)
	var choices: Array = preload("res://scripts/fleet.gd").NAMES if tab == "crafts" else Campaign.SKINS if tab == "skins" else Campaign.EFFECTS if tab == "effects" else Campaign.TRAILS
	var current: int = game.campaign.craft if tab == "crafts" else game.campaign.skin if tab == "skins" else game.campaign.effect if tab == "effects" else game.campaign.trail
	for i in choices.size():
		var label: String = choices[i][0] if tab == "skins" else choices[i]
		button(("✓ " if i == current else "")+label, Rect2(left+(i%2)*(area+8)/2,h-360+(i/2)*65,(area-8)/2,55), func(): equip(i), i==current)

func turn_page(delta: int) -> void:
	page = clampi(page+delta, 0, Campaign.REGIONS.size()-1)
	rebuild()

func choose_level(index: int) -> void:
	if not game.campaign.can_select(index): return
	game.load_level(index)
	game.close_panel()

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
	if not visible or tab in ["levels", "shop"]: return
	preview_time += dt
	# Preview the chosen particles in place without starting a round.
	if preview_time > 1.1:
		preview_time = 0.0
		if tab == "effects": game.fx.puff(game.hole_position, 0.9, 1.0)
	if tab == "trails":
		game.fx.move_trail(game.hole_position+Vector3(sin(preview_time*TAU)*1.4,0,cos(preview_time*TAU)*1.4), true)

func label_at(value: String, pos: Vector2, font_size: int, color := Color("fff9ed")) -> void:
	draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var full := tab in ["levels", "shop"]
	draw_rect(Rect2(Vector2.ZERO,size), Color("162a40ed") if full else Color("162a4050"))
	if not full: draw_rect(Rect2(size.x*0.44,96,size.x*0.56,size.y-96) if size.x>size.y else Rect2(0,size.y-390,size.x,390),Color("162a40f5"))
	if tab == "levels": draw_journey()
	elif tab == "shop": draw_shop()
	else:
		label_at("BỘ SƯU TẬP", Vector2(28,74), 24)
		label_at("Chạm để trang bị",Vector2(28,size.y-90),17) if size.x>size.y else label_at("Chạm để trang bị · Xem thử ngay trên hố",Vector2(28,size.y-415),17)
		label_at("Tất cả mẫu đều dùng miễn phí",Vector2(28,size.y-55),16,Color("c1d0db"))

func draw_journey() -> void:
	var region: Dictionary = Campaign.REGIONS[page]
	var testing: bool = game.campaign.unlock_all_for_testing
	label_at("HÀNH TRÌNH XÂM LĂNG", Vector2(28,74), 24)
	label_at("TEST · Đã mở tất cả %d thành phố" % Campaign.level_count() if testing else "Chiếm một thành phố để mở thành phố kế tiếp", Vector2(28,120), 16, Color("f1cd84") if testing else Color("c1d0db"))
	label_at(region.name, Vector2(28,165), 22, Color("9ff0d8"))
	label_at("Đã chiếm %d/%d" % [game.campaign.region_progress(page), Campaign.CITIES_PER_REGION], Vector2(size.x-170,165), 17, Color("f1cd84"))
	label_at("%d / %d" % [page+1, Campaign.REGIONS.size()], Vector2(size.x/2-20,size.y-(64 if size.x>size.y else 104)), 18)
	label_at("3 sao: chiếm thành phố và nuốt ít nhất 90%", Vector2(28,size.y-(18 if size.x>size.y else 55)), 16, Color("c1d0db"))

func draw_shop() -> void:
	label_at("NÂNG CẤP ĐĨA BAY", Vector2(28,74), 24)
	label_at("XU: %d" % game.campaign.coins, Vector2(28,120), 20, Color("f1cd84"))
	var row_h := shop_row_height()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("223a50")
	style.set_corner_radius_all(16)
	for i in Campaign.UPGRADES.size():
		var upgrade: Array = Campaign.UPGRADES[i]
		var level: int = game.campaign.upgrades[upgrade[0]]
		var y := 176 + i*row_h
		if size.x > size.y:
			y = 176+(i/2)*row_h
			var x := 28+(i%2)*(size.x/2)
			draw_style_box(style,Rect2(x-8,y-8,size.x/2-28,row_h-4))
			label_at(upgrade[1],Vector2(x+8,y+20),18)
			label_at(upgrade[2],Vector2(x+8,y+43),12,Color("c1d0db"))
			for k in int(upgrade[4]): draw_rect(Rect2(x+8+k*18,y+59,14,8),Color("9ff0d8") if k<level else Color("3a5367"))
			continue
		draw_style_box(style, Rect2(20, y-8, size.x-40, row_h-4))
		label_at(upgrade[1], Vector2(40, y+22), 19)
		label_at(upgrade[2], Vector2(40, y+46), 14, Color("c1d0db"))
		for k in int(upgrade[4]):
			draw_rect(Rect2(40 + k*18, y+58, 14, 8), Color("9ff0d8") if k < level else Color("3a5367"))
	label_at("Nhận xu sau mỗi màn · Nhiều xu hơn khi thắng nhiều sao", Vector2(28,size.y-55), 15, Color("c1d0db"))
