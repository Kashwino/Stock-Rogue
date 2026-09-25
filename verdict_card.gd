extends CanvasLayer
class_name VerdictCard
## The VERDICT card: the kneeling boss's case file, his plea, and your options
## as rubber stamps (EXECUTE red, FLIP green, SHAKE DOWN gold, TAKE HIS DEAL
## blue; or the Chairman's TAKE THE SEAT / BURN THE BOARD / WALK AWAY).
## Choosing one slams its stamp onto the file with a thud before the verdict
## plays. Pauses the heist while it's up; keys 1-4, a pad or a tap choose.
## Built in code under one full-rect Control (PROCESS_MODE_ALWAYS).

signal chosen(verdict: StringName)

const STAMP_SIZE := Vector2(226, 300)

var boss_id: StringName = &"landlord"
## Options that can't be taken here (TAKE HIS DEAL on a practice job).
var disabled: Array = []
## How long the stamp's impression sits on the file before the verdict runs.
var slam_time := 0.5
var _root: Control
var _file: CaseFile
var _cards: Array = []
var _options: Array = []
var _done := false
var _chosen: StringName = &""
var _committed := false

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.release_all()
	_options = Verdicts.options_for(boss_id)
	_build()
	get_tree().paused = true
	Audio.play_ui("paper")

func _exit_tree() -> void:
	if not _committed and is_inside_tree():
		get_tree().paused = false

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.02, 0.02, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_file = CaseFile.new()
	_file.boss_id = boss_id
	_file.position = Vector2(70, 34)
	_file.size = Vector2(1140, 640)
	_root.add_child(_file)
	var n := _options.size()
	var gap := 18.0
	var width := n * STAMP_SIZE.x + (n - 1) * gap
	for i in n:
		var stamp := StampButton.new()
		stamp.verdict = _options[i]
		stamp.number = i + 1
		stamp.boss_id = boss_id
		stamp.locked = _options[i] in disabled
		stamp.disabled = stamp.locked
		stamp.position = Vector2((1280.0 - width) * 0.5 + i * (STAMP_SIZE.x + gap), 262)
		stamp.size = STAMP_SIZE
		stamp.pressed.connect(choose.bind(_options[i]))
		_root.add_child(stamp)
		_cards.append(stamp)
	for card: Button in _cards:
		if not card.disabled:
			card.grab_focus.call_deferred()
			break

func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
	if index < 0 or index >= _options.size() or _cards[index].disabled:
		return
	get_viewport().set_input_as_handled()
	choose(_options[index])

## Hand down the verdict: the stamp slams onto the file, then the heist
## carries it out.
func choose(v: StringName) -> void:
	if _done or v in disabled or not (v in _options):
		return
	_done = true
	_chosen = v
	for card: Button in _cards:
		card.disabled = true
	_file.slam(Verdicts.card_title(v, boss_id), Verdicts.stamp_color(v))
	Audio.play_ui("stamp")
	if slam_time <= 0.0 or HudKit.reduce_motion():
		_commit()
	else:
		get_tree().create_timer(slam_time, true, false, true).timeout.connect(_commit)

func _commit() -> void:
	if _committed or not is_inside_tree():
		return
	_committed = true
	get_tree().paused = false
	chosen.emit(_chosen)
	queue_free()


## The boss's case file: manila, typed, his plea in quotes; the chosen
## verdict's impression slams onto it.
class CaseFile extends Control:
	var boss_id: StringName = &"landlord"
	var _stamp_text := ""
	var _stamp_color := Palette.STAMP_RED
	var _slam := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(false)

	func slam(text: String, color: Color) -> void:
		_stamp_text = text
		_stamp_color = color
		_slam = 1.0
		set_process(true)

	func _process(delta: float) -> void:
		_slam = maxf(_slam - delta * 6.0, 0.0)
		queue_redraw()
		if _slam <= 0.0:
			set_process(false)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# The folder tab, then the file itself.
		HudKit.paper_poly(self, PackedVector2Array([Vector2(30, 0), Vector2(260, 0), Vector2(280, 26), Vector2(10, 26)]), Palette.MANILA_DARK, Palette.MANILA_DARK.darkened(0.3))
		HudKit.draw_paper(self, Rect2(Vector2(0, 22), r.size - Vector2(0, 22)), 71, 0, -0.008, Palette.MANILA, Palette.MANILA_DARK)
		var type := VisualTheme.font("type_bold")
		var heading := VisualTheme.font("heading_bold")
		var chairman := boss_id == &"chairman"
		draw_string(type, Vector2(46, 18), "CASE FILE  ·  VERDICT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.HUD_INK)
		var kicker := "THE LAST TRADE" if chairman else ("SHE'S ON HER KNEES" if boss_id == &"ambassador" else "HE'S ON HIS KNEES")
		draw_string(type, Vector2(40, 60), kicker, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.STAMP_RED)
		draw_string(heading, Vector2(36, 124), Story.boss_name(boss_id), HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Palette.HUD_INK)
		draw_string(VisualTheme.font("type"), Vector2(40, 164), "\"%s\"" % Verdicts.plea(boss_id), HORIZONTAL_ALIGNMENT_LEFT, size.x - 80, 20, Palette.HUD_INK)
		draw_string(type, Vector2(40, 200), "FEAR %d   ·   LOYALTY %d   ·   GREED %d" % [RunState.fear, RunState.loyalty, RunState.greed], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.with_alpha(Palette.HUD_INK, 0.7))
		draw_string(type, Vector2(40, size.y - 22), "Press 1-%d, or pick up a stamp. There is no going back." % Verdicts.options_for(boss_id).size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.with_alpha(Palette.HUD_INK, 0.7))
		HudKit.draw_paperclip(self, Vector2(size.x - 60, 12), -0.25)
		if _stamp_text != "":
			var k := 1.0 + 0.8 * _slam
			draw_set_transform(Vector2(size.x - 250, 120), -0.14, Vector2(k, k))
			var f := VisualTheme.font("heading_bold")
			var w := HudKit.text_width(f, _stamp_text, 40) + 36.0
			draw_rect(Rect2(-w * 0.5, -34, w, 68), Palette.with_alpha(_stamp_color, 0.9), false, 5.0)
			draw_rect(Rect2(-w * 0.5 + 8, -26, w - 16, 52), Palette.with_alpha(_stamp_color, 0.6), false, 2.0)
			draw_string(f, Vector2(-w * 0.5 + 18, 14), _stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Palette.with_alpha(_stamp_color, 0.92))
			draw_set_transform_matrix(Transform2D.IDENTITY)


## One verdict as a rubber stamp standing on the file: a wooden handle, the
## inked base with the verdict on it, the terms typed underneath. Hover lifts
## it off the paper.
class StampButton extends Button:
	var verdict: StringName = &"execute"
	var boss_id: StringName = &"landlord"
	var number := 1
	var locked := false
	var _hover := false

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		set_meta("qa_label", Verdicts.card_title(verdict, boss_id))

	func _set_hover(on: bool) -> void:
		_hover = on
		queue_redraw()

	func _draw() -> void:
		var col := Verdicts.stamp_color(verdict)
		if locked:
			col = Color(0.35, 0.33, 0.3)
		var lift := 6.0 if (_hover or has_focus()) and not locked else 0.0
		var cx := size.x * 0.5
		var type := VisualTheme.font("type_bold")
		var heading := VisualTheme.font("heading_bold")
		# Shadow on the paper, the handle, the base.
		draw_colored_polygon(HudKit.ellipse(Vector2(cx + 4, 106), 92, 12), Color(0, 0, 0, 0.25 + 0.1 * lift / 6.0))
		var base := Rect2(Vector2(cx - 96, 58 - lift), Vector2(192, 44))
		draw_circle(Vector2(cx, 18 - lift), 17, Color("5a3a22"))
		draw_circle(Vector2(cx - 5, 13 - lift), 6, Color("8a5e3a"))
		draw_rect(Rect2(Vector2(cx - 9, 30 - lift), Vector2(18, 20)), Color("4a2e1a"))
		draw_rect(Rect2(Vector2(cx - 60, 48 - lift), Vector2(120, 12)), Color("3a2414"))
		draw_rect(base, Palette.HUD_INK)
		draw_rect(base.grow(-4), col)
		var title := Verdicts.card_title(verdict, boss_id)
		var size_px := 22 if title.length() <= 12 else 18
		var w := HudKit.text_width(heading, title, size_px)
		draw_string(heading, Vector2(cx - w * 0.5, base.get_center().y + size_px * 0.36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Palette.PAPER_CREAM)
		draw_string(type, Vector2(10, 22), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.with_alpha(Palette.HUD_INK, 0.6))
		# The terms, typed on the file under the stamp.
		var text := "Not on a practice job." if locked else Verdicts.describe(verdict, boss_id)
		var y := 132.0
		for line in HudKit.wrap(VisualTheme.font("type"), text, 14, size.x - 20.0):
			draw_string(VisualTheme.font("type"), Vector2(10, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.with_alpha(Palette.HUD_INK, 0.55 if locked else 0.9))
			y += 17.0
