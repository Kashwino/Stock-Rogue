extends Control
class_name Narration
## Typewriter narration: plays `lines` one at a time, a key clack per letter.
## Tap / click / any key finishes the current line, the next press moves on.
## `hold` seconds after a line completes it advances by itself. Emits
## `finished` after the last line. Works while the tree is paused.

signal finished

var lines: Array = []
var hold := 2.6
var chars_per_second := 42.0
var font_size := 30
var color := Palette.PAPER
var _index := -1
var _shown := 0.0
var _wait := 0.0
var _label: Label
var _done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = VisualTheme.label("", "", font_size, color)
	_label.add_theme_font_override("font", VisualTheme.font("type_bold"))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	add_child(_label)
	gui_input.connect(_on_gui_input)
	_next()

func _next() -> void:
	_index += 1
	if _index >= lines.size():
		if not _done:
			_done = true
			finished.emit()
		return
	_label.text = String(lines[_index])
	_label.visible_characters = 0
	_shown = 0.0
	_wait = hold

func _process(delta: float) -> void:
	if _done or _index < 0 or _index >= lines.size():
		return
	var total := _label.text.length()
	if _label.visible_characters < total:
		var before := int(_shown)
		_shown += delta * chars_per_second
		_label.visible_characters = mini(int(_shown), total)
		if int(_shown) != before and int(_shown) % 2 == 0:
			var audio := get_node_or_null("/root/Audio")
			if audio:
				audio.play_ui("typewriter")
	else:
		_wait -= delta
		if _wait <= 0.0:
			_next()

## Finish the current line, or move to the next one.
func advance() -> void:
	if _done or _index >= lines.size():
		return
	if _label.visible_characters < _label.text.length():
		_label.visible_characters = _label.text.length()
		_shown = _label.text.length()
	else:
		_next()

func skip_all() -> void:
	if not _done:
		_done = true
		finished.emit()

func _on_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		advance()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			skip_all()
		else:
			advance()
		get_viewport().set_input_as_handled()
