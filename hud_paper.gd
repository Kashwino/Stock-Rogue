extends RefCounted
class_name HudPaper
## The HUD's paper and machines (Brief 3):
##   ObjectiveNote   a torn notepad page, paperclipped, typewritten; a change
##                   strikes the old note in red pencil and slides a fresh one
##                   over it; clocks are written in red and tick
##   BlueprintMap    the minimap on folded blueprint paper: rooms in chalk,
##                   the player, the car and the exits as pencil marks
##   TickerMachine   the venue's chart on ticker tape curling out of a
##                   glass-dome ticker machine: a stamped name, the quota in
##                   red pencil, the index in gold ink
##   Telegram        one trader-feed line as a pasted telegram strip
## Minimal style draws the same information as outlined text without props.


## The objective, typed on a torn notepad page clipped to the corner.
class ObjectiveNote extends HudProps.HudProp:
	const WIDTH := 292.0
	var title := "OBJECTIVE"
	var body := ""
	var _old_title := ""
	var _old_body := ""
	var _strike := 0.0            # 0 -> 1: pencil across the old note
	var _slide := 0.0             # 1 -> 0: the new note sliding in
	var tilt := -0.052            # about -3 degrees

	func set_objective(t: String, b: String) -> void:
		if t == title and b == body:
			return
		var ticking := t == title and _shape(b) == _shape(body)
		if ticking or body == "" or HudKit.reduce_motion():
			title = t
			body = b
			queue_redraw()
			return
		_old_title = title
		_old_body = body
		title = t
		body = b
		_strike = 0.0
		_slide = 1.0
		animate(0.9)
		Audio.play_ui("typewriter")

	## The text with its numbers taken out: a ticking clock is the same note.
	static func _shape(s: String) -> String:
		var re := RegEx.create_from_string("[0-9]")
		return re.sub(s, "", true)

	func _advance(delta: float) -> void:
		if _strike < 1.0:
			_strike = minf(_strike + delta * 3.2, 1.0)
		elif _slide > 0.0:
			_slide = maxf(_slide - delta * 3.4, 0.0)

	func _lines(t: String, b: String) -> Array:
		return HudKit.wrap(VisualTheme.font("type"), b, 16, WIDTH - 44.0)

	func note_height(b: String) -> float:
		return 44.0 + 20.0 * _lines("", b).size() + 10.0

	func _draw() -> void:
		if HudKit.minimal():
			var f := VisualTheme.font("heading_bold")
			HudKit.text(self, f, Vector2(4, 20), title, 16, Palette.GOLD)
			var y := 42.0
			for line in _lines(title, body):
				HudKit.text(self, VisualTheme.font("body"), Vector2(4, y), line, 16, Palette.PAPER)
				y += 20.0
			return
		if _slide > 0.0 and _old_body != "":
			_draw_note(_old_title, _old_body, Vector2.ZERO, _strike, 1.0)
		var offset := Vector2(-WIDTH * 1.1 * _slide * _slide, 6.0 * _slide)
		if _slide < 1.0 or _old_body == "":
			_draw_note(title, body, offset, 0.0, 1.0)
		HudKit.draw_paperclip(self, Vector2(26, -6), 0.15)

	func _draw_note(t: String, b: String, offset: Vector2, strike: float, alpha: float) -> void:
		var h := note_height(b)
		var rect := Rect2(offset, Vector2(WIDTH, h))
		HudKit.draw_paper(self, rect, 17, 1, tilt)
		draw_set_transform(rect.get_center(), tilt, Vector2.ONE)
		var local := Rect2(-rect.size * 0.5, rect.size)
		HudKit.draw_rules(self, Rect2(local.position + Vector2(0, 30), Vector2(local.size.x, local.size.y - 30)), 20.0)
		var head := VisualTheme.font("type_bold")
		var type := VisualTheme.font("type")
		draw_string(head, local.position + Vector2(30, 24), t, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 40, 16, Palette.with_alpha(Palette.HUD_INK, alpha))
		var y := local.position.y + 46.0
		var clock := RegEx.create_from_string("[0-9]+:[0-9][0-9]")
		var i := 0
		for line: String in _lines(t, b):
			var col := Palette.RED_PENCIL if clock.search(line) != null else Palette.HUD_INK
			draw_string(type, Vector2(local.position.x + 30, y), line, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 40, 16, Palette.with_alpha(col, alpha))
			if strike > 0.0:
				var w := HudKit.text_width(type, line, 16)
				HudKit.draw_strike(self, Vector2(local.position.x + 26, y - 5), Vector2(local.position.x + 34 + w, y - 7), clampf(strike * 2.0 - i * 0.3, 0.0, 1.0))
			y += 20.0
			i += 1
		draw_set_transform_matrix(Transform2D.IDENTITY)


## The minimap, on a folded blueprint held by a pushpin: discovered rooms in
## chalk lines, the boss room hatched in red pencil, treasure in gold, exits
## and the car as pencil marks, the player as a circled X.
class BlueprintMap extends HudProps.HudProp:
	var floor_host: Node
	var bounds := Rect2()
	var _clock := 0.0

	func _ready() -> void:
		super._ready()
		set_process(true)

	func _process(delta: float) -> void:
		_clock -= delta
		if _clock <= 0.0:
			_clock = 0.2
			queue_redraw()

	func _draw() -> void:
		var inner := Rect2(Vector2(10, 12), size - Vector2(20, 22))
		if HudKit.minimal():
			draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.02, 0.02, 0.03, 0.55))
		else:
			inner = HudKit.draw_blueprint(self, Rect2(Vector2(4, 4), size - Vector2(8, 8)), 23, 0.02).grow(-4.0)
		if floor_host == null or not is_instance_valid(floor_host) or floor_host.generator == null:
			return
		var tmap: HeistMap = floor_host.tactical_map
		if bounds.size == Vector2.ZERO:
			for room in floor_host.generator.rooms:
				var rr := Rect2(room.global_position, room.room_size)
				bounds = rr if bounds.size == Vector2.ZERO else bounds.merge(rr)
			if floor_host.car:
				bounds = bounds.merge(Rect2(floor_host.car.global_position - Vector2(80, 80), Vector2(160, 160)))
		var k := minf(inner.size.x / bounds.size.x, inner.size.y / bounds.size.y)
		var origin := inner.position + (inner.size - bounds.size * k) * 0.5
		var reveal: bool = tmap != null and tmap.full_reveal
		var chalk := Palette.with_alpha(Color("eef4fb"), 0.9)
		for room in floor_host.generator.rooms:
			if not reveal and (tmap == null or not tmap.discovered.has(room.get_instance_id())):
				continue
			var r := Rect2(origin + (room.global_position - bounds.position) * k, room.room_size * k).grow(-1.5)
			if room.has_meta("is_boss"):
				var y := r.position.y + 3.0
				while y < r.end.y:
					draw_line(Vector2(r.position.x + 1, y), Vector2(minf(r.end.x - 1, r.position.x + 1 + (r.end.y - y)), minf(r.end.y, y + (r.end.x - r.position.x))), Palette.with_alpha(Palette.RED_PENCIL.lightened(0.2), 0.7), 1.0)
					y += 5.0
			elif room.has_meta("chest_kind"):
				draw_rect(r, Palette.with_alpha(Palette.GOLD, 0.25))
			var seed_value: int = room.get_instance_id() % 97
			var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
			for i in pts.size():
				pts[i] += Vector2(HudKit.noise(seed_value, i) - 0.5, HudKit.noise(seed_value, i + 9) - 0.5) * 1.4
			draw_polyline(pts, chalk, 1.4, true)
		var gen = floor_host.generator
		for gap: Dictionary in [gen.entrance] + gen.exits:
			if gap.is_empty():
				continue
			var at: Vector2 = origin + (gap["inside_pos"] - bounds.position) * k
			var col := Palette.GOLD if gap == gen.entrance else (Palette.NEON_GREEN if gap.get("open", false) else Palette.RED_PENCIL.lightened(0.3))
			draw_line(at + Vector2(-3, -3), at + Vector2(3, 3), col, 2.0)
			draw_line(at + Vector2(-3, 3), at + Vector2(3, -3), col, 2.0)
		if floor_host.car:
			var cp: Vector2 = origin + (floor_host.car.global_position - bounds.position) * k
			draw_rect(Rect2(cp - Vector2(6, 3.5), Vector2(12, 7)), Palette.GOLD, false, 1.6)
		if floor_host.has_method("objective_points"):
			for at: Vector2 in floor_host.objective_points():
				var op: Vector2 = origin + (at - bounds.position) * k
				draw_arc(op, 6.0, 0, TAU, 14, Palette.RED_PENCIL.lightened(0.25), 2.0, true)
		if is_instance_valid(floor_host.player):
			var pp: Vector2 = origin + (floor_host.player.global_position - bounds.position) * k
			draw_circle(pp, 6.5, Palette.with_alpha(Palette.HUD_INK, 0.5))
			draw_arc(pp, 6.5, 0, TAU, 14, Color.WHITE, 1.6, true)
			draw_line(pp + Vector2(-3, -3), pp + Vector2(3, 3), Palette.GOLD, 2.0)
			draw_line(pp + Vector2(-3, 3), pp + Vector2(3, -3), Palette.GOLD, 2.0)


## The venue's price on ticker tape. The machine (a glass dome on a brass
## base) sits on the left; the tape curls out over graph paper carrying the
## chart. The venue's name is a rubber stamp, the quota a red pencil line
## with the gap scribbled next to it, the Board index in gold ink.
class TickerMachine extends HudProps.HudProp:
	var venue_id: StringName = &""
	var chart: TapeChart
	var price := 0.0
	var change := 0.0
	var _flash := 0.0
	var _flash_up := true

	func _ready() -> void:
		super._ready()
		chart = TapeChart.new()
		chart.position = Vector2(64, 44)
		chart.size = Vector2(size.x - 70, size.y - 52)
		add_child(chart)

	func set_venue(id: StringName) -> void:
		venue_id = id
		chart.venue_id = id
		chart.refresh()
		queue_redraw()

	func set_price(p: float, ratio: float, up: bool) -> void:
		price = p
		change = ratio
		_flash = 1.0
		_flash_up = up
		animate(0.45)

	func _advance(delta: float) -> void:
		_flash = maxf(_flash - delta * 2.4, 0.0)

	func _draw() -> void:
		var mono := VisualTheme.font("mono")
		var type := VisualTheme.font("type_bold")
		var col := Palette.change(change)
		if HudKit.minimal():
			HudKit.text(self, VisualTheme.font("heading_bold"), Vector2(4, 16), Venues.display_name(venue_id).to_upper(), 14, Palette.GOLD, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8)
			HudKit.text(self, mono, Vector2(4, 38), "$%.2f  %+.1f%%" % [price, change * 100.0], 18, col)
			return
		# The tape: a cream strip curling out of the machine, down and right.
		var tape := Rect2(Vector2(58, 38), Vector2(size.x - 60, size.y - 42))
		var curl := PackedVector2Array([Vector2(40, 60), Vector2(58, 40), tape.position, Vector2(tape.end.x, tape.position.y),
			Vector2(tape.end.x - 4, tape.end.y - 8), Vector2(tape.end.x - 16, tape.end.y), Vector2(tape.position.x, tape.end.y), Vector2(52, 90)])
		HudKit.paper_poly(self, curl, Palette.PAPER_CREAM, Palette.PAPER_EDGE)
		# Graph paper grid on the tape.
		var gx := tape.position.x + 6.0
		while gx < tape.end.x - 6.0:
			draw_line(Vector2(gx, tape.position.y + 3), Vector2(gx, tape.end.y - 3), Color(0.35, 0.55, 0.45, 0.16), 1.0)
			gx += 10.0
		var gy := tape.position.y + 6.0
		while gy < tape.end.y - 3.0:
			draw_line(Vector2(tape.position.x + 3, gy), Vector2(tape.end.x - 6, gy), Color(0.35, 0.55, 0.45, 0.16), 1.0)
			gy += 10.0
		# The machine: brass base, glass dome, the type wheel.
		draw_rect(Rect2(6, 74, 52, 14), Palette.BRASS.darkened(0.2))
		draw_rect(Rect2(10, 70, 44, 6), Palette.BRASS)
		draw_colored_polygon(HudKit.ellipse(Vector2(32, 52), 22, 22), Color(0.75, 0.85, 0.95, 0.18))
		draw_arc(Vector2(32, 52), 22, PI, TAU, 18, Color(1, 1, 1, 0.55), 1.6, true)
		draw_line(Vector2(10, 52), Vector2(10, 70), Color(1, 1, 1, 0.4), 1.4)
		draw_line(Vector2(54, 52), Vector2(54, 70), Color(1, 1, 1, 0.4), 1.4)
		draw_arc(Vector2(24, 44), 12, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.7), 2.0, true)
		draw_circle(Vector2(32, 60), 7, Palette.HUD_INK)
		draw_circle(Vector2(32, 60), 4, Palette.BRASS)
		# The venue's name, stamped; the price typed beside the machine.
		HudKit.draw_stamp(self, Vector2(118, 14), Venues.ticker(venue_id), Palette.RED_PENCIL.lightened(0.15), -0.08, 15)
		var flash := Palette.with_alpha(Palette.UP if _flash_up else Palette.DOWN, _flash)
		HudKit.text(self, mono, Vector2(158, 21), "$%.2f" % price, 17, Palette.PAPER.lerp(flash, _flash * 0.8) if _flash > 0.0 else Palette.PAPER)
		HudKit.text(self, mono, Vector2(158, 36), "%+.1f%%" % (change * 100.0), 13, col)


## The StockChart, drawn on the ticker tape: index in gold ink, the venue in
## blue ink, the quota as a red pencil line with the gap scribbled beside it.
class TapeChart extends StockChart:
	func _draw() -> void:
		if _index_samples.is_empty():
			return
		var w := size.x
		var h := size.y
		var plot := Rect2(Vector2(4, 8), Vector2(w - 12, h - 26))
		var lo := _quota
		var hi := _quota
		for v in _index_samples:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var span := maxf(hi - lo, 10.0)
		lo -= span * 0.15
		hi += span * 0.15
		span = hi - lo
		var vlo := INF
		var vhi := -INF
		for v in _venue_samples:
			vlo = minf(vlo, v)
			vhi = maxf(vhi, v)
		if vlo == INF:
			vlo = 0.0
			vhi = 1.0
		var vspan := maxf(vhi - vlo, 0.001)
		vlo -= vspan * 0.15
		vspan *= 1.3
		var type := VisualTheme.font("type_bold")
		# Quota: red pencil, dashed, with the gap scribbled on.
		var qy := plot.position.y + plot.size.y * (1.0 - (_quota - lo) / span)
		var x := plot.position.x
		while x < plot.end.x:
			draw_line(Vector2(x, qy), Vector2(minf(x + 6.0, plot.end.x), qy + 0.6), Palette.RED_PENCIL, 1.6)
			x += 10.0
		if _venue_samples.size() > 1:
			var vstep := plot.size.x / float(maxi(_venue_samples.size() - 1, 1))
			var vpts := PackedVector2Array()
			for i in _venue_samples.size():
				vpts.append(Vector2(plot.position.x + vstep * i, plot.position.y + plot.size.y * (1.0 - (_venue_samples[i] - vlo) / vspan)))
			draw_polyline(vpts, Color("2f5d9e"), 1.4, true)
		var current: float = _index_samples[_index_samples.size() - 1]
		if _index_samples.size() > 1:
			var step := plot.size.x / float(maxi(_index_samples.size() - 1, 1))
			var pts := PackedVector2Array()
			for i in _index_samples.size():
				pts.append(Vector2(plot.position.x + step * i, plot.position.y + plot.size.y * (1.0 - (_index_samples[i] - lo) / span)))
			draw_polyline(pts, Palette.GOLD.darkened(0.25), 3.0, true)
			draw_polyline(pts, Palette.GOLD, 1.6, true)
			draw_circle(pts[pts.size() - 1], 2.6, Palette.GOLD.darkened(0.2))
		var gap := current - _quota
		var note := ("+%d over quota" % roundi(gap)) if gap >= 0.0 else ("%d to quota" % roundi(-gap))
		draw_string(type, Vector2(plot.position.x + 2, h - 5), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.STAMP_GREEN if gap >= 0.0 else Palette.RED_PENCIL)
		draw_string(type, Vector2(plot.end.x - 36, h - 5), "%d" % roundi(current), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.GOLD.darkened(0.35))


## One trader-feed line as a telegram strip pasted at a slight angle.
class Telegram extends Control:
	var handle := ""
	var message := ""
	var ink := Palette.HUD_INK
	var tilt := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tilt = randf_range(-0.035, 0.035)

	func _draw() -> void:
		var type := VisualTheme.font("type_bold")
		var line := "%s: %s" % [handle, message.to_upper()]
		if HudKit.minimal():
			HudKit.text(self, VisualTheme.font("body"), Vector2(2, size.y - 5), line, 14, ink, HORIZONTAL_ALIGNMENT_LEFT, size.x)
			return
		var rect := Rect2(Vector2(0, 1), size - Vector2(0, 2))
		HudKit.draw_paper(self, rect, hash(line) % 1000, 10, tilt, Palette.PAPER_CREAM.darkened(0.03), Palette.PAPER_EDGE, true)
		draw_set_transform(rect.get_center(), tilt, Vector2.ONE)
		var col := ink
		if ink == Palette.UP:
			col = Palette.STAMP_GREEN
		elif ink == Palette.DOWN:
			col = Palette.RED_PENCIL
		elif ink == Palette.GOLD:
			col = Palette.GOLD.darkened(0.45)
		else:
			col = Palette.HUD_INK
		draw_string(type, Vector2(-rect.size.x * 0.5 + 6, 5), line, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12, 12, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)
