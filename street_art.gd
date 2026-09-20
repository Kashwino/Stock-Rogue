extends Node2D
class_name StreetArt
var bounds := Rect2()
func _ready() -> void:
	z_index = -20
func _draw() -> void:
	var outer := bounds.grow(520)
	draw_rect(outer, Color("17232d"))
	for y in range(int(outer.position.y), int(outer.end.y), 90):
		for x in range(int(outer.position.x), int(outer.end.x), 110):
			draw_line(Vector2(x, y), Vector2(x + 46, y + 2), Color(0.36, 0.47, 0.49, 0.04), 1)
	draw_rect(bounds.grow(115), Color("2b3940"))
	draw_rect(bounds.grow(105), Color("25323a"))
	draw_rect(bounds.grow(100), Color("1e2b32"), false, 3)
	for x in range(int(outer.position.x), int(outer.end.x), 120):
		draw_rect(Rect2(x, bounds.end.y + 265, 62, 5), Color("8c8870"))
		draw_rect(Rect2(x, bounds.position.y - 265, 62, 5), Color("8c8870"))
	for y in range(int(outer.position.y), int(outer.end.y), 120):
		draw_rect(Rect2(bounds.end.x + 265, y, 5, 62), Color("8c8870"))
		draw_rect(Rect2(bounds.position.x - 265, y, 5, 62), Color("8c8870"))
