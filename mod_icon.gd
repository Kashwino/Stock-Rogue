extends Control
class_name ModIcon
## A small drawn pictogram for a map modifier or an objective, with a tooltip.
## Used on the case files, the intro card and the HUD. `id` is a modifier id,
## an objective id, or &"?" for a stranger's tip.

var id: StringName = &"?"
var ink := Palette.INK
var paper := Palette.MANILA

func _ready() -> void:
	custom_minimum_size = Vector2(30, 30)
	if size == Vector2.ZERO:
		size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS
	if tooltip_text == "":
		tooltip_text = describe(id)

static func describe(key: StringName) -> String:
	if MapNode.MODIFIERS.has(key):
		return "%s — %s" % MapNode.MODIFIERS[key]
	if Objectives.DATA.has(key):
		var bonus := Objectives.reward(key)
		return "%s — %s%s" % [Objectives.title(key), Objectives.brief(key), ("  Bonus: " + bonus) if bonus != "" else ""]
	return "A stranger's tip: details unknown. A Recon Network reveals them."

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, ink)
	draw_circle(c, r - 2.0, paper)
	var k := r / 15.0
	match id:
		&"heavy_police":
			draw_arc(c + Vector2(0, 3) * k, 8 * k, PI, TAU, 12, ink, 3.0 * k)
			draw_rect(Rect2(c + Vector2(-9, 3) * k, Vector2(18, 4) * k), ink)
			draw_circle(c + Vector2(-4, -1) * k, 2.5 * k, Palette.POLICE_RED)
			draw_circle(c + Vector2(4, -1) * k, 2.5 * k, Palette.POLICE_BLUE)
		&"lockdown":
			draw_arc(c + Vector2(0, -3) * k, 5 * k, PI, TAU, 10, ink, 2.5 * k)
			draw_rect(Rect2(c + Vector2(-7, -2) * k, Vector2(14, 11) * k), ink)
			draw_circle(c + Vector2(0, 3) * k, 1.8 * k, paper)
		&"insider":
			var eye := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				eye.append(c + Vector2(cos(a) * -10.0, -sin(a) * 6.0) * k)
			for i in 13:
				var a := PI * i / 12.0
				eye.append(c + Vector2(cos(a) * 10.0, sin(a) * 6.0) * k)
			draw_colored_polygon(eye, ink)
			draw_circle(c, 3.5 * k, paper)
			draw_circle(c, 1.8 * k, ink)
		&"blackout":
			draw_circle(c + Vector2(0, -2) * k, 6 * k, ink)
			draw_rect(Rect2(c + Vector2(-3, 3) * k, Vector2(6, 5) * k), ink)
			draw_line(c + Vector2(-10, -10) * k, c + Vector2(10, 10) * k, Palette.DANGER, 2.5 * k)
		&"camera_network":
			for dx in [-5.0, 5.0]:
				draw_rect(Rect2(c + Vector2(dx - 4, -4) * k, Vector2(8, 7) * k), ink)
				draw_circle(c + Vector2(dx + 4, -0.5) * k, 2 * k, ink)
			draw_line(c + Vector2(-5, 3) * k, c + Vector2(-5, 9) * k, ink, 2.0 * k)
			draw_line(c + Vector2(5, 3) * k, c + Vector2(5, 9) * k, ink, 2.0 * k)
		&"payday":
			draw_circle(c + Vector2(0, 3) * k, 8 * k, ink)
			draw_rect(Rect2(c + Vector2(-3, -9) * k, Vector2(6, 5) * k), ink)
			draw_string(VisualTheme.font("heading_bold"), c + Vector2(-4, 8) * k, "$", HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * k), paper)
		&"skeleton_crew":
			draw_circle(c + Vector2(0, -5) * k, 3.5 * k, ink)
			draw_rect(Rect2(c + Vector2(-4, -1) * k, Vector2(8, 10) * k), ink)
			for dx in [-9.0, 9.0]:
				draw_arc(c + Vector2(dx, 2) * k, 3.5 * k, 0, TAU, 8, Palette.with_alpha(ink, 0.45), 1.2)
		&"rival_crew":
			for dx in [-5.0, 5.0]:
				draw_circle(c + Vector2(dx, 0) * k, 5.5 * k, ink)
				draw_line(c + Vector2(dx - 3, -1) * k, c + Vector2(dx + 3, -1) * k, Palette.NEON_GREEN, 1.8 * k)
		&"loot":
			var d := PackedVector2Array([c + Vector2(0, -9) * k, c + Vector2(8, -2) * k, c + Vector2(0, 9) * k, c + Vector2(-8, -2) * k])
			draw_colored_polygon(d, ink)
		&"assassination":
			draw_arc(c, 8 * k, 0, TAU, 20, Palette.DANGER, 2.0 * k)
			for a in [0.0, PI * 0.5, PI, PI * 1.5]:
				draw_line(c + Vector2.from_angle(a) * 4 * k, c + Vector2.from_angle(a) * 11 * k, ink, 2.0 * k)
		&"smash_grab":
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c, c + Vector2.from_angle(a) * (10.0 if i % 2 == 0 else 6.0) * k, ink, 2.0 * k)
		&"ghost":
			var g := PackedVector2Array()
			for i in 9:
				var a := PI + PI * i / 8.0
				g.append(c + Vector2(cos(a) * 8.0, sin(a) * 8.0 - 1.0) * k)
			g.append(c + Vector2(8, 9) * k)
			g.append(c + Vector2(4, 6) * k)
			g.append(c + Vector2(0, 9) * k)
			g.append(c + Vector2(-4, 6) * k)
			g.append(c + Vector2(-8, 9) * k)
			draw_colored_polygon(g, ink)
			draw_circle(c + Vector2(-3, -2) * k, 1.6 * k, paper)
			draw_circle(c + Vector2(3, -2) * k, 1.6 * k, paper)
		&"sabotage":
			draw_circle(c + Vector2(-1, 2) * k, 7 * k, ink)
			draw_line(c + Vector2(3, -4) * k, c + Vector2(8, -9) * k, ink, 2.0 * k)
			draw_circle(c + Vector2(9, -10) * k, 2 * k, Palette.SODIUM)
		&"package":
			draw_rect(Rect2(c + Vector2(-9, -5) * k, Vector2(18, 13) * k), ink)
			draw_rect(Rect2(c + Vector2(-4, -9) * k, Vector2(8, 4) * k), ink, false, 2.0 * k)
		_:
			draw_string(VisualTheme.font("heading_bold"), c + Vector2(-5, 7) * k, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * k), ink)
