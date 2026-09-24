extends RefCounted
class_name CaseWallArt
## Drawn pieces for the case wall (the run map): the corkboard, pinned
## building photos, pins and red string, the collector's table.

class Corkboard extends Control:
	var seed_value := 3
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("2a1d12"))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for i in 2600:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var c := Palette.CORK.darkened(rng.randf_range(0.25, 0.6))
			draw_rect(Rect2(p, Vector2(rng.randf_range(1, 3), rng.randf_range(1, 3))), c)
		# Desk-lamp pool from above and heavy vignette.
		for k in 10:
			var rad := 900.0 - k * 70.0
			draw_circle(Vector2(size.x * 0.45, -120), rad, Color(1.0, 0.8, 0.45, 0.018))
		for k in 12:
			var inset := k * 18.0
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(0, 0, 0, 0.05), false, 18.0)
		# Wooden frame.
		draw_rect(r, Color("140c06"), false, 14.0)

class Pin extends Control:
	var color := Palette.STAMP_RED
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(16, 16)
	func _draw() -> void:
		draw_circle(Vector2(10, 11), 6, Color(0, 0, 0, 0.45))
		draw_circle(Vector2(8, 8), 6.5, color)
		draw_circle(Vector2(6, 6), 2.2, color.lightened(0.5))

## Red string between pinned points, sagging slightly.
class RedString extends Control:
	var points: Array = []          # [[Vector2 a, Vector2 b], ...]
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		for seg: Array in points:
			var a: Vector2 = seg[0]
			var b: Vector2 = seg[1]
			var pts := PackedVector2Array()
			var sag := minf(a.distance_to(b) * 0.08, 30.0)
			for i in 17:
				var t := i / 16.0
				pts.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * sag))
			var shadow := PackedVector2Array()
			for p in pts:
				shadow.append(p + Vector2(3, 5))
			draw_polyline(shadow, Color(0, 0, 0, 0.35), 3.0, true)
			draw_polyline(pts, Palette.STRING_RED, 2.5, true)

## A night photo of the target building, stapled to its case file.
class BuildingSketch extends Control:
	var stage := 0
	var sign_text := ""
	var seed_value := 0
	var boss := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("f2eee4"))
		var photo := r.grow(-7)
		photo.size.y -= 18
		draw_rect(photo, Color("0d1018"))
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var ground := photo.end.y - 10
		# Background skyline.
		var x := photo.position.x
		while x < photo.end.x:
			var w := rng.randf_range(18, 40)
			var h := rng.randf_range(20, photo.size.y * 0.6)
			draw_rect(Rect2(x, ground - h, w, h), Color("161a24"))
			x += w
		var neon: Color = [Palette.NEON_MAGENTA, Palette.NEON_CYAN, Color("ff5a3a"), Palette.NEON_GREEN][rng.randi() % 4]
		var cx := photo.get_center().x
		match stage:
			0:
				var b := Rect2(cx - photo.size.x * 0.34, ground - photo.size.y * 0.42, photo.size.x * 0.68, photo.size.y * 0.42)
				draw_rect(b, Color("4a2a22"))
				for i in 6:
					draw_rect(Rect2(b.position.x + 6 + i * b.size.x / 6.0, b.position.y + 6, b.size.x / 6.0 - 10, 10), Color("2a1612"))
				draw_rect(Rect2(b.position.x - 4, b.position.y + b.size.y * 0.45, b.size.x + 8, 8), Color("7a1f22"))
				for i in 8:
					draw_rect(Rect2(b.position.x + i * b.size.x / 8.0, b.position.y + b.size.y * 0.45, b.size.x / 16.0, 8), Color("e8e0d0"))
				draw_rect(Rect2(b.position.x + 10, b.end.y - 22, b.size.x - 20, 18), Color("ffcf7a").darkened(0.2))
			1:
				var b := Rect2(cx - photo.size.x * 0.22, photo.position.y + 12, photo.size.x * 0.44, ground - photo.position.y - 12)
				draw_rect(b, Color("252b38"))
				for yy in range(int(b.position.y) + 6, int(b.end.y) - 8, 9):
					for xx in range(int(b.position.x) + 5, int(b.end.x) - 5, 8):
						if rng.randf() < 0.35:
							draw_rect(Rect2(xx, yy, 4, 5), Color("ffd98a"))
			2:
				var b := Rect2(cx - photo.size.x * 0.36, ground - photo.size.y * 0.4, photo.size.x * 0.72, photo.size.y * 0.4)
				draw_rect(b, Color("3a2e26"))
				draw_colored_polygon(PackedVector2Array([Vector2(b.position.x - 6, b.position.y), Vector2(cx, b.position.y - 26), Vector2(b.end.x + 6, b.position.y)]), Color("4a3a30"))
				for i in 5:
					draw_rect(Rect2(b.position.x + 10 + i * (b.size.x - 20) / 4.5, b.position.y + 8, 6, b.size.y - 12), Color("d8cdb8"))
				draw_arc(Vector2(cx, b.position.y - 26), 14, PI, TAU, 16, Palette.GOLD, 3.0)
			_:
				var b := Rect2(cx - photo.size.x * 0.16, photo.position.y + 4, photo.size.x * 0.32, ground - photo.position.y - 4)
				draw_colored_polygon(PackedVector2Array([Vector2(b.position.x, b.end.y), Vector2(b.position.x + 8, b.position.y), Vector2(b.end.x - 8, b.position.y), Vector2(b.end.x, b.end.y)]), Color("16222c"))
				for yy in range(int(b.position.y) + 8, int(b.end.y) - 6, 6):
					draw_line(Vector2(b.position.x + 6, yy), Vector2(b.end.x - 6, yy), Palette.with_alpha(Palette.NEON_CYAN, 0.35 if rng.randf() < 0.6 else 0.1), 1.0)
				draw_circle(Vector2(cx, b.position.y + 2), 3, Palette.DANGER)
		# The neon sign.
		var f := VisualTheme.font("heading_bold")
		var sign_w := minf(photo.size.x - 12, f.get_string_size(sign_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 8)
		draw_rect(Rect2(cx - sign_w * 0.5, ground - 12, sign_w, 12), Color(0, 0, 0, 0.85))
		draw_string(f, Vector2(cx - sign_w * 0.5, ground - 2), sign_text, HORIZONTAL_ALIGNMENT_CENTER, sign_w, 11, neon.lightened(0.4))
		draw_rect(Rect2(photo.position.x, ground, photo.size.x, photo.end.y - ground), Color("0a0b0f"))
		if boss:
			draw_rect(photo, Palette.with_alpha(Palette.DANGER, 0.12))
		# Photo gloss.
		draw_line(photo.position + Vector2(4, 4), photo.position + Vector2(photo.size.x * 0.4, photo.size.y * 0.6), Color(1, 1, 1, 0.06), 10.0)

## The collector's side of the table: a heavy silhouette under a hanging lamp.
class CollectorScene extends Control:
	var mood := 0     # 0 waiting, 1 satisfied, -1 unhappy
	var _t := 0.0
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.52)
		# Lamp cone.
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 30, 0), Vector2(c.x + 30, 0), Vector2(c.x + 260, size.y), Vector2(c.x - 260, size.y)]), Color(1.0, 0.82, 0.5, 0.07))
		draw_line(Vector2(c.x, 0), Vector2(c.x, 30), Color("111111"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - 26, 44), Vector2(c.x + 26, 44), Vector2(c.x + 12, 28), Vector2(c.x - 12, 28)]), Color("2a2a2a"))
		draw_circle(Vector2(c.x, 46), 8, Color("ffe2a0"))
		# The man: broad shoulders, hat, cigar glow.
		var body := PackedVector2Array()
		for i in 24:
			var a := PI + PI * i / 23.0
			body.append(c + Vector2(cos(a) * 150.0, sin(a) * 80.0 + 110.0))
		draw_colored_polygon(body, Color("0c0c10"))
		draw_circle(c + Vector2(0, -8), 52, Color("0c0c10"))
		draw_rect(Rect2(c + Vector2(-80, -58), Vector2(160, 14)), Color("08080a"))
		draw_rect(Rect2(c + Vector2(-46, -104), Vector2(92, 50)), Color("08080a"))
		draw_rect(Rect2(c + Vector2(-46, -66), Vector2(92, 8)), Palette.with_alpha(Palette.GOLD_DIM, 0.6))
		var glow := 0.6 + 0.4 * sin(_t * 1.7)
		draw_circle(c + Vector2(34, 18), 4.5, Color(1.0, 0.45, 0.15, glow))
		for k in 3:
			var p := c + Vector2(40 + k * 8 + sin(_t + k) * 6, 8 - k * 18 - fmod(_t * 12.0, 18.0))
			draw_circle(p, 6 + k * 3, Color(0.8, 0.8, 0.85, 0.05))
		# Eyes catch the light when he's unhappy.
		if mood < 0:
			draw_circle(c + Vector2(-16, -12), 3, Palette.DANGER)
			draw_circle(c + Vector2(16, -12), 3, Palette.DANGER)
		# The table.
		draw_rect(Rect2(0, size.y - 70, size.x, 70), Color("2a1a0e"))
		draw_rect(Rect2(0, size.y - 70, size.x, 6), Color("4a3018"))
