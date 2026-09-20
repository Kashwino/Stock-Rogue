extends Control
class_name RouteMapArt
var completed := 0
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("0b171e"))
	# Street blocks, a river and connecting roads form the target district.
	for x in range(20, 1280, 90):
		for y in range(160, 560, 70):
			draw_rect(Rect2(x, y, 64, 46), Color("152830"))
	draw_polyline(PackedVector2Array([Vector2(620, 165), Vector2(670, 290), Vector2(610, 430), Vector2(660, 555)]), Color("20464a"), 38, true)
	for y in [270, 470]:
		draw_line(Vector2(80, y), Vector2(1200, y), Color("53635e"), 5, true)
	draw_line(Vector2(120, 270), Vector2(120, 470), Color("53635e"), 5, true)
	for i in 10:
		var at := Vector2(100 + i * 118, 128)
		var color := VisualTheme.TEAL if i < completed else (VisualTheme.GOLD if i == completed else Color("3b5058"))
		if i < 9:
			draw_line(at, at + Vector2(118, 0), Color("3b5058"), 3)
		draw_circle(at, 15, color)
		draw_string(ThemeDB.fallback_font, at + Vector2(-6, 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("0b171e"))
