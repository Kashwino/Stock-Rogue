extends CanvasLayer
## Autoload "Transition". Covers scene changes with a fade to black or a
## case-file "stamp wipe" (a manila sheet slides across, gets stamped, slides
## off). Blocks input while covered. Runs while the tree is paused.

signal covered

const COVER_TIME := 0.22
const REVEAL_TIME := 0.3

var busy := false
var _root: Control
var _black: ColorRect
var _sheet: Control
var _stamp: StampArt
var _pending := ""

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_black = ColorRect.new()
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.color = Color(0.02, 0.02, 0.03, 0.0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_black)
	_sheet = PaperSheet.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.visible = false
	_root.add_child(_sheet)
	_stamp = StampArt.new()
	_stamp.text = "NEXT JOB"
	_stamp.font_size = 64
	_stamp.visible = false
	_root.add_child(_stamp)

## Cover the screen, swap scenes, reveal. `style` is "fade" or "stamp".
func change_scene(path: String, style: String = "fade", stamp_text: String = "") -> void:
	if busy:
		_pending = path
		return
	busy = true
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var instant: bool = Settings.values.get("reduce_flashing", false) and style == "stamp"
	if style == "stamp" and not instant:
		await _stamp_cover(stamp_text)
	else:
		await _fade_to(1.0, COVER_TIME)
	covered.emit()
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Transition: cannot open scene " + path + " (" + str(error) + ")")
	await get_tree().process_frame
	await get_tree().process_frame
	if _sheet.visible:
		await _stamp_reveal()
	else:
		await _fade_to(0.0, REVEAL_TIME)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	if _pending != "":
		var next := _pending
		_pending = ""
		change_scene(next)

func _fade_to(alpha: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, time)
	await tw.finished

func _stamp_cover(stamp_text: String) -> void:
	var view := _root.get_viewport_rect().size
	_sheet.size = view + Vector2(120, 80)
	_sheet.position = Vector2(-view.x - 160, -40)
	_sheet.visible = true
	var tw := create_tween()
	tw.tween_property(_sheet, "position:x", -60.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_stamp.set_text(stamp_text if stamp_text != "" else "NEXT JOB")
	_stamp.position = view * 0.5 - _stamp.size * 0.5
	_stamp.visible = true
	_stamp.slam()
	await get_tree().create_timer(0.38, true, false, true).timeout

func _stamp_reveal() -> void:
	var view := _root.get_viewport_rect().size
	var tw := create_tween()
	tw.tween_property(_sheet, "position:x", view.x + 80.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_stamp, "position:x", view.x + 80.0 + _stamp.position.x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	_sheet.visible = false
	_stamp.visible = false

## Quick full-screen flash of colour (damage, boss death). Honours reduce-flashing.
func flash(color: Color, time: float = 0.18) -> void:
	if Settings.values.get("reduce_flashing", false):
		color.a *= 0.35
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(rect)
	var tw := rect.create_tween()
	tw.tween_property(rect, "color:a", 0.0, time)
	tw.tween_callback(rect.queue_free)
