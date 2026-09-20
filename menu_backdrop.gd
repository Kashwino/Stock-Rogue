extends Control
class_name MenuBackdrop
var hero := false
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1219"))
	for y in range(0, int(size.y), 24):
		var t: float = float(y) / maxf(size.y, 1.0)
		draw_rect(Rect2(0, y, size.x, 24), Color(0.045 + t * 0.018, 0.075 + t * 0.025, 0.095 + t * 0.023))
	for x in range(0, int(size.x), 56):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.35, 0.6, 0.6, 0.035))
	for y in range(0, int(size.y), 56):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.35, 0.6, 0.6, 0.035))
	draw_line(Vector2(48, 48), Vector2(size.x - 48, 48), Color("375052"), 1)
	draw_line(Vector2(48, size.y - 40), Vector2(size.x - 48, size.y - 40), Color("375052"), 1)
	if not hero:
		return
	# A bespoke vault illustration, rendered as crisp vector artwork at any scale.
	var c := Vector2(535, 430)
	for r in range(210, 179, -6):
		draw_circle(c + Vector2(0, 12), r, Color(0.02, 0.03, 0.04, 0.20))
	draw_rect(Rect2(c - Vector2(206, 206), Vector2(412, 412)), Color("132b32"))
	draw_rect(Rect2(c - Vector2(194, 194), Vector2(388, 388)), Color("27414a"), false, 3)
	draw_circle(c, 171, Color("09151d"))
	draw_circle(c, 160, Color("243c43"))
	draw_circle(c - Vector2(3, 4), 151, Color("172c34"))
	draw_arc(c, 150, -PI * 0.9, -PI * 0.12, 48, Color("829184"), 4, true)
	draw_arc(c, 140, 0, TAU, 64, Color("40565a"), 2, true)
	for i in 32:
		var a := TAU * i / 32.0
		draw_line(c + Vector2.from_angle(a) * 131, c + Vector2.from_angle(a) * (119 if i % 4 == 0 else 124), Color("a4905e"), 2)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var at: Vector2 = c + Vector2.from_angle(a) * 80
		draw_line(c, at, Color("080f16"), 18, true)
		draw_line(c - Vector2(2, 2), at - Vector2(2, 2), Color("b6a67e"), 8, true)
	draw_circle(c, 39, Color("09151d"))
	draw_circle(c, 29, Color("d9bb76"))
	draw_circle(c, 20, Color("34474a"))
	draw_line(c + Vector2(0, -14), c + Vector2(0, 14), Color("e4cc92"), 4)
	for y in [-120, 100]:
		draw_style_box(VisualTheme.panel(Color("576d6b"), 0), Rect2(c + Vector2(-222, y), Vector2(48, 70)))
	# Market candles behind the title, kept deliberately low contrast.
	for i in 12:
		var x := 82.0 + i * 42
		var y := 345.0 + sin(i * 0.8) * 38
		var col := Color(0.41, 0.78, 0.68, 0.16) if i % 3 else Color(0.91, 0.60, 0.40, 0.16)
		draw_line(Vector2(x, y - 26), Vector2(x, y + 46), col, 2)
		draw_rect(Rect2(x - 7, y - 8, 14, 28), col)
