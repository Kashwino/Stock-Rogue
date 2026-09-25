extends Control
class_name TickerTape
## A crawling stock ticker: every venue on the Board with price, arrow and
## change since its listing price, coloured up/down. The venue being robbed is
## boxed in gold. flash() lights the tape when the player moves the market.
## Reused by the HUD, the main menu, the hideout TV and the case wall.

@export var speed := 70.0
@export var font_size := 17
@export var highlight: StringName = &""
@export var show_background := true
## Brief 3 (the heist HUD): a cream paper strip with perforations along both
## edges, black typewriter type and red / green arrows; a symbol whose price
## jumps flashes for a moment.
@export var paper := false
var _items: Array = []            # [text, color, id]
var _last_ratio: Dictionary = {}  # id -> ratio at the previous rebuild
var _jumps: Dictionary = {}       # id -> seconds of flash left
var _offset := 0.0
var _refresh := 0.0
var _flash := 0.0
var _width := 1.0
var _demo_rng := RandomNumberGenerator.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_demo_rng.seed = 7
	_rebuild()

func flash(color: Color = Palette.GOLD) -> void:
	_flash = 1.0
	modulate = Color(1, 1, 1)
	set_meta("flash_color", color)

func _rebuild() -> void:
	_items.clear()
	var f := VisualTheme.font("mono")
	var assets: Array = RunState.market.assets if RunState.market else []
	if assets.is_empty():
		# Menus with no run: a believable fake tape.
		for id: StringName in Venues.DATA:
			var d := _demo_rng.randf_range(-0.12, 0.18)
			_items.append(["%s %.2f   %.1f%%" % [Venues.ticker(id), _demo_rng.randf_range(4, 200), absf(d) * 100.0], Palette.change(d), id, signf(d)])
	else:
		var held := Positions.sides()
		for a: CriminalAsset in assets:
			var ratio := a.current_price / maxf(a.base_price, 0.01) - 1.0
			if _last_ratio.has(a.id) and absf(ratio - float(_last_ratio[a.id])) > 0.004:
				_jumps[a.id] = 0.9
			_last_ratio[a.id] = ratio
			var side: String = held.get(a.id, "")
			var tag := "" if side == "" else ("L " if side == "long" else "S ")
			_items.append([tag + "%s %.2f   %.1f%%" % [Venues.ticker(a.id), a.current_price, absf(ratio) * 100.0], Palette.change(ratio), a.id, signf(ratio), side])
		if RunState.market:
			var idx := RunState.empire_index()
			_items.push_front(["BOARD INDEX %d" % roundi(idx), Palette.GOLD, &"__index", 0.0])
	_width = 0.0
	for item: Array in _items:
		_width += f.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 46.0
	_width = maxf(_width, 1.0)

func _process(delta: float) -> void:
	_offset = fmod(_offset + delta * speed, _width)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.5
		_rebuild()
	if _flash > 0.0:
		_flash = maxf(_flash - delta * 2.5, 0.0)
	for id in _jumps.keys():
		_jumps[id] = float(_jumps[id]) - delta
		if _jumps[id] <= 0.0:
			_jumps.erase(id)
	queue_redraw()

func _draw() -> void:
	if paper and not HudKit.minimal():
		_draw_paper()
		return
	if show_background:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03, 0.88))
		draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Palette.GOLD_DIM, 1.0)
	if _flash > 0.0:
		var fc: Color = get_meta("flash_color", Palette.GOLD)
		draw_rect(Rect2(Vector2.ZERO, size), Palette.with_alpha(fc, 0.22 * _flash))
	var f := VisualTheme.font("mono")
	var baseline := size.y * 0.5 + font_size * 0.35
	var x := -_offset
	while x < size.x:
		for item: Array in _items:
			var w := f.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if x + w > -20.0 and x < size.x + 20.0:
				if item[2] == highlight and highlight != &"":
					draw_rect(Rect2(x - 6, 3, w + 12, size.y - 6), Palette.with_alpha(Palette.GOLD, 0.16 + 0.3 * _flash))
					draw_rect(Rect2(x - 6, 3, w + 12, size.y - 6), Palette.GOLD, false, 1.0)
				var side: String = item[4] if item.size() > 4 else ""
				if side != "":
					# Open Fence position: a green L / red S chip on the venue.
					var cw := f.get_string_size("L", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 6.0
					draw_rect(Rect2(x - 3, 4, cw, size.y - 8), Palette.UP if side == "long" else Palette.DOWN)
				draw_string(f, Vector2(x, baseline), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, item[1])
				if side != "":
					draw_string(f, Vector2(x, baseline), "L" if side == "long" else "S", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.INK)
				var dir: float = item[3]
				if dir != 0.0:
					# Arrow drawn as a shape: no glyph-coverage surprises on the Web.
					var num_w := f.get_string_size(String(item[0]).get_slice("   ", 0) + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
					var ax := x + num_w + font_size * 0.45
					var ay := size.y * 0.5
					var h := font_size * 0.32
					var tri := PackedVector2Array([Vector2(ax - h, ay + h * dir), Vector2(ax + h, ay + h * dir), Vector2(ax, ay - h * dir)])
					draw_colored_polygon(tri, item[1])
				draw_circle(Vector2(x + w + 22, size.y * 0.5), 2.0, Palette.GOLD_DIM)
			x += w + 46.0
		if _items.is_empty():
			break

## The perforated paper strip (the heist HUD). The one straight, sharp
## element across the top of the screen.
func _draw_paper() -> void:
	draw_rect(Rect2(Vector2(0, size.y), Vector2(size.x, 4)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(Vector2.ZERO, size), Palette.PAPER_CREAM)
	draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Palette.PAPER_EDGE, 1.0)
	if _flash > 0.0:
		var fc: Color = get_meta("flash_color", Palette.GOLD)
		draw_rect(Rect2(Vector2.ZERO, size), Palette.with_alpha(fc, 0.25 * _flash))
	# Perforations along both edges scroll with the tape.
	var hole := fmod(_offset, 14.0)
	var hx := -hole
	while hx < size.x + 14.0:
		draw_circle(Vector2(hx, 3.5), 1.8, Color(0.05, 0.05, 0.06, 0.85))
		draw_circle(Vector2(hx, size.y - 3.5), 1.8, Color(0.05, 0.05, 0.06, 0.85))
		hx += 14.0
	var f := VisualTheme.font("type_bold")
	var fs := font_size - 1
	var baseline := size.y * 0.5 + fs * 0.34
	var x := -_offset
	while x < size.x:
		for item: Array in _items:
			var w := f.get_string_size(item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if x + w > -20.0 and x < size.x + 20.0:
				var dir: float = item[3]
				var ink := Palette.HUD_INK
				var arrow := Palette.STAMP_GREEN if dir > 0.0 else Palette.RED_PENCIL
				if item[2] == &"__index":
					ink = Palette.GOLD.darkened(0.45)
				if _jumps.has(item[2]):
					var k := clampf(float(_jumps[item[2]]) / 0.9, 0.0, 1.0)
					draw_colored_polygon(HudKit.impact(Vector2(x + w * 0.5, size.y * 0.5), w * 0.6 + 6.0, w * 0.4, 4, 10), Palette.with_alpha(Palette.GOLD, 0.55 * k))
				if item[2] == highlight and highlight != &"":
					# The venue being robbed: circled in red pencil.
					draw_arc(Vector2(x + w * 0.5, size.y * 0.5), w * 0.5 + 8.0, 0.0, TAU, 32, Palette.RED_PENCIL, 1.6, true)
				var side: String = item[4] if item.size() > 4 else ""
				if side != "":
					var cw := f.get_string_size("L", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
					draw_rect(Rect2(x - 3, 7, cw, size.y - 14), Palette.STAMP_GREEN if side == "long" else Palette.RED_PENCIL)
				draw_string(f, Vector2(x, baseline), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
				if side != "":
					draw_string(f, Vector2(x, baseline), "L" if side == "long" else "S", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.PAPER_CREAM)
				if dir != 0.0:
					var num_w := f.get_string_size(String(item[0]).get_slice("   ", 0) + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
					var ax := x + num_w + fs * 0.45
					var ay := size.y * 0.5
					var h := fs * 0.32
					draw_colored_polygon(PackedVector2Array([Vector2(ax - h, ay + h * dir), Vector2(ax + h, ay + h * dir), Vector2(ax, ay - h * dir)]), arrow)
				draw_circle(Vector2(x + w + 22, size.y * 0.5), 2.0, Palette.PAPER_EDGE.darkened(0.3))
			x += w + 46.0
		if _items.is_empty():
			break
