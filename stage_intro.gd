extends Control
class_name StageIntro
## A stage's opening card on the case wall: the stage, one line of narration
## and a teaser of the boss waiting at the end of it. Shown once per stage
## per run (RunState.stage_intros); tap to put it away.

signal closed

var stage := 0
var _narration: Narration

## Shows the card on its own layer under `host` (freed with the scene).
static func present(host: Node, stage_index: int) -> StageIntro:
	var layer := CanvasLayer.new()
	layer.layer = 40
	host.add_child(layer)
	var card := StageIntro.new()
	card.stage = stage_index
	layer.add_child(card)
	card.closed.connect(layer.queue_free)
	return card

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var data: Array = Story.STAGE_INTROS.get(stage, ["", "", ""])
	var card := PaperSheet.new()
	card.stock = Palette.MANILA
	card.position = Vector2(190, 100)
	card.size = Vector2(900, 490)
	card.rotation = -0.012
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var kicker := VisualTheme.label("STAGE %d OF 4" % (stage + 1), "", 20, Palette.STAMP_RED)
	kicker.add_theme_font_override("font", VisualTheme.font("type_bold"))
	kicker.position = Vector2(72, 36)
	card.add_child(kicker)
	var title := VisualTheme.label(String(data[0]), "", 76, Palette.INK)
	title.add_theme_font_override("font", VisualTheme.font("heading_bold"))
	title.position = Vector2(68, 60)
	card.add_child(title)
	_narration = Narration.new()
	_narration.lines = [data[1]]
	_narration.font_size = 24
	_narration.color = Palette.INK
	_narration.hold = 999.0
	_narration.position = Vector2(72, 170)
	_narration.size = Vector2(780, 120)
	_narration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(_narration)
	var boss := VisualTheme.label(String(data[2]), "", 20, Palette.STAMP_RED)
	boss.add_theme_font_override("font", VisualTheme.font("type_bold"))
	boss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	boss.custom_minimum_size = Vector2(560, 0)
	boss.position = Vector2(72, 316)
	card.add_child(boss)
	boss.set_deferred("size", Vector2(560, 0))
	var stamp := StampArt.new()
	stamp.text = "NEXT TARGET"
	stamp.font_size = 30
	stamp.tilt = 0.12
	card.add_child(stamp)
	stamp.position = Vector2(640, 330)
	stamp.slam(0.6)
	var go := Button.new()
	go.text = "OPEN THE CASE"
	go.theme_type_variation = "PrimaryButton"
	go.position = Vector2(72, 412)
	go.size = Vector2(260, 52)
	go.pressed.connect(_close)
	card.add_child(go)
	go.grab_focus.call_deferred()
	gui_input.connect(_on_input)
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui("paper")

func _on_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_dismiss()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_dismiss()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	if _narration and not _narration._done and _narration._label.visible_characters < _narration._label.text.length():
		_narration.advance()
		return
	_close()

var _closing := false

func _close() -> void:
	if _closing:
		return
	_closing = true
	closed.emit()
	queue_free()
