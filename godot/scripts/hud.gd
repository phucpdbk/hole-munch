extends Control

signal play_requested
signal pause_requested
signal menu_requested
signal levels_requested
signal styles_requested
signal shop_requested
var level_title := ""
var city := ""
var region_title := ""
var map_title := ""
var landmark := true
var coins := 0
var reward := 0
var shop_button: Button
var weather_title := ""
var boss_title := ""
var has_next := true
var level_count := 12
var playtest := false
var levels_button: Button
var styles_button: Button
var mode := "menu"
var last_layout_mode := ""
var score := 0
var best := 0
var seconds := 110.0
var growth := 0.0
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
var play_button: Button
var pause_button: Button
var menu_button: Button
var font: Font = ThemeDB.fallback_font
const INK = Color("223649")
const LIGHT = Color("fff9ed")
const MUTED = Color("a4b6c5")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_button = make_button("▶  CHƠI NGAY", Color("f6cb70"), INK)
	play_button.pressed.connect(func(): play_requested.emit())
	pause_button = make_button("Ⅱ", Color("233c50"), LIGHT)
	pause_button.pressed.connect(func(): pause_requested.emit())
	menu_button = make_button("VỀ TRANG CHỦ", Color("334e60"), LIGHT)
	menu_button.pressed.connect(func(): menu_requested.emit())
	levels_button = make_button("CHỌN MÀN", Color("334e60"), LIGHT)
	levels_button.pressed.connect(func(): levels_requested.emit())
	styles_button = make_button("TỦ ĐỒ", Color("334e60"), LIGHT)
	styles_button.pressed.connect(func(): styles_requested.emit())
	shop_button = make_button("NÂNG CẤP", Color("5b4a8a"), LIGHT)
	shop_button.pressed.connect(func(): shop_requested.emit())
	levels_button.icon = preload("res://scripts/ui_style.gd").icon("map")
	shop_button.icon = preload("res://scripts/ui_style.gd").icon("upgrade")
	styles_button.icon = preload("res://scripts/ui_style.gd").icon("fleet")
	resized.connect(layout)
	layout()

func make_button(text: String, bg: Color, fg: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", fg)
	preload("res://scripts/ui_style.gd").button(button, bg, fg == INK)
	add_child(button)
	return button

func layout() -> void:
	if not is_instance_valid(play_button): return
	var w := size.x
	var h := size.y
	play_button.position = Vector2(44, h - 172)
	play_button.size = Vector2(w - 88, 66)
	pause_button.position = Vector2(w - 84, 42)
	pause_button.size = Vector2(54, 54)
	menu_button.position = Vector2(44, h - 94)
	menu_button.size = Vector2(w - 88, 52)
	var third := (w-88-16)/3
	for i in 3:
		var b: Button = [levels_button, shop_button, styles_button][i]
		b.position = Vector2(44 + i*(third+8), h-94)
		b.size = Vector2(third, 52)
		b.add_theme_font_size_override("font_size", 13)
	if w > h:
		var left := 36.0 if mode == "menu" else w/2-264
		var width := 360.0 if mode == "menu" else 528.0
		play_button.position = Vector2(left,h-166)
		play_button.size = Vector2(width,60)
		menu_button.position = Vector2(left,h-92)
		menu_button.size = Vector2(width,52)
		for i in 3:
			var b: Button = [levels_button, shop_button, styles_button][i]
			b.position = Vector2(36+i*124,h-92)
			b.size = Vector2(112,52)

func sync() -> void:
	if last_layout_mode != mode:
		layout()
		last_layout_mode = mode
	play_button.visible = mode != "playing"
	play_button.text = "TIẾP TỤC" if mode == "paused" else "MÀN TIẾP THEO" if mode == "result" and won and has_next else "CHƠI LẠI" if mode == "result" else "▶  CHƠI NGAY"
	levels_button.visible = mode == "menu"
	styles_button.visible = mode == "menu"
	shop_button.visible = mode == "menu"
	menu_button.visible = mode in ["paused", "result"]
	pause_button.visible = mode == "playing"
	queue_redraw()

func panel(rect: Rect2, color: Color, radius: int = 20) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(1)
	style.border_color = Color("527288")
	style.shadow_color = Color(0.02,0.05,0.1,0.35)
	style.shadow_size = 10
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	draw_style_box(style, rect)

func text_at(text: String, pos: Vector2, font_size: int, color: Color, centered := false) -> void:
	if centered: pos.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	var w := size.x
	var h := size.y
	# White flash when the boss is swallowed.
	if flash > 0: draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash*0.55))
	if w > h and mode == "menu":
		draw_landscape_menu()
		return
	if w > h and mode in ["paused", "result"]:
		draw_landscape_result()
		return
	if mode == "menu":
		panel(Rect2(w/2-128, 54, 256, 30), Color("2b2350"), 15)
		text_at("CUỘC XÂM LĂNG TRÁI ĐẤT", Vector2(w/2, 75), 13, Color("9ff0d8"), true)
		panel(Rect2(w-118, 12, 100, 34), Color("223649e6"), 16)
		text_at("XU %d" % coins, Vector2(w-68, 35), 15, Color("f6cb70"), true)
		var title_width := font.get_string_size("HOLE MUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		draw_string_outline(font, Vector2(w/2-title_width/2, 153), "HOLE MUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 5, Color("223649"))
		text_at("HOLE MUNCH", Vector2(w/2, 153), 52, LIGHT, true)
		panel(Rect2(w/2-173, 165, 346, 36), Color("223649dc"), 16)
		text_at(level_title, Vector2(w/2, 189), 18, LIGHT, true)
		panel(Rect2(24, h-276, w-48, 250), Color("223649f5"), 28)
		text_at(region_title, Vector2(w/2, h-240), 15, Color("f6cb70"), true)
		text_at("%s · %d giây · Map %s" % [weather_title, int(seconds), map_title], Vector2(w/2, h-214), 15, MUTED, true)
		text_at(("Nuốt thành phố, rồi chiếm " if landmark else "Nuốt thành phố, rồi hạ ") + boss_title.to_lower(), Vector2(w/2, h-188), 15, LIGHT, true)
	elif mode == "playing":
		panel(Rect2(24, 36, 126, 68), Color("223649ed"), 20)
		text_at("ĐIỂM", Vector2(42, 60), 12, MUTED)
		text_at(str(score), Vector2(42, 88), 26, LIGHT)
		panel(Rect2(w/2-98, 36, 108, 68), Color("223649ed"), 20)
		panel(Rect2(w-172, 36, 80, 68), Color("223649ed"), 20)
		text_at("DỌN", Vector2(w-132, 60), 12, MUTED, true)
		text_at("%d%%" % int(completion*100), Vector2(w-132, 88), 22, LIGHT, true)
		if combo >= 2: draw_combo()
		draw_floaters()
		text_at("%d:%02d" % [int(ceil(seconds))/60, int(ceil(seconds))%60], Vector2(w/2-44, 82), 28, Color("ffad94") if seconds<15 else LIGHT, true)
		panel(Rect2(24, h-115, w-48, 88), Color("223649ed"), 20)
		text_at(("CHIẾM " if landmark else "HẠ ") + boss_title, Vector2(44, h-82), 16, LIGHT)
		text_at("%d%%" % int(growth*100), Vector2(w-86, h-82), 17, Color("f6cb70"))
		panel(Rect2(44, h-63, w-88, 9), Color("465d6b"), 4)
		panel(Rect2(44, h-63, maxf(8, (w-88)*growth), 9), Color("b7a2f1"), 4)
		if waiting:
			panel(Rect2(w/2-166, h/2+88, 332, 45), Color("223649df"), 18)
			text_at("Kéo một ngón để bắt đầu", Vector2(w/2, h/2+117), 18, LIGHT, true)
		elif note != "":
			text_at(note, Vector2(w/2, 186), 18, INK, true)
		if stick_active:
			draw_circle(stick_origin, 54, Color(1,1,1,0.13))
			draw_arc(stick_origin, 54, 0, TAU, 32, Color(1,1,1,0.65), 2, true)
			draw_circle(stick_origin+stick_delta.limit_length(54), 22, Color("fff9edb0"))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color("172b4180"))
		panel(Rect2(24, h-440, w-48, 414), Color("223649f5"), 28)
		if mode == "result":
			for i in range(3): draw_star(Vector2(w/2+(i-1)*62, h-390), 24, i < stars)
		var title := "TẠM DỪNG" if mode == "paused" else ("ĐÃ CHIẾM %s!" % city.to_upper()) if won else "BỊ ĐẨY LÙI!"
		text_at(title, Vector2(w/2, h-320), 32, Color("f6cb70"), true)
		text_at("%s điểm  ·  %s món đã nuốt" % [score, eaten], Vector2(w/2, h-280), 19, LIGHT, true)
		text_at("Dọn sạch %d%%  ·  Combo tốt nhất %d" % [int(completion*100), best_combo], Vector2(w/2, h-252), 16, LIGHT, true)
		if mode == "result": text_at("+%d xu  ·  Tổng %d xu" % [reward, coins], Vector2(w/2, h-222), 16, Color("f6cb70"), true)
		var sub := "Thành phố sẽ chờ bạn." if mode == "paused" else "Trái Đất đã thuộc về bạn!" if won and not has_next else "Thành phố tiếp theo đã mở!" if won else "Nuốt đồ nhỏ trước · Mua nâng cấp để mạnh hơn"
		if mode == "result" and won and playtest: sub = "TEST · Bạn có thể chọn bất kỳ màn nào."
		text_at(sub, Vector2(w/2, h-194), 15, MUTED, true)

func draw_landscape_menu() -> void:
	var h := size.y
	panel(Rect2(20,24,400,h-48),Color("152a40f2"),24)
	text_at("CUỘC XÂM LĂNG TRÁI ĐẤT",Vector2(36,60),15,Color("9ff0d8"))
	text_at("HOLE MUNCH",Vector2(36,112),42,LIGHT)
	text_at(level_title,Vector2(36,153),20,Color("f6cb70"))
	text_at(region_title,Vector2(36,190),17,LIGHT)
	text_at("%s · %d giây · Map %s" % [weather_title,int(seconds),map_title],Vector2(36,219),15,MUTED)
	text_at(("CHIẾM " if landmark else "HẠ ")+boss_title,Vector2(36,255),16,LIGHT)
	text_at("Kéo để di chuyển · Nuốt đồ nhỏ để lớn lên",Vector2(36,290),15,MUTED)
	panel(Rect2(size.x-156,28,128,40),Color("223649ed"),16)
	text_at("XU %d" % coins,Vector2(size.x-92,55),18,Color("f6cb70"),true)

func draw_landscape_result() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO,size),Color("172b4180"))
	panel(Rect2(w/2-300,24,600,h-48),Color("223649f5"),24)
	if mode == "result":
		for i in 3: draw_star(Vector2(w/2+(i-1)*62,72),22,i<stars)
	var title := "TẠM DỪNG" if mode == "paused" else ("ĐÃ CHIẾM %s!" % city.to_upper()) if won else "BỊ ĐẨY LÙI!"
	text_at(title,Vector2(w/2,130),28,Color("f6cb70"),true)
	text_at("%s điểm · %s món đã nuốt" % [score,eaten],Vector2(w/2,172),19,LIGHT,true)
	text_at("Dọn sạch %d%% · Combo tốt nhất %d" % [int(completion*100),best_combo],Vector2(w/2,205),17,LIGHT,true)
	if mode == "result": text_at("+%d xu · Tổng %d xu" % [reward,coins],Vector2(w/2,240),18,Color("f6cb70"),true)
	text_at("Thành phố sẽ chờ bạn." if mode == "paused" else "TEST · Bạn có thể chọn bất kỳ màn nào." if playtest else "Tiếp tục hành trình chinh phục!",Vector2(w/2,280),16,MUTED,true)

func draw_combo() -> void:
	panel(Rect2(24, 112, 152, 36), Color("f6cb70"), 16)
	var label := "COMBO %d" % combo
	if multiplier > 1.0: label += "  ×%s" % ("%.1f" % multiplier).trim_suffix(".0")
	text_at(label, Vector2(100, 137), 17, INK, true)

# Score popups rise and fade above the swallowed object.
func draw_floaters() -> void:
	for floater in floaters:
		var t: float = floater.t
		var font_size := 30 if floater.big else 20
		var pos: Vector2 = floater.screen - Vector2(0, t*46)
		var color := Color("f6cb70") if floater.big else LIGHT
		color.a = 1.0 - t*t
		var outline := Color(INK, color.a)
		var width := font.get_string_size(floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string_outline(font, pos - Vector2(width/2, 0), floater.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, outline)
		text_at(floater.text, pos, font_size, color, true)

func draw_star(center: Vector2, radius: float, filled: bool) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var r := radius if i % 2 == 0 else radius*0.45
		var angle := -PI/2 + i*PI/5
		points.append(center + Vector2(cos(angle), sin(angle))*r)
	draw_colored_polygon(points, Color("f6cb70") if filled else Color("465d6b"))
