extends Node2D
class_name TouchArt
var action := ""
var stick := false
func _draw() -> void:
	var radius := 83.0 if stick else 45.0
	var color := VisualTheme.TEAL if stick or action == "interact" else VisualTheme.GOLD
	draw_circle(Vector2(0, 3), radius + 4, Color(0, 0, 0, 0.22))
	draw_circle(Vector2.ZERO, radius, Color(0.035, 0.07, 0.09, 0.76))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, 0.48), 2, true)
	draw_arc(Vector2.ZERO, radius - 5, 0, TAU, 48, Color(color, 0.12), 1, true)
	if stick:
		for a in [0.0, PI * 0.5, PI, PI * 1.5]:
			draw_line(Vector2.from_angle(a) * 69, Vector2.from_angle(a) * 76, color, 2, true)
		return
	match action:
		"interact":
			draw_rect(Rect2(-9, -20, 18, 19), color, false, 2)
			draw_line(Vector2(-5, -11), Vector2(14, -11), color, 2, true)
			draw_line(Vector2(9, -16), Vector2(14, -11), color, 2, true)
		"reload":
			draw_arc(Vector2(0, -10), 11, -PI * 0.8, PI * 0.7, 18, color, 2, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-11, -24), Vector2(-3, -20), Vector2(-11, -16)]), color)
		"dodge":
			for x in [-6, 5]:
				draw_polyline(PackedVector2Array([Vector2(x - 5, -22), Vector2(x + 4, -13), Vector2(x - 5, -4)]), color, 3, true)
		"melee":
			# A knife: blade and grip.
			draw_colored_polygon(PackedVector2Array([Vector2(-12, -8), Vector2(10, -20), Vector2(4, -8)]), color)
			draw_line(Vector2(-12, -8), Vector2(-17, -3), color, 4, true)
		"swap_weapon":
			draw_line(Vector2(-12, -17), Vector2(12, -17), color, 2)
			draw_line(Vector2(-12, -6), Vector2(12, -6), color, 2)
			draw_line(Vector2(6, -23), Vector2(12, -17), color, 2)
			draw_line(Vector2(-6, 0), Vector2(-12, -6), color, 2)
