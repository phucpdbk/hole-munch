extends Node

# Captions and the end card for ad clips (ad_capture.gd, ad_daily.gd). Drawn on
# its own canvas layer above the HUD and showtime, so the movie maker records
# them; nothing here is used in the game itself.
const UiStyle = preload("res://scripts/ui_style.gd")
const POP_TIME := 0.35
const FADE_TIME := 0.25
const RED := Color("ff5d6c")
const ICON := "res://assets/app_icon/ios_1024.png"

var canvas: Control
var text := ""
var color := UiStyle.LIGHT
var life := 0.0
var age := -1.0
var tilt := 0.0
var card_t := -1.0
# Caption height as a share of the screen; daily clips keep the HUD up top.
var top := 0.17
var icon: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(draw_all)
	layer.add_child(canvas)
	if ResourceLoader.exists(ICON): icon = load(ICON)

# One caption at a time; a new one replaces the last. `seconds` <= 0 keeps it up
# until the next caption or clear().
func say(value: String, seconds := 1.8, tint := UiStyle.LIGHT) -> void:
	text = value
	color = tint
	life = seconds
	age = 0.0
	# Alternate a slight lean so consecutive captions read as new ones.
	tilt = -0.035 if tilt >= 0.0 else 0.035

func clear() -> void:
	age = -1.0

func end_card() -> void:
	clear()
	card_t = 0.0

# Real seconds, so a sped-up clip (Engine.time_scale) keeps captions readable.
func _process(delta: float) -> void:
	var dt := delta/maxf(Engine.time_scale, 0.01)
	if age >= 0.0:
		age += dt
		if life > 0.0 and age > life: age = -1.0
	if card_t >= 0.0: card_t += dt
	canvas.queue_redraw()

func draw_all() -> void:
	if card_t >= 0.0:
		draw_card()
		return
	if age >= 0.0 and text != "": draw_caption()

func draw_caption() -> void:
	var w := canvas.size.x
	var h := canvas.size.y
	var pop := 1.0 - pow(2.0, -10.0*age/POP_TIME)*cos(age/POP_TIME*5.0)
	var fade := 1.0 if life <= 0.0 else clampf((life - age)/FADE_TIME, 0.0, 1.0)
	var lines := text.split("\n")
	var font := UiStyle.font(800)
	var widest := 1.0
	for line in lines: widest = maxf(widest, UiStyle.text_width(line, 100, font))
	var size := clampf(100.0*w*0.88/widest, 18.0, w/7.0)
	var drawn := int(size*pop)
	if drawn < 4: return
	var tint := color
	tint.a = fade
	var y := h*top - (lines.size() - 1)*size*0.55
	canvas.draw_set_transform(Vector2(w/2, y), tilt*(1.0 - pop*0.5), Vector2.ONE)
	for i in lines.size():
		UiStyle.text(canvas, lines[i], Vector2(0, i*size*1.08), drawn, tint, true, maxi(4, drawn/5), font)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Icon, name, tagline and a pulsing PLAY FREE button over a dark wash.
func draw_card() -> void:
	var w := canvas.size.x
	var h := canvas.size.y
	var t := card_t
	var wash := clampf(t/0.25, 0.0, 1.0)
	canvas.draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.03, 0.14, 0.86*wash))
	var pop := 1.0 - pow(2.0, -10.0*t/0.5)*cos(t/0.5*5.0)
	var side := w*0.42*pop
	if icon and side > 2.0:
		canvas.draw_texture_rect(icon, Rect2(Vector2(w/2 - side/2, h*0.34 - side/2), Vector2(side, side)), false)
	var font := UiStyle.font(800)
	var title := int(w/7.5*pop)
	if title > 4:
		UiStyle.text(canvas, "HOLE MUNCH", Vector2(w/2, h*0.55), title, UiStyle.GOLD, true, title/5, font)
		UiStyle.text(canvas, "Eat the whole world", Vector2(w/2, h*0.55 + title*0.9), int(title*0.42), UiStyle.LIGHT, true, 5, UiStyle.font(700))
	if t < 0.45: return
	var beat := 1.0 + sin((t - 0.45)*7.0)*0.05
	var button := Vector2(w*0.62, w*0.16)*beat
	var centre := Vector2(w/2, h*0.75)
	var box := Rect2(centre - button/2, button)
	canvas.draw_style_box(pill(Color("b3541e"), button.y), Rect2(box.position + Vector2(0, 5), box.size))
	canvas.draw_style_box(pill(Color("ff9b3d"), button.y), box)
	var label := int(button.y*0.5)
	UiStyle.text(canvas, "PLAY FREE", centre + Vector2(0, label*0.36), label, UiStyle.LIGHT, true, 6, font)

func pill(fill: Color, height: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(int(height/2))
	return box
