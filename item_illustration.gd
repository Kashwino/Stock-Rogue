extends Control
class_name ItemIllustration
var item: Resource
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var accent := VisualTheme.GOLD
	if item and item.has_method("rarity_color"):
		accent = item.rarity_color()
	var c := size * 0.5
	draw_arc(c, 43, 0, TAU, 40, Color(accent, 0.13), 1, true)
	if item is WeaponItem:
		var big := item.slot == WeaponItem.Slot.BIG
		var length := 102.0 if big else 65.0
		var start := c - Vector2(length * 0.5, 7)
		draw_rect(Rect2(start + Vector2(-3, 6), Vector2(length + 6, 16)), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(start, Vector2(length * 0.72, 15)), Color("87948f"))
		draw_rect(Rect2(start + Vector2(length * 0.72, 2), Vector2(length * 0.28, 6)), accent)
		draw_rect(Rect2(start + Vector2(8, 11), Vector2(12, 23)), Color("705345"))
		draw_rect(Rect2(start + Vector2(28, 12), Vector2(10, 24 if big else 10)), Color("33464e"))
		if big:
			draw_rect(Rect2(start + Vector2(-12, -1), Vector2(19, 22)), Color("705345"))
			draw_rect(Rect2(start + Vector2(44, 9), Vector2(24, 10)), Color("506f70"))
		for i in 4:
			draw_line(start + Vector2(10 + i * 8, 3), start + Vector2(10 + i * 8, 9), Color("2a3c47"), 2)
	else:
		var shield := PackedVector2Array([c + Vector2(-26, -23), c + Vector2(26, -23), c + Vector2(22, 17), c + Vector2(0, 34), c + Vector2(-22, 17)])
		draw_colored_polygon(shield, Color("35545b"))
		draw_polyline(shield + PackedVector2Array([shield[0]]), accent, 3, true)
		draw_line(c + Vector2(-12, 1), c + Vector2(12, 1), accent, 5)
		draw_line(c + Vector2(0, -11), c + Vector2(0, 13), accent, 5)
