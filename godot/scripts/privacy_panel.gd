extends Control

const I18n = preload("res://scripts/i18n.gd")
const UiStyle = preload("res://scripts/ui_style.gd")
const UiButton = preload("res://scripts/ui_button.gd")
const POLICY_URL := "https://phucpdbk.github.io/hole-munch/privacy.html"
var ads: Node
var choices: BaseButton
var retry_button: BaseButton
var policy: BaseButton
var close_button: BaseButton
var note: Label
var title_label: Label
var panel: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.1, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142840")
	style.set_corner_radius_all(20)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	title_label = Label.new()
	title_label.add_theme_font_override("font", UiStyle.font(800))
	title_label.add_theme_font_size_override("font_size", 24)
	box.add_child(title_label)
	note = Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_override("font", UiStyle.body_font(700))
	note.add_theme_font_size_override("font_size", 17)
	box.add_child(note)
	policy = button(box, "lock")
	policy.pressed.connect(func(): OS.shell_open(POLICY_URL))
	choices = button(box, "lock")
	choices.pressed.connect(func(): ads.show_privacy_options())
	retry_button = button(box, "replay")
	retry_button.pressed.connect(func(): ads.retry_consent())
	close_button = button(box, "close")
	close_button.pressed.connect(hide)
	resized.connect(layout)
	hide()

func button(box: VBoxContainer, icon: String) -> BaseButton:
	var result := UiButton.new()
	result.icon = UiStyle.icon(icon)
	result.accent = Color("35546d")
	result.font_size = 17
	result.custom_minimum_size.y = 48
	box.add_child(result)
	return result

func open() -> void:
	title_label.text = I18n.t("privacy")
	note.text = I18n.t("privacy_note")
	policy.text = I18n.t("privacy_policy")
	choices.text = I18n.t("privacy_choices")
	retry_button.text = I18n.t("privacy_retry")
	close_button.text = I18n.t("close")
	show()
	refresh()
	layout.call_deferred()
	close_button.grab_focus()

func _process(_delta: float) -> void:
	if visible:
		refresh()
		layout()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()

func layout() -> void:
	if panel == null: return
	panel.size = Vector2(minf(520, size.x-32), panel.get_combined_minimum_size().y)
	panel.position = (size-panel.size)/2

func refresh() -> void:
	choices.visible = ads.privacy_options_required()
	choices.disabled = ads.privacy_busy()
	retry_button.visible = ads.backend != null and not choices.visible
	retry_button.disabled = ads.privacy_busy()
