extends RefCounted
class_name HudProps
## The HUD's diegetic props (Brief 3): objects lying on the heist table.
##   ChipStack   health as poker chips (gold chips for bonus max HP)
##   MoneyClip   cash on a banknote in a brass clip + the loot luggage tag
##   WeaponRack  the gun's silhouette, real rounds (a cylinder for revolvers,
##               shells for shotguns), the reserve's cartridge box
##   Matchbooks  relics as matchbooks fanned along the bottom
## Every prop redraws only when its value changes or while an animation runs
## (idle wobbles and swings stop with Reduce motion). Minimal style draws the
## same information as outlined text and simple icons, no props.


## Shared base: a mouse-transparent Control that animates only when asked.
class HudProp extends Control:
	var _anim := 0.0              # seconds of animation left
	var _idle := false            # an idle loop (wobble, swing) wants frames
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(false)
		Settings.changed.connect(queue_redraw)

	## Run `_process` for `seconds` (value-change animation).
	func animate(seconds: float) -> void:
		_anim = maxf(_anim, seconds)
		set_process(true)
		queue_redraw()

	func set_idle(on: bool) -> void:
		_idle = on and not HudKit.reduce_motion()
		if _idle:
			set_process(true)

	func _process(delta: float) -> void:
		_t += delta
		_anim = maxf(_anim - delta, 0.0)
		_advance(delta)
		queue_redraw()
		if _anim <= 0.0 and not _idle:
			set_process(false)

	## Per-frame animation hook for subclasses.
	func _advance(_delta: float) -> void:
		pass


## Health: one red chip per heart (gold for bonus max HP) stacked on the table.
## A hit flips the top chip off with a clack; healing drops one on. At 1 HP
## the last chip wobbles and glows red.
class ChipStack extends HudProp:
	const RX := 23.0
	const RY := 9.0
	const THICK := 6.0
	var current := 3
	var maximum := 3
	var base := 3
	var _last := -1
	var _lost := 0.0              # 1 -> 0: the chip flipping off
	var _gained := 0.0            # 1 -> 0: the chip dropping on

	func set_health(c: int, m: int) -> void:
		base = int(RunState.profile_value("base_health", 3)) if RunState.character_profile else 3
		var motion := not HudKit.reduce_motion()
		if _last >= 0 and c < _last:
			_lost = 1.0 if motion else 0.0
			animate(0.5)
			Audio.play_ui("case_tick")
		elif _last >= 0 and c > _last:
			_gained = 1.0 if motion else 0.0
			animate(0.4)
			Audio.play_ui("case_tick")
		_last = c
		current = c
		maximum = m
		set_idle(current == 1 and maximum > 1)
		queue_redraw()

	func _advance(delta: float) -> void:
		_lost = maxf(_lost - delta * 2.2, 0.0)
		_gained = maxf(_gained - delta * 2.8, 0.0)

	func _step() -> float:
		return clampf(96.0 / maxf(maximum, 1), 5.0, THICK + 6.0)

	func _chip_at(i: int) -> Vector2:
		# Stacked upward from the bottom, a little crooked like a real stack.
		return Vector2(size.x * 0.5 + (HudKit.noise(11, i) - 0.5) * 3.0, size.y - RY - THICK - i * _step())

	func _draw() -> void:
		if HudKit.minimal():
			_draw_minimal()
			return
		var step := _step()
		# Missing chips: faint outlines where they sat.
		for i in range(current, maximum):
			draw_polyline(HudKit.closed(HudKit.ellipse(_chip_at(i), RX, RY)), Color(1, 1, 1, 0.16), 1.0, true)
		draw_colored_polygon(HudKit.ellipse(Vector2(size.x * 0.5 + 3, size.y - RY + 2), RX + 3, RY + 2), Color(0, 0, 0, 0.35))
		for i in current:
			var c := _chip_at(i)
			if i == current - 1 and _gained > 0.0:
				c.y -= 40.0 * _gained * _gained
			var face := Palette.CHIP_GOLD if i >= base else Palette.CHIP_RED
			var glow := 0.0
			if current == 1 and maximum > 1:
				glow = 0.6 if HudKit.calm() or HudKit.reduce_motion() else 0.45 + 0.4 * sin(_t * 6.0)
				if not HudKit.reduce_motion():
					c.x += sin(_t * 9.0) * 1.6
			HudKit.draw_chip(self, c, RX, RY, minf(THICK, step - 1.0), face, Palette.PAPER_CREAM, glow)
		# The count, typed small beside the top chip (easier than counting).
		var top := _chip_at(maxi(current - 1, 0))
		HudKit.text(self, VisualTheme.font("type_bold"), top + Vector2(RX + 3, 4), "x%d" % current, 14, Palette.PAPER_CREAM if current > 1 else Palette.DANGER.lightened(0.2))
		if _lost > 0.0:
			# The lost chip flips and slides off to the right.
			var k := 1.0 - _lost
			var c := _chip_at(current) + Vector2(60.0 * k, 26.0 * k * k)
			var squash := absf(cos(k * PI * 2.0))
			var face := Palette.CHIP_GOLD if current >= base else Palette.CHIP_RED
			HudKit.draw_chip(self, c, RX, maxf(RY * squash, 1.0), THICK * 0.8, Palette.with_alpha(face, _lost), Palette.with_alpha(Palette.PAPER_CREAM, _lost))

	func _draw_minimal() -> void:
		var f := VisualTheme.font("heading_bold")
		var x := 4.0
		for i in maximum:
			var c := Vector2(x + 10, size.y - 16)
			if i < current:
				draw_circle(c, 9.0, Palette.CHIP_GOLD if i >= base else Palette.CHIP_RED)
			draw_arc(c, 9.0, 0, TAU, 18, Palette.HUD_INK, 2.0, true)
			x += 22.0
		HudKit.text(self, f, Vector2(4, size.y - 34), "HP %d/%d" % [current, maximum], 16, Palette.PAPER)


## Cash on a banknote in a brass money clip; the stack thickens in three
## tiers. Gains riffle the bills and roll the number up; spending slides a
## bill out. The loot multiplier hangs off the clip on a luggage tag.
class MoneyClip extends HudProp:
	var shown := 0.0              # the rolling number
	var target := 0
	var loot_mult := 1.0
	var _riffle := 0.0
	var _slide := 0.0
	var _swing := 0.0             # tag angle velocity kick
	var _tag_angle := 0.0
	var _tag_vel := 0.0

	func set_gold(amount: int) -> void:
		if target == 0 and shown == 0.0:
			shown = amount
		if HudKit.reduce_motion():
			pass
		elif amount > target:
			_riffle = 1.0
			animate(0.7)
		elif amount < target:
			_slide = 1.0
			animate(0.6)
		target = amount
		if HudKit.reduce_motion():
			shown = amount
		animate(0.8)

	func set_loot_multiplier(m: float) -> void:
		if absf(m - loot_mult) > 0.004:
			_tag_vel += 2.2 * signf(m - loot_mult)
			animate(1.5)
		loot_mult = m

	func tier() -> int:
		return 0 if target < 250 else (1 if target < 1200 else 2)

	func anchor() -> Vector2:
		return global_position + Vector2(96, 30) * get_global_transform().get_scale()

	func _advance(delta: float) -> void:
		shown = move_toward(shown, float(target), maxf(absf(target - shown) * delta * 6.0, delta * 40.0))
		_riffle = maxf(_riffle - delta * 2.0, 0.0)
		_slide = maxf(_slide - delta * 1.8, 0.0)
		# The tag swings like a damped pendulum when the multiplier changes,
		# then hangs still (no idle redraws).
		_tag_vel += (-_tag_angle * 18.0) * delta
		_tag_vel *= exp(-2.6 * delta)
		_tag_angle = clampf(_tag_angle + _tag_vel * delta, -0.6, 0.6)
		if HudKit.reduce_motion():
			_tag_angle = 0.0
			_tag_vel = 0.0

	func _draw() -> void:
		var f := VisualTheme.font("type_bold")
		var money := "$ %d" % roundi(shown)
		if HudKit.minimal():
			HudKit.text(self, VisualTheme.font("mono"), Vector2(4, 30), money, 24, Palette.GOLD)
			HudKit.text(self, VisualTheme.font("mono"), Vector2(4, 54), "LOOT x%.2f" % loot_mult, 15, _tag_color())
			return
		var note := Rect2(Vector2(8, 16), Vector2(170, 56))
		var bills: int = [2, 4, 7][tier()]
		# The stack: older bills underneath, fanned a little on a riffle.
		for i in range(bills - 1, 0, -1):
			var fan := (0.05 + 0.1 * _riffle * sin(_t * 30.0 + i)) * (1 if i % 2 == 0 else -1) if _riffle > 0.0 else (HudKit.noise(5, i) - 0.5) * 0.08
			HudKit.draw_banknote(self, Rect2(note.position + Vector2(i * 1.5, i * 2.2), note.size), fan, Color("5f7f55").darkened(0.05 * i), i == bills - 1)
		var top_off := Vector2(-90.0 * (1.0 - _slide) * _slide * 4.0, 0) if _slide > 0.0 else Vector2.ZERO
		HudKit.draw_banknote(self, Rect2(note.position + top_off, note.size), -0.02, Color("6f8f62"), bills == 1)
		# The paper band with the amount typed on it.
		var band := Rect2(note.position + Vector2(44, 14), Vector2(116, 28))
		HudKit.draw_paper(self, band, 44, 5, -0.02, Palette.PAPER_CREAM, Palette.PAPER_EDGE, false)
		HudKit.text(self, f, band.position + Vector2(8, 21), money, 20, Palette.HUD_INK, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.PAPER_CREAM, 0)
		# The brass clip across the left of the stack.
		var clip := PackedVector2Array([Vector2(18, 8), Vector2(42, 8), Vector2(42, 80), Vector2(18, 80)])
		HudKit.shadowed(self, clip, Palette.BRASS)
		draw_line(Vector2(21, 10), Vector2(21, 78), Palette.with_alpha(Color.WHITE, 0.45), 2.0)
		draw_polyline(HudKit.closed(clip), Palette.BRASS.darkened(0.4), 1.2, true)
		_draw_tag(Vector2(172, 22))

	func _tag_color() -> Color:
		return Palette.UP.darkened(0.3) if loot_mult > 1.02 else (Palette.RED_PENCIL if loot_mult < 0.98 else Palette.HUD_INK)

	## The luggage tag: string from the clip, a manila tag with the multiplier.
	func _draw_tag(hook: Vector2) -> void:
		var a := _tag_angle + 0.18
		var knot := hook + Vector2.from_angle(PI * 0.5 + a) * 22.0
		draw_line(hook, knot, Color("d9cfb4"), 1.5, true)
		var tag := PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(20, 12), Vector2(20, 44), Vector2(-20, 44), Vector2(-20, 12)])
		var pts := PackedVector2Array()
		for p in tag:
			pts.append(knot + p.rotated(a))
		HudKit.paper_poly(self, pts, Palette.MANILA, Palette.MANILA_DARK)
		draw_circle(knot + Vector2(0, 6).rotated(a), 2.5, Color(0.15, 0.12, 0.1))
		draw_set_transform(knot, a, Vector2.ONE)
		var f := VisualTheme.font("type_bold")
		HudKit.text(self, VisualTheme.font("type"), Vector2(-15, 24), "LOOT", 11, Palette.HUD_INK, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.MANILA, 0)
		HudKit.text(self, f, Vector2(-17, 39), "x%.2f" % loot_mult, 14, _tag_color(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, Palette.MANILA, 0)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## The gun on the table: its silhouette, the magazine as real rounds (a
## revolver's cylinder, a shotgun's shells), the reserve on a cartridge box
## (a stamped infinity for a sidearm). Each shot ejects a round that spins
## off; a reload slides rounds back in one by one; a swap flips like a card.
class WeaponRack extends HudProp:
	var weapon: WeaponItem
	var mag := 0
	var reserve := 0
	var gun := SpriteKit.Gun.PISTOL
	var reload_t := 0.0
	var reload_len := 0.0
	var _reload_from := 0
	var _flip := 0.0              # 1 -> 0: the card flip on a swap
	var _ejected: Array = []      # [pos, vel, angle, spin, life]
	var _cyl_angle := 0.0
	var _pending: WeaponItem = null
	var _pending_ammo := Vector2i.ZERO

	func set_weapon(w: WeaponItem, m: int, r: int) -> void:
		if weapon != null and w != weapon and not HudKit.reduce_motion():
			_pending = w
			_pending_ammo = Vector2i(m, r)
			_flip = 1.0
			animate(0.3)
			Audio.play_ui("paper")
			return
		_apply(w, m, r)

	func _apply(w: WeaponItem, m: int, r: int) -> void:
		weapon = w
		mag = m
		reserve = r
		gun = SpriteKit.gun_for(w)
		reload_t = 0.0
		queue_redraw()

	func set_ammo(m: int, r: int) -> void:
		if m < mag and not HudKit.reduce_motion():
			for i in mini(mag - m, 4):
				_ejected.append([_round_pos(mag - 1 - i), Vector2(randf_range(40, 90), randf_range(-160, -110)), 0.0, randf_range(-14, 14), 0.55])
			if gun == SpriteKit.Gun.REVOLVER:
				_cyl_angle += TAU / maxf(_capacity(), 1)
			animate(0.6)
		mag = m
		reserve = r
		if reload_t > 0.0 and m >= _capacity():
			reload_t = 0.0
		queue_redraw()

	func start_reload(duration: float) -> void:
		reload_len = maxf(duration, 0.01)
		reload_t = reload_len
		_reload_from = mag
		animate(duration + 0.1)

	func _capacity() -> int:
		return maxi(weapon.eff_mag() if weapon else 1, 1)

	func _kind() -> String:
		match gun:
			SpriteKit.Gun.SHOTGUN:
				return "shell"
			SpriteKit.Gun.RIFLE, SpriteKit.Gun.LONG_RIFLE, SpriteKit.Gun.LMG:
				return "rifle"
		return "round"

	## Rounds shown (filling one by one while reloading).
	func _shown_rounds() -> int:
		if reload_t > 0.0:
			var fill := mini(_capacity(), _reload_from + maxi(reserve, 0) if reserve >= 0 else _capacity())
			var k := 1.0 - reload_t / reload_len
			return clampi(_reload_from + int(floor((fill - _reload_from) * k)), 0, _capacity())
		return mag

	const ROUNDS_RIGHT := 192.0       # the row of rounds ends here, left of the name

	func _round_step() -> float:
		var n := _capacity()
		var avail := ROUNDS_RIGHT - 10.0
		var w := 26.0 if _kind() == "shell" else (32.0 if _kind() == "rifle" else 20.0)
		return clampf(avail / n, 3.0, w * 0.5 + 2.0)

	func _round_pos(i: int) -> Vector2:
		# A row of standing rounds (nose up), ending beside the gun.
		var start := maxf(10.0, ROUNDS_RIGHT - _capacity() * _round_step())
		return Vector2(start + i * _round_step(), size.y - 14)

	func _advance(delta: float) -> void:
		if reload_t > 0.0:
			reload_t = maxf(reload_t - delta, 0.0)
		if _flip > 0.0:
			var was := _flip
			_flip = maxf(_flip - delta * 3.6, 0.0)
			if was > 0.5 and _flip <= 0.5 and _pending:
				_apply(_pending, _pending_ammo.x, _pending_ammo.y)
				_pending = null
		for e: Array in _ejected:
			e[1] += Vector2(0, 520) * delta
			e[0] += e[1] * delta
			e[2] += e[3] * delta
			e[4] -= delta
		_ejected = _ejected.filter(func(e): return e[4] > 0.0)

	func _draw() -> void:
		if weapon == null:
			return
		if HudKit.minimal():
			_draw_minimal()
			return
		var flip_scale := absf(cos(_flip * PI)) if _flip > 0.0 else 1.0
		var head := VisualTheme.font("heading_bold")
		var mono := VisualTheme.font("mono")
		# The gun, lying on the table (tilted a little), right side.
		var gun_rect := Rect2(Vector2(size.x - 140, 2), Vector2(134, 52))
		draw_set_transform(gun_rect.get_center(), -0.05, Vector2(flip_scale, 1.0))
		_draw_gun(Rect2(-gun_rect.size * 0.5, gun_rect.size))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		HudKit.text(self, head, Vector2(size.x - 140, 72), weapon.display_name.to_upper(), 16, weapon.rarity_color(), HORIZONTAL_ALIGNMENT_LEFT, 136.0)
		if not weapon.mods.is_empty():
			var tags: Array = weapon.mods.map(func(m): return WeaponMods.tag_of(m))
			HudKit.text(self, mono, Vector2(size.x - 140, 88), " ".join(tags), 12, Palette.NEON_CYAN)
		# The rounds.
		if gun == SpriteKit.Gun.REVOLVER:
			_draw_cylinder(Vector2(ROUNDS_RIGHT - 44, size.y - 40), 30.0)
		else:
			var shown := _shown_rounds()
			var n := _capacity()
			var kind := _kind()
			for i in n:
				var p := _round_pos(i)
				var loaded := i < shown
				if reload_t > 0.0 and i == shown - 1:
					var frac := fmod((1.0 - reload_t / reload_len) * (_capacity() - _reload_from), 1.0)
					p.y -= 14.0 * (1.0 - frac)
				HudKit.draw_bullet(self, p, kind, -PI * 0.5, 1.15, not loaded, 1.0 if loaded else 0.28)
		for e: Array in _ejected:
			HudKit.draw_bullet(self, e[0], "round" if _kind() == "round" else _kind(), e[2], 1.1, true, clampf(e[4] / 0.3, 0.0, 1.0))
		_draw_reserve(Vector2(size.x - 196, 8))
		if reload_t > 0.0:
			HudKit.text(self, VisualTheme.font("type_bold"), Vector2(14, 16), "RELOADING", 15, Palette.GOLD_PALE)
		elif mag == 0:
			HudKit.text(self, VisualTheme.font("type_bold"), Vector2(14, 16), "EMPTY — RELOAD", 15, Palette.RED_PENCIL.lightened(0.2))

	func _draw_gun(r: Rect2) -> void:
		var c := r.get_center()
		var k := minf(r.size.x / 110.0, r.size.y / 44.0)
		var body := weapon.rarity_color().darkened(0.2).lerp(Color("2a2c31"), 0.55)
		var dark := Color("15161a")
		var parts: Array = HudKit.gun_parts(gun, body, dark)
		for p: Array in parts:
			var rr: Rect2 = p[0]
			draw_rect(Rect2(c + rr.position * k + Vector2(3, 4), rr.size * k), Color(0, 0, 0, 0.45))
		# A pale rim, then ink: the gun reads on dark floors and lit ones.
		for p: Array in parts:
			var rr: Rect2 = p[0]
			draw_rect(Rect2(c + rr.position * k, rr.size * k).grow(3.0), Palette.with_alpha(Palette.PAPER_CREAM, 0.35))
		for p: Array in parts:
			var rr: Rect2 = p[0]
			draw_rect(Rect2(c + rr.position * k, rr.size * k).grow(1.5), Palette.HUD_INK)
		for p: Array in parts:
			var rr: Rect2 = p[0]
			draw_rect(Rect2(c + rr.position * k, rr.size * k), p[1])
		var top: Rect2 = parts[0][0]
		draw_line(c + top.position * k + Vector2(2, 2), c + Vector2(top.end.x, top.position.y) * k + Vector2(-2, 2), Palette.with_alpha(weapon.rarity_color(), 0.8), 1.5)

	func _draw_cylinder(c: Vector2, r: float) -> void:
		var n := _capacity()
		var shown := _shown_rounds()
		draw_circle(c + Vector2(2, 3), r + 2, Color(0, 0, 0, 0.45))
		draw_circle(c, r + 2, Palette.HUD_INK)
		draw_circle(c, r, Color("3a3d44"))
		draw_circle(c, r * 0.22, Color("24262b"))
		for i in n:
			var p := c + Vector2.from_angle(_cyl_angle + TAU * i / n - PI * 0.5) * r * 0.62
			var cr := r * minf(0.26, 1.6 / n)
			if i < shown:
				draw_circle(p, cr, Palette.BRASS.lightened(0.15))
				draw_circle(p, cr * 0.45, Color("c0703f"))
			else:
				draw_circle(p, cr, Color("111215"))
			draw_arc(p, cr, 0, TAU, 12, Color(0, 0, 0, 0.6), 1.0, true)
		HudKit.text(self, VisualTheme.font("type_bold"), c + Vector2(-r - 44, 6), "%d/%d" % [mag, n], 15, Palette.PAPER_CREAM)

	## A small cardboard cartridge box with the reserve count, or a stamped
	## infinity for a sidearm that never runs dry.
	func _draw_reserve(at: Vector2) -> void:
		var box := Rect2(at, Vector2(48, 30))
		var pts := HudKit.rotated(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]), box.get_center(), 0.04)
		HudKit.shadowed(self, pts, Color("b99a62"))
		draw_polyline(HudKit.closed(pts), Color("6b5230"), 1.2, true)
		draw_rect(Rect2(box.position + Vector2(4, 4), Vector2(40, 7)), Color("8a2a24"))
		if reserve < 0:
			# A stamped infinity sign (drawn: not every font has the glyph).
			var c := box.get_center() + Vector2(0, 5)
			draw_set_transform(c, -0.15, Vector2.ONE)
			draw_rect(Rect2(-18, -9, 36, 18), Palette.RED_PENCIL, false, 2.0)
			HudKit.draw_infinity(self, Vector2.ZERO, 11.0, Palette.RED_PENCIL)
			draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			var f := VisualTheme.font("type_bold")
			var s := str(reserve)
			var w := HudKit.text_width(f, s, 15)
			draw_string(f, box.get_center() + Vector2(-w * 0.5, 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.HUD_INK)

	func _draw_minimal() -> void:
		var f := VisualTheme.font("heading_bold")
		var mono := VisualTheme.font("mono")
		HudKit.text(self, f, Vector2(size.x - 190, 30), weapon.display_name.to_upper(), 18, weapon.rarity_color(), HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
		var readout := "%d / %s" % [mag, "INF" if reserve < 0 else str(reserve)]
		HudKit.text(self, mono, Vector2(size.x - 190, 58), readout, 22, Palette.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
		if reload_t > 0.0:
			HudKit.text(self, mono, Vector2(size.x - 190, 80), "RELOADING", 14, Palette.GOLD_PALE, HORIZONTAL_ALIGNMENT_RIGHT, 180.0)
		elif mag == 0:
			HudKit.text(self, mono, Vector2(size.x - 190, 80), "EMPTY — RELOAD", 14, Palette.DANGER, HORIZONTAL_ALIGNMENT_RIGHT, 180.0)


## Relics as matchbooks and keychain charms fanned in a slight arc along the
## bottom: a folded card in the relic's rarity colour, a striker strip and the
## relic's mark. Hover one for its name and effect.
class Matchbooks extends HudProp:
	var _ids: Array = []
	var _clock := 0.0
	var _drop := 0.0

	func _ready() -> void:
		super._ready()
		# PASS, not STOP: hovering shows a tooltip, clicks still reach the game.
		mouse_filter = Control.MOUSE_FILTER_PASS
		set_process(true)

	func _process(delta: float) -> void:
		_clock -= delta
		if _clock <= 0.0:
			_clock = 0.5
			var ids: Array = []
			for id in RunState.relics:
				if not (id in ids):
					ids.append(id)
			if ids != _ids:
				if ids.size() > _ids.size() and not HudKit.reduce_motion():
					_drop = 1.0
				_ids = ids
				queue_redraw()
		if _drop > 0.0:
			_drop = maxf(_drop - delta * 3.0, 0.0)
			queue_redraw()

	func _book_slot(i: int) -> Array:
		var n := maxi(_ids.size(), 1)
		var spread := minf(40.0, (size.x - 40.0) / n)
		var x := size.x * 0.5 + (i - (n - 1) * 0.5) * spread
		var arc := (i - (n - 1) * 0.5) / maxf(n, 1)
		return [Vector2(x, size.y - 30 + absf(arc) * 14.0), arc * 0.5]

	func _get_tooltip(at_position: Vector2) -> String:
		for i in _ids.size():
			var slot := _book_slot(i)
			if at_position.distance_to(slot[0]) < 18.0:
				var r := Relics.make(_ids[i])
				if r:
					var stack := RunState.relic_count(_ids[i])
					return "%s%s\n%s" % [r.display_name, (" x%d" % stack) if stack > 1 else "", r.description]
		return ""

	func _draw() -> void:
		var f := VisualTheme.font("heading_bold")
		for i in _ids.size():
			var r := Relics.make(_ids[i])
			if r == null:
				continue
			var slot := _book_slot(i)
			var c: Vector2 = slot[0]
			var angle: float = slot[1]
			if i == _ids.size() - 1 and _drop > 0.0:
				c.y -= 30.0 * _drop
			var col := r.rarity_color()
			if HudKit.minimal():
				draw_circle(c, 13.0, Color(0, 0, 0, 0.5))
				HudKit.text_centered(self, f, c, r.mark, 13, col)
				continue
			var book := PackedVector2Array([Vector2(-15, -22), Vector2(15, -22), Vector2(15, 22), Vector2(-15, 22)])
			var pts := PackedVector2Array()
			for p in book:
				pts.append(c + p.rotated(angle))
			HudKit.shadowed(self, pts, col.darkened(0.35))
			draw_polyline(HudKit.closed(pts), Palette.HUD_INK, 1.5, true)
			# The cover flap and the striker strip.
			draw_line(c + Vector2(-15, 10).rotated(angle), c + Vector2(15, 10).rotated(angle), Palette.HUD_INK, 1.2)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-15, 14).rotated(angle), c + Vector2(15, 14).rotated(angle),
				c + Vector2(15, 20).rotated(angle), c + Vector2(-15, 20).rotated(angle)]), Color("4a3a30"))
			draw_circle(c + Vector2(0, -6).rotated(angle), 11.0, Palette.PAPER_CREAM)
			draw_set_transform(c + Vector2(0, -6).rotated(angle), angle, Vector2.ONE)
			var w := HudKit.text_width(f, r.mark, 12)
			draw_string(f, Vector2(-w * 0.5, 4.5), r.mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col.darkened(0.4))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			var stack := RunState.relic_count(_ids[i])
			if stack > 1:
				HudKit.text(self, f, c + Vector2(10, 20), "x%d" % stack, 12, Palette.PAPER)
