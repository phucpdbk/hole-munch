extends Control

# Test mode only: the daily button opens this list of every mini-game, so each
# one can be played on demand (game.gd start_daily). AUTO plays today's game.
# Debug tooling, so its own labels stay in English like the TEST MODE tag; the
# game names and goals come from daily_games.gd in the chosen language.
const Campaign = preload("res://scripts/campaign.gd")
const DailyGames = preload("res://scripts/daily_games.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const ROW_H := 64.0
const GOAL_H := 26.0
var game
var rows: Array[BaseButton] = []
var close_button: BaseButton

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for type in choices():
		var row := UiButton.new()
		row.icon = UiStyle.icon(DailyGames.ICON.get(type, "daily"))
		row.pressed.connect(func(): game.play_daily(type))
		add_child(row)
		rows.append(row)
	close_button = UiButton.new()
	close_button.icon = UiStyle.icon("close")
	close_button.accent = Color("35546d")
	close_button.pressed.connect(hide)
	add_child(close_button)
	resized.connect(layout)
	hide()

# "" is AUTO (today's mini-game), then every type in campaign.gd order.
static func choices() -> Array:
	return [""] + Campaign.DAILY_TYPES

func open() -> void:
	show()
	layout()

# Landscape needs a third column once the list is too long for a short screen.
func columns() -> int:
	if size.x <= size.y: return 1
	return 3 if choices().size() > 8 else 2

func card_rect() -> Rect2:
	var count := choices().size()
	var lines := ceili(count/float(columns()))
	var width := minf(size.x - 48, [640.0, 820.0, 1100.0][columns() - 1])
	var height := 88.0 + lines*(ROW_H + GOAL_H + 10)
	return Rect2((size.x - width)/2, (size.y - height)/2, width, height)

func row_rect(i: int) -> Rect2:
	var card := card_rect()
	var width := (card.size.x - 48 - 16*(columns()-1))/columns()
	return Rect2(card.position.x + 24 + (i%columns())*(width + 16), card.position.y + 78 + (i/columns())*(ROW_H + GOAL_H + 10), width, ROW_H)

func label(type: String) -> String:
	if type == "": return "AUTO · " + DailyGames.title(Campaign.daily_type(Campaign.today()))
	return DailyGames.title(type)

func layout() -> void:
	if not is_instance_valid(game): return
	var list := choices()
	for i in rows.size():
		var rect := row_rect(i)
		var row := rows[i]
		row.position = rect.position
		row.size = rect.size
		row.text = label(list[i])
		row.font_size = 20
		while row.font_size > 13 and UiStyle.text_width(row.text, row.font_size) > rect.size.x - 90: row.font_size -= 1
		var picked: bool = list[i] == game.daily_override
		row.primary = picked
		row.accent = UiStyle.GOLD if picked else Color("8a3a8f")
	var card := card_rect()
	close_button.position = Vector2(card.end.x - 70, card.position.y + 14)
	close_button.size = Vector2(52, 50)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game): return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.12, 0.78))
	var card := card_rect()
	UiStyle.card(self, card, Color("1b3048"), 26)
	UiStyle.text(self, "TEST · DAILY", card.position + Vector2(26, 52), 28, Color("ff6b6b"), false, 4, UiStyle.font(800))
	var list := choices()
	for i in list.size():
		var rect := row_rect(i)
		var type: String = list[i] if list[i] != "" else Campaign.daily_type(Campaign.today())
		UiStyle.text(self, DailyGames.goal_line(type), Vector2(rect.position.x + 12, rect.end.y + 20), 14, UiStyle.MUTED, false, 0, UiStyle.body_font(700))
