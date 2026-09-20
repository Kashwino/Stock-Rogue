extends Control
class_name PortraitArt
var unlocked := true
func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var c := size * 0.5
	var light := Color("e6d8b7") if unlocked else Color("6b777a")
	draw_circle(c, 43, Color("18343b"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-37, 35), c + Vector2(-30, 16), c + Vector2(0, 3), c + Vector2(30, 16), c + Vector2(37, 35)]), Color("345360"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-20, 12), c + Vector2(0, 20), c + Vector2(20, 12), c + Vector2(9, 38), c + Vector2(-9, 38)]), light)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 19), c + Vector2(5, 25), c + Vector2(2, 38), c + Vector2(-3, 38), c + Vector2(-5, 25)]), VisualTheme.GOLD)
	draw_rect(Rect2(c + Vector2(-9, 2), Vector2(18, 14)), light.darkened(0.2))
	draw_circle(c + Vector2(0, -10), 23, Color("08151c"))
	draw_style_box(VisualTheme.panel(light, 0), Rect2(c + Vector2(-17, -26), Vector2(34, 38)))
	draw_rect(Rect2(c + Vector2(-16, -19), Vector2(32, 22)), light)
	draw_line(c + Vector2(-13, -10), c + Vector2(13, -10), Color("19313b"), 7, true)
	draw_line(c + Vector2(-9, -10), c + Vector2(-5, -10), VisualTheme.GOLD, 2)
	draw_line(c + Vector2(5, -10), c + Vector2(9, -10), VisualTheme.GOLD, 2)
	draw_rect(Rect2(c + Vector2(-16, -2), Vector2(32, 10)), Color("2c444b"))
