extends Node3D

# The moments built to be clipped and shared:
# - the landmark's conquest: it trembles, loose food around the hole is vacuumed
#   in, the camera swings round and zooms in, the landmark tips into the hole, the
#   hole burps and a "<CITY> CONQUERED!" banner pops before the result screen;
# - the guardian clinging to the rim after its last heart (mascot.gd "cling"),
#   with a TAP TAP prompt drawn here;
# - panicked shouts from people and cars at the hole's edge.
# game.gd asks busy() to freeze the round during the conquest. Smoke runs switch
# it off (enabled = false) so rule checks keep their instant wins.
const I18n = preload("res://scripts/i18n.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const Traffic = preload("res://scripts/traffic.gd")
const TREMBLE := 0.9
const FALL := 1.5
const BANNER := 1.5
# Loose food within this many hole radii is pulled in with the landmark.
const VACUUM_REACH := 2.6
const VACUUM_GAP := 0.045
const ORBIT := 0.9
const ZOOM := 0.8
const SHOUT_GAP := 0.32
const SHOUT_TIME := 1.1
const SHOUT_COOLDOWN := 5.0
const SHOUT_POOL := 5
# Shouts keep this far apart so they never pile up on one another.
const SHOUT_SPACING := 3.5
# Shouting kinds -> i18n key of their lines.
const SHOUT_LINES := {"person":"shout_people", "car":"shout_cars", "jamcar":"shout_jam"}
const CALLOUT_TIME := 1.6

var enabled := true
var phase := ""
var timer := 0.0
var boss: Dictionary = {}
var queue: Array = []
var blend := 0.0
var angle := 0.0
var focus := Vector3.ZERO
var size := 30.0
var banner := ""
var banner_sub := ""
var banner_t := -1.0
var shout_timer := 0.0
var shouts: Array[Dictionary] = []
var callout_text := ""
var callout_color := Color.WHITE
var callout_t := -1.0
# Ad capture hides the HUD; score popups are then drawn here instead.
var show_floaters := false
var overlay: Control
var game

func _ready() -> void:
	for i in SHOUT_POOL:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font = UiStyle.font(800)
		label.font_size = 72
		label.outline_size = 22
		label.modulate = Color("fff6dc")
		label.outline_modulate = Color("3b1d2c")
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.visible = false
		add_child(label)
		shouts.append({"label":label, "t":-1.0, "item":{}})
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	overlay = Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.draw.connect(draw_overlay)
	layer.add_child(overlay)

func reset(owner) -> void:
	game = owner
	phase = ""
	timer = 0.0
	boss = {}
	queue.clear()
	banner_t = -1.0
	callout_t = -1.0
	blend = 0.0
	angle = 0.0
	for shout in shouts:
		shout.t = -1.0
		shout.label.visible = false

# The round is on hold while the landmark goes down.
func busy() -> bool:
	return phase != ""

# --- landmark conquest ------------------------------------------------------------

func start_conquer(owner, item: Dictionary) -> void:
	game = owner
	boss = item
	phase = "tremble"
	timer = 0.0
	banner = I18n.t("conquered", game.hud.city.to_upper())
	banner_sub = game.Campaign.boss_name(game.level.boss)
	focus = game.hole_position.lerp(Vector3(item.position.x, 0, item.position.z), 0.5)
	size = maxf(14.0, game.camera.size*ZOOM)
	# Nearest first, so the pull ripples outward from the rim.
	var reach: float = game.radius*VACUUM_REACH
	var loose: Array = game.items.filter(func(other): return vacuumable(other, reach))
	loose.sort_custom(func(a, b): return flat_gap(a) < flat_gap(b))
	queue.clear()
	for i in loose.size(): queue.append({"item":loose[i], "at":TREMBLE*0.15 + i*VACUUM_GAP})
	game.fx.shake = maxf(game.fx.shake, 0.6)
	game.sfx.play("rumble")
	game.add_floater(item.position, I18n.t("big_enough", banner_sub).to_upper(), true)

func vacuumable(item: Dictionary, reach: float) -> bool:
	if not Traffic.is_active(item) or item.get("is_boss", false) or item.get("guardian", false) or item.get("bomb", false): return false
	if item.radius > game.radius*game.EAT_RATIO: return false
	return flat_gap(item) < reach

func flat_gap(item: Dictionary) -> float:
	return Vector2(item.position.x - game.hole_position.x, item.position.z - game.hole_position.z).length()

# Runs instead of the normal round step; returns true once the banner is done.
func update(dt: float) -> bool:
	timer += dt
	pull(dt)
	match phase:
		"tremble":
			blend = minf(1.0, blend + dt*2.2)
			tremble()
			if timer >= TREMBLE:
				phase = "fall"
				timer = 0.0
				game.start_fall(boss, game.hole_position)
				boss.sink = "player"
				boss.fall_time = FALL
				game.sfx.play("boss")
		"fall":
			if boss.eaten:
				phase = "banner"
				timer = 0.0
				banner_t = 0.0
				game.fx.burst(game.hole_position, game.radius)
				game.fx.ripple(game.hole_position, game.radius*1.6, Color("b7a2f1"))
				game.add_floater(game.hole_position, I18n.t("burp"), true)
				game.sfx.play("burp")
				game.pulse = 1.0
				game.saucer_wobble = 0.5
		"banner":
			banner_t = timer
			if timer >= BANNER:
				phase = ""
				return true
	angle += dt*ORBIT*blend
	return false

# The landmark shakes harder and harder, shedding dust, before it goes.
func tremble() -> void:
	var k := timer/TREMBLE
	var wobble := sin(timer*38.0)*0.05*(0.3 + k)
	var lean := Vector3(game.hole_position.x - boss.position.x, 0, game.hole_position.z - boss.position.z)
	var axis := Vector3.UP.cross(lean.normalized()) if lean.length() > 0.01 else Vector3.RIGHT
	var basis := Basis(axis, k*k*0.18 + wobble) * Basis(Vector3.UP, boss.yaw)
	game.set_item_basis(boss, basis.scaled(Vector3.ONE*game.model_scale(boss)))
	game.fx.shake = maxf(game.fx.shake, 0.25 + k*0.4)
	if int(timer*10.0) != int((timer - 0.016)*10.0):
		var spot: Vector3 = boss.position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))*game.boss_radius*0.8
		game.fx.puff(spot, 0.6, game.boss_radius*0.5)

# Staggered falls for the vacuumed food: score and popups, no completion credit.
func pull(dt: float) -> void:
	for entry in queue: entry.at -= dt
	for entry in queue.filter(func(e): return e.at <= 0):
		var item: Dictionary = entry.item
		if not Traffic.is_active(item): continue
		game.start_fall(item, game.hole_position)
		item.sink = "player"
		var points: int = game.base_points(item)
		game.score += points
		game.eaten += 1
		game.add_floater(item.position, "+%d" % points, false)
		game.sfx.pop(item.radius)
	queue.assign(queue.filter(func(e): return e.at > 0))

# While the guardian clings, the camera eases in on it and the saucer climbs out of
# the way (game.gd reads blend for both), then lets go again.
func track(dt: float) -> void:
	if phase != "" or game == null or game.mode != "playing": return
	var clinging: bool = game.mechanics.guardian_clinging()
	if clinging:
		var at: Vector3 = game.mechanics.guardian.position
		focus = game.hole_position.lerp(Vector3(at.x, 0, at.z), 0.6)
		size = maxf(12.0, (21.0 + game.radius*1.8)*ZOOM)
	blend = move_toward(blend, 0.85 if clinging else 0.0, dt*(3.0 if clinging else 1.5))

# On the result screen the camera keeps drifting round and eases back out.
func idle(dt: float) -> void:
	if blend <= 0.0: return
	angle += dt*ORBIT*0.35*blend
	blend = move_toward(blend, 0.45, dt*0.4)

# --- shouts -----------------------------------------------------------------------

# People and cars at the rim yell, and keep yelling as they go in.
func update_shouts(dt: float, active: bool) -> void:
	for shout in shouts:
		if shout.t < 0.0: continue
		shout.t += dt
		var item: Dictionary = shout.item
		var k: float = shout.t/SHOUT_TIME
		if k >= 1.0:
			shout.t = -1.0
			shout.label.visible = false
			continue
		shout.label.position = Vector3(item.position.x, 1.1 + item.radius*2.0 + k*0.8, item.position.z)
		shout.label.modulate.a = 1.0 - k*k
		shout.label.outline_modulate.a = 1.0 - k*k
		shout.label.pixel_size = game.camera.size*0.00045*(1.0 + (1.0 - minf(1.0, shout.t*6.0))*0.5)
	if not active or not enabled: return
	shout_timer -= dt
	if shout_timer > 0.0: return
	shout_timer = SHOUT_GAP
	var item := pick_shouter()
	if item.is_empty(): return
	shout_at(item, SHOUT_LINES[item.kind])

# A random line from an i18n "a|b|c" key over an item, if a bubble is free.
func shout_at(item: Dictionary, key: String) -> void:
	var free: Array = shouts.filter(func(s): return s.t < 0.0)
	if free.is_empty(): return
	var shout: Dictionary = free[0]
	item.shouted = game.elapsed
	var lines: PackedStringArray = I18n.t(key).split("|")
	shout.item = item
	shout.t = 0.0
	shout.label.text = lines[randi() % lines.size()]
	shout.label.visible = true

# A big line across the top for a moment ("RUSH HOUR!", gate results).
func callout(text: String, color: Color) -> void:
	callout_text = text
	callout_color = color
	callout_t = 0.0

func pick_shouter() -> Dictionary:
	var edge: float = game.radius
	var best: Dictionary = {}
	var best_gap := INF
	for item in game.items:
		if not SHOUT_LINES.has(item.kind) or item.eaten or item.get("hidden", false): continue
		if game.elapsed - float(item.get("shouted", -99.0)) < SHOUT_COOLDOWN: continue
		if item.radius > game.radius*game.EAT_RATIO: continue
		var gap := flat_gap(item) - edge
		if item.fall >= 0.0 or gap <= 0.0 or gap > 2.6 or gap >= best_gap or crowded(item): continue
		best = item
		best_gap = gap
	return best

func crowded(item: Dictionary) -> bool:
	for shout in shouts:
		if shout.t < 0.0: continue
		var other: Vector3 = shout.item.position
		if Vector2(other.x - item.position.x, other.z - item.position.z).length() < SHOUT_SPACING: return true
	return false

# --- overlay: banner and the cling prompt --------------------------------------------

func _process(dt: float) -> void:
	if callout_t >= 0.0:
		callout_t += dt
		if callout_t > CALLOUT_TIME: callout_t = -1.0
	overlay.queue_redraw()

func draw_overlay() -> void:
	if game == null: return
	var mascot = game.mechanics.mascot
	if mascot != null and mascot.state == "cling": draw_cling(mascot)
	if phase == "banner": draw_banner()
	if callout_t >= 0.0: draw_callout()
	if show_floaters: draw_floaters()

func draw_callout() -> void:
	var w := overlay.size.x
	var t := callout_t
	var pop := 1.0 - pow(2.0, -10.0*t)*cos(t*14.0)
	var fade := clampf((CALLOUT_TIME - t)/0.3, 0.0, 1.0)
	var font_size := int(clampf(w/11.0, 34.0, 76.0)*pop)
	if font_size < 4: return
	var color := callout_color
	color.a = fade
	UiStyle.text(overlay, callout_text, Vector2(w/2, overlay.size.y*0.16), font_size, color, true, 14, UiStyle.font(800))

# Same look as hud.gd's popups, for clips recorded without the HUD.
func draw_floaters() -> void:
	for floater in game.floaters:
		var t: float = floater.t/game.FLOATER_TIME
		var font_size := 30 if floater.big else 20
		var pos: Vector2 = game.camera.unproject_position(floater.position) - Vector2(0, t*46)
		var color := UiStyle.GOLD if floater.big else UiStyle.LIGHT
		color.a = 1.0 - t*t
		UiStyle.text(overlay, floater.text, pos, font_size, color, true, 6, UiStyle.font(800))

func draw_banner() -> void:
	var w := overlay.size.x
	var h := overlay.size.y
	var t := banner_t
	# Elastic pop, then a slow breathe.
	var pop := 1.0 - pow(2.0, -10.0*t)*cos(t*14.0) if t < 0.8 else 1.0 + sin(t*3.0)*0.02
	var top := h*0.24
	var band := 132.0*clampf(t*5.0, 0.0, 1.0)
	overlay.draw_rect(Rect2(0, top - band/2, w, band), Color(0.07, 0.04, 0.16, 0.78))
	overlay.draw_rect(Rect2(0, top - band/2, w, 5), UiStyle.GOLD)
	overlay.draw_rect(Rect2(0, top + band/2 - 5, w, 5), UiStyle.GOLD)
	var font_size := int(clampf(w/14.0, 30.0, 64.0)*pop)
	if font_size < 4: return
	UiStyle.text(overlay, banner, Vector2(w/2, top + font_size*0.3), font_size, UiStyle.GOLD, true, 12, UiStyle.font(800))
	UiStyle.text(overlay, banner_sub, Vector2(w/2, top + font_size*0.3 + 34), 22, UiStyle.LIGHT, true, 6, UiStyle.font(700))

func draw_cling(mascot) -> void:
	var item: Dictionary = mascot.item
	var at: Vector2 = game.camera.unproject_position(item.position + Vector3(0, item.radius*1.6, 0))
	var beat := 1.0 + absf(sin(game.elapsed*12.0))*0.12
	var text := I18n.t("tap_drop")
	UiStyle.text(overlay, text, at - Vector2(0, 46), int(34*beat), UiStyle.GOLD, true, 10, UiStyle.font(800))
	var count: int = mascot.CLING_TAPS
	for i in count:
		var spot := at + Vector2((i - (count - 1)/2.0)*24.0, -22)
		overlay.draw_circle(spot, 8.0, Color("ff6b7d") if i < mascot.taps else Color(1, 1, 1, 0.35))
	# Tap rings pulsing on the guardian.
	var ring := fmod(game.elapsed*2.5, 1.0)
	var on: Vector2 = game.camera.unproject_position(item.position + Vector3(0, item.radius*0.4, 0)) + Vector2(item.radius*28.0 + 40.0, 10.0)
	overlay.draw_arc(on, 18.0 + ring*34.0, 0, TAU, 32, Color(1, 1, 1, 0.8*(1.0 - ring)), 4.0, true)
	overlay.draw_circle(on, 12.0, Color(1, 1, 1, 0.55))
