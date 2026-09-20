extends Control
class_name HUDFrame
var health := 6
var max_health := 6
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_style_box(VisualTheme.panel(Color("48615c"), 0), Rect2(20, 18, 282, 86))
	draw_style_box(VisualTheme.panel(VisualTheme.EDGE, 0), Rect2(20, 114, 282, 77))
	draw_style_box(VisualTheme.panel(VisualTheme.EDGE, 0), Rect2(318, 18, 565, 126))
	draw_style_box(VisualTheme.panel(VisualTheme.EDGE, 0), Rect2(898, 105, 360, 190))
	draw_rect(Rect2(20, 38, 3, 40), VisualTheme.TEAL)
	draw_rect(Rect2(318, 38, 3, 58), VisualTheme.GOLD)
	for i in mini(max_health, 12):
		var col := VisualTheme.TEAL if i < health else Color("34434a")
		draw_style_box(VisualTheme.panel(col, 0), Rect2(155 + i * minf(17, 125.0 / max_health), 36, 12, 15))
		if i < health:
			draw_rect(Rect2(158 + i * minf(17, 125.0 / max_health), 39, 6, 9), col)
