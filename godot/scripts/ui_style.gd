extends RefCounted

# Shared UI look: fonts (Baloo 2 for titles and buttons, Nunito for body text,
# both OFL, full Vietnamese coverage), baked POLYGON icons (tools/bake_icons.gd)
# and the palette used by ui_button.gd, hud.gd, wardrobe.gd and intro.gd.
const ICON_DIR := "res://assets/icons/"
const DISPLAY_FONT := "res://assets/fonts/Baloo2.ttf"
const BODY_FONT := "res://assets/fonts/Nunito.ttf"
const INK := Color("172939")
const LIGHT := Color("fff9ed")
const MUTED := Color("a4b6c5")
const GOLD := Color("f6cb70")
const MINT := Color("9ff0d8")
const PANEL := Color("1b3048")
const PANEL_EDGE := Color("527288")

static var icons := {}
static var fonts := {}
static var system_font: Font

# Weighted cut of a variable font; the engine font stays as a glyph fallback (★, ×).
static func font(weight := 700, body := false) -> Font:
	var key := "%s%d" % ["body" if body else "display", weight]
	if fonts.has(key): return fonts[key]
	if not system_font: system_font = ThemeDB.fallback_font
	var path := BODY_FONT if body else DISPLAY_FONT
	if not ResourceLoader.exists(path): return system_font
	var base: FontFile = load(path)
	base.fallbacks = [system_font]
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	fonts[key] = variation
	return variation

static func body_font(weight := 700) -> Font:
	return font(weight, true)

# Every Control and Label3D without its own font now uses Baloo 2.
static func install_theme() -> void:
	var display := font(700)
	ThemeDB.fallback_font = display

static func icon(kind: String) -> Texture2D:
	if icons.has(kind): return icons[kind]
	var path := ICON_DIR + kind + ".png"
	icons[kind] = load(path) if ResourceLoader.exists(path) else vector_icon(kind)
	return icons[kind]

# Line-art fallback when the licensed icon bake is not present in a checkout.
static func vector_icon(kind: String) -> Texture2D:
	var paths := {
		"map":'<path d="M3 6L9 3L15 6L21 3V18L15 21L9 18L3 21Z M9 3V18 M15 6V21"/>',
		"upgrade":'<path d="M5 13L12 5L19 13 M12 5V21 M5 3H19"/>',
		"play":'<path d="M7 4L19 12L7 20Z"/>', "pause":'<path d="M8 4V20 M16 4V20"/>',
		"close":'<path d="M5 5L19 19 M19 5L5 19"/>', "left":'<path d="M15 4L7 12L15 20"/>',
		"right":'<path d="M9 4L17 12L9 20"/>', "star":'<path d="M12 3L15 9L21 10L16 14L18 21L12 17L6 21L8 14L3 10L9 9Z"/>',
	}
	var img := Image.new()
	img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 24 24"><g fill="none" stroke="#fff4dc" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">'+paths.get(kind, '<circle cx="12" cy="12" r="8"/>')+'</g></svg>')
	return ImageTexture.create_from_image(img)

static func flat(color: Color, radius: float, border := 0, border_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 6
	s.anti_aliasing = true
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	return s

# Rounded card with a soft shadow and a thin light rim, for HUD and panels.
static func card(canvas: CanvasItem, rect: Rect2, color: Color, radius := 18.0) -> void:
	canvas.draw_style_box(flat(Color(0.02, 0.05, 0.1, 0.35), radius), Rect2(rect.position + Vector2(0, 4), rect.size))
	canvas.draw_style_box(flat(color, radius, 1, Color(PANEL_EDGE, 0.8)), rect)

static func text_width(value: String, size: int, use_font: Font = null) -> float:
	return (use_font if use_font else font()).get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

# Text with an optional dark outline, optionally centred on pos.x.
static func text(canvas: CanvasItem, value: String, pos: Vector2, size: int, color: Color, centered := false, outline := 0, use_font: Font = null) -> void:
	var f := use_font if use_font else font()
	if centered: pos.x -= f.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x/2.0
	if outline > 0: canvas.draw_string_outline(f, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(INK, color.a))
	canvas.draw_string(f, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func draw_icon(canvas: CanvasItem, kind: String, center: Vector2, size: float, tint := Color.WHITE) -> void:
	canvas.draw_texture_rect(icon(kind), Rect2(center - Vector2(size, size)/2, Vector2(size, size)), false, tint)
