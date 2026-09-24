extends Node2D
class_name HideoutArt
## The hideout's look: a lived-in backroom under warm lamps. Plank floor, a
## rug with a card table, stacked cash, a TV running the Board's ticker, and a
## neon sign over each vendor's corner. Drawn once; the TV ticker animates.

const SIZE := Vector2(1120, 640)

func _ready() -> void:
	z_index = -10
	queue_redraw()

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# Plank floor.
	var plank := 38.0
	for y in range(0, int(SIZE.y), int(plank)):
		var offset := rng.randf_range(0, 160)
		var x := -offset
		while x < SIZE.x:
			var w := rng.randf_range(140, 260)
			var tone := Color("3a2a1e").lerp(Color("2e2118"), rng.randf())
			draw_rect(Rect2(maxf(x, 0), y, minf(w, SIZE.x - maxf(x, 0)), plank - 2), tone)
			draw_line(Vector2(x + w, y), Vector2(x + w, y + plank - 2), Color("1c140e"), 2.0)
			x += w
	# Rug under the card table.
	var rug := Rect2(SIZE * 0.5 - Vector2(230, 120) + Vector2(0, 30), Vector2(460, 240))
	draw_rect(Rect2(rug.position + Vector2(5, 7), rug.size), Color(0, 0, 0, 0.3))
	draw_rect(rug, Color("5a1a1e"))
	draw_rect(rug.grow(-10), Palette.GOLD_DIM, false, 3.0)
	draw_rect(rug.grow(-20), Color("7a2a2a"), false, 2.0)
	for i in 6:
		var p := rug.get_center() + Vector2(-150 + i * 60, 0)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -18), p + Vector2(14, 0), p + Vector2(0, 18), p + Vector2(-14, 0)]), Palette.with_alpha(Palette.GOLD, 0.2))
	# Card table with chips, cards and an ashtray.
	var table_c := rug.get_center()
	draw_circle(table_c + Vector2(6, 8), 78, Color(0, 0, 0, 0.35))
	draw_circle(table_c, 76, Color("3a2412"))
	draw_circle(table_c, 68, Color("1f5a38"))
	for i in 9:
		var p := table_c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 50)
		draw_circle(p, 6, [Color("d03a3a"), Color("2a5ad0"), Color("f0f0f0"), Palette.GOLD][rng.randi() % 4])
		draw_circle(p, 3, Color(1, 1, 1, 0.25))
	for i in 4:
		var card := Rect2(table_c + Vector2(-30 + i * 14, -6 + (i % 2) * 5), Vector2(16, 22))
		draw_rect(card, Color("f4f0e6"))
		draw_rect(card, Color("888888"), false, 1.0)
	draw_circle(table_c + Vector2(44, 34), 9, Color("555a60"))
	draw_circle(table_c + Vector2(44, 34), 5, Color("222222"))
	for a in [0.0, 1.57, 3.14, 4.71]:
		draw_circle(table_c + Vector2.from_angle(a) * 96, 16, Color("1a1a1f"))
	# Stacked cash on a crate by the wall.
	var crate := Rect2(Vector2(SIZE.x - 250, SIZE.y - 150), Vector2(110, 80))
	draw_rect(Rect2(crate.position + Vector2(5, 7), crate.size), Color(0, 0, 0, 0.35))
	draw_rect(crate, Color("6a4a2a"))
	draw_rect(crate, Color("2a1a0a"), false, 2.0)
	for i in 3:
		for j in 2:
			var stack := Rect2(crate.position + Vector2(8 + i * 33, 8 + j * 34), Vector2(28, 26))
			draw_rect(stack, Color("4a7a4a"))
			draw_rect(Rect2(stack.position + Vector2(0, 10), Vector2(stack.size.x, 5)), Color("e8e0c0"))
	# Walls: dark plaster with a wainscot line.
	draw_rect(Rect2(Vector2(-24, -60), Vector2(SIZE.x + 48, 84)), Color("1d1a1c"))
	draw_rect(Rect2(Vector2(-24, 10), Vector2(SIZE.x + 48, 14)), Color("2c2224"))
	draw_line(Vector2(0, 24), Vector2(SIZE.x, 24), Color("0c0a0b"), 3.0)
	# Vendor corners: the dealer's gun rack, the Fence's desk, the market crates.
	_gun_rack(Vector2(150, 40))
	_fence_desk(Vector2(SIZE.x * 0.5, 120))
	_market_crates(Vector2(SIZE.x - 190, 150))
	# Old poster and a calendar.
	draw_rect(Rect2(Vector2(360, -46), Vector2(70, 50)), Color("c8b890"))
	draw_rect(Rect2(Vector2(366, -40), Vector2(58, 26)), Color("8a2a2a"))
	draw_rect(Rect2(Vector2(740, -46), Vector2(60, 50)), Color("d8d0c0"))
	for i in 4:
		draw_line(Vector2(746, -30 + i * 9), Vector2(794, -30 + i * 9), Color(0, 0, 0, 0.3), 1.0)

func _gun_rack(at: Vector2) -> void:
	var board := Rect2(at - Vector2(110, 60), Vector2(220, 40))
	draw_rect(board, Color("2a2a30"))
	for i in 5:
		var y := board.position.y + 8 + i * 6
		draw_line(Vector2(board.position.x + 12, y), Vector2(board.end.x - 12 - i * 10, y), Color("8a9098"), 3.0)
	var counter := Rect2(at + Vector2(-110, 10), Vector2(220, 46))
	draw_rect(Rect2(counter.position + Vector2(5, 7), counter.size), Color(0, 0, 0, 0.35))
	draw_rect(counter, Color("4a3222"))
	draw_rect(Rect2(counter.position, Vector2(counter.size.x, 6)), Color("6a4a32"))
	draw_rect(Rect2(counter.position + Vector2(20, 14), Vector2(70, 14)), Color("2a2c30"))
	draw_rect(Rect2(counter.position + Vector2(120, 16), Vector2(80, 10)), Color("2a2c30"))

func _fence_desk(at: Vector2) -> void:
	var desk := Rect2(at - Vector2(120, 20), Vector2(240, 54))
	draw_rect(Rect2(desk.position + Vector2(5, 7), desk.size), Color(0, 0, 0, 0.35))
	draw_rect(desk, Color("5a3a22"))
	draw_rect(desk.grow(-5), Color("6a4628"))
	draw_rect(Rect2(desk.position + Vector2(20, 10), Vector2(56, 34)), Color("e8dfc4"))
	draw_line(desk.position + Vector2(24, 20), desk.position + Vector2(70, 20), Color("555555"), 1.0)
	draw_line(desk.position + Vector2(24, 28), desk.position + Vector2(66, 28), Color("555555"), 1.0)
	draw_circle(desk.position + Vector2(190, 26), 12, Color("2a2a2a"))
	draw_circle(desk.position + Vector2(190, 26), 6, Palette.GOLD)

func _market_crates(at: Vector2) -> void:
	for i in 3:
		var r := Rect2(at + Vector2(-90 + i * 62, -30 + (i % 2) * 12), Vector2(56, 56))
		draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("3a2f40"))
		draw_line(r.position + Vector2(4, 4), r.end - Vector2(4, 4), Color("241c2a"), 4.0)
		draw_rect(r, Color("140e18"), false, 2.0)


## A neon sign on the back wall.
class Neon extends Node2D:
	var text := "OPEN"
	var color := Palette.NEON_CYAN
	func _ready() -> void:
		z_index = 5
		var label := Label.new()
		label.text = text
		var ls := LabelSettings.new()
		ls.font = VisualTheme.font("heading_bold")
		ls.font_size = 30
		ls.font_color = color.lightened(0.55)
		ls.outline_size = 9
		ls.outline_color = Palette.with_alpha(color, 0.9)
		ls.shadow_size = 16
		ls.shadow_color = Palette.with_alpha(color, 0.45)
		ls.shadow_offset = Vector2.ZERO
		label.label_settings = ls
		label.material = StreetArt._unshaded()
		var w := ls.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 30
		label.size = Vector2(w, 48)
		label.position = Vector2(-w * 0.5, -24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		if not Settings.values.get("reduce_flashing", false):
			var tw := label.create_tween().set_loops()
			tw.tween_interval(randf_range(2.0, 5.0))
			tw.tween_property(label, "modulate:a", 0.4, 0.05)
			tw.tween_property(label, "modulate:a", 1.0, 0.07)


## A TV on the wall showing the live ticker.
class TV extends Node2D:
	func _ready() -> void:
		z_index = 4
		var frame := Panel.new()
		frame.position = Vector2(-120, -44)
		frame.size = Vector2(240, 88)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", VisualTheme.box(Color("08090c"), Color("2a2a30"), 6, 6, 0))
		frame.material = StreetArt._unshaded()
		add_child(frame)
		var title := VisualTheme.label("THE BOARD — LIVE", "", 14, Palette.GOLD)
		title.add_theme_font_override("font", VisualTheme.font("mono"))
		title.position = Vector2(-104, -36)
		title.material = StreetArt._unshaded()
		add_child(title)
		var tape := TickerTape.new()
		tape.position = Vector2(-108, -12)
		tape.size = Vector2(216, 44)
		tape.font_size = 18
		tape.speed = 45.0
		tape.material = StreetArt._unshaded()
		add_child(tape)


## A vendor behind their counter: drawn character, idle sway, speech bubble.
class Vendor extends Node2D:
	var spec: Dictionary = {}
	var lines: Array = []
	var bubble: Label
	var _t := 0.0
	var _line_clock := 0.0
	var kit: SpriteKit
	var talking := false

	func _ready() -> void:
		z_index = 3
		var holder := Node2D.new()
		holder.rotation = PI * 0.5
		add_child(holder)
		kit = SpriteKit.new()
		kit.apply(spec)
		holder.add_child(kit)
		bubble = Label.new()
		bubble.add_theme_font_override("font", VisualTheme.font("type"))
		bubble.add_theme_font_size_override("font_size", 17)
		bubble.add_theme_color_override("font_color", Palette.INK)
		bubble.add_theme_stylebox_override("normal", VisualTheme.box(Palette.PAPER, Palette.INK, 2, 6, 8))
		bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bubble.custom_minimum_size = Vector2(250, 0)
		bubble.size = Vector2(250, 0)
		bubble.position = Vector2(-125, -120)
		bubble.material = StreetArt._unshaded()
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.modulate.a = 0.0
		add_child(bubble)

	func say(text: String) -> void:
		bubble.text = text
		bubble.reset_size()
		bubble.position = Vector2(-125, -60 - bubble.size.y)
		var tw := create_tween()
		tw.tween_property(bubble, "modulate:a", 1.0, 0.2)

	func hush() -> void:
		var tw := create_tween()
		tw.tween_property(bubble, "modulate:a", 0.0, 0.3)

	func _process(delta: float) -> void:
		_t += delta
		rotation = sin(_t * 0.9) * 0.05
		if talking:
			_line_clock -= delta
			if _line_clock <= 0.0 and not lines.is_empty():
				_line_clock = 5.5
				say(lines[randi() % lines.size()])
