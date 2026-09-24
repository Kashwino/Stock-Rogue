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
var _items: Array = []            # [text, color, id]
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
		for a: CriminalAsset in assets:
			var ratio := a.current_price / maxf(a.base_price, 0.01) - 1.0
			_items.append(["%s %.2f   %.1f%%" % [Venues.ticker(a.id), a.current_price, absf(ratio) * 100.0], Palette.change(ratio), a.id, signf(ratio)])
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
	queue_redraw()

func _draw() -> void:
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
				draw_string(f, Vector2(x, baseline), item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, item[1])
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
