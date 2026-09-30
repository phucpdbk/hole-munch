extends BaseButton

# Chunky game button drawn in one pass: soft shadow, darker 3D lip, body, top
# gloss, icon and Baloo 2 label. Pressing sinks the body onto the lip. Replaces
# the engine Button so the font, icon size and colours match the game art.
const UiStyle = preload("res://scripts/ui_style.gd")
const LIP := 5.0

var text := "":
	set(value):
		if value == text: return
		text = value
		queue_redraw()
var icon: Texture2D:
	set(value):
		icon = value
		queue_redraw()
var accent := Color("2f4b63"):
	set(value):
		accent = value
		queue_redraw()
# Primary buttons use dark ink on a bright body.
var primary := false:
	set(value):
		primary = value
		queue_redraw()
var font_size := 18:
	set(value):
		font_size = value
		queue_redraw()
# Icon height as a share of the body height.
var icon_scale := 0.62

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)

func _draw() -> void:
	var mode := get_draw_mode()
	var down := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var off := disabled
	var base := Color("2c3d4f") if off else accent
	if mode == DRAW_HOVER: base = base.lightened(0.08)
	var radius := minf(size.y*0.36, 20.0)
	var sink := LIP - 1.5 if down else 0.0
	var body := Rect2(0, sink, size.x, size.y - LIP)
	if not down: draw_style_box(UiStyle.flat(Color(0.01, 0.04, 0.09, 0.4), radius), Rect2(0, 4, size.x, size.y))
	draw_style_box(UiStyle.flat(base.darkened(0.42), radius), Rect2(0, LIP, size.x, size.y - LIP))
	draw_style_box(UiStyle.flat(base, radius, 2, base.lightened(0.28)), body)
	if not off:
		var gloss := UiStyle.flat(Color(1, 1, 1, 0.16 if primary else 0.1), radius - 3)
		gloss.corner_radius_bottom_left = 4
		gloss.corner_radius_bottom_right = 4
		draw_style_box(gloss, Rect2(4, sink + 3, size.x - 8, body.size.y*0.42))
	draw_content(body, off)

func draw_content(body: Rect2, off: bool) -> void:
	var ink := UiStyle.INK if primary else UiStyle.LIGHT
	if off: ink = Color("7f90a0")
	var tint := Color(0.55, 0.6, 0.65, 0.8) if off else Color.WHITE
	var f := UiStyle.font(800)
	var icon_size := body.size.y*icon_scale if icon else 0.0
	if text == "":
		if icon: draw_texture_rect(icon, Rect2(body.get_center() - Vector2(icon_size, icon_size)/2, Vector2(icon_size, icon_size)), false, tint)
		return
	var gap := icon_size*0.18 if icon else 0.0
	var room := body.size.x - 20.0 - icon_size - gap
	var fitted := font_size
	while fitted > 10 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > room: fitted -= 1
	var width := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x
	var left := body.get_center().x - (icon_size + gap + width)/2
	if icon: draw_texture_rect(icon, Rect2(left, body.get_center().y - icon_size/2, icon_size, icon_size), false, tint)
	var baseline := body.get_center().y + (f.get_ascent(fitted) - f.get_descent(fitted))/2 - 1
	var pos := Vector2(left + icon_size + gap, baseline)
	if not primary and not off: draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, 4, Color(0.02, 0.07, 0.13, 0.45))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted, ink)
