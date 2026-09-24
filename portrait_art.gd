extends Control
class_name PortraitArt
## Front-facing mugshot for a specialist, against a height chart. Locked
## specialists are a black silhouette with a question mark.

var unlocked := true
var who: StringName = &"operator"

func _ready() -> void:
	custom_minimum_size = Vector2(120, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color("c9c4b4") if unlocked else Color("2a2a30"))
	# Height chart lines.
	for i in 6:
		var y := size.y * (0.12 + i * 0.16)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.18), 1.0)
		draw_string(VisualTheme.font("mono"), Vector2(3, y - 2), "%d" % (7 - i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.35))
	var c := Vector2(size.x * 0.5, size.y * 0.52)
	var s := size.y / 120.0
	var skin := Color("e0b48c")
	var coat := Color("2c2b33")
	var hat := Color("1a191e")
	match who:
		&"ghost":
			coat = Color("26272c")
			hat = Color("121216")
		&"wolf":
			coat = Color("4a3226")
			skin = Color("c68c62")
		&"broker":
			coat = Color("1f2a44")
			skin = Color("f0cfae")
		&"legend":
			coat = Color("d8d0bd")
			hat = Color("e8e2d0")
			skin = Color("9a6445")
	if not unlocked:
		skin = Color("0c0c0f")
		coat = Color("0c0c0f")
		hat = Color("0c0c0f")
	# Shoulders and collar.
	var shoulders := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		shoulders.append(c + Vector2(cos(a) * 52.0, sin(a) * 26.0 + 58.0) * s)
	draw_colored_polygon(shoulders, coat)
	if unlocked:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 34) * s, c + Vector2(0, 52) * s, c + Vector2(12, 34) * s]), Color("e8e4dc") if who != &"legend" else Color("2a2a2a"))
		if who == &"broker":
			draw_line(c + Vector2(0, 36) * s, c + Vector2(0, 56) * s, Palette.GOLD, 4.0 * s)
	# Neck and head.
	draw_rect(Rect2(c + Vector2(-9, 16) * s, Vector2(18, 18) * s), skin.darkened(0.15))
	draw_circle(c + Vector2(0, 0), 25.0 * s, skin)
	if unlocked:
		draw_circle(c + Vector2(-9, -2) * s, 2.6 * s, Color("1a1a1a"))
		draw_circle(c + Vector2(9, -2) * s, 2.6 * s, Color("1a1a1a"))
		draw_line(c + Vector2(-7, 12) * s, c + Vector2(7, 12) * s, skin.darkened(0.4), 2.0 * s)
	match who:
		&"ghost":
			if unlocked:
				draw_circle(c, 25.5 * s, hat)
				draw_rect(Rect2(c + Vector2(-16, -8) * s, Vector2(32, 11) * s), skin)
				draw_circle(c + Vector2(-8, -2) * s, 2.6 * s, Color("1a1a1a"))
				draw_circle(c + Vector2(8, -2) * s, 2.6 * s, Color("1a1a1a"))
		&"wolf":
			if unlocked:
				draw_line(c + Vector2(4, -14) * s, c + Vector2(14, 4) * s, Color("7a2c2c"), 2.5 * s)
				draw_line(c + Vector2(-12, 16) * s, c + Vector2(12, 16) * s, Color("4a2a1a"), 5.0 * s)
		&"broker":
			draw_arc(c + Vector2(0, -6) * s, 24.0 * s, PI, TAU, 16, Color("121212") if unlocked else hat, 10.0 * s)
			if unlocked:
				draw_rect(Rect2(c + Vector2(-16, -6) * s, Vector2(13, 8) * s), Color("dfe8f0"), false, 1.5 * s)
				draw_rect(Rect2(c + Vector2(3, -6) * s, Vector2(13, 8) * s), Color("dfe8f0"), false, 1.5 * s)
		_:
			# Fedora.
			draw_rect(Rect2(c + Vector2(-40, -22) * s, Vector2(80, 8) * s), hat)
			draw_rect(Rect2(c + Vector2(-24, -44) * s, Vector2(48, 24) * s), hat)
			draw_rect(Rect2(c + Vector2(-24, -28) * s, Vector2(48, 5) * s), Palette.GOLD_DIM if who != &"legend" else Color("1a1a1a"))
	if not unlocked:
		draw_string(VisualTheme.font("heading_bold"), c + Vector2(-12, 16) * s, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(44 * s), Palette.MUTED)
	draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)
