extends Node2D
class_name PropArt
var kind := "terminal"
var tone := Color("69d6c4")
func _draw() -> void:
	if kind == "car":
		draw_style_box(VisualTheme.panel(Color("071015"), 0), Rect2(-64, -32, 128, 72))
		for at in [Vector2(-35, -31), Vector2(33, -31), Vector2(-35, 25), Vector2(33, 25)]:
			draw_rect(Rect2(at, Vector2(21, 9)), Color("04090d"))
		draw_style_box(VisualTheme.panel(Color("a6aaa0"), 0), Rect2(-64, -27, 128, 54))
		draw_rect(Rect2(-54, -24, 107, 46), Color("3f545b"))
		draw_rect(Rect2(-28, -21, 52, 42), Color("122c38"))
		draw_rect(Rect2(-16, -22, 28, 44), Color("526970"))
		draw_line(Vector2(-28, -17), Vector2(-22, 16), Color("548895"), 3)
		draw_line(Vector2(18, -16), Vector2(22, 16), Color("548895"), 3)
		for y in [-19, 15]:
			draw_rect(Rect2(58, y, 7, 7), Color("ffdfa0"))
			draw_rect(Rect2(-65, y, 5, 7), Color("d46154"))
			draw_line(Vector2(-12, y), Vector2(5, y), Color("c7c7ad"), 2)
	elif kind == "loot":
		draw_circle(Vector2(0, 4), 19, Color(0, 0, 0, 0.22))
		draw_rect(Rect2(-14, -8, 28, 18), Color("183831"))
		draw_rect(Rect2(-14, -12, 28, 17), Color("85b58b"))
		draw_rect(Rect2(-11, -10, 22, 12), Color("3d7762"), false, 2)
		draw_rect(Rect2(-3, -12, 6, 17), Color("e2ce91"))
		draw_line(Vector2(-9, 9), Vector2(10, 9), Color("658e73"), 1)
	elif kind == "chest":
		draw_style_box(VisualTheme.panel(tone, 0), Rect2(-32, -23, 64, 46))
		draw_rect(Rect2(-28, -18, 56, 31), Color("344751"))
		draw_rect(Rect2(-28, -18, 56, 7), tone.darkened(0.2))
		for x in [-23, 19]:
			draw_rect(Rect2(x, -22, 5, 43), tone)
		draw_rect(Rect2(-10, -28, 20, 6), Color("9aa9a3"), false, 3)
		draw_rect(Rect2(-5, 0, 10, 10), tone)
	else:
		draw_rect(Rect2(-22, -18, 49, 45), Color(0, 0, 0, 0.35))
		draw_style_box(VisualTheme.panel(Color("668e90"), 0), Rect2(-28, -23, 56, 47))
		draw_rect(Rect2(-23, -18, 46, 26), Color("123f42"))
		var graph := PackedVector2Array([Vector2(-19, 2), Vector2(-11, -4), Vector2(-4, -1), Vector2(5, -11), Vector2(12, -7), Vector2(20, -14)])
		draw_polyline(graph, tone, 2, true)
		for i in 6:
			draw_rect(Rect2(-20 + i * 7, 14, 4, 3), Color("668e90"))
