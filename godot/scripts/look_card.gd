extends Control

# One shop card in the wardrobe, as in the 2D shop: a live preview (hole skin,
# bite effect or trail), the name, and a price / Equip / Equipped button.
const Campaign = preload("res://scripts/campaign.gd")
const Fx = preload("res://scripts/fx.gd")
const ShapeTextures = preload("res://scripts/shape_textures.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const PREVIEW := 46.0
const BUTTON_H := 34.0
var slot := "skins"
var index := 0
var title := ""
var selected := false
var clock := 0.0
var button: BaseButton

func setup(slot_id: String, item: int, item_name: String, label: String, enabled: bool, is_equipped: bool, action: Callable, icon_kind := "") -> void:
	slot = slot_id
	index = item
	title = item_name
	selected = is_equipped
	button = UiButton.new()
	button.text = label
	button.font_size = 14
	button.disabled = not enabled
	button.primary = enabled and not is_equipped
	button.accent = Color("6c4dff") if enabled and not is_equipped else Color("4a5d73")
	if icon_kind != "": button.icon = UiStyle.icon(icon_kind)
	button.pressed.connect(action)
	add_child(button)
	resized.connect(place_button)
	place_button()

func place_button() -> void:
	button.position = Vector2(8, size.y - BUTTON_H - 8)
	button.size = Vector2(size.x - 16, BUTTON_H)

func _process(dt: float) -> void:
	clock += dt
	queue_redraw()

func _draw() -> void:
	var edge := UiStyle.GOLD if selected else Color(UiStyle.PANEL_EDGE, 0.5)
	draw_style_box(UiStyle.flat(Color("1f3852e6"), 16, 3 if selected else 1, edge), Rect2(Vector2.ZERO, size))
	var center := Vector2(size.x/2, 10 + PREVIEW/2)
	draw_style_box(UiStyle.flat(Color("6fbf73"), 12), Rect2(center - Vector2.ONE*PREVIEW/2, Vector2.ONE*PREVIEW))
	match slot:
		"skins": draw_skin(center, PREVIEW*0.34)
		"effects": draw_shapes(center, Fx.EFFECT_LOOKS[index])
		"trails": draw_trail(center)
		_: draw_circle(center, PREVIEW*0.3, Color(preload("res://scripts/fleet.gd").COLORS[index]))
	var font_size := 15 if UiStyle.text_width(title, 15) < size.x - 12 else 12
	UiStyle.text(self, title, Vector2(size.x/2, 10 + PREVIEW + 20), font_size, UiStyle.LIGHT, true)

# A flat sketch of the 3D rim (rim.gdshader): dark well plus a patterned ring.
func draw_skin(center: Vector2, r: float) -> void:
	var look: Array = Campaign.SKINS[index]
	var a := Color(look[1])
	var b := Color(look[2])
	draw_circle(center, r*1.18, a.darkened(0.35))
	draw_circle(center, r, Color("0b0616"))
	var segments := 36
	for i in segments:
		var t0 := TAU*i/segments
		var colour := a
		match index:
			1: colour = Color.WHITE if (i/2)%2 else Color("ff4d6d")
			5: colour = Color.from_hsv(fposmod(i/36.0 + clock*0.4, 1.0), 0.85, 1.0)
			7: colour = Color.from_hsv(fposmod(i/36.0 + clock*0.07, 1.0), 0.35, 1.0)
			_: colour = a.lerp(b, 0.5 + 0.5*sin(t0*4.0 + clock*2.0))
		draw_arc(center, r*1.05, t0, t0 + TAU/segments + 0.02, 3, colour, r*0.24, true)
	draw_skin_ornament(center, r, b)

# The decorations hole_style.gd adds in 3D, plus the animated 2D rims.
func draw_skin_ornament(center: Vector2, r: float, b: Color) -> void:
	match index:
		2:
			for i in 12:
				var dir := Vector2.from_angle(TAU*i/12 + clock*0.5)
				draw_line(center + dir*r*1.15, center + dir*r*(1.32 + 0.08*sin(clock*9 + i)), Color("ffb02e"), 3)
		4:
			for i in 9: draw_circle(center + Vector2.from_angle(i*2.4 + clock*0.3)*r*(0.25 + 0.07*i), 1.5, Color.WHITE)
		8:
			for i in 6: draw_circle(center + Vector2.from_angle(TAU*i/6)*r*1.05, r*0.12, Color("e8423f") if i%2 else Color("ffd54f"))
		10:
			for i in 8: draw_circle(center + Vector2.from_angle(TAU*i/8 + clock*0.15)*r*1.05, r*0.1, Color("ff7cac") if i%2 else Color("7ff7e9"))
		11: draw_circle(center + Vector2.from_angle(clock*1.4)*r*1.05, r*0.16, Color("f4dbff"))
		12:
			for i in 8: draw_circle(center + Vector2.from_angle(TAU*i/8)*r*1.12 + Vector2(0, r*0.1), r*(0.09 + 0.03*sin(clock*3 + i)), b)

func draw_trail(center: Vector2) -> void:
	var look: Array = Fx.TRAIL_LOOKS[index]
	if look.is_empty():
		UiStyle.text(self, "Ø", center + Vector2(0, 11), 30, UiStyle.LIGHT, true)
		return
	draw_shapes(center, [look[0], look[1]])

# A small cluster of the effect's particle sprites in its own colours.
func draw_shapes(center: Vector2, look: Array) -> void:
	var colours: Array = []
	if look[1] is String:
		colours = Fx.RAINBOW if look[1] == "rainbow" else Fx.CONFETTI if look[1] == "palette" else [Color("9b5de5")]
	else:
		colours = look[1].map(func(hex): return Color(hex))
	var shape: String = {"dust":"circle", "confetti":"square", "pixel":"square"}.get(look[0], look[0])
	var tex := ShapeTextures.texture(shape)
	var spots := [Vector2(-12, 6), Vector2(10, 9), Vector2(0, -10), Vector2(13, -9), Vector2(-13, -8)]
	for i in spots.size():
		var s := 15.0 if i < 3 else 10.0
		var at: Vector2 = center + spots[i] + Vector2(0, sin(clock*3.0 + i)*2.0)
		draw_texture_rect(tex, Rect2(at - Vector2.ONE*s/2, Vector2.ONE*s), false, colours[i % colours.size()])
