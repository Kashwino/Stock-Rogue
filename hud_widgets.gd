extends RefCounted
class_name HudWidgets
## Small drawn HUD pieces. Each is a Control inner class with its own _draw.

static func heart_points(center: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(center + Vector2(x, y) * s / 17.0)
	return pts


class Hearts extends Control:
	var current := 3
	var maximum := 3
	var _pulse := 0.0
	var _last := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(260, 34)

	func set_health(c: int, m: int) -> void:
		if _last >= 0 and c < _last:
			_pulse = 1.0
		_last = c
		current = c
		maximum = m
		queue_redraw()

	func _process(delta: float) -> void:
		if _pulse > 0.0 or current == 1:
			_pulse = maxf(_pulse - delta * 2.0, 0.0)
			queue_redraw()

	func _draw() -> void:
		var s := 13.0 if maximum <= 8 else 9.0
		var step := s * 2.3
		var t := Time.get_ticks_msec() / 1000.0
		for i in maximum:
			var c := Vector2(s + 2 + i * step, size.y * 0.5)
			var scale := 1.0
			if i == current - 1 and current == 1:
				scale = 1.0 + 0.12 * maxf(sin(t * 6.0), 0.0)
			var pts := HudWidgets.heart_points(c, s * scale)
			if i < current:
				draw_colored_polygon(HudWidgets.heart_points(c + Vector2(1.5, 2), s * scale), Color(0, 0, 0, 0.5))
				draw_colored_polygon(pts, Palette.DANGER.lightened(0.1))
				draw_colored_polygon(HudWidgets.heart_points(c + Vector2(-s * 0.25, -s * 0.2), s * 0.35), Color(1, 1, 1, 0.3))
			else:
				draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.with_alpha(Palette.PAPER_DIM, 0.6), 1.5, true)
		if _pulse > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Palette.with_alpha(Palette.DANGER, _pulse * 0.25))


class HeatMeter extends Control:
	## Heat bar with a green "fire exits" tick and a red "police" tick. Pulses
	## red/blue once a response is rolling. Shows the latest heat sources.
	var heat := 0.0
	var dispatch := 16.0
	var fire_limit := 12.0
	var timer := 0.0
	var log_lines: Array = []       # [text, age]
	var hot := false
	const MAX_HEAT := 40.0
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func push_source(text: String) -> void:
		log_lines.push_front([text, 0.0])
		while log_lines.size() > 3:
			log_lines.pop_back()

	func _process(delta: float) -> void:
		_t += delta
		for line: Array in log_lines:
			line[1] += delta
		while not log_lines.is_empty() and log_lines.back()[1] > 7.0:
			log_lines.pop_back()
		queue_redraw()

	func _draw() -> void:
		var f := VisualTheme.font("heading")
		var mono := VisualTheme.font("mono")
		var bar := Rect2(Vector2(70, 8), Vector2(size.x - 170, 20))
		hot = heat >= dispatch
		draw_string(f, Vector2(0, 26), "HEAT", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.DANGER if hot else Palette.PAPER)
		draw_rect(bar, Color(0.03, 0.03, 0.04, 0.9))
		var fill := clampf(heat / MAX_HEAT, 0.0, 1.0)
		var col := Palette.GOLD.lerp(Palette.DANGER, clampf(heat / dispatch, 0.0, 1.0))
		if hot and not Settings.values.get("reduce_flashing", false):
			col = Palette.POLICE_RED if fmod(_t, 0.5) < 0.25 else Palette.POLICE_BLUE
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), col)
		for i in range(1, 8):
			var x := bar.position.x + bar.size.x * i / 8.0
			draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0, 0, 0, 0.45), 1.0)
		var fx := bar.position.x + bar.size.x * clampf(fire_limit / MAX_HEAT, 0, 1)
		draw_line(Vector2(fx, bar.position.y - 5), Vector2(fx, bar.end.y + 5), Palette.NEON_GREEN, 2.0)
		var px := bar.position.x + bar.size.x * clampf(dispatch / MAX_HEAT, 0, 1)
		draw_line(Vector2(px, bar.position.y - 5), Vector2(px, bar.end.y + 5), Palette.POLICE_RED, 2.0)
		draw_rect(bar, Palette.GOLD_DIM, false, 1.0)
		draw_string(mono, Vector2(fx - 20, bar.end.y + 17), "EXITS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.NEON_GREEN)
		draw_string(mono, Vector2(px + 4, bar.end.y + 17), "POLICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.POLICE_RED)
		var status := "VAN IN %ds" % ceili(timer) if hot else "%d" % roundi(heat)
		draw_string(mono, Vector2(bar.end.x + 10, 25), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.DANGER if hot else Palette.PAPER)
		var y := 56.0
		for line: Array in log_lines:
			var a := clampf(1.6 - line[1] / 4.5, 0.0, 1.0)
			draw_string(mono, Vector2(0, y), line[0], HORIZONTAL_ALIGNMENT_LEFT, size.x, 15, Palette.with_alpha(Palette.GOLD_PALE, a))
			y += 18.0


class WeaponIcon extends Control:
	## Side-view gun silhouette matching SpriteKit.Gun.
	var gun := SpriteKit.Gun.PISTOL
	var tint := Palette.PAPER

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var k := minf(size.x / 110.0, size.y / 44.0)
		var dark := Color("15161a")
		var body := tint.darkened(0.15)
		var parts: Array = []   # [Rect2 (local units, centre origin), colour]
		match gun:
			SpriteKit.Gun.PISTOL:
				parts = [[Rect2(-26, -10, 44, 11), body], [Rect2(-26, 1, 12, 20), dark], [Rect2(18, -8, 6, 6), dark]]
			SpriteKit.Gun.REVOLVER:
				parts = [[Rect2(-12, -9, 48, 8), body], [Rect2(-16, -12, 16, 16), dark], [Rect2(-26, -2, 12, 22), dark]]
			SpriteKit.Gun.SMG:
				parts = [[Rect2(-36, -10, 64, 14), body], [Rect2(-8, 4, 9, 20), dark], [Rect2(-32, 4, 10, 14), dark], [Rect2(28, -6, 12, 6), dark]]
			SpriteKit.Gun.RIFLE:
				parts = [[Rect2(-50, -9, 90, 11), body], [Rect2(-52, -6, 22, 16), Color("6b4a31")], [Rect2(-4, 2, 8, 18), dark], [Rect2(40, -6, 12, 5), dark]]
			SpriteKit.Gun.LONG_RIFLE:
				parts = [[Rect2(-54, -7, 110, 9), body], [Rect2(-56, -5, 24, 16), Color("6b4a31")], [Rect2(-14, -18, 30, 9), dark], [Rect2(-2, 2, 7, 14), dark]]
			SpriteKit.Gun.SHOTGUN:
				parts = [[Rect2(-50, -10, 96, 13), body], [Rect2(-52, -8, 24, 18), Color("6b4a31")], [Rect2(0, 3, 26, 8), Color("6b4a31").darkened(0.2)]]
			SpriteKit.Gun.LMG:
				parts = [[Rect2(-54, -12, 104, 16), body], [Rect2(-8, 4, 24, 20), Color("3d4a33")], [Rect2(34, 4, 4, 18), dark], [Rect2(-56, -10, 18, 20), dark]]
			_:
				parts = [[Rect2(-20, -8, 40, 16), body]]
		for p: Array in parts:
			var r: Rect2 = p[0]
			draw_rect(Rect2(c + r.position * k + Vector2(2, 3), r.size * k), Color(0, 0, 0, 0.45))
		for p: Array in parts:
			var r: Rect2 = p[0]
			draw_rect(Rect2(c + r.position * k, r.size * k), p[1])
		var top: Rect2 = parts[0][0]
		draw_line(c + top.position * k + Vector2(2, 2), c + Vector2(top.end.x, top.position.y) * k + Vector2(-2, 2), Palette.with_alpha(Color.WHITE, 0.4), 1.5)


class WeaponPanel extends Control:
	## Bottom-centre weapon readout: icon, name in rarity colour, magazine pips,
	## reserve, reload progress.
	var weapon: WeaponItem
	var mag := 0
	var reserve := 0
	var reload_t := 0.0
	var reload_len := 0.0
	var icon: HudWidgets.WeaponIcon

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon = HudWidgets.WeaponIcon.new()
		icon.position = Vector2(14, 12)
		icon.size = Vector2(110, 46)
		add_child(icon)

	func set_weapon(w: WeaponItem, m: int, r: int) -> void:
		weapon = w
		mag = m
		reserve = r
		icon.gun = SpriteKit.gun_for(w)
		icon.tint = w.rarity_color() if w else Palette.PAPER
		icon.queue_redraw()
		queue_redraw()

	func set_ammo(m: int, r: int) -> void:
		mag = m
		reserve = r
		queue_redraw()

	func start_reload(duration: float) -> void:
		reload_len = maxf(duration, 0.01)
		reload_t = reload_len

	func _process(delta: float) -> void:
		if reload_t > 0.0:
			reload_t = maxf(reload_t - delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		draw_style_box(VisualTheme.panel(Palette.GOLD_DIM, 0), Rect2(Vector2.ZERO, size))
		if weapon == null:
			return
		var f := VisualTheme.font("heading")
		var mono := VisualTheme.font("mono")
		draw_string(f, Vector2(136, 28), weapon.display_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 21, weapon.rarity_color())
		var pip_area := size.x - 150.0
		var n := maxi(weapon.eff_mag(), 1)
		var pw := clampf(pip_area / n - 2.0, 2.0, 9.0)
		for i in n:
			var r := Rect2(136 + i * (pw + 2.0), 40, pw, 14)
			if i < mag:
				draw_rect(r, Palette.GOLD)
				draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Palette.GOLD_PALE)
			else:
				draw_rect(r, Color(1, 1, 1, 0.1))
		if not weapon.mods.is_empty():
			var tags: Array = weapon.mods.map(func(m): return WeaponMods.tag_of(m))
			draw_string(mono, Vector2(14, size.y - 4), " ".join(tags), HORIZONTAL_ALIGNMENT_LEFT, 116, 12, Palette.NEON_CYAN)
		var readout := "%d / %s" % [mag, "∞" if reserve < 0 else str(reserve)]
		draw_string(mono, Vector2(size.x - 104, 26), readout, HORIZONTAL_ALIGNMENT_RIGHT, 92, 18, Palette.PAPER)
		if reload_t > 0.0:
			var p := 1.0 - reload_t / reload_len
			draw_rect(Rect2(136, 60, pip_area * p, 5), Palette.GOLD_PALE)
			draw_string(mono, Vector2(136, size.y - 4), "RELOADING", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.GOLD_PALE)
		elif mag == 0:
			draw_string(mono, Vector2(136, size.y - 4), "EMPTY - RELOAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.DANGER)


class Minimap extends Control:
	## Discovered rooms, the car, exits and the player. Insider shows it all.
	var floor_host: Node
	var bounds := Rect2()
	var _clock := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock -= delta
		if _clock <= 0.0:
			_clock = 0.2
			queue_redraw()

	func _draw() -> void:
		draw_style_box(VisualTheme.panel(Palette.GOLD_DIM, 0), Rect2(Vector2.ZERO, size))
		if floor_host == null or not is_instance_valid(floor_host) or floor_host.generator == null:
			return
		var tmap: HeistMap = floor_host.tactical_map
		if bounds.size == Vector2.ZERO:
			for room in floor_host.generator.rooms:
				var rr := Rect2(room.global_position, room.room_size)
				bounds = rr if bounds.size == Vector2.ZERO else bounds.merge(rr)
			if floor_host.car:
				bounds = bounds.merge(Rect2(floor_host.car.global_position - Vector2(80, 80), Vector2(160, 160)))
		var inner := Rect2(Vector2(8, 8), size - Vector2(16, 16))
		var k := minf(inner.size.x / bounds.size.x, inner.size.y / bounds.size.y)
		var origin := inner.position + (inner.size - bounds.size * k) * 0.5
		var reveal: bool = tmap != null and tmap.full_reveal
		for room in floor_host.generator.rooms:
			if not reveal and (tmap == null or not tmap.discovered.has(room.get_instance_id())):
				continue
			var r := Rect2(origin + (room.global_position - bounds.position) * k, room.room_size * k)
			var col := Color(0.25, 0.27, 0.32)
			if room.has_meta("is_boss"):
				col = Color(0.55, 0.16, 0.2)
			elif room.has_meta("chest_kind"):
				col = Palette.GOLD_DIM
			draw_rect(r.grow(-1), col)
			draw_rect(r.grow(-1), Color(0, 0, 0, 0.6), false, 1.0)
		var gen = floor_host.generator
		for gap: Dictionary in [gen.entrance] + gen.exits:
			if gap.is_empty():
				continue
			var at: Vector2 = origin + (gap["inside_pos"] - bounds.position) * k
			draw_circle(at, 3.0, Palette.GOLD if gap == gen.entrance else (Palette.NEON_GREEN if gap.get("open", false) else Palette.DANGER))
		if floor_host.car:
			var cp: Vector2 = origin + (floor_host.car.global_position - bounds.position) * k
			draw_rect(Rect2(cp - Vector2(5, 3), Vector2(10, 6)), Palette.GOLD)
		# Objective marks (VIP, jackpots, charges, the package) always show.
		if floor_host.has_method("objective_points"):
			var blink := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
			for at: Vector2 in floor_host.objective_points():
				var op: Vector2 = origin + (at - bounds.position) * k
				draw_circle(op, 5.0, Palette.with_alpha(Palette.DANGER, blink))
				draw_arc(op, 7.5, 0, TAU, 12, Palette.PAPER, 1.5)
		if is_instance_valid(floor_host.player):
			var pp: Vector2 = origin + (floor_host.player.global_position - bounds.position) * k
			draw_circle(pp, 4.0, Color.WHITE)
			draw_arc(pp, 6.5, 0, TAU, 12, Palette.GOLD, 1.5)


class RelicTokens extends Control:
	## A row of owned relics as small gold-rimmed medallions with their marks.
	var _clock := 0.0
	var _count := -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_clock -= delta
		if _clock <= 0.0:
			_clock = 0.5
			if RunState.relics.size() != _count:
				_count = RunState.relics.size()
				queue_redraw()

	func _draw() -> void:
		var f := VisualTheme.font("heading_bold")
		var x := 12.0
		var seen: Dictionary = {}
		for id in RunState.relics:
			if seen.has(id):
				continue
			seen[id] = true
			var r := Relics.make(id)
			if r == null:
				continue
			var c := Vector2(x, size.y * 0.5)
			var col := r.rarity_color()
			draw_circle(c, 12.0, Color(0.06, 0.06, 0.07, 0.9))
			draw_arc(c, 12.0, 0.0, TAU, 20, col, 2.0, true)
			var w := f.get_string_size(r.mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string(f, c + Vector2(-w * 0.5, 4.5), r.mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			var stack := RunState.relic_count(id)
			if stack > 1:
				draw_string(f, c + Vector2(8, 13), "x%d" % stack, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.PAPER)
			x += 28.0
			if x > size.x - 12.0:
				break
