extends Control
class_name StampArt
## A rubber-stamp impression: double-ruled box, heading-font caps, ink wear.
## `slam()` animates it hitting the page. Purely decorative; ignores the mouse.

@export var text := "APPROVED"
@export var ink := Palette.STAMP_RED
@export var font_size := 46
@export var tilt := -0.12
var _wear: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(text)
	for i in 26:
		_wear.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(1.5, 4.5)])
	rotation = tilt
	_fit()

func _fit() -> void:
	var f := VisualTheme.font("heading_bold")
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 44
	custom_minimum_size = Vector2(w, font_size + 34)
	size = custom_minimum_size
	pivot_offset = size * 0.5

func set_text(value: String) -> void:
	text = value
	_fit()
	queue_redraw()

func _draw() -> void:
	var f := VisualTheme.font("heading_bold")
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r.grow(-2), ink, false, 4.0)
	draw_rect(r.grow(-9), Palette.with_alpha(ink, 0.8), false, 2.0)
	var baseline := size.y * 0.5 + font_size * 0.36
	draw_string(f, Vector2(0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, ink)
	# Worn ink: little gaps where the stamp didn't take.
	var paper := Palette.with_alpha(Palette.PAPER, 0.55)
	for w in _wear:
		draw_circle(Vector2(w[0].x * size.x, w[0].y * size.y), w[1], paper if w[1] < 3.0 else Palette.with_alpha(paper, 0.25))

## Scale down from big and fade in: the thunk of a stamp hitting paper.
func slam(delay: float = 0.0) -> void:
	scale = Vector2(2.4, 2.4)
	modulate.a = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(delay)
	tw.tween_property(self, "modulate:a", 1.0, 0.05)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_thunk)

func _thunk() -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.05)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui("stamp")
