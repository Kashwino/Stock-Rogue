extends Control
class_name ContractArt
var accent := Color("69d6c4")
func _ready() -> void:
	custom_minimum_size.y = 106
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var c := size * Vector2(0.5, 0.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color("101e28"))
	for x in range(0, int(size.x), 24):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.3, 0.6, 0.6, 0.08))
	var front := Rect2(c + Vector2(-64, -19), Vector2(128, 57))
	draw_rect(Rect2(front.position + Vector2(7, 8), front.size), Color(0, 0, 0, 0.3))
	draw_rect(front, Color("35505a"))
	draw_rect(Rect2(c + Vector2(-70, -26), Vector2(140, 8)), accent.darkened(0.22))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-70, -26), c + Vector2(0, -47), c + Vector2(70, -26)]), Color("52716f"))
	for x in [-51, -25, 27, 53]:
		draw_rect(Rect2(c + Vector2(x - 5, -10), Vector2(10, 38)), Color("9caa94"))
		draw_line(c + Vector2(x - 6, 29), c + Vector2(x + 6, 29), accent, 3)
	draw_rect(Rect2(c + Vector2(-10, 7), Vector2(20, 31)), Color("07121b"))
	draw_rect(Rect2(c + Vector2(-8, 9), Vector2(16, 20)), accent.darkened(0.4))
	draw_line(c + Vector2(-76, 41), c + Vector2(76, 41), Color("667d7b"), 4)
