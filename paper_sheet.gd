extends Control
class_name PaperSheet
## A sheet of case-file paper: warm stock, faint rules, punched margin, a
## coffee ring. Used by transitions, reports and the newspaper.

@export var stock := Palette.MANILA
@export var ruled := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2(6, 8), size), Color(0, 0, 0, 0.35))
	draw_rect(r, stock)
	# Fibre speckle, deterministic per size.
	var rng := RandomNumberGenerator.new()
	rng.seed = int(size.x * 7 + size.y)
	for i in int(size.x * size.y / 900.0):
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_rect(Rect2(p, Vector2(2, 1)), stock.darkened(rng.randf_range(0.04, 0.12)))
	if ruled:
		for y in range(96, int(size.y) - 30, 34):
			draw_line(Vector2(70, y), Vector2(size.x - 40, y), Palette.with_alpha(Color("7a8aa6"), 0.18), 1.0)
		draw_line(Vector2(64, 0), Vector2(64, size.y), Palette.with_alpha(Palette.STAMP_RED, 0.28), 1.5)
		for y in [size.y * 0.2, size.y * 0.5, size.y * 0.8]:
			draw_circle(Vector2(30, y), 9, stock.darkened(0.35))
	# Coffee ring in the corner.
	var ring := Vector2(size.x - 150, size.y - 130)
	draw_arc(ring, 52, 0.3, TAU - 0.4, 40, Palette.with_alpha(Color("6b4a2a"), 0.18), 5.0, true)
	draw_rect(r, stock.darkened(0.3), false, 2.0)
