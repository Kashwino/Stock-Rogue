extends Control
class_name EndingArt
## Each ending's final image, drawn procedurally: a chair in the Landlord's
## doorway, the Auditor's two-column ledger, a beach at dusk, a burning
## skyline and one gold line rising out of the fire... Drawn in a 640x440
## design space and scaled to the control; `silhouette` darkens it to a
## locked gallery card. Static: drawn once (and on resize).

const DESIGN := Vector2(640, 440)

var ending: StringName = &"retired"
## Locked in the gallery: a dark silhouette only.
var silhouette := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	resized.connect(queue_redraw)
	if silhouette:
		modulate = Color(0.13, 0.13, 0.15)

var _k := 1.0
var _off := Vector2.ZERO

func _draw() -> void:
	_k = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_off = (size - DESIGN * _k) * 0.5
	draw_set_transform(_off, 0.0, Vector2(_k, _k))
	match ending:
		&"landlords_chair": _landlords_chair()
		&"cooked_books": _cooked_books()
		&"diplomatic_exit": _diplomatic_exit()
		&"black_monday": _black_monday()
		&"scorched_earth": _scorched_earth()
		&"syndicate": _syndicate()
		&"purge": _purge()
		&"puppeteer": _puppeteer()
		&"new_chairman": _new_chairman()
		&"seat_at_table": _seat_at_table()
		&"busted": _busted()
		_: _retired()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- helpers --
func _bg(top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(DESIGN.x, 0), DESIGN, Vector2(0, DESIGN.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _rng(tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(tag)
	return rng

## A row of buildings along `base`, `lit` = chance a window glows.
func _skyline(base: float, color: Color, tag: String, tallest: float, lit: float = 0.0, window: Color = Color("f3d98c")) -> void:
	var rng := _rng(tag)
	var x := 0.0
	while x < DESIGN.x - 4.0:
		var w := minf(rng.randf_range(34.0, 78.0), DESIGN.x - x)
		var h := rng.randf_range(tallest * 0.3, tallest)
		draw_rect(Rect2(x, base - h, w, h + 2.0), color)
		if lit > 0.0:
			var wy := base - h + 10.0
			while wy < base - 8.0:
				var wx := x + 6.0
				while wx < x + w - 8.0:
					if rng.randf() < lit:
						draw_rect(Rect2(wx, wy, 4, 6), Palette.with_alpha(window, rng.randf_range(0.4, 0.9)))
					wx += 10.0
				wy += 13.0
		x += w + rng.randf_range(2.0, 10.0)

func _rain(color: Color = Color(0.7, 0.75, 0.85, 0.18)) -> void:
	var rng := _rng("rain")
	for i in 70:
		var p := Vector2(rng.randf() * DESIGN.x, rng.randf() * DESIGN.y)
		draw_line(p, p + Vector2(-4, 16), color, 1.0)

## A standing figure (feet at `at`): a coat, a head and a hat.
func _figure(at: Vector2, s: float, color: Color, hat := "fedora") -> void:
	var body := PackedVector2Array([at + Vector2(-18, 0) * s, at + Vector2(-14, -62) * s, at + Vector2(14, -62) * s, at + Vector2(18, 0) * s])
	draw_colored_polygon(body, color)
	draw_circle(at + Vector2(0, -74) * s, 11.0 * s, color)
	match hat:
		"fedora":
			draw_rect(Rect2(at + Vector2(-17, -84) * s, Vector2(34, 4) * s), color)
			draw_rect(Rect2(at + Vector2(-10, -95) * s, Vector2(20, 12) * s), color)
		"hair":
			draw_circle(at + Vector2(0, -80) * s, 12.0 * s, color)
		"slick":
			draw_rect(Rect2(at + Vector2(-11, -86) * s, Vector2(22, 6) * s), color)

func _chair(at: Vector2, s: float, color: Color, high := false) -> void:
	var back := 70.0 if high else 44.0
	draw_rect(Rect2(at + Vector2(-22, -back - 30) * s, Vector2(44, back) * s), color)
	draw_rect(Rect2(at + Vector2(-26, -32) * s, Vector2(52, 10) * s), color)
	draw_rect(Rect2(at + Vector2(-22, -22) * s, Vector2(5, 22) * s), color)
	draw_rect(Rect2(at + Vector2(17, -22) * s, Vector2(5, 22) * s), color)

func _cone(from: Vector2, left: Vector2, right: Vector2, color: Color) -> void:
	draw_polygon(PackedVector2Array([from, left, right]), PackedColorArray([color, Palette.with_alpha(color, 0.0), Palette.with_alpha(color, 0.0)]))

# ----------------------------------------------------------------- scenes --
func _landlords_chair() -> void:
	_bg(Color("1c140f"), Color("0b0806"))
	# The doorway, light spilling in across the floor.
	draw_rect(Rect2(250, 90, 140, 250), Color("d9b77a"))
	draw_polygon(PackedVector2Array([Vector2(250, 340), Vector2(390, 340), Vector2(520, 440), Vector2(120, 440)]),
		PackedColorArray([Color(0.85, 0.7, 0.45, 0.5), Color(0.85, 0.7, 0.45, 0.5), Color(0.85, 0.7, 0.45, 0.0), Color(0.85, 0.7, 0.45, 0.0)]))
	# The armchair in silhouette, a rent book, a ring of keys.
	var chair := Color("140d09")
	draw_rect(Rect2(270, 200, 100, 110), chair)
	draw_rect(Rect2(252, 250, 26, 70), chair)
	draw_rect(Rect2(362, 250, 26, 70), chair)
	draw_rect(Rect2(262, 300, 116, 30), chair)
	draw_rect(Rect2(440, 300, 70, 8), Color("3a2a1c"))
	draw_rect(Rect2(452, 276, 44, 24), Color("7a1f1f"))
	draw_rect(Rect2(455, 279, 38, 3), Palette.GOLD)
	draw_arc(Vector2(150, 150), 16, 0.0, TAU, 20, Palette.GOLD, 3.0)
	for i in 4:
		var a := 1.2 + i * 0.35
		draw_line(Vector2(150, 150) + Vector2.from_angle(a) * 16, Vector2(150, 150) + Vector2.from_angle(a) * 40, Color("c9a452"), 4.0)
	draw_line(Vector2(320, 0), Vector2(320, 60), Color("2a2018"), 2.0)
	draw_circle(Vector2(320, 66), 8, Color("ffe7a8"))

func _cooked_books() -> void:
	_bg(Color("0e1411"), Color("050806"))
	_cone(Vector2(330, 70), Vector2(120, 400), Vector2(560, 400), Color(0.95, 0.9, 0.65, 0.35))
	draw_colored_polygon(PackedVector2Array([Vector2(300, 60), Vector2(360, 60), Vector2(380, 86), Vector2(280, 86)]), Color("1f5a3a"))
	draw_line(Vector2(330, 60), Vector2(330, 20), Color("444"), 3.0)
	# The open ledger: two columns, one in black, one in red.
	draw_colored_polygon(PackedVector2Array([Vector2(170, 300), Vector2(320, 280), Vector2(320, 400), Vector2(150, 420)]), Color("e9dfc4"))
	draw_colored_polygon(PackedVector2Array([Vector2(320, 280), Vector2(470, 300), Vector2(490, 420), Vector2(320, 400)]), Color("ddd2b4"))
	for i in 7:
		var y := 300.0 + i * 14.0
		draw_line(Vector2(180, y + 4 - i * 0.6), Vector2(300, y - 12 - i * 0.6 + 4), Color("222"), 2.0)
		draw_line(Vector2(340, y - 12 + 4), Vector2(460, y + 4), Color("b8322c"), 2.0)
	draw_line(Vector2(470, 380), Vector2(540, 330), Color("15151a"), 5.0)
	draw_line(Vector2(540, 330), Vector2(548, 324), Palette.GOLD, 5.0)

func _diplomatic_exit() -> void:
	_bg(Color("3b1d4a"), Color("f08a4b"))
	draw_circle(Vector2(420, 262), 64, Color("ffd27a"))
	for i in 6:
		var y := 262.0 + i * 16.0
		draw_rect(Rect2(0, y, DESIGN.x, 9), Color(0.12 + i * 0.02, 0.2 + i * 0.03, 0.35 + i * 0.03))
	draw_rect(Rect2(0, 350, DESIGN.x, 90), Color("d9b27a"))
	# A palm in silhouette.
	var palm := Color("1a0f14")
	draw_polyline(PackedVector2Array([Vector2(120, 360), Vector2(126, 300), Vector2(138, 240), Vector2(156, 190)]), palm, 10.0)
	for a in [-2.6, -2.0, -1.2, -0.5, 0.2]:
		var tip := Vector2(156, 190) + Vector2.from_angle(a) * 80.0
		draw_polyline(PackedVector2Array([Vector2(156, 190), Vector2(156, 190).lerp(tip, 0.5) + Vector2(0, -10), tip]), palm, 7.0)
	# The passport and the postcard in the sand.
	draw_colored_polygon(PackedVector2Array([Vector2(300, 392), Vector2(350, 384), Vector2(356, 418), Vector2(306, 426)]), Color("5a1622"))
	draw_circle(Vector2(328, 404), 6, Palette.GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(430, 380), Vector2(510, 372), Vector2(516, 416), Vector2(436, 424)]), Color("f4efe2"))
	draw_line(Vector2(444, 392), Vector2(500, 386), Color("333"), 2.0)
	draw_line(Vector2(444, 402), Vector2(488, 398), Color("b8322c"), 2.0)

func _black_monday() -> void:
	_bg(Color("200606"), Color("5a1a08"))
	_skyline(420.0, Color("0c0404"), "bm", 250.0, 0.25, Color("ff7a2a"))
	var rng := _rng("fire")
	for i in 30:
		draw_circle(Vector2(rng.randf() * DESIGN.x, rng.randf_range(250, 420)), rng.randf_range(8, 30), Color(1.0, rng.randf_range(0.3, 0.6), 0.1, 0.18))
	# The market's line crashing through the city...
	var crash := PackedVector2Array()
	for i in 12:
		crash.append(Vector2(20 + i * 55, 80 + i * i * 2.4 + rng.randf_range(-12, 12)))
	draw_polyline(crash, Color("ff4d5e"), 5.0, true)
	# ...and one gold line going the other way.
	draw_polyline(PackedVector2Array([Vector2(20, 400), Vector2(200, 360), Vector2(330, 300), Vector2(460, 170), Vector2(620, 30)]), Palette.GOLD, 6.0, true)
	draw_circle(Vector2(620, 30), 8, Palette.GOLD)

func _scorched_earth() -> void:
	_bg(Color("141414"), Color("2a1a14"))
	var rng := _rng("smoke")
	for i in 26:
		var p := Vector2(320 + rng.randf_range(-120, 160), 220 - i * 9.0)
		draw_circle(p, 20 + i * 2.2, Color(0.2, 0.2, 0.22, 0.12))
	draw_colored_polygon(PackedVector2Array([Vector2(260, 420), Vector2(270, 170), Vector2(300, 150), Vector2(330, 190), Vector2(345, 160), Vector2(380, 180), Vector2(390, 420)]), Color("080706"))
	_skyline(430.0, Color("0d0b0a"), "ash", 120.0)
	for i in 40:
		draw_circle(Vector2(rng.randf() * DESIGN.x, rng.randf_range(150, 430)), 1.6, Color(1.0, 0.5, 0.15, rng.randf_range(0.3, 0.9)))
	_rain()

func _syndicate() -> void:
	_bg(Color("12100c"), Color("070605"))
	_cone(Vector2(320, 0), Vector2(90, 440), Vector2(550, 440), Color(0.95, 0.85, 0.55, 0.25))
	# The round table, squashed into perspective.
	draw_set_transform(_off + Vector2(320, 330) * _k, 0.0, Vector2(1.0, 0.36) * _k)
	draw_circle(Vector2.ZERO, 190, Color("2a1d12"))
	draw_arc(Vector2.ZERO, 190, 0.0, TAU, 60, Palette.GOLD_DIM, 4.0)
	draw_set_transform(_off, 0.0, Vector2(_k, _k))
	_figure(Vector2(150, 330), 1.3, Color("0a0806"), "fedora")
	_figure(Vector2(250, 300), 1.1, Color("0a0806"), "slick")
	_figure(Vector2(390, 300), 1.1, Color("0a0806"), "hair")
	_figure(Vector2(490, 330), 1.3, Color("0a0806"), "fedora")
	_figure(Vector2(320, 290), 1.2, Color("3a2c10"), "fedora")
	draw_circle(Vector2(320, 190), 5, Palette.GOLD)

func _purge() -> void:
	_bg(Color("1a0506"), Color("060202"))
	# One long table, every chair empty but the last.
	draw_colored_polygon(PackedVector2Array([Vector2(170, 420), Vector2(300, 180), Vector2(340, 180), Vector2(470, 420)]), Color("2a0c0c"))
	for i in 6:
		var t := float(i) / 6.0
		var y := lerpf(400.0, 200.0, t)
		var sc := lerpf(1.1, 0.45, t)
		_chair(Vector2(lerpf(150.0, 290.0, t), y), sc, Color("120505"), true)
		_chair(Vector2(lerpf(490.0, 350.0, t), y), sc, Color("120505"), true)
	_chair(Vector2(320, 185), 0.55, Color("5a0c10"), true)
	_figure(Vector2(320, 176), 0.5, Color("000000"), "fedora")
	_cone(Vector2(320, 0), Vector2(250, 440), Vector2(390, 440), Color(0.8, 0.1, 0.1, 0.18))

func _puppeteer() -> void:
	_bg(Color("0f0e14"), Color("050408"))
	_chair(Vector2(320, 400), 2.0, Color("24202c"), true)
	_figure(Vector2(320, 380), 1.2, Color("3a3444"), "slick")
	# The strings, from a hand you can't see.
	var hand := Vector2(320, 30)
	for p: Vector2 in [Vector2(290, 300), Vector2(350, 300), Vector2(305, 260), Vector2(335, 260), Vector2(320, 250)]:
		draw_line(hand + Vector2((p.x - 320) * 0.6, 0), p, Color(0.9, 0.85, 0.7, 0.55), 1.2)
	draw_rect(Rect2(250, 20, 140, 10), Color("6b4a31"))
	draw_rect(Rect2(315, 0, 10, 40), Color("6b4a31"))
	_cone(Vector2(320, 0), Vector2(160, 440), Vector2(480, 440), Color(0.8, 0.8, 1.0, 0.12))

func _new_chairman() -> void:
	_bg(Color("0a0d1a"), Color("1d1a2a"))
	_skyline(440.0, Color("0b0c14"), "city", 150.0, 0.2)
	draw_rect(Rect2(270, 60, 100, 380), Color("11131e"))
	draw_colored_polygon(PackedVector2Array([Vector2(270, 60), Vector2(320, 20), Vector2(370, 60)]), Color("11131e"))
	draw_rect(Rect2(270, 110, 100, 10), Palette.GOLD)
	var rng := _rng("tower")
	for row in 18:
		for col in 5:
			if rng.randf() < 0.35:
				draw_rect(Rect2(280 + col * 18, 140 + row * 16, 8, 8), Color(0.95, 0.85, 0.55, 0.5))
	# The one lit office at the top.
	draw_rect(Rect2(290, 72, 60, 28), Color("ffd27a"))
	_chair(Vector2(320, 100), 0.35, Color("2a1d12"), true)
	_rain(Color(0.7, 0.75, 0.9, 0.12))

func _seat_at_table() -> void:
	_bg(Color("0d0d10"), Color("040405"))
	_cone(Vector2(320, 0), Vector2(220, 440), Vector2(420, 440), Color(0.95, 0.9, 0.7, 0.3))
	_chair(Vector2(320, 380), 1.6, Color("1d1a14"), true)
	_figure(Vector2(320, 360), 0.9, Color("2a261c"), "fedora")
	# The Board, standing in the dark with their eyes on you.
	var rng := _rng("board")
	for i in 8:
		var x := 60.0 + i * 74.0
		if absf(x - 320.0) < 90.0:
			continue
		var y := 330.0 + rng.randf_range(-20, 20)
		_figure(Vector2(x, y), 1.4, Color("060607"), ["fedora", "slick", "hair"][i % 3])
		draw_circle(Vector2(x - 4, y - 104), 1.8, Color("ffcf4a"))
		draw_circle(Vector2(x + 4, y - 104), 1.8, Color("ffcf4a"))

func _retired() -> void:
	_bg(Color("f2b27a"), Color("7fb3c9"))
	draw_circle(Vector2(470, 250), 52, Color("fff0c0"))
	draw_rect(Rect2(0, 260, DESIGN.x, 80), Color("5d8fb0"))
	for i in 5:
		draw_line(Vector2(380 + i * 10, 270 + i * 12), Vector2(560 - i * 10, 270 + i * 12), Color(1.0, 0.95, 0.8, 0.4), 2.0)
	# A balcony, a deck chair, the paper and a cup.
	draw_rect(Rect2(0, 340, DESIGN.x, 100), Color("c9b58f"))
	for i in 12:
		draw_rect(Rect2(10 + i * 54, 300, 6, 40), Color("f4efe2"))
	draw_rect(Rect2(0, 296, DESIGN.x, 6), Color("f4efe2"))
	draw_colored_polygon(PackedVector2Array([Vector2(170, 410), Vector2(250, 330), Vector2(270, 340), Vector2(200, 420)]), Color("2f6f8f"))
	draw_colored_polygon(PackedVector2Array([Vector2(200, 420), Vector2(330, 410), Vector2(330, 420), Vector2(210, 430)]), Color("2f6f8f"))
	draw_colored_polygon(PackedVector2Array([Vector2(380, 420), Vector2(450, 410), Vector2(456, 430), Vector2(386, 438)]), Color("ece6d6"))
	draw_line(Vector2(392, 420), Vector2(440, 414), Color("333"), 2.0)
	draw_rect(Rect2(480, 404, 18, 20), Color("f4efe2"))
	draw_arc(Vector2(500, 414), 6, -1.5, 1.5, 10, Color("f4efe2"), 2.0)

func _busted() -> void:
	_bg(Color("1a1a1e"), Color("0c0c0e"))
	# A chalk outline on the floor, and the tape.
	var chalk := Color(0.92, 0.92, 0.9, 0.85)
	var pts := PackedVector2Array([Vector2(300, 150), Vector2(340, 150), Vector2(350, 190), Vector2(420, 170), Vector2(426, 190), Vector2(356, 220),
		Vector2(370, 330), Vector2(400, 400), Vector2(378, 404), Vector2(330, 320), Vector2(300, 400), Vector2(278, 396), Vector2(296, 300),
		Vector2(280, 220), Vector2(220, 250), Vector2(214, 230), Vector2(286, 186), Vector2(300, 150)])
	draw_polyline(pts, chalk, 3.0, true)
	draw_arc(Vector2(320, 124), 26, 0.0, TAU, 30, chalk, 3.0)
	for i in 3:
		var y := 60.0 + i * 150.0
		draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(DESIGN.x, y - 40), Vector2(DESIGN.x, y - 18), Vector2(0, y + 22)]), Color("e8c832"))
