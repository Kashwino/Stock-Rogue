extends CanvasLayer
class_name BossIntroCard
## The boss title card: a red band slams across the screen with the name,
## the title and a PRIORITY TARGET stamp while the camera looks at him.
## Runs on its own timer (about 2.4 s) and never pauses the tree.

signal finished

var boss_name := ""
var subtitle := ""
var duration := 2.0
var _root: Control
var _done := false

func _ready() -> void:
	layer = 55
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var band := ColorRect.new()
	band.color = Color(0.1, 0.02, 0.02, 0.9)
	band.position = Vector2(0, 470)
	band.size = Vector2(1280, 170)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(band)
	for y in [470.0, 638.0]:
		var rule := ColorRect.new()
		rule.color = Palette.DANGER
		rule.position = Vector2(0, y)
		rule.size = Vector2(1280, 3)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(rule)
	var kicker := VisualTheme.label("THE BOARD SENDS ITS REGARDS", "KickerLabel", 18)
	kicker.position = Vector2(90, 486)
	_root.add_child(kicker)
	var title := VisualTheme.label(boss_name, "TitleLabel", 72, Palette.PAPER)
	title.position = Vector2(84, 506)
	_root.add_child(title)
	var sub := VisualTheme.label(subtitle, "", 22, Palette.GOLD_PALE)
	sub.position = Vector2(90, 596)
	sub.size = Vector2(900, 30)
	_root.add_child(sub)
	var stamp := StampArt.new()
	stamp.text = "PRIORITY TARGET"
	stamp.font_size = 28
	stamp.tilt = -0.12
	_root.add_child(stamp)
	stamp.position = Vector2(980, 540)
	stamp.slam(0.35)
	_root.position.x = -1280.0
	var tw := create_tween()
	tw.tween_property(_root, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_callback(close)
	Audio.play("boss_intro")

func close() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(_finish)

func _finish() -> void:
	finished.emit()
	queue_free()
