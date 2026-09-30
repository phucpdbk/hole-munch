extends RefCounted

static var icons := {}

static func icon(kind: String) -> Texture2D:
	if icons.has(kind): return icons[kind]
	var paths := {
		"map":'<path d="M3 6L9 3L15 6L21 3V18L15 21L9 18L3 21Z M9 3V18 M15 6V21"/>',
		"upgrade":'<path d="M5 13L12 5L19 13 M12 5V21 M5 3H19"/>',
		"fleet":'<ellipse cx="12" cy="14" rx="10" ry="4"/><path d="M7 12V9A5 5 0 0 1 10 0V12 M8 21H16"/>',
	}
	var img := Image.new()
	img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#bce8ef" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">'+paths.get(kind,paths.fleet)+'</g></svg>')
	icons[kind] = ImageTexture.create_from_image(img)
	return icons[kind]

# Shared tactile controls, built from native style boxes (no texture uploads).
static func button(b: Button, accent: Color, primary := false) -> void:
	b.add_theme_color_override("font_color", Color("172939") if primary else Color("eefaff"))
	b.add_theme_color_override("font_hover_color", Color("172939") if primary else Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color("172939") if primary else Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("718699"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = accent if primary else Color("263e55")
		if state == "hover": s.bg_color = s.bg_color.lightened(0.12)
		if state == "pressed": s.bg_color = s.bg_color.darkened(0.12)
		if state == "disabled": s.bg_color = Color("203143")
		s.set_corner_radius_all(12)
		s.border_color = accent.lightened(0.25) if primary else accent.darkened(0.3)
		if state == "disabled": s.border_color = Color("344658")
		s.set_border_width_all(1)
		s.border_width_top = 2
		s.border_width_bottom = 4 if state != "pressed" else 1
		s.shadow_color = Color(0.025,0.06,0.11,0.45)
		s.shadow_size = 5 if state != "pressed" else 1
		s.shadow_offset = Vector2(0,4 if state != "pressed" else 1)
		b.add_theme_stylebox_override(state,s)
	# A short highlight pulse also supplies feedback on touch screens.
	b.button_down.connect(func(): b.modulate = Color(0.82,0.92,1.0))
	b.button_up.connect(func(): b.create_tween().tween_property(b,"modulate",Color.WHITE,0.16))
