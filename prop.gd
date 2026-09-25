extends StaticBody2D
class_name Prop
## A piece of furniture that doubles as cover: blocks walking, bullets and
## line of sight (layer Layers.PROPS). Flying drones pass over it. Drawn once
## in _draw; a few kinds (server racks, slot machines, screens) blink slowly.

var kind := "crate"
var size := Vector2(60, 60)
var is_round := false
var theme: EnvTheme
var seed_value := 0
var _blink := false

const BLINKERS := ["server_rack", "slot_machine", "big_screen", "trading_desk"]
## Decoration-only kinds: drawn on the floor, no collision.
const FLAT := ["gold_stack", "pallet"]

func _ready() -> void:
	z_index = -1
	collision_layer = 0 if kind in FLAT else Layers.PROPS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	if is_round:
		var circle := CircleShape2D.new()
		circle.radius = size.x * 0.5
		shape.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
	shape.disabled = kind in FLAT
	add_child(shape)
	if kind in FLAT:
		z_index = -4
	if kind in BLINKERS and not Settings.values.get("low_effects", false):
		var timer := Timer.new()
		timer.wait_time = 0.6 + (seed_value % 5) * 0.11
		timer.autostart = true
		timer.timeout.connect(_on_blink)
		add_child(timer)
	queue_redraw()

func _on_blink() -> void:
	_blink = not _blink
	queue_redraw()

func footprint() -> Rect2:
	return Rect2(position - size * 0.5, size)

# ----------------------------------------------------------------- drawing --
func _draw() -> void:
	var h := size * 0.5
	var r := Rect2(-h, size)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Contact shadow first: everything sits on the floor.
	if is_round:
		draw_circle(Vector2(4, 6), h.x, Color(0, 0, 0, 0.35))
	elif not kind in FLAT:
		draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.35))
	match kind:
		"crate": _crate(r, rng)
		"pallet": _pallet(r)
		"barrel": _barrel(h.x)
		"shelf": _shelf(r, rng)
		"workbench": _workbench(r)
		"display_case": _display(r, rng)
		"safe": _safe(r)
		"car": _car(r)
		"desk": _desk(r, rng)
		"filing": _filing(r)
		"cubicle": _cubicle(r)
		"plant": _plant(h.x, rng)
		"water_cooler": _cooler(r)
		"copier": _copier(r)
		"counter": _counter(r, rng)
		"sofa": _sofa(r)
		"meeting_table": _meeting(r)
		"slot_machine": _slot(r, rng)
		"card_table": _card_table(h.x, rng)
		"roulette": _roulette(h.x)
		"pillar": _pillar(r)
		"statue": _statue(h.x)
		"bar": _bar(r, rng)
		"server_rack": _server(r, rng)
		"trading_desk": _trading(r, rng)
		"big_screen": _screen(r, rng)
		"glass": _glass(r)
		"gold_stack": _gold(r)
		_: draw_rect(r, Color("444"))

func _edge(r: Rect2, c: Color, w: float = 2.0) -> void:
	draw_rect(r, c, false, w)

func _crate(r: Rect2, rng: RandomNumberGenerator) -> void:
	var wood := Color("7a5a36").darkened(rng.randf() * 0.15)
	draw_rect(r, wood)
	for i in range(1, 4):
		var y := r.position.y + r.size.y * i / 4.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), wood.darkened(0.3), 1.5)
	draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), wood.darkened(0.35), 4.0)
	_edge(r.grow(-2), wood.lightened(0.18), 3.0)
	_edge(r, Color("1c140c"))
	draw_string(VisualTheme.font("mono"), r.position + Vector2(6, 16), "FRAGILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.with_alpha(Color("2a1a0c"), 0.6))

func _pallet(r: Rect2) -> void:
	var wood := Color("8a6a40")
	for i in 5:
		var x := r.position.x + i * r.size.x / 5.0
		draw_rect(Rect2(x + 2, r.position.y, r.size.x / 5.0 - 5, r.size.y), wood)
	draw_rect(Rect2(r.position.x, r.position.y + 6, r.size.x, 6), wood.darkened(0.3))
	draw_rect(Rect2(r.position.x, r.end.y - 12, r.size.x, 6), wood.darkened(0.3))

func _barrel(radius: float) -> void:
	draw_circle(Vector2.ZERO, radius, Color("2f4a3a"))
	draw_arc(Vector2.ZERO, radius - 3, 0, TAU, 24, Color("47715a"), 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.55, 0, TAU, 20, Color("22362b"), 2.0, true)
	draw_circle(Vector2(radius * 0.35, -radius * 0.2), 3.0, Color("0f0f0f"))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color("0d1410"), 2.0, true)

func _shelf(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("3a3d42"))
	var vertical := r.size.y > r.size.x
	var n := int((r.size.y if vertical else r.size.x) / 26.0)
	for i in n:
		var box := Rect2()
		if vertical:
			box = Rect2(r.position.x + 4, r.position.y + 4 + i * 26, r.size.x - 8, 20)
		else:
			box = Rect2(r.position.x + 4 + i * 26, r.position.y + 4, 20, r.size.y - 8)
		var tone: Color = [Color("a07a4a"), Color("6c7a8a"), Color("8a4a3a"), Color("c0b090")][rng.randi() % 4]
		draw_rect(box, tone)
		_edge(box, tone.darkened(0.4), 1.0)
	_edge(r, Color("111317"))

func _workbench(r: Rect2) -> void:
	draw_rect(r, Color("5c4630"))
	draw_rect(r.grow(-4), Color("6e5438"))
	draw_line(r.position + Vector2(12, 10), r.position + Vector2(40, 18), Color("9aa0a8"), 4.0)
	draw_circle(r.position + Vector2(r.size.x - 22, r.size.y * 0.5), 7, Color("c23a2a"))
	_edge(r, Color("1a120a"))

func _display(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("2a2622"))
	var glass := r.grow(-5)
	draw_rect(glass, Color(0.5, 0.75, 0.85, 0.28))
	for i in 5:
		var p := glass.position + Vector2(rng.randf() * glass.size.x, rng.randf() * glass.size.y)
		draw_circle(p, 2.5, [Palette.GOLD, Color("dfe8ff"), Color("ff5a7a")][rng.randi() % 3])
	draw_line(glass.position + Vector2(4, 4), glass.position + Vector2(glass.size.x * 0.4, glass.size.y - 4), Color(1, 1, 1, 0.3), 2.0)
	_edge(r, Palette.GOLD_DIM)

func _safe(r: Rect2) -> void:
	draw_rect(r, Color("50555c"))
	draw_rect(r.grow(-4), Color("3f444a"))
	draw_circle(r.get_center(), r.size.x * 0.22, Color("25282c"))
	draw_arc(r.get_center(), r.size.x * 0.22, 0, TAU, 20, Color("a8adb4"), 2.0, true)
	draw_line(r.get_center(), r.get_center() + Vector2(0, -r.size.x * 0.18), Color("d0d4da"), 2.0)
	_edge(r, Color("15171a"))

func _car(r: Rect2) -> void:
	var body := Color("6a2a2a")
	draw_rect(r, body)
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.28, 5), Vector2(r.size.x * 0.4, r.size.y - 10)), Color("1c2a33"))
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.34, 8), Vector2(r.size.x * 0.28, r.size.y - 16)), body.darkened(0.15))
	for p in [r.position, Vector2(r.end.x - 22, r.position.y), Vector2(r.position.x, r.end.y - 8), Vector2(r.end.x - 22, r.end.y - 8)]:
		draw_rect(Rect2(p + Vector2(8, -2), Vector2(18, 10)), Color("0c0c0c"))
	_edge(r, Color("1a0c0c"))
	draw_rect(Rect2(r.end.x - 8, r.position.y + 6, 6, 10), Color("ffe8a0"))
	draw_rect(Rect2(r.end.x - 8, r.end.y - 16, 6, 10), Color("ffe8a0"))

func _desk(r: Rect2, rng: RandomNumberGenerator) -> void:
	var top := Color("6b4a30") if theme == null or theme.stage < 3 else Color("2a3038")
	draw_rect(r, top)
	_edge(r.grow(-3), top.lightened(0.15), 1.5)
	var mon := Rect2(r.get_center() - Vector2(20, r.size.y * 0.4), Vector2(40, 8))
	draw_rect(mon, Color("111418"))
	draw_rect(mon.grow(-2), Color("3a8ab0") if rng.randf() < 0.6 else Color("1a2a33"))
	draw_rect(Rect2(r.position + Vector2(10, r.size.y * 0.5), Vector2(26, 18)), Color("e6e0d0"))
	draw_rect(Rect2(r.position + Vector2(14, r.size.y * 0.5 + 3), Vector2(26, 18)), Color("f2eee2"))
	draw_circle(Vector2(r.end.x - 18, r.position.y + 14), 5, Color("5a3320"))
	_edge(r, Color("140e08"))
	# Chair tucked behind the desk.
	draw_circle(Vector2(0, r.end.y + 10), 11, Color("1d1d22"))

func _filing(r: Rect2) -> void:
	draw_rect(r, Color("5e6670"))
	var vertical := r.size.y > r.size.x
	var n := 3
	for i in n:
		var d := Rect2()
		if vertical:
			d = Rect2(r.position.x + 4, r.position.y + 4 + i * (r.size.y - 8) / n, r.size.x - 8, (r.size.y - 8) / n - 3)
		else:
			d = Rect2(r.position.x + 4 + i * (r.size.x - 8) / n, r.position.y + 4, (r.size.x - 8) / n - 3, r.size.y - 8)
		draw_rect(d, Color("6f7882"))
		draw_rect(Rect2(d.get_center() - Vector2(5, 1.5), Vector2(10, 3)), Color("2a2e33"))
	_edge(r, Color("1d2126"))

func _cubicle(r: Rect2) -> void:
	draw_rect(r, Color("3a4452"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), Color("596676"))
	draw_rect(Rect2(r.position, Vector2(8, r.size.y)), Color("596676"))
	var desk := Rect2(r.position + Vector2(12, 12), Vector2(r.size.x - 16, r.size.y * 0.45))
	draw_rect(desk, Color("8a7a60"))
	draw_rect(Rect2(desk.position + Vector2(desk.size.x * 0.35, 4), Vector2(28, 7)), Color("15181c"))
	_edge(r, Color("161a20"))

func _plant(radius: float, rng: RandomNumberGenerator) -> void:
	draw_circle(Vector2.ZERO, radius * 0.72, Color("6a4a32"))
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf() * 0.4
		var leaf := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - 0.25) * radius * 0.8, Vector2.from_angle(a) * radius * 1.25, Vector2.from_angle(a + 0.25) * radius * 0.8])
		draw_colored_polygon(leaf, Color("2f6a3a").lightened(rng.randf() * 0.15))
	draw_circle(Vector2.ZERO, radius * 0.3, Color("3f8a4a"))

func _cooler(r: Rect2) -> void:
	draw_rect(r, Color("d8dcdf"))
	draw_circle(r.get_center(), r.size.x * 0.34, Color("6ab4e8"))
	_edge(r, Color("5a6068"))

func _copier(r: Rect2) -> void:
	draw_rect(r, Color("b8bcc0"))
	draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, r.size.y * 0.45)), Color("80858b"))
	draw_rect(Rect2(r.position + Vector2(r.size.x - 18, r.size.y - 14), Vector2(10, 6)), Color("3ad06a"))
	_edge(r, Color("40444a"))

func _counter(r: Rect2, rng: RandomNumberGenerator) -> void:
	var stone := Color("c9c2b0") if theme == null or theme.stage != 0 else Color("5a4632")
	draw_rect(r, stone)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), stone.lightened(0.15))
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - 6), Vector2(r.size.x, 6)), stone.darkened(0.3))
	for i in 3:
		var x := r.position.x + 20 + i * (r.size.x - 40) / 2.0
		draw_rect(Rect2(x - 10, r.position.y + 9, 20, 8), Color("202428"))
	if rng.randf() < 0.6:
		draw_circle(Vector2(r.end.x - 16, r.get_center().y), 5, Palette.GOLD)
	_edge(r, stone.darkened(0.5))

func _sofa(r: Rect2) -> void:
	var fabric := Color("5a2430") if theme == null or theme.stage >= 2 else Color("3a4a5a")
	draw_rect(r, fabric.darkened(0.25))
	var vertical := r.size.y > r.size.x
	if vertical:
		draw_rect(Rect2(r.position + Vector2(10, 4), r.size - Vector2(14, 8)), fabric)
		draw_line(Vector2(r.position.x + 10, 0), Vector2(r.end.x - 4, 0), fabric.darkened(0.3), 2.0)
	else:
		draw_rect(Rect2(r.position + Vector2(4, 10), r.size - Vector2(8, 14)), fabric)
		draw_line(Vector2(0, r.position.y + 10), Vector2(0, r.end.y - 4), fabric.darkened(0.3), 2.0)
	_edge(r, fabric.darkened(0.6))

func _meeting(r: Rect2) -> void:
	for i in 4:
		var x := r.position.x + 30 + i * (r.size.x - 60) / 3.0
		draw_circle(Vector2(x, r.position.y - 12), 10, Color("1c1c22"))
		draw_circle(Vector2(x, r.end.y + 12), 10, Color("1c1c22"))
	draw_rect(r, Color("4a3020"))
	draw_rect(r.grow(-6), Color("5a3a26"))
	draw_line(Vector2(r.position.x + 20, 0), Vector2(r.end.x - 20, 0), Color(1, 1, 1, 0.06), 6.0)
	_edge(r, Color("1c1008"))

func _slot(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("2a1830"))
	var screen := Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, r.size.y * 0.5))
	var lit := Palette.NEON_MAGENTA if _blink else Palette.GOLD
	draw_rect(screen, lit.darkened(0.3))
	for i in 3:
		draw_rect(Rect2(screen.position + Vector2(3 + i * (screen.size.x - 6) / 3.0, 3), Vector2((screen.size.x - 12) / 3.0, screen.size.y - 6)), Color("f4eee0"))
	draw_circle(Vector2(r.end.x - 6, r.end.y - 10), 4, Color("ff3030"))
	_edge(r, lit.darkened(0.5))
	rng.randf()

func _card_table(radius: float, rng: RandomNumberGenerator) -> void:
	draw_circle(Vector2.ZERO, radius, Color("3a2412"))
	draw_circle(Vector2.ZERO, radius - 6, Color("1f5a38"))
	draw_arc(Vector2.ZERO, radius - 14, 0, TAU, 32, Color(1, 1, 1, 0.12), 1.5, true)
	for i in 5:
		var p := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4, radius - 18)
		draw_circle(p, 4, [Color("d03a3a"), Color("2a5ad0"), Color("f0f0f0"), Palette.GOLD][rng.randi() % 4])
	draw_rect(Rect2(-12, -8, 10, 14), Color("f4f0e6"))
	draw_rect(Rect2(2, -6, 10, 14), Color("f4f0e6"))

func _roulette(radius: float) -> void:
	draw_circle(Vector2.ZERO, radius, Color("3a2412"))
	for i in 18:
		var a0 := TAU * i / 18.0
		var pts := PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a0) * (radius - 6), Vector2.from_angle(a0 + TAU / 18.0) * (radius - 6)])
		draw_colored_polygon(pts, Color("a01818") if i % 2 == 0 else Color("111111"))
	draw_circle(Vector2.ZERO, radius * 0.35, Palette.GOLD_DIM)
	draw_circle(Vector2.ZERO, radius * 0.12, Palette.GOLD)

func _pillar(r: Rect2) -> void:
	var stone := theme.wall_top.lightened(0.2) if theme else Color("8a8a8a")
	draw_rect(r, stone.darkened(0.15))
	draw_rect(r.grow(-5), stone)
	draw_line(r.position + Vector2(5, 5), Vector2(r.position.x + 5, r.end.y - 5), stone.lightened(0.25), 2.0)
	_edge(r, stone.darkened(0.5))

func _statue(radius: float) -> void:
	draw_rect(Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0), Color("3a3634"))
	draw_circle(Vector2.ZERO, radius * 0.7, Color("c8c0b0"))
	draw_circle(Vector2(radius * 0.15, -radius * 0.1), radius * 0.32, Color("e0d8c8"))
	_edge(Rect2(Vector2(-radius, -radius), Vector2(radius, radius) * 2.0), Color("1a1818"))

func _bar(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("3a2210"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), Palette.GOLD_DIM)
	var vertical := r.size.y > r.size.x
	for i in 8:
		var p := r.get_center() + (Vector2(0, (i - 3.5) * r.size.y / 9.0) if vertical else Vector2((i - 3.5) * r.size.x / 9.0, 0))
		draw_circle(p, 4, [Color("3a7a4a"), Color("8a2a1a"), Color("c0a060"), Color("2a4a8a")][rng.randi() % 4])
	_edge(r, Color("140a04"))

func _server(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("16191e"))
	var vertical := r.size.y > r.size.x
	var n := int((r.size.y if vertical else r.size.x) / 12.0)
	for i in n:
		var row := Rect2(r.position + (Vector2(4, 4 + i * 12) if vertical else Vector2(4 + i * 12, 4)), (Vector2(r.size.x - 8, 8) if vertical else Vector2(8, r.size.y - 8)))
		draw_rect(row, Color("252a31"))
		var on := (rng.randi() % 3 == 0) != _blink
		draw_circle(row.position + Vector2(4, 4), 2.0, Palette.NEON_GREEN if on else Color("1a3a2a"))
		if rng.randf() < 0.4:
			draw_circle(row.position + Vector2(10, 4), 2.0, Palette.NEON_CYAN if not on else Color("0a2a33"))
	_edge(r, Palette.with_alpha(Palette.NEON_CYAN, 0.35), 1.5)

func _trading(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("1d2229"))
	for i in 3:
		var mon := Rect2(r.position + Vector2(8 + i * (r.size.x - 16) / 3.0, 6), Vector2((r.size.x - 28) / 3.0, r.size.y * 0.42))
		draw_rect(mon, Color("050a0d"))
		var line := PackedVector2Array()
		var y := mon.get_center().y
		for k in 8:
			y = clampf(y + rng.randf_range(-4, 4) + (-1.5 if _blink else 1.5), mon.position.y + 2, mon.end.y - 2)
			line.append(Vector2(mon.position.x + 2 + k * (mon.size.x - 4) / 7.0, y))
		draw_polyline(line, Palette.UP if rng.randf() < 0.55 else Palette.DOWN, 1.5, true)
	_edge(r, Color("0a0c10"))
	draw_circle(Vector2(0, r.end.y + 10), 11, Color("15181c"))

func _screen(r: Rect2, rng: RandomNumberGenerator) -> void:
	draw_rect(r, Color("06090c"))
	var inner := r.grow(-3)
	draw_rect(inner, Color("0b1a22"))
	var vertical := r.size.y > r.size.x
	var n := 10
	for i in n:
		var up := rng.randf() < (0.6 if _blink else 0.45)
		var seg := Rect2(inner.position + (Vector2(2, 2 + i * inner.size.y / n) if vertical else Vector2(2 + i * inner.size.x / n, 2)), (Vector2(inner.size.x - 4, inner.size.y / n - 3) if vertical else Vector2(inner.size.x / n - 3, inner.size.y - 4)))
		draw_rect(seg, Palette.with_alpha(Palette.UP if up else Palette.DOWN, 0.6))
	_edge(r, Palette.with_alpha(Palette.NEON_CYAN, 0.5), 1.5)

func _glass(r: Rect2) -> void:
	draw_rect(r, Color(0.55, 0.8, 0.9, 0.22))
	_edge(r, Color(0.7, 0.9, 1.0, 0.6), 1.5)
	draw_line(r.position + Vector2(3, 3), r.position + Vector2(r.size.x * 0.3, r.size.y - 3), Color(1, 1, 1, 0.35), 1.5)

func _gold(r: Rect2) -> void:
	for i in 3:
		for j in 2:
			var bar := Rect2(r.position + Vector2(i * 22, j * 14 + i % 2 * 4), Vector2(20, 11))
			draw_rect(bar, Palette.GOLD)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x, 3)), Palette.GOLD_PALE)
			_edge(bar, Palette.GOLD_DIM, 1.0)
