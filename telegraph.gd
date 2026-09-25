extends Node2D
class_name Telegraph
## World-space warning shapes: aim lasers, landing circles, charge lanes.
## Drawn unshaded above everything so darkness never hides a threat. The owner
## sets the shape each frame it matters and calls clear() when it is over.
##   line(from, to, color, width)          a laser or charge lane
##   ring(center, radius, color, fill)     a landing marker (fill 0..1 grows inward)

var _lines: Array = []
var _rings: Array = []

func _ready() -> void:
	top_level = true
	z_index = 45
	material = StreetArt._unshaded()

func line(from: Vector2, to: Vector2, color: Color, width: float = 2.0) -> void:
	_lines.append([from, to, color, width])
	queue_redraw()

func ring(center: Vector2, radius: float, color: Color, fill: float = 0.0) -> void:
	_rings.append([center, radius, color, clampf(fill, 0.0, 1.0)])
	queue_redraw()

func clear() -> void:
	if _lines.is_empty() and _rings.is_empty():
		return
	_lines.clear()
	_rings.clear()
	queue_redraw()

func _draw() -> void:
	var flicker := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.03)
	if Settings.values.get("reduce_flashing", false):
		flicker = 0.9
	for l in _lines:
		var c: Color = l[2]
		draw_line(l[0], l[1], Palette.with_alpha(c, 0.22 * flicker), l[3] * 3.5, true)
		draw_line(l[0], l[1], Palette.with_alpha(c, 0.9 * flicker), l[3], true)
		draw_circle(l[1], l[3] * 1.8, Palette.with_alpha(c, flicker))
	for r in _rings:
		var center: Vector2 = r[0]
		var radius: float = r[1]
		var c: Color = r[2]
		draw_circle(center, radius, Palette.with_alpha(c, 0.12))
		draw_circle(center, radius * r[3], Palette.with_alpha(c, 0.28))
		draw_arc(center, radius, 0.0, TAU, 40, Palette.with_alpha(c, 0.95 * flicker), 3.0, true)
		# Hazard ticks around the rim read as "get out" at a glance.
		for i in 8:
			var a := TAU * i / 8.0 + Time.get_ticks_msec() * 0.0015
			draw_line(center + Vector2.from_angle(a) * (radius - 9.0), center + Vector2.from_angle(a) * (radius + 3.0), c, 3.0)
