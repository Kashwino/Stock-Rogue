extends RefCounted
class_name HudPulp
## The HUD's pulp elements (Brief 3): skewed slabs, halftone, heavy italic.
##   HeatBar      top-centre slanted heat bar with a hatched fill, five police
##                badge stars above it, a green EXIT sign where the fire exits
##                seal, red notches for the police, the heat log as captions
##   ComboSlab    THE RALLY: a big italic count on a skewed slab with a
##                halftone burst, the tier on a slanted banner, the window as
##                a draining skewed bar; tier-ups slam in with speed lines, a
##                PANIC SELL tears the slab apart
##   Banner       DOUBLE / TRIPLE / MASSACRE on a skewed banner (MASSACRE
##                gets an impact star), "3 DOWN" typed underneath
##   Caption      the combo's cash-out / panic-sell line on a slant
## Pulp elements are skewed, never tilted. Reduce flashing turns slams and
## flashes into plain fades; Minimal style keeps only outlined type.


class HeatBar extends HudProps.HudProp:
	const MAX_HEAT := 40.0
	var heat := 0.0
	var dispatch := 16.0
	var fire_limit := 12.0
	var timer := 0.0
	var stars := 0
	var log_lines: Array = []       # [text, age]
	var _star_flash := 0.0

	func set_values(h: float, d: float, f: float, t: float) -> void:
		var changed := absf(h - heat) > 0.05 or d != dispatch or f != fire_limit or ceili(t) != ceili(timer)
		heat = h
		dispatch = d
		fire_limit = f
		timer = t
		_update_idle()
		if changed:
			queue_redraw()

	func set_stars(n: int) -> void:
		if n > stars:
			_star_flash = 1.0
			animate(0.8)
		stars = n
		_update_idle()
		queue_redraw()

	## The police lights keep the bar redrawing while a response is rolling
	## (or at five stars) — unless Reduce flashing holds them steady.
	func _update_idle() -> void:
		_idle = not HudKit.calm() and (heat >= dispatch or stars >= 5)
		if _idle:
			set_process(true)

	func push_source(text: String) -> void:
		log_lines.push_front([text, 0.0])
		while log_lines.size() > 3:
			log_lines.pop_back()
		animate(8.0)

	func _advance(delta: float) -> void:
		_star_flash = maxf(0.0, _star_flash - delta * 1.5)
		for line: Array in log_lines:
			line[1] += delta
		while not log_lines.is_empty() and log_lines.back()[1] > 7.0:
			log_lines.pop_back()

	func _draw() -> void:
		var pulp := VisualTheme.font("pulp")
		var type := VisualTheme.font("type_bold")
		var hot := heat >= dispatch
		var bar := Rect2(Vector2(66, 34), Vector2(size.x - 170, 22))
		var fill := clampf(heat / MAX_HEAT, 0.0, 1.0)
		var col := Palette.GOLD.lerp(Palette.DANGER, clampf(heat / dispatch, 0.0, 1.0))
		if hot and not HudKit.calm():
			col = Palette.POLICE_RED if fmod(_t, 0.5) < 0.25 else Palette.POLICE_BLUE
		HudKit.text(self, pulp, Vector2(4, 54), "HEAT", 24, Palette.DANGER if hot else Palette.PAPER_CREAM)
		if HudKit.minimal():
			draw_line(Vector2(bar.position.x, bar.end.y - 6), Vector2(bar.end.x, bar.end.y - 6), Color(0, 0, 0, 0.6), 7.0)
			draw_line(Vector2(bar.position.x, bar.end.y - 6), Vector2(bar.position.x + bar.size.x * fill, bar.end.y - 6), col, 5.0)
		else:
			HudKit.draw_slant_panel(self, bar, Color(0.05, 0.05, 0.06, 0.85))
			if fill > 0.0:
				var filled := Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)).grow(-3.0)
				var pts := HudKit.slant(filled)
				draw_colored_polygon(pts, col)
				# Hatching over the fill, like a pulp print.
				var x := filled.position.x - filled.size.y
				while x < filled.end.x:
					var a := Vector2(maxf(x, filled.position.x), filled.end.y)
					var b := Vector2(minf(x + filled.size.y, filled.end.x - HudKit.SKEW * filled.size.y), filled.position.y)
					if b.x > a.x:
						draw_line(a, b, Color(0, 0, 0, 0.28), 2.0)
					x += 8.0
			draw_polyline(HudKit.closed(HudKit.slant(bar)), Palette.HUD_INK, 2.0, true)
		# The police line: red notches cut into the bar, labelled above it.
		var px := bar.position.x + bar.size.x * clampf(dispatch / MAX_HEAT, 0.0, 1.0)
		for dy: float in [0.0, bar.size.y]:
			var base_x := px - (bar.size.y - dy) * HudKit.SKEW
			var tri := PackedVector2Array([Vector2(base_x - 5, bar.position.y + dy + (-7 if dy == 0.0 else 7)), Vector2(base_x + 5, bar.position.y + dy + (-7 if dy == 0.0 else 7)), Vector2(base_x, bar.position.y + dy)])
			draw_colored_polygon(tri, Palette.POLICE_RED)
		HudKit.text(self, type, Vector2(px - bar.size.y * HudKit.SKEW - 22, bar.position.y - 9), "POLICE", 12, Palette.POLICE_RED.lightened(0.25))
		# The fire exits' limit: a little green EXIT sign on the bar.
		var fx := bar.position.x + bar.size.x * clampf(fire_limit / MAX_HEAT, 0.0, 1.0)
		var sign_rect := Rect2(Vector2(fx - 16, bar.end.y + 2), Vector2(32, 13))
		draw_rect(sign_rect.grow(1.5), Palette.HUD_INK)
		draw_rect(sign_rect, Color("1f7a3a") if heat < fire_limit else Color("2a3a2e"))
		var ef := VisualTheme.font("heading_bold")
		draw_string(ef, sign_rect.position + Vector2(3, 11), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("dfffe6") if heat < fire_limit else Color(0.6, 0.7, 0.6, 0.6))
		draw_line(Vector2(fx - (bar.size.y) * HudKit.SKEW * 0.5, bar.position.y + 2), Vector2(fx, bar.end.y), Color("5dffa0"), 2.0)
		# Van clock or heat number, big italic at the end of the bar.
		var status := "VAN IN %ds" % ceili(timer) if hot else "%d" % roundi(heat)
		HudKit.text(self, pulp, Vector2(bar.end.x + 12, 54), status, 20, Palette.DANGER if hot else Palette.PAPER_CREAM)
		# WANTED: five police badges above the bar's right half.
		for i in 5:
			var c := Vector2(bar.end.x - 118 + i * 26, 14)
			var earned := i < stars
			var badge_col := Palette.GOLD
			if earned and stars >= 5 and not HudKit.calm():
				badge_col = Palette.POLICE_RED if fmod(_t * 2.0 + i * 0.25, 1.0) < 0.5 else Palette.POLICE_BLUE
			var flash := _star_flash if earned and i == stars - 1 and not HudKit.calm() else 0.0
			if HudKit.minimal():
				draw_colored_polygon(HudKit.star(c, 9.0, 4.0), badge_col if earned else Color(1, 1, 1, 0.2))
			else:
				HudKit.draw_badge(self, c, 10.0, earned, badge_col, flash)
		# The heat log: short skewed captions under the bar.
		var y := bar.end.y + 32.0
		for line: Array in log_lines:
			var a := clampf(1.6 - line[1] / 4.5, 0.0, 1.0)
			var w := HudKit.text_width(type, line[0], 13) + 14.0
			if not HudKit.minimal():
				draw_colored_polygon(HudKit.slant(Rect2(Vector2(62, y - 13), Vector2(w, 17))), Color(0.05, 0.05, 0.06, 0.7 * a))
			HudKit.text(self, type, Vector2(70, y), line[0], 13, Palette.with_alpha(Palette.GOLD_PALE, a))
			y += 19.0


## THE RALLY, pulp style. Hidden while no combo is live.
class ComboSlab extends HudProps.HudProp:
	var combo: Combo
	var _shown := false
	var _slam := 0.0              # 1 -> 0 after a tier-up
	var _tear := 0.0              # 1 -> 0 after a panic sell
	var _torn_points := 0
	var _torn_tier := 0
	var _fade := 0.0              # alpha

	func _ready() -> void:
		super._ready()
		_apply_scale()
		Settings.changed.connect(_apply_scale)

	func _apply_scale() -> void:
		var s := float(Settings.values.get("combo_hud_scale", 1.0))
		scale = Vector2(s, s)

	func bind_combo(c: Combo) -> void:
		combo = c
		combo.changed.connect(_refresh)
		combo.tier_up.connect(_on_tier_up)
		combo.panicked.connect(_on_panic)

	func _refresh() -> void:
		if combo == null:
			return
		if combo.live and not _shown:
			_shown = true
			_fade = 0.0
		elif not combo.live and _shown:
			_shown = false
		animate(0.35)

	func _on_tier_up(_t: int) -> void:
		_slam = 1.0
		animate(0.5)

	func _on_panic(points: int, tier: int, _gold: int) -> void:
		_torn_points = points
		_torn_tier = tier
		_tear = 1.0
		animate(0.9)

	func _advance(delta: float) -> void:
		_slam = maxf(_slam - delta * 3.0, 0.0)
		_tear = maxf(_tear - delta * 1.4, 0.0)
		_fade = move_toward(_fade, 1.0 if _shown else 0.0, delta * (8.0 if _shown else 3.0))
		if _shown:
			animate(0.1)          # the window drains every frame

	func _draw() -> void:
		if _tear > 0.0 and not HudKit.calm():
			_draw_torn()
		if combo == null or (_fade <= 0.0 and not _shown):
			return
		modulate.a = _fade
		var tier_col := combo.tier_color() if combo.live else Palette.PAPER_DIM
		var pulp := VisualTheme.font("pulp")
		var type := VisualTheme.font("type_bold")
		var slam := 0.0 if HudKit.calm() else _slam
		var grow := 1.0 + 0.18 * slam
		var slab := Rect2(Vector2(26, 10), Vector2(size.x - 40, 74))
		var points := str(combo.points) if combo.live else ""
		if HudKit.minimal():
			HudKit.text(self, pulp, Vector2(30, 60), points, 48, tier_col)
			HudKit.text(self, pulp, Vector2(110, 40), combo.tier_name(), 20, tier_col)
			HudKit.text(self, VisualTheme.font("mono"), Vector2(110, 62), "x%.1f  $%d" % [combo.multiplier(), combo.pending_gold()], 15, Palette.PAPER)
			var k := clampf(combo.window_left / maxf(combo.window, 0.01), 0.0, 1.0)
			draw_line(Vector2(30, 76), Vector2(30 + (size.x - 60) * k, 76), tier_col, 4.0)
			return
		HudKit.draw_speed_lines(self, slab, tier_col, slam)
		# Halftone burst behind the count.
		draw_colored_polygon(HudKit.impact(Vector2(60, 46), 52 * grow, 34 * grow, combo.tier + 3, 14), Palette.with_alpha(tier_col, 0.9))
		HudKit.draw_halftone(self, Rect2(Vector2(14, 6), Vector2(100, 82)), Palette.with_alpha(Palette.HUD_INK, 0.35), 6.0)
		HudKit.draw_slant_panel(self, Rect2(slab.position + Vector2(62, 8), Vector2(slab.size.x - 62, 58)), Color(0.05, 0.05, 0.06, 0.9), HudKit.SKEW, true, Palette.with_alpha(tier_col, 0.35))
		# The count: big and italic, over the burst.
		var count_size := int(54 * grow)
		HudKit.text(self, pulp, Vector2(60 - HudKit.text_width(pulp, points, count_size) * 0.5, 46 + count_size * 0.36), points, count_size, Palette.PAPER_CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.HUD_INK, 3)
		# Tier on a slanted banner.
		var banner := Rect2(Vector2(104, 2), Vector2(HudKit.text_width(pulp, combo.tier_name(), 20) + 24, 26))
		HudKit.draw_slant_panel(self, banner, tier_col, HudKit.SKEW, false)
		HudKit.text(self, pulp, banner.position + Vector2(12, 20), combo.tier_name(), 20, Palette.HUD_INK, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tier_col, 0)
		HudKit.text(self, VisualTheme.font("mono"), Vector2(112, 50), "x%.1f  $%d" % [combo.multiplier(), combo.pending_gold()], 15, Palette.PAPER_CREAM)
		# The window: a skewed bar draining right to left.
		var k := clampf(combo.window_left / maxf(combo.window, 0.01), 0.0, 1.0)
		var track := Rect2(Vector2(106, 60), Vector2(slab.size.x - 96, 9))
		draw_colored_polygon(HudKit.slant(track), Color(1, 1, 1, 0.14))
		if k > 0.0:
			draw_colored_polygon(HudKit.slant(Rect2(track.position, Vector2(track.size.x * k, track.size.y))), tier_col)
		# The last bonuses, typed.
		var lines: Array = combo.log_lines.slice(maxi(0, combo.log_lines.size() - 3))
		lines.reverse()
		var y := 102.0
		for line in lines:
			HudKit.text(self, type, Vector2(34, y), String(line), 13, Palette.GOLD_PALE)
			y += 16.0

	## PANIC SELL: the slab tears in two and the pieces fall away.
	func _draw_torn() -> void:
		var k := 1.0 - _tear
		var col := Palette.DANGER
		var left := PackedVector2Array([Vector2(26, 10), Vector2(120, 10), Vector2(104, 40), Vector2(126, 56), Vector2(98, 84), Vector2(10, 84)])
		var right := PackedVector2Array([Vector2(120, 10), Vector2(size.x - 6, 10), Vector2(size.x - 20, 84), Vector2(98, 84), Vector2(126, 56), Vector2(104, 40)])
		for piece: Array in [[left, Vector2(-30, 160), -0.5], [right, Vector2(40, 180), 0.6]]:
			var pts := PackedVector2Array()
			var off: Vector2 = piece[1] * k * k
			for p: Vector2 in piece[0]:
				pts.append(Vector2(60, 46) + (p - Vector2(60, 46)).rotated(piece[2] * k) + off)
			draw_colored_polygon(pts, Palette.with_alpha(Color(0.08, 0.03, 0.03), _tear))
			draw_polyline(HudKit.closed(pts), Palette.with_alpha(col, _tear), 2.0, true)
		HudKit.text(self, VisualTheme.font("pulp"), Vector2(40, 60 + 40 * k), "PANIC SELL", 26, Palette.with_alpha(col, _tear))


## DOUBLE / TRIPLE / MASSACRE.
class Banner extends HudProps.HudProp:
	var title := ""
	var sub := ""
	var massacre := false
	var _pop := 0.0
	var _life := 0.0

	func show_count(count: int) -> void:
		if count < 2:
			return
		title = HudWidgets.MultiBanner.title_for(count)
		sub = "%d DOWN" % count
		massacre = count >= 4
		_pop = 1.0
		_life = 1.6
		animate(1.7)

	func _advance(delta: float) -> void:
		_pop = maxf(_pop - delta * 6.0, 0.0)
		_life = maxf(_life - delta, 0.0)

	func _draw() -> void:
		if _life <= 0.0:
			return
		var a := clampf(_life / 0.35, 0.0, 1.0)
		modulate.a = a if not HudKit.calm() else minf(a, (1.6 - _life) / 0.15)
		var pop := 0.0 if HudKit.calm() else _pop
		var pulp := VisualTheme.font("pulp")
		var size_px := int(46 * (1.0 + 0.4 * pop))
		var w := HudKit.text_width(pulp, title, size_px) + 40.0
		var c := size * 0.5
		var col := Palette.DANGER if massacre else Palette.GOLD
		if not HudKit.minimal():
			if massacre:
				draw_colored_polygon(HudKit.impact(c + Vector2(0, -4), w * 0.55, w * 0.34, 9, 16), Palette.with_alpha(Palette.GOLD, 0.9))
			var rect := Rect2(c + Vector2(-w * 0.5, -30), Vector2(w, 50))
			HudKit.draw_slant_panel(self, rect, Color(0.07, 0.05, 0.05, 0.92), HudKit.SKEW, true, Palette.with_alpha(col, 0.4))
		HudKit.text(self, pulp, c + Vector2(-w * 0.5 + 18, 10), title, size_px, col, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.HUD_INK, 3)
		var type := VisualTheme.font("type_bold")
		HudKit.text_centered(self, type, c + Vector2(0, 34), sub, 15, Palette.PAPER_CREAM)


## One line of pulp news on a slant (combo cash-outs, panic sells, verdicts).
class Caption extends HudProps.HudProp:
	var line := ""
	var color := Palette.GOLD
	var _pop := 0.0
	var _life := 0.0

	func show_line(text: String, c: Color, slam: bool) -> void:
		line = text
		color = c
		_pop = 1.0 if slam and not HudKit.calm() else 0.0
		_life = 2.3
		animate(2.4)

	func _advance(delta: float) -> void:
		_pop = maxf(_pop - delta * 7.0, 0.0)
		_life = maxf(_life - delta, 0.0)

	func _draw() -> void:
		if _life <= 0.0 or line == "":
			return
		modulate.a = clampf(_life / 0.5, 0.0, 1.0)
		var pulp := VisualTheme.font("pulp")
		var size_px := int(22 * (1.0 + 0.5 * _pop))
		var w := minf(HudKit.text_width(pulp, line, size_px) + 36.0, size.x)
		var rect := Rect2(Vector2((size.x - w) * 0.5, 4), Vector2(w, size.y - 8))
		if not HudKit.minimal():
			HudKit.draw_slant_panel(self, rect, Color(0.05, 0.05, 0.06, 0.9), HudKit.SKEW, false)
			draw_line(rect.position + Vector2(-rect.size.y * HudKit.SKEW, 0), Vector2(rect.end.x - rect.size.y * HudKit.SKEW, rect.position.y), color, 3.0)
		HudKit.text(self, pulp, Vector2(rect.position.x + 18, rect.get_center().y + size_px * 0.36), line, size_px, color, HORIZONTAL_ALIGNMENT_LEFT, w - 24.0)
