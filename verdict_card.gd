extends CanvasLayer
class_name VerdictCard
## The VERDICT card: a kneeling boss, his plea, and your options as cards
## (EXECUTE / FLIP / SHAKE DOWN / TAKE HIS DEAL, or the Chairman's TAKE THE
## SEAT / BURN THE BOARD / WALK AWAY). Pauses the heist while it's up; keys
## 1-4, a pad or a tap choose. Built in code under one full-rect Control.

signal chosen(verdict: StringName)

const CARD_SIZE := Vector2(282, 300)

var boss_id: StringName = &"landlord"
## Options that can't be taken here (TAKE HIS DEAL on a practice job).
var disabled: Array = []
var _root: Control
var _cards: Array = []
var _options: Array = []
var _done := false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.release_all()
	_options = Verdicts.options_for(boss_id)
	_build()
	get_tree().paused = true
	Audio.play_ui("stamp")

func _exit_tree() -> void:
	if not _done and is_inside_tree():
		get_tree().paused = false

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var chairman := boss_id == &"chairman"
	var kicker := VisualTheme.label("VERDICT  ·  %s" % ("THE LAST TRADE" if chairman else "HE'S ON HIS KNEES" if boss_id != &"ambassador" else "SHE'S ON HER KNEES"), "KickerLabel", 20, Palette.DANGER)
	kicker.position = Vector2(80, 40)
	_root.add_child(kicker)
	var title := VisualTheme.label(Story.boss_name(boss_id), "TitleLabel", 64, Palette.GOLD)
	title.position = Vector2(76, 64)
	_root.add_child(title)
	var plea := VisualTheme.label("\"%s\"" % Verdicts.plea(boss_id), "", 22, Palette.PAPER)
	plea.add_theme_font_override("font", VisualTheme.font("type"))
	plea.position = Vector2(80, 150)
	plea.size = Vector2(1120, 40)
	plea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(plea)
	var rep := VisualTheme.label("FEAR %d   ·   LOYALTY %d   ·   GREED %d" % [RunState.fear, RunState.loyalty, RunState.greed], "", 16, Palette.PAPER_DIM)
	rep.add_theme_font_override("font", VisualTheme.font("mono"))
	rep.position = Vector2(80, 196)
	_root.add_child(rep)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := _options.size()
	var width := n * CARD_SIZE.x + (n - 1) * 16.0
	row.position = Vector2((1280.0 - width) * 0.5, 236)
	row.size = Vector2(width, CARD_SIZE.y)
	_root.add_child(row)
	for i in n:
		var card := _make_card(i, _options[i])
		row.add_child(card)
		_cards.append(card)
	var hint := VisualTheme.label("Press 1-%d, or choose a card. There is no going back." % n, "", 15, Palette.PAPER_DIM)
	hint.position = Vector2(80, 560)
	_root.add_child(hint)
	for card: Button in _cards:
		if not card.disabled:
			card.grab_focus.call_deferred()
			break

func _accent(v: StringName) -> Color:
	match v:
		Verdicts.EXECUTE, Verdicts.SEAT:
			return Palette.DANGER
		Verdicts.FLIP:
			return Palette.STAMP_GREEN
		Verdicts.SHAKE, Verdicts.BURN:
			return Palette.GOLD
	return Palette.NEON_CYAN

func _make_card(index: int, v: StringName) -> Button:
	var card := Button.new()
	card.custom_minimum_size = CARD_SIZE
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.disabled = v in disabled
	var accent := _accent(v)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Palette.PANEL_HI if state in ["hover", "focus"] else (Palette.BG if state == "pressed" else Palette.PANEL)
		sb.border_color = accent if state != "disabled" else Palette.PAPER_DIM.darkened(0.5)
		sb.set_border_width_all(3 if state in ["hover", "focus"] else 1)
		sb.set_corner_radius_all(6)
		card.add_theme_stylebox_override(state, sb)
	var number := VisualTheme.label(str(index + 1), "", 18, Palette.PAPER_DIM)
	number.add_theme_font_override("font", VisualTheme.font("mono"))
	number.position = Vector2(14, 10)
	card.add_child(number)
	var name_label := VisualTheme.label(_option_title(v), "", 30, accent)
	name_label.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	name_label.position = Vector2(14, 34)
	name_label.size = Vector2(CARD_SIZE.x - 28, 40)
	card.add_child(name_label)
	var text := Verdicts.describe(v, boss_id)
	if card.disabled:
		text = "Not on a practice job."
	var body := VisualTheme.label(text, "", 16, Palette.PAPER if not card.disabled else Palette.PAPER_DIM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.position = Vector2(14, 84)
	body.size = Vector2(CARD_SIZE.x - 28, CARD_SIZE.y - 96)
	body.custom_minimum_size = Vector2(CARD_SIZE.x - 28, 0)
	card.add_child(body)
	card.pressed.connect(choose.bind(v))
	return card

func _option_title(v: StringName) -> String:
	if v == Verdicts.DEAL and boss_id == &"ambassador":
		return "TAKE HER DEAL"
	return Verdicts.option_name(v)

func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
	if index < 0 or index >= _options.size() or _cards[index].disabled:
		return
	get_viewport().set_input_as_handled()
	choose(_options[index])

## Hand down the verdict: unpause, tell the heist, go.
func choose(v: StringName) -> void:
	if _done or v in disabled or not (v in _options):
		return
	_done = true
	get_tree().paused = false
	Audio.play_ui("stamp")
	chosen.emit(v)
	queue_free()
