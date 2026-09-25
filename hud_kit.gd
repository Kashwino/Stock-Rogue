extends RefCounted
class_name HudKit
## Shared drawing for the Noir Props HUD (Brief 3). Three ingredients:
##   diegetic props  paper with torn edges, poker chips, cartridges, banknotes,
##                   typewriter keys, a blueprint — lying on the screen at a
##                   slight angle with a soft drop shadow
##   pulp slants     skewed parallelograms (-12 degrees), halftone dots,
##                   impact stars, heavy italic type
##   the ticker      the one straight, sharp strip across the top
## Every helper draws onto `ci` (a CanvasItem inside its _draw). Helpers that
## rotate set a transform and reset it to identity before returning, so call
## them outside your own draw_set_transform blocks. Torn edges come from
## seeded hashes, so paper never jitters; grain is one cached texture.
## Every piece of text gets a 2 px ink outline (text()).

const SKEW := -0.2126                 # tan(-12 degrees)
## The baked grain texture (released on shutdown by the Look autoload, so
## nothing outlives the renderer).
static var _grain_cache: Dictionary = {}

static func release_cache() -> void:
	_grain_cache.clear()
const OUTLINE := 2
const SHADOW := Color(0, 0, 0, 0.38)
const SHADOW_OFFSET := Vector2(3, 4)


# ------------------------------------------------------------- settings ----
static func minimal() -> bool:
	return int(Settings.values.get("hud_style", 0)) == Settings.HUD_MINIMAL

static func reduce_motion() -> bool:
	return bool(Settings.values.get("reduce_motion", false))

static func calm() -> bool:
	return bool(Settings.values.get("reduce_flashing", false))

# ------------------------------------------------------------------ text ----
## Text with a 2 px ink outline: reads over lit rooms, dark rooms and rain.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, ink := Palette.HUD_INK, outline := OUTLINE) -> void:
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, size, outline * 2, Palette.with_alpha(ink, color.a))
	ci.draw_string(font, pos, s, align, width, size, color)

static func text_width(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Word-wrap `s` (keeping its own line breaks) to `width` pixels.
static func wrap(font: Font, s: String, size: int, width: float) -> Array:
	var out: Array = []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and text_width(font, trial, size) > width:
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out

## A string centred on `center` (baseline adjusted for the font size).
static func text_centered(ci: CanvasItem, font: Font, center: Vector2, s: String, size: int, color: Color, ink := Palette.HUD_INK, outline := OUTLINE) -> void:
	var w := text_width(font, s, size)
	text(ci, font, center + Vector2(-w * 0.5, size * 0.36), s, size, color, HORIZONTAL_ALIGNMENT_LEFT, -1.0, ink, outline)

## Give a status Label the pulp look: heavy italic, ink outline, on a skewed
## dark slab (StyleBoxFlat.skew) with a coloured top edge.
static func style_label(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_override("font", VisualTheme.font("pulp"))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Palette.HUD_INK)
	label.add_theme_constant_override("outline_size", 4)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.04, 0.05, 0.82)
	box.skew = Vector2(-SKEW, 0.0)
	box.border_color = color
	box.border_width_top = 2
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	label.add_theme_stylebox_override("normal", box)

# ---------------------------------------------------------------- shapes ----
static func rotated(points: PackedVector2Array, pivot: Vector2, angle: float) -> PackedVector2Array:
	if is_zero_approx(angle):
		return points
	var out := PackedVector2Array()
	for p in points:
		out.append(pivot + (p - pivot).rotated(angle))
	return out

static func ellipse(center: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	if not out.is_empty():
		out.append(out[0])
	return out

## A stable pseudo-random value in [0, 1) for (seed, i).
static func noise(seed_value: int, i: int) -> float:
	return float(absi(hash(seed_value * 7919 + i * 104729)) % 10000) / 10000.0

## A rectangle's outline with torn edges (bitmask: 1 top, 2 right, 4 bottom,
## 8 left). Stable for a given seed.
static func torn_rect(rect: Rect2, seed_value: int, torn: int = 15, amp: float = 2.6, step: float = 7.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var normals := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	var n := 0
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		var length := a.distance_to(b)
		var steps := maxi(1, int(length / step))
		var ragged := (torn >> side) & 1 == 1
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			if ragged and k > 0:
				p += normals[side] * (noise(seed_value, n) - 0.35) * amp * 2.0
			pts.append(p)
			n += 1
	return pts

## Skewed parallelogram (pulp slant) for `rect`: the top edge leans right.
static func slant(rect: Rect2, skew: float = SKEW) -> PackedVector2Array:
	var off := -rect.size.y * skew
	return PackedVector2Array([rect.position + Vector2(off, 0), Vector2(rect.end.x + off, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

static func star(center: Vector2, outer: float, inner: float, points: int = 5, angle: float = -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2.from_angle(angle + i * PI / points) * r)
	return pts

## A comic impact burst: jagged, irregular spikes.
static func impact(center: Vector2, outer: float, inner: float, seed_value: int = 3, spikes: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in spikes * 2:
		var r := (outer if i % 2 == 0 else inner) * (0.8 + 0.4 * noise(seed_value, i))
		pts.append(center + Vector2.from_angle(TAU * i / (spikes * 2)) * r)
	return pts

static func shadowed(ci: CanvasItem, points: PackedVector2Array, color: Color, shadow := true) -> void:
	if shadow:
		var s := PackedVector2Array()
		for p in points:
			s.append(p + SHADOW_OFFSET)
		ci.draw_colored_polygon(s, Palette.with_alpha(SHADOW, SHADOW.a * color.a))
	ci.draw_colored_polygon(points, color)

# ----------------------------------------------------------------- paper ----
## A small cached grain texture (baked once): fibres and specks.
static func grain() -> Texture2D:
	if _grain_cache.has("grain"):
		return _grain_cache["grain"]
	if true:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1955
		for y in 64:
			for x in 64:
				var v := 0.9 + rng.randf() * 0.1
				if rng.randf() < 0.02:
					v -= 0.18
				img.set_pixel(x, y, Color(v, v, v * 0.98, 1.0))
		var tex := ImageTexture.create_from_image(img)
		_grain_cache["grain"] = tex
		return tex
	return null

## Paper: `points` filled with grain in `color`, a soft shadow, an aged edge.
static func paper_poly(ci: CanvasItem, points: PackedVector2Array, color: Color = Palette.PAPER_CREAM,
		edge: Color = Palette.PAPER_EDGE, shadow := true) -> void:
	if shadow:
		var s := PackedVector2Array()
		for p in points:
			s.append(p + SHADOW_OFFSET)
		ci.draw_colored_polygon(s, SHADOW)
	# The grain tiles (without repeat its edge pixels would smear).
	if ci.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
		ci.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append(p / 64.0)
	ci.draw_polygon(points, PackedColorArray([color]), uvs, grain())
	ci.draw_polyline(closed(points), edge, 1.5, true)

## draw_paper(rect, seed, torn edges): a torn sheet, rotated `angle` about
## its centre.
static func draw_paper(ci: CanvasItem, rect: Rect2, seed_value: int, torn: int = 15, angle: float = 0.0,
		color: Color = Palette.PAPER_CREAM, edge: Color = Palette.PAPER_EDGE, shadow := true) -> void:
	paper_poly(ci, rotated(torn_rect(rect, seed_value, torn), rect.get_center(), angle), color, edge, shadow)

## Ruled lines on a notepad sheet (drawn inside the current transform).
static func draw_rules(ci: CanvasItem, rect: Rect2, spacing: float, color: Color = Color(0.45, 0.6, 0.8, 0.35)) -> void:
	var y := rect.position.y + spacing
	while y < rect.end.y - 2.0:
		ci.draw_line(Vector2(rect.position.x + 4, y), Vector2(rect.end.x - 4, y), color, 1.0)
		y += spacing
	ci.draw_line(Vector2(rect.position.x + 22, rect.position.y + 2), Vector2(rect.position.x + 22, rect.end.y - 2), Palette.with_alpha(Palette.RED_PENCIL, 0.45), 1.0)

## A paperclip holding the top of a sheet.
static func draw_paperclip(ci: CanvasItem, at: Vector2, angle: float = 0.2, color: Color = Color("9aa0a8")) -> void:
	var pts := PackedVector2Array()
	var loops := [[Vector2(0, 0), 5.0, 26.0], [Vector2(2, 3), 3.2, 19.0]]
	for l: Array in loops:
		var o: Vector2 = l[0]
		var r: float = l[1]
		var h: float = l[2]
		pts = PackedVector2Array()
		for i in 13:
			pts.append(o + Vector2.from_angle(PI + PI * i / 12.0) * r)
		pts.append(o + Vector2(r, h))
		for i in 13:
			pts.append(o + Vector2(0, h) + Vector2.from_angle(PI * i / 12.0) * r)
		pts = rotated(pts, Vector2.ZERO, angle)
		var moved := PackedVector2Array()
		for p in pts:
			moved.append(p + at)
		ci.draw_polyline(moved, Color(0, 0, 0, 0.35), 3.4, true)
		ci.draw_polyline(moved, color, 2.0, true)

static func draw_pushpin(ci: CanvasItem, at: Vector2, color: Color = Palette.RED_PENCIL) -> void:
	ci.draw_circle(at + Vector2(2, 3), 6.5, SHADOW)
	ci.draw_circle(at, 6.5, color.darkened(0.25))
	ci.draw_circle(at + Vector2(-1, -1), 4.5, color)
	ci.draw_circle(at + Vector2(-2, -2.5), 1.6, Color(1, 1, 1, 0.6))

## A pencil strike-through across `from` -> `to`, drawn `k` (0..1) of the way.
static func draw_strike(ci: CanvasItem, from: Vector2, to: Vector2, k: float, color: Color = Palette.RED_PENCIL) -> void:
	if k <= 0.0:
		return
	var end := from.lerp(to, clampf(k, 0.0, 1.0))
	ci.draw_line(from + Vector2(0, 1), end + Vector2(0, -1), color, 2.6, true)

# ----------------------------------------------------------------- props ----
## A poker chip seen at a low angle: an ellipse top and a banded edge.
## `face` red or gold; cream dashes around the rim like a real chip.
static func draw_chip(ci: CanvasItem, center: Vector2, rx: float, ry: float, thick: float,
		face: Color = Palette.CHIP_RED, dash: Color = Palette.PAPER_CREAM, glow: float = 0.0) -> void:
	var band := PackedVector2Array()
	for i in 15:
		var a := PI * i / 14.0
		band.append(center + Vector2(cos(a) * rx, sin(a) * ry + thick))
	for i in 15:
		var a := PI - PI * i / 14.0
		band.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_colored_polygon(band, face.darkened(0.35))
	for i in 6:
		var a := PI * (i + 0.5) / 6.0
		var x := cos(a) * rx
		ci.draw_line(center + Vector2(x, sin(a) * ry + 1), center + Vector2(x, sin(a) * ry + thick - 1), dash.darkened(0.15), 3.0)
	ci.draw_colored_polygon(ellipse(center, rx, ry), face)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := center + Vector2(cos(a) * rx * 0.82, sin(a) * ry * 0.82)
		ci.draw_colored_polygon(ellipse(p, rx * 0.11, ry * 0.2, 10), dash)
	ci.draw_polyline(closed(ellipse(center, rx * 0.58, ry * 0.58)), Palette.with_alpha(dash, 0.8), 1.2, true)
	ci.draw_polyline(closed(ellipse(center, rx, ry)), face.darkened(0.5), 1.0, true)
	if glow > 0.0:
		ci.draw_colored_polygon(ellipse(center, rx + 4, ry + 3), Palette.with_alpha(Palette.DANGER, 0.35 * glow))

## draw_bullet(kind): a cartridge in side view, nose along +X from `pos`.
##   "round"   brass case, copper bullet
##   "shell"   red hull, brass head
##   "rifle"   long bottlenecked case
##   `spent`   an empty casing (dim, no bullet)
static func draw_bullet(ci: CanvasItem, pos: Vector2, kind: String = "round", angle: float = 0.0, s: float = 1.0, spent := false, alpha := 1.0) -> void:
	var parts: Array = []            # [points, colour]
	var brass := Palette.BRASS.lightened(0.15)
	match kind:
		"shell":
			parts.append([PackedVector2Array([Vector2(0, -5), Vector2(6, -5), Vector2(6, 5), Vector2(0, 5)]), brass])
			parts.append([PackedVector2Array([Vector2(6, -4.5), Vector2(22, -4.5), Vector2(22, 4.5), Vector2(6, 4.5)]), Color("a8322d") if not spent else Color("5a2a26")])
			parts.append([PackedVector2Array([Vector2(20, -4.5), Vector2(22, -4.5), Vector2(22, 4.5), Vector2(20, 4.5)]), Color("7a1f1f")])
		"rifle":
			parts.append([PackedVector2Array([Vector2(0, -3.6), Vector2(16, -3.6), Vector2(19, -2.4), Vector2(21, -2.4), Vector2(21, 2.4), Vector2(19, 2.4), Vector2(16, 3.6), Vector2(0, 3.6)]), brass])
			if not spent:
				parts.append([PackedVector2Array([Vector2(21, -2.4), Vector2(26, -1.6), Vector2(29, 0), Vector2(26, 1.6), Vector2(21, 2.4)]), Color("c0703f")])
		_:
			parts.append([PackedVector2Array([Vector2(0, -3.8), Vector2(10, -3.8), Vector2(10, 3.8), Vector2(0, 3.8)]), brass])
			if not spent:
				parts.append([PackedVector2Array([Vector2(10, -3.4), Vector2(13, -3.4), Vector2(16, -1.6), Vector2(17, 0), Vector2(16, 1.6), Vector2(13, 3.4), Vector2(10, 3.4)]), Color("c0703f")])
	for part: Array in parts:
		var pts := PackedVector2Array()
		for p: Vector2 in part[0]:
			pts.append(pos + (p * s).rotated(angle))
		var col: Color = part[1]
		if spent:
			col = col.darkened(0.45)
		ci.draw_colored_polygon(pts, Palette.with_alpha(col, alpha))
		ci.draw_polyline(closed(pts), Color(0, 0, 0, 0.55 * alpha), 1.0, true)
	# Rim line and a highlight along the top.
	ci.draw_line(pos + (Vector2(1.5, -3.5) * s).rotated(angle), pos + (Vector2(1.5, 3.5) * s).rotated(angle), Color(0, 0, 0, 0.4 * alpha), 1.0)
	ci.draw_line(pos + (Vector2(1, -2.4) * s).rotated(angle), pos + (Vector2(9, -2.4) * s).rotated(angle), Color(1, 1, 1, 0.35 * alpha), 1.0)

## A banknote (rotated `angle` about its centre): border, portrait oval,
## corner numerals.
static func draw_banknote(ci: CanvasItem, rect: Rect2, angle: float = 0.0, color: Color = Color("6f8f62"), shadow := true) -> void:
	var c := rect.get_center()
	var body := rotated(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), c, angle)
	shadowed(ci, body, color, shadow)
	var inner := rect.grow(-3.0)
	ci.draw_polyline(closed(rotated(PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]), c, angle)), color.darkened(0.35), 1.0, true)
	ci.draw_colored_polygon(rotated(ellipse(c, rect.size.y * 0.3, rect.size.y * 0.34, 16), c, angle), color.lightened(0.25))
	for corner in [Vector2(-1, -1), Vector2(1, 1)]:
		var p: Vector2 = c + (Vector2(rect.size.x * 0.5 - 7, rect.size.y * 0.5 - 6) * corner).rotated(angle)
		ci.draw_circle(p, 2.6, color.darkened(0.3))

## draw_slant_panel: a skewed slab, ink-outlined, optionally with halftone
## dots fading across it.
static func draw_slant_panel(ci: CanvasItem, rect: Rect2, color: Color, skew: float = SKEW, halftone := false,
		dots: Color = Color(0, 0, 0, 0.3), outline := true, shadow := true) -> void:
	var pts := slant(rect, skew)
	shadowed(ci, pts, color, shadow)
	if halftone:
		draw_halftone(ci, rect.grow(-3.0), dots, 7.0, skew)
	if outline:
		ci.draw_polyline(closed(pts), Palette.HUD_INK, 2.0, true)

## draw_halftone: comic-print dots, big on the left fading to the right.
## One cached texture stretched over `rect` (a single draw call, so a live
## combo slab costs nothing per frame).
static func draw_halftone(ci: CanvasItem, rect: Rect2, color: Color, _spacing: float = 7.0, _skew: float = 0.0) -> void:
	ci.draw_texture_rect(halftone(), rect, false, color)

static func halftone() -> Texture2D:
	if _grain_cache.has("halftone"):
		return _grain_cache["halftone"]
	var w := 192
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var spacing := 8.0
	var row := 0
	var y := spacing * 0.5
	while y < h:
		var x := spacing * 0.5 + (spacing * 0.5 if row % 2 == 1 else 0.0)
		while x < w:
			var r := spacing * 0.46 * (1.0 - x / w)
			for py in range(int(y - r - 1), int(y + r + 2)):
				for px in range(int(x - r - 1), int(x + r + 2)):
					if px < 0 or py < 0 or px >= w or py >= h:
						continue
					var d := Vector2(px + 0.5, py + 0.5).distance_to(Vector2(x, y))
					var a := clampf(r - d + 0.5, 0.0, 1.0)
					if a > 0.0:
						img.set_pixel(px, py, Color(1, 1, 1, maxf(a, img.get_pixel(px, py).a)))
			x += spacing
		y += spacing * 0.86
		row += 1
	var tex := ImageTexture.create_from_image(img)
	_grain_cache["halftone"] = tex
	return tex

## Speed lines streaking left of `rect` (a slam).
static func draw_speed_lines(ci: CanvasItem, rect: Rect2, color: Color, k: float, seed_value: int = 5) -> void:
	if k <= 0.0:
		return
	for i in 7:
		var y := rect.position.y + rect.size.y * (0.1 + 0.8 * noise(seed_value, i))
		var length := (40.0 + 60.0 * noise(seed_value, i + 20)) * k
		ci.draw_line(Vector2(rect.position.x - 6 - length, y), Vector2(rect.position.x - 6, y), Palette.with_alpha(color, 0.8 * k), 2.0)

## draw_stamp: a rubber stamp, double-bordered, rotated `angle`.
static func draw_stamp(ci: CanvasItem, center: Vector2, label: String, color: Color, angle: float = -0.12, size: int = 20, alpha: float = 1.0) -> void:
	var f := VisualTheme.font("heading_bold")
	var w := text_width(f, label, size) + 18.0
	var h := size + 12.0
	ci.draw_set_transform(center, angle, Vector2.ONE)
	var ink := Palette.with_alpha(color, 0.9 * alpha)
	ci.draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), ink, false, 2.5)
	ci.draw_rect(Rect2(-w * 0.5 + 4, -h * 0.5 + 4, w - 8, h - 8), Palette.with_alpha(color, 0.5 * alpha), false, 1.0)
	ci.draw_string(f, Vector2(-w * 0.5 + 9, size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

## draw_typewriter_key: a round key cap in a brass ring with an ink letter.
## `lift` > 0 hovers it up, < 0 presses it in.
static func draw_typewriter_key(ci: CanvasItem, center: Vector2, r: float, label: String, lift: float = 0.0, icon: String = "") -> void:
	var up := Vector2(0, -lift)
	ci.draw_circle(center + Vector2(1, 3 + maxf(lift, 0.0)), r + 1.0, Color(0, 0, 0, 0.45))
	ci.draw_circle(center + up, r, Palette.BRASS.darkened(0.25))
	ci.draw_circle(center + up, r - 1.5, Palette.BRASS)
	ci.draw_arc(center + up, r - 2.5, PI * 1.1, PI * 1.7, 12, Palette.with_alpha(Color.WHITE, 0.55), 1.5, true)
	ci.draw_circle(center + up, r - 4.5, Palette.PAPER_CREAM)
	ci.draw_circle(center + up, r - 6.5, Palette.HUD_INK)
	if icon != "":
		draw_icon(ci, icon, center + up, r * 0.42, Palette.PAPER_CREAM)
	elif label != "":
		var f := VisualTheme.font("type_bold")
		var size := int(r * (0.9 if label.length() <= 1 else 0.62))
		var w := text_width(f, label, size)
		ci.draw_string(f, center + up + Vector2(-w * 0.5, size * 0.34), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.PAPER_CREAM)

## An infinity sign (a lemniscate), `w` wide.
static func draw_infinity(ci: CanvasItem, c: Vector2, w: float, color: Color, width: float = 2.2) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var t := TAU * i / 32.0
		var d := 1.0 + sin(t) * sin(t)
		pts.append(c + Vector2(cos(t) / d, sin(t) * cos(t) / d) * w)
	ci.draw_polyline(pts, color, width, true)

## Small line icons for keys: "map", "pause".
static func draw_icon(ci: CanvasItem, icon: String, c: Vector2, s: float, color: Color) -> void:
	match icon:
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.7, -s), Vector2(s * 0.5, s * 2)), color)
			ci.draw_rect(Rect2(c + Vector2(s * 0.2, -s), Vector2(s * 0.5, s * 2)), color)
		"map":
			var pts := PackedVector2Array([c + Vector2(-s, -s * 0.7), c + Vector2(-s * 0.33, -s), c + Vector2(s * 0.33, -s * 0.7),
				c + Vector2(s, -s), c + Vector2(s, s * 0.7), c + Vector2(s * 0.33, s), c + Vector2(-s * 0.33, s * 0.7), c + Vector2(-s, s)])
			ci.draw_polyline(closed(pts), color, 1.8, true)
			ci.draw_line(c + Vector2(-s * 0.33, -s), c + Vector2(-s * 0.33, s * 0.7), color, 1.2)
			ci.draw_line(c + Vector2(s * 0.33, -s * 0.7), c + Vector2(s * 0.33, s), color, 1.2)

## draw_blueprint: folded blueprint paper with a grid, fold creases, one
## torn corner and a pushpin. Returns the drawable inner rect.
static func draw_blueprint(ci: CanvasItem, rect: Rect2, seed_value: int, angle: float = 0.0) -> Rect2:
	# The bottom-left corner is torn away.
	var tear := PackedVector2Array()
	for i in 6:
		var t := float(i) / 5.0
		tear.append(Vector2(rect.position.x, rect.end.y - 22).lerp(Vector2(rect.position.x + 22, rect.end.y), t)
			+ Vector2(noise(seed_value, i + 90) * 4.0 - 2.0, noise(seed_value, i + 99) * 4.0 - 2.0))
	var outline := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x + 22, rect.end.y)])
	for i in range(tear.size() - 1, -1, -1):
		outline.append(tear[i])
	outline = rotated(outline, rect.get_center(), angle)
	paper_poly(ci, outline, Palette.BLUEPRINT, Palette.BLUEPRINT.darkened(0.3))
	ci.draw_set_transform(rect.get_center(), angle, Vector2.ONE)
	var local := Rect2(rect.position - rect.get_center(), rect.size)
	var grid := Palette.with_alpha(Palette.BLUEPRINT_LINE, 0.12)
	var x := local.position.x + 12.0
	while x < local.end.x:
		ci.draw_line(Vector2(x, local.position.y + 2), Vector2(x, local.end.y - 2), grid, 1.0)
		x += 12.0
	var y := local.position.y + 12.0
	while y < local.end.y:
		ci.draw_line(Vector2(local.position.x + 2, y), Vector2(local.end.x - 2, y), grid, 1.0)
		y += 12.0
	# Fold creases: one down the middle, one across.
	ci.draw_line(Vector2(0, local.position.y), Vector2(0, local.end.y), Color(0, 0, 0, 0.22), 2.0)
	ci.draw_line(Vector2(1.5, local.position.y), Vector2(1.5, local.end.y), Color(1, 1, 1, 0.08), 1.0)
	ci.draw_line(Vector2(local.position.x, 0), Vector2(local.end.x, 0), Color(0, 0, 0, 0.18), 2.0)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_pushpin(ci, rect.get_center() + (Vector2(0, -rect.size.y * 0.5 + 8)).rotated(angle))
	return rect.grow(-8.0)

## A police badge star: five points with round tips and a ring.
static func draw_badge(ci: CanvasItem, center: Vector2, r: float, lit: bool, color: Color, flash: float = 0.0) -> void:
	var rr := r * (1.0 + 0.35 * flash)
	var pts := star(center, rr, rr * 0.5)
	if lit:
		ci.draw_colored_polygon(star(center + Vector2(1.5, 2), rr, rr * 0.5), Color(0, 0, 0, 0.45))
		ci.draw_colored_polygon(pts, color)
		for i in 5:
			ci.draw_circle(pts[i * 2], rr * 0.16, color.lightened(0.2))
		ci.draw_arc(center, rr * 0.36, 0, TAU, 16, Palette.with_alpha(Palette.HUD_INK, 0.7), 1.4, true)
		ci.draw_polyline(closed(pts), Palette.HUD_INK, 1.4, true)
		if flash > 0.0:
			ci.draw_colored_polygon(impact(center, rr * 1.7, rr * 1.1, 7, 10), Palette.with_alpha(Color.WHITE, 0.35 * flash))
	else:
		ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.35))
		ci.draw_polyline(closed(pts), Palette.with_alpha(Palette.PAPER_CREAM, 0.45), 1.2, true)

## A world-space interaction prompt: a typewriter key cap and a short skewed
## label to its right. `at` is the key's centre.
static func draw_key_prompt(ci: CanvasItem, at: Vector2, key: String, label: String, color: Color = Palette.GOLD) -> void:
	var f := VisualTheme.font("pulp")
	var size := 14
	var r := 11.0 if key.length() <= 1 else 13.0
	var w := text_width(f, label, size) + 18.0
	var rect := Rect2(at + Vector2(r + 2, -10), Vector2(w, 20))
	if label != "":
		draw_slant_panel(ci, rect, Palette.HUD_INK, SKEW, false, Color.TRANSPARENT, false)
		ci.draw_line(rect.position + Vector2(-rect.size.y * SKEW, 0), Vector2(rect.end.x - rect.size.y * SKEW, rect.position.y), color, 2.0)
		text(ci, f, rect.position + Vector2(9, 15), label, size, color)
	var key_font_label := key if key.length() <= 3 else key.substr(0, 3)
	draw_typewriter_key(ci, at, r, key_font_label)

## Gun silhouette parts (centre origin, side view), shared with the old icon:
## [[Rect2, colour], ...]; the first part is the top of the gun.
static func gun_parts(gun: int, body: Color, dark: Color) -> Array:
	var wood := Color("6b4a31")
	match gun:
		SpriteKit.Gun.PISTOL:
			return [[Rect2(-26, -10, 44, 11), body], [Rect2(-26, 1, 12, 20), dark], [Rect2(18, -8, 6, 6), dark]]
		SpriteKit.Gun.REVOLVER:
			return [[Rect2(-12, -9, 48, 8), body], [Rect2(-16, -12, 16, 16), dark], [Rect2(-26, -2, 12, 22), wood]]
		SpriteKit.Gun.SMG:
			return [[Rect2(-36, -10, 64, 14), body], [Rect2(-8, 4, 9, 20), dark], [Rect2(-32, 4, 10, 14), dark], [Rect2(28, -6, 12, 6), dark]]
		SpriteKit.Gun.RIFLE:
			return [[Rect2(-50, -9, 90, 11), body], [Rect2(-52, -6, 22, 16), wood], [Rect2(-4, 2, 8, 18), dark], [Rect2(40, -6, 12, 5), dark]]
		SpriteKit.Gun.LONG_RIFLE:
			return [[Rect2(-54, -7, 110, 9), body], [Rect2(-56, -5, 24, 16), wood], [Rect2(-14, -18, 30, 9), dark], [Rect2(-2, 2, 7, 14), dark]]
		SpriteKit.Gun.SHOTGUN:
			return [[Rect2(-50, -10, 96, 13), body], [Rect2(-52, -8, 24, 18), wood], [Rect2(0, 3, 26, 8), wood.darkened(0.2)]]
		SpriteKit.Gun.LMG:
			return [[Rect2(-54, -12, 104, 16), body], [Rect2(-8, 4, 24, 20), Color("3d4a33")], [Rect2(34, 4, 4, 18), dark], [Rect2(-56, -10, 18, 20), dark]]
	return [[Rect2(-20, -8, 40, 16), body]]
