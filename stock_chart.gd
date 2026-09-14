extends Control
class_name StockChart

## Live stock ticker for the top-right of the HUD. Plots TWO things:
##   - a white line: the run-wide EMPIRE INDEX (what the quota actually checks)
##   - a cyan line: the venue you're currently robbing (this heist's stock)
## A gold horizontal line marks the next quota threshold. When the index is
## under the line the fill runs red; over it, green.
##
## Drop this on a Control node in hud.tscn, top-right, ~260x150.
## It polls RunState every sample_interval seconds — no wiring needed.

const MAX_SAMPLES := 120         # ~30s of history at 0.25s sampling
const PAD_LEFT := 6.0
const PAD_RIGHT := 52.0          # room for the price labels on the right
const PAD_TOP := 20.0            # room for the venue name
const PAD_BOTTOM := 14.0

@export var sample_interval: float = 0.25
@export var venue_id: StringName = &""      # set by HeistFloor; blank = index only

var _index_samples: Array[float] = []
var _venue_samples: Array[float] = []
var _timer: float = 0.0
var _quota: float = 120.0
var _font: Font

func _ready() -> void:
	custom_minimum_size = Vector2(260, 150)
	_font = ThemeDB.fallback_font
	set_process(true)
	# Do NOT sample here — RunState may not be ready yet on some scenes. The
	# first _process tick will sample once the tree is settled.

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = sample_interval
		_sample()
		queue_redraw()

func _sample() -> void:
	# Fully defensive: this can run from a manually-primed instance (the shop
	# attaches this script at runtime) before RunState or its market exist.
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var rs = tree.root.get_node_or_null("RunState")
	if rs == null:
		return
	if not rs.has_method("empire_index"):
		return
	_index_samples.append(rs.empire_index())
	if _index_samples.size() > MAX_SAMPLES:
		_index_samples.pop_front()

	if venue_id != &"" and "market" in rs and rs.market:
		var a = rs.market.get_asset(venue_id)
		if a:
			_venue_samples.append(a.current_price)
			if _venue_samples.size() > MAX_SAMPLES:
				_venue_samples.pop_front()

	if "run_map" in rs and rs.run_map:
		_quota = rs.run_map.current_stock_quota()

## Force an immediate sample + redraw (call after a big stock event).
func refresh() -> void:
	_sample()
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var plot_w := w - PAD_LEFT - PAD_RIGHT
	var plot_h := h - PAD_TOP - PAD_BOTTOM

	# Panel background.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.09, 0.82))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.26, 0.32, 0.9), false, 1.0)

	if _index_samples.is_empty():
		return

	# --- Index axis: fit the index samples AND the quota line ---
	var lo := _quota
	var hi := _quota
	for v in _index_samples:
		lo = minf(lo, v); hi = maxf(hi, v)
	var span := maxf(hi - lo, 10.0)
	lo -= span * 0.15
	hi += span * 0.15
	span = hi - lo

	var to_y := func(value: float) -> float:
		return PAD_TOP + plot_h * (1.0 - (value - lo) / span)

	# --- Venue axis: the raw price lives on its own scale, since a $150 stock
	# and a 100 index can't share one vertical range. Same plot rectangle,
	# independent mapping, so both lines read clearly. ---
	var vlo := INF
	var vhi := -INF
	for v in _venue_samples:
		vlo = minf(vlo, v); vhi = maxf(vhi, v)
	if vlo == INF:
		vlo = 0.0; vhi = 1.0
	var vspan := maxf(vhi - vlo, 0.001)
	vlo -= vspan * 0.15
	vhi += vspan * 0.15
	vspan = vhi - vlo

	var venue_to_y := func(value: float) -> float:
		return PAD_TOP + plot_h * (1.0 - (value - vlo) / vspan)

	var current: float = _index_samples[_index_samples.size() - 1]
	var over := current >= _quota
	var line_col := Color(0.4, 0.95, 0.55) if over else Color(1.0, 0.42, 0.38)

	# --- Filled area under the index line ---
	if _index_samples.size() > 1:
		var poly := PackedVector2Array()
		var step := plot_w / float(maxi(_index_samples.size() - 1, 1))
		for i in _index_samples.size():
			poly.append(Vector2(PAD_LEFT + step * i, to_y.call(_index_samples[i])))
		# Close the shape along the bottom.
		poly.append(Vector2(PAD_LEFT + plot_w, PAD_TOP + plot_h))
		poly.append(Vector2(PAD_LEFT, PAD_TOP + plot_h))
		draw_colored_polygon(poly, Color(line_col.r, line_col.g, line_col.b, 0.14))

	# --- Quota line (gold, dashed) ---
	var qy: float = to_y.call(_quota)
	if qy > PAD_TOP - 4.0 and qy < PAD_TOP + plot_h + 4.0:
		var gold := Color(1.0, 0.82, 0.25)
		var x := PAD_LEFT
		while x < PAD_LEFT + plot_w:
			draw_line(Vector2(x, qy), Vector2(minf(x + 7.0, PAD_LEFT + plot_w), qy),
				gold, 1.6)
			x += 12.0
		draw_string(_font, Vector2(PAD_LEFT + plot_w + 4.0, qy + 4.0),
			"%d" % int(_quota), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gold)

	# --- Venue line (blue, thin) — actual stock value on its own axis ---
	if _venue_samples.size() > 1:
		var vstep := plot_w / float(maxi(_venue_samples.size() - 1, 1))
		var vpts := PackedVector2Array()
		for i in _venue_samples.size():
			vpts.append(Vector2(PAD_LEFT + vstep * i,
				venue_to_y.call(_venue_samples[i])))
		draw_polyline(vpts, Color(0.45, 0.8, 1.0, 0.9), 1.6, true)
		# Current dollar value, right at the tip of the line.
		var vlast: float = _venue_samples[_venue_samples.size() - 1]
		draw_circle(vpts[vpts.size() - 1], 2.5, Color(0.45, 0.8, 1.0))
		draw_string(_font, Vector2(PAD_LEFT + plot_w + 4.0,
			venue_to_y.call(vlast) + 4.0),
			"$%.0f" % vlast, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.45, 0.8, 1.0))

	# --- Index line (thick, red/green) ---
	if _index_samples.size() > 1:
		var step2 := plot_w / float(maxi(_index_samples.size() - 1, 1))
		var pts := PackedVector2Array()
		for i in _index_samples.size():
			pts.append(Vector2(PAD_LEFT + step2 * i, to_y.call(_index_samples[i])))
		draw_polyline(pts, line_col, 2.4, true)
		# Dot on the latest value.
		draw_circle(pts[pts.size() - 1], 3.0, line_col)

	# --- Labels ---
	draw_string(_font, Vector2(PAD_LEFT + 2.0, 13.0), "EMPIRE INDEX",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.62, 0.64, 0.72))
	draw_string(_font, Vector2(PAD_LEFT + plot_w + 4.0, to_y.call(current) + 4.0),
		"%d" % int(current), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, line_col)
	if venue_id != &"":
		draw_string(_font, Vector2(PAD_LEFT + 92.0, 13.0),
			String(venue_id).to_upper().replace("_", " "),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.45, 0.8, 1.0))

	# Gap to quota, bottom-right.
	var gap := current - _quota
	var gap_txt := ("+%d over quota" % int(gap)) if gap >= 0.0 \
		else ("%d to quota" % int(-gap))
	draw_string(_font, Vector2(PAD_LEFT + 2.0, h - 3.0), gap_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.5, 0.9, 0.6) if gap >= 0.0 else Color(1.0, 0.6, 0.4))
