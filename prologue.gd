extends CanvasLayer
class_name Prologue
## The prologue over the rainy skyline when a new run begins: the full four
## cards on a case file's first run, one line after that. Tap to hurry a
## line, SKIP (or Esc) to jump straight to the case wall. Parented to the
## root so it survives the scene change beneath it.

signal finished

var full := true
var slot := 0
var _root: Control

static func play(host: Node, show_full: bool, slot_index: int) -> Prologue:
	var p := Prologue.new()
	p.full = show_full
	p.slot = slot_index
	host.get_tree().root.add_child(p)
	return p

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var backdrop := MenuBackdrop.new()
	_root.add_child(backdrop)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var kicker := VisualTheme.label("CASE FILE %02d  ·  THE BOARD" % (slot + 1), "KickerLabel", 20)
	kicker.position = Vector2(90, 150)
	_root.add_child(kicker)
	var text := Narration.new()
	text.lines = Story.PROLOGUE if full else [Story.PROLOGUE_SHORT % (slot + 1)]
	text.position = Vector2(140, 200)
	text.size = Vector2(1000, 300)
	text.finished.connect(_close)
	_root.add_child(text)
	var skip := Button.new()
	skip.text = "SKIP"
	skip.position = Vector2(1100, 630)
	skip.size = Vector2(140, 56)
	skip.pressed.connect(_close)
	_root.add_child(skip)
	var hint := VisualTheme.label("tap to continue", "DimLabel", 16)
	hint.position = Vector2(560, 640)
	_root.add_child(hint)
	Audio.music("menu")

var _closing := false

func _close() -> void:
	if _closing or not is_inside_tree():
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_finish)

func _finish() -> void:
	finished.emit()
	queue_free()
