extends Control
class_name MenuBackdrop
## Animated menu backdrop: looking out of a dark office window at a rain-soaked
## skyline. Blinking windows, a neon crown on the Exchange tower, searchlight
## sweeps, and raindrops that slide down the glass. `hero` adds the window
## frame and heavier rain for the main menu; other screens get a dimmer take.

var hero := false
var _t := 0.0
var _buildings: Array = []     # [Rect2, layer, window seeds]
var _lit: Dictionary = {}      # window key -> on
var _drops: Array = []         # [pos, speed, radius]
var _rng := RandomNumberGenerator.new()
var _blink_clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 1947
	_generate()
	resized.connect(_generate)

func _generate() -> void:
	_buildings.clear()
	var w := maxf(size.x, 1280.0)
	var h := maxf(size.y, 720.0)
	for layer in 3:
		var x := -40.0
		while x < w + 40.0:
			var bw := _rng.randf_range(60, 150) * (1.0 + layer * 0.25)
			var bh := _rng.randf_range(160, 420) * (0.55 + layer * 0.3)
			_buildings.append([Rect2(x, h - bh - 60, bw, bh + 60), layer])
			x += bw + _rng.randf_range(-10, 20)
	_drops.clear()
	for i in (70 if hero else 26):
		_drops.append([Vector2(_rng.randf() * w, _rng.randf() * h), _rng.randf_range(20, 90), _rng.randf_range(1.5, 4.0)])

func _process(delta: float) -> void:
	_t += delta
	_blink_clock -= delta
	if _blink_clock <= 0.0:
		_blink_clock = 0.12
		for i in 6:
			_lit[_rng.randi() % 4000] = _rng.randf() < 0.55
	for d: Array in _drops:
		d[0].y += d[1] * delta
		d[0].x += sin(_t * 0.7 + d[2]) * 4.0 * delta
		if d[0].y > size.y + 10:
			d[0] = Vector2(_rng.randf() * size.x, -10)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	# Night sky.
	for i in 24:
		var t := float(i) / 24.0
		draw_rect(Rect2(0, h * t, w, h / 24.0 + 1), Color("0a0c16").lerp(Color("2a1428"), t * t))
	# Searchlights.
	for k in 2:
		var a := -PI * 0.5 + sin(_t * 0.25 + k * 2.2) * 0.6
		var base := Vector2(w * (0.3 + k * 0.45), h)
		var tip := base + Vector2.from_angle(a) * h * 1.4
		var side := Vector2.from_angle(a + PI * 0.5) * 70.0
		draw_colored_polygon(PackedVector2Array([base, tip + side, tip - side]), Color(0.8, 0.85, 1.0, 0.035))
	# Skyline, far to near.
	var tower_x := w * 0.52
	for b: Array in _buildings:
		var r: Rect2 = b[0]
		var layer: int = b[1]
		var shade := Color("0f1018").lerp(Color("07070b"), layer / 2.0)
		draw_rect(r, shade)
		var bright := 0.25 + layer * 0.3
		var cols := int(r.size.x / 14.0)
		var rows := int(r.size.y / 18.0)
		for cx in cols:
			for cy in rows:
				var key := int(r.position.x) * 31 + cx * 7 + cy * 131
				var on: bool = _lit.get(key % 4000, (key % 7) == 0)
				if on:
					draw_rect(Rect2(r.position.x + 5 + cx * 14, r.position.y + 8 + cy * 18, 6, 8), Color(1.0, 0.8, 0.45, bright * 0.8))
	# The Exchange tower with its neon crown.
	var tower := Rect2(tower_x - 60, h * 0.18, 120, h * 0.82)
	draw_rect(tower, Color("06060a"))
	draw_colored_polygon(PackedVector2Array([Vector2(tower_x - 60, h * 0.18), Vector2(tower_x, h * 0.08), Vector2(tower_x + 60, h * 0.18)]), Color("06060a"))
	var pulse := 0.6 + 0.4 * sin(_t * 1.3)
	draw_polyline(PackedVector2Array([Vector2(tower_x - 60, h * 0.18), Vector2(tower_x, h * 0.08), Vector2(tower_x + 60, h * 0.18)]), Palette.with_alpha(Palette.GOLD, pulse), 3.0, true)
	draw_circle(Vector2(tower_x, h * 0.08), 4, Palette.DANGER if fmod(_t, 1.2) < 0.6 else Color(0.3, 0.05, 0.05))
	for i in 18:
		var y := h * 0.22 + i * 26
		draw_line(Vector2(tower_x - 50, y), Vector2(tower_x + 50, y), Palette.with_alpha(Palette.NEON_CYAN, 0.12 + 0.1 * sin(_t * 2.0 + i)), 1.5)
	# Street glow at the bottom.
	draw_rect(Rect2(0, h - 60, w, 60), Color(0.9, 0.5, 0.2, 0.08))
	# Rain on the glass.
	for d: Array in _drops:
		var p: Vector2 = d[0]
		var r2: float = d[2]
		draw_line(p - Vector2(0, r2 * 6.0), p, Color(0.7, 0.8, 1.0, 0.12), r2 * 0.6)
		draw_circle(p, r2, Color(0.75, 0.85, 1.0, 0.25))
		draw_circle(p - Vector2(r2 * 0.3, r2 * 0.3), r2 * 0.35, Color(1, 1, 1, 0.35))
	if hero:
		# Window frame and a desk-lamp glow inside the office.
		var frame := Color("050507")
		draw_rect(Rect2(0, 0, w, 18), frame)
		draw_rect(Rect2(0, h - 18, w, 18), frame)
		draw_rect(Rect2(0, 0, 18, h), frame)
		draw_rect(Rect2(w - 18, 0, 18, h), frame)
		draw_rect(Rect2(w * 0.5 - 7, 0, 14, h), frame)
		draw_rect(Rect2(0, h * 0.42 - 6, w, 12), frame)
		for i in 10:
			draw_circle(Vector2(w * 0.05, h * 1.05), 520 - i * 45, Color(1.0, 0.72, 0.35, 0.012))
	else:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
