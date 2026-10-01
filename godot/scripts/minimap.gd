extends RefCounted

# A small top-down map of the city in the HUD: roads, the hole, the landmark,
# the rival, and pickups or bombs falling from the sky. game.gd fills the data
# each frame (minimap_data); positions are world x/z.
const UiStyle = preload("res://scripts/ui_style.gd")
const SIZE := 132.0

static func draw(canvas: CanvasItem, top_right: Vector2, data: Dictionary) -> void:
	if data.is_empty(): return
	var half: Vector2 = data.half
	var scale := SIZE/(2.0*maxf(half.x, half.y))
	var area := half*2.0*scale
	var rect := Rect2(top_right - Vector2(area.x, 0), area)
	canvas.draw_style_box(UiStyle.flat(Color("1b3048d9"), 12, 1, Color(UiStyle.PANEL_EDGE, 0.7)), rect.grow(6))
	canvas.draw_rect(rect, Color("6f9d6e"))
	# Gold and danger districts (map_features.gd).
	for zone in data.get("zones", []):
		var block: Rect2 = zone.rect
		canvas.draw_rect(Rect2(to_map(rect, half, scale, block.position), block.size*scale), Color(zone.color, 0.85))
	for x in data.streets_x:
		canvas.draw_line(to_map(rect, half, scale, Vector2(x, -half.y)), to_map(rect, half, scale, Vector2(x, half.y)), Color("3c4650"), 3.0)
	for z in data.streets_z:
		canvas.draw_line(to_map(rect, half, scale, Vector2(-half.x, z)), to_map(rect, half, scale, Vector2(half.x, z)), Color("3c4650"), 3.0)
	for lane in data.get("shortcuts", []):
		canvas.draw_dashed_line(to_map(rect, half, scale, lane[0]), to_map(rect, half, scale, lane[1]), UiStyle.MINT, 2.0, 4.0)
	for spot in data.get("barriers", []):
		canvas.draw_rect(Rect2(to_map(rect, half, scale, spot) - Vector2(4, 4), Vector2(8, 8)), Color("ff9a3c"))
		canvas.draw_rect(Rect2(to_map(rect, half, scale, spot) - Vector2(4, 4), Vector2(8, 8)), UiStyle.INK, false, 1.0)
	for dot in data.get("dots", []): canvas.draw_circle(to_map(rect, half, scale, dot), 2.5, UiStyle.GOLD)
	if data.has("boss"):
		var boss := to_map(rect, half, scale, data.boss)
		canvas.draw_circle(boss, 6.0, UiStyle.GOLD if data.open else Color("9fdcff"))
		canvas.draw_arc(boss, 7.5, 0, TAU, 16, UiStyle.INK, 1.5, true)
	for bomb in data.bombs: canvas.draw_circle(to_map(rect, half, scale, bomb), 3.0, Color("ff5a4e"))
	if data.has("pickup"): canvas.draw_circle(to_map(rect, half, scale, data.pickup), 3.5, Color("c69bff"))
	if data.has("rival"):
		canvas.draw_circle(to_map(rect, half, scale, data.rival), maxf(3.0, data.rival_radius*scale), Color("ff5a4e"))
	var hole := to_map(rect, half, scale, data.hole)
	var size := maxf(3.5, data.radius*scale)
	canvas.draw_circle(hole, size, Color("10061f"))
	canvas.draw_arc(hole, size, 0, TAU, 20, Color("b7a2f1"), 2.0, true)

static func to_map(rect: Rect2, half: Vector2, scale: float, at: Vector2) -> Vector2:
	return rect.position + (at + half)*scale
