extends Boss
class_name ChairmanBoss
## THE CHAIRMAN (Doomsday, final). The trading floor under a giant ticker wall.
##   P1 "Bull Market"   volleys shaped like rising chart lines (shown first),
##                      with a gap to slip through
##   P2 "Margin Call"   (66%) the floor splits into strips that follow a live
##                      price line: strips under the margin line turn orange,
##                      then red, and hurt while you stand in them
##   P3 "Liquidation"   (30%) drains your gold every second until he falls
## His death ends the run: the heist extracts on its own and the ending plays.

var wall: TickerWall
var margin: MarginFloor
var _chart: Array = []            # pending volley: [Vector2 offset along/side]
var _dir := Vector2.RIGHT
var _drain_clock := 1.0
var drained := 0
## Black Ledger sabotage: no Liquidation drain.
var drain_disabled := false
var _cycle := 0

func setup_boss() -> void:
	boss_id = &"chairman"
	display_name = "THE CHAIRMAN"
	subtitle = Story.BOSSES[&"chairman"][1]
	max_health = 180
	thresholds = [0.66, 0.3]
	phase_lines = ["Margin call. Everybody pays.", "Liquidate everything."]
	move_speed = 80.0
	kit = SpriteKit.dress(sprite, {"body": SpriteKit.Body.SUIT, "head": SpriteKit.Head.SLICKED, "gun": SpriteKit.Gun.CANE,
		"color": Color("121216"), "trim": Palette.GOLD, "hair": Color("c8c8c8"), "skin": SpriteKit.SKIN[4],
		"acc": ["pinstripe", "tie", "cigar", "gold_band"], "scale": 1.5})

func begin_fight() -> void:
	var host := heist()
	if host:
		wall = TickerWall.new()
		wall.width = arena.size.x - 80.0
		host.add_child(wall)
		wall.global_position = Vector2(arena.position.x + 40.0, arena.position.y + 34.0)
		margin = MarginFloor.new()
		margin.arena = arena.grow(-30.0)
		margin.boss = self
		host.add_child(margin)
	_sabotage()
	attack = &"stroll"
	clock = 1.0

## The shaken-down bosses' relics each break one of his phases.
##   Deed Box          he starts 15% down
##   Black Ledger      Liquidation can't touch your gold
##   Diplomatic Pouch  Margin Call's hazard strips are half as wide
func _sabotage() -> void:
	var host := heist()
	var lines: Array = []
	if Verdicts.shaken(&"landlord"):
		health = int(round(max_health * Verdicts.DEED_BOX_HP))
		lines.append("DEED BOX: HE STARTS 15% DOWN")
	if Verdicts.shaken(&"auditor"):
		drain_disabled = true
		lines.append("BLACK LEDGER: NO LIQUIDATION")
	if Verdicts.shaken(&"ambassador") and margin:
		margin.hazard_scale = Verdicts.MARGIN_HALVED
		lines.append("DIPLOMATIC POUCH: MARGIN CALL HALVED")
	if host:
		for i in lines.size():
			host.fx.chip(global_position + Vector2(0, -60 - 26 * i), "SABOTAGED — " + lines[i], Palette.GOLD)

## On his knees: the floor stops trading against you.
func stand_down_floor() -> void:
	if margin:
		margin.active = false
		margin.queue_redraw()
	if wall:
		wall.alarm = false

func _process(delta: float) -> void:
	if not intro_done or is_down():
		return
	if phase >= 3 and not drain_disabled:
		_drain_clock -= delta
		if _drain_clock <= 0.0:
			_drain_clock = 1.0
			var take := maxi(4, int(RunEconomy.gold * 0.02))
			take = mini(take, RunEconomy.gold)
			if take > 0:
				RunEconomy.add_bonus(-take)
				drained += take
				var host := heist()
				if host and is_instance_valid(host.player):
					host.fx.chip(host.player.global_position, "-$%d" % take, Palette.DANGER)

func next_attack() -> void:
	telegraph_clear()
	if attack == &"chart_wind":
		_fire_chart()
		attack = &"stroll"
		clock = 1.6 if phase == 1 else 1.2
		if phase >= 3:
			clock = 0.9
		return
	_cycle += 1
	attack = &"chart_wind"
	clock = 0.6
	_plan_chart()

func run_attack(_delta: float) -> void:
	var d := face_player()
	match attack:
		&"stroll":
			var want := global_position + d.orthogonal() * 70.0
			if to_player().length() > 460.0:
				want = _player.global_position
			velocity = _steer_toward(want, move_speed)
		&"chart_wind":
			velocity = Vector2.ZERO
			var t := telegraph()
			t.clear()
			var pts := _chart_points()
			for i in range(1, pts.size()):
				if pts[i] != Vector2.INF and pts[i - 1] != Vector2.INF:
					t.line(pts[i - 1], pts[i], Palette.GOLD, 2.0)

## A rising zig-zag of rounds across the aim line, with a two-round gap.
func _plan_chart() -> void:
	_dir = to_player().normalized()
	_chart.clear()
	var n := 13 if phase == 1 else 15
	var gap := randi_range(2, n - 4)
	var rise := 0.0
	for i in n:
		var side := lerpf(-300.0, 300.0, float(i) / float(n - 1))
		rise += randf_range(-14.0, 30.0)
		_chart.append(Vector2(rise, side) if i != gap and i != gap + 1 else Vector2.INF)

func _chart_points() -> Array:
	var out: Array = []
	var side_axis := _dir.orthogonal()
	for p: Vector2 in _chart:
		if p == Vector2.INF:
			out.append(Vector2.INF)
		else:
			out.append(global_position + _dir * (60.0 + p.x) + side_axis * p.y)
	return out

func _fire_chart() -> void:
	var speed := 230.0 if phase == 1 else 270.0
	var loud := true
	for at in _chart_points():
		if at == Vector2.INF:
			continue
		var b := _fire_bullet(_dir, 1 + damage_bonus, speed, loud)
		loud = false
		if b:
			b.global_position = at
	if kit:
		kit.kick(1.0)
	Audio.play("stock_up", global_position, 2.0, 0.7)
	Audio.play("shot_lmg", global_position, -4.0, 0.7)

func on_phase(n: int) -> void:
	if n == 2 and margin:
		margin.active = true
	if n >= 2 and wall:
		wall.alarm = n >= 3
	if n == 3:
		var host := heist()
		if host:
			host.fx.chip(global_position, "LIQUIDATION" if not drain_disabled else "LIQUIDATION — BLOCKED BY THE BLACK LEDGER", Palette.DANGER)

func _die() -> void:
	if margin:
		margin.queue_free()
	if wall:
		wall.alarm = false
		wall.crashed = true
	super._die()


## The giant ticker board over the trading floor: venue tickers crawling, the
## Board's own price line, and LIQUIDATION in red once he is desperate.
class TickerWall extends Node2D:
	var width := 1100.0
	var alarm := false
	var crashed := false
	var _t := 0.0
	var _line: Array = []

	func _ready() -> void:
		z_index = 8
		material = StreetArt._unshaded()
		for i in 60:
			_line.append(0.5)

	func _process(delta: float) -> void:
		_t += delta
		if int(_t * 4.0) != int((_t - delta) * 4.0):
			var last: float = _line.back()
			var drift := -0.06 if crashed or alarm else 0.01
			_line.append(clampf(last + randf_range(-0.08, 0.08) + drift, 0.05, 0.95))
			_line.pop_front()
		queue_redraw()

	func _draw() -> void:
		var h := 70.0
		draw_rect(Rect2(-6, -6, width + 12, h + 12), Color(0.02, 0.02, 0.03))
		draw_rect(Rect2(0, 0, width, h), Color(0.05, 0.06, 0.07))
		var font := VisualTheme.font("mono")
		var tape := ""
		for id in Venues.DATA.keys():
			tape += "%s  " % Venues.ticker(id)
		var scroll := fmod(_t * 70.0, 600.0)
		var col := Palette.DANGER if alarm or crashed else Palette.UP
		draw_string(font, Vector2(8 - scroll, 22), tape + tape, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.with_alpha(col, 0.85))
		var pts := PackedVector2Array()
		for i in _line.size():
			pts.append(Vector2(width * i / float(_line.size() - 1), h - 6.0 - float(_line[i]) * 38.0))
		draw_polyline(pts, Palette.GOLD, 2.0, true)
		if alarm and int(_t * 3.0) % 2 == 0:
			draw_string(VisualTheme.font("heading_bold"), Vector2(width * 0.5 - 120, h - 12), "LIQUIDATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.DANGER)
		elif crashed:
			draw_string(VisualTheme.font("heading_bold"), Vector2(width * 0.5 - 140, h - 12), "TRADING HALTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.PAPER)


## Margin Call: the floor is cut into strips that follow a live price line.
## Strips under the margin line warn (orange) for a beat, then burn (red).
class MarginFloor extends Node2D:
	const STRIPS := 8
	const STEP := 0.9
	var arena := Rect2()
	var boss: Boss
	var active := false
	## Diplomatic Pouch sabotage: each hazard strip is only this wide.
	var hazard_scale := 1.0
	var prices: Array = []
	var state: Array = []          # 0 safe, 1 warning, 2 hazard
	var _clock := 0.0
	var _price := 0.0
	var _hurt := 0.0

	func _ready() -> void:
		z_index = -4
		material = StreetArt._unshaded()
		for i in STRIPS:
			prices.append(0.0)
			state.append(0)

	func _process(delta: float) -> void:
		if not active:
			return
		_clock -= delta
		if _clock <= 0.0:
			_clock = STEP
			_step()
		_hurt -= delta
		var host := get_tree().current_scene as HeistFloor
		if host and is_instance_valid(host.player) and _hurt <= 0.0:
			var p: Vector2 = host.player.global_position
			if arena.has_point(p) and state[strip_at(p.x)] == 2 and in_hazard(p.x):
				_hurt = 1.0
				host.player.last_hit_dir = Vector2.UP
				host.player.take_damage(1)
		queue_redraw()

	func strip_at(x: float) -> int:
		return clampi(int((x - arena.position.x) / (arena.size.x / STRIPS)), 0, STRIPS - 1)

	## Inside the burning part of a strip (the middle `hazard_scale` of it).
	func in_hazard(x: float) -> bool:
		var w := arena.size.x / STRIPS
		var centre := arena.position.x + (strip_at(x) + 0.5) * w
		return absf(x - centre) <= w * 0.5 * hazard_scale

	func strip_rect(i: int) -> Rect2:
		var w := arena.size.x / STRIPS
		var hw := w * hazard_scale
		return Rect2(arena.position.x + i * w + (w - hw) * 0.5, arena.position.y, hw, arena.size.y)

	## The price ticks; history slides one strip left; the three lowest strips
	## are under the margin line.
	func _step() -> void:
		_price += randf_range(-0.9, 0.9) - _price * 0.25
		prices.pop_front()
		prices.append(_price)
		var order: Array = range(STRIPS)
		order.sort_custom(func(a, b): return prices[a] < prices[b])
		var under: Array = order.slice(0, 3)
		for i in STRIPS:
			if i in under:
				state[i] = 2 if state[i] >= 1 else 1
			else:
				state[i] = 0

	func _draw() -> void:
		if not active:
			return
		var w := arena.size.x / STRIPS
		for i in STRIPS:
			var r := strip_rect(i)
			if state[i] == 1:
				draw_rect(r, Color(1.0, 0.55, 0.1, 0.16))
				draw_rect(r, Color(1.0, 0.55, 0.1, 0.5), false, 3.0)
			elif state[i] == 2:
				draw_rect(r, Color(0.9, 0.12, 0.1, 0.3))
				draw_rect(r, Color(1.0, 0.2, 0.15, 0.8), false, 3.0)
		# The live price line across the floor, and the margin line.
		var pts := PackedVector2Array()
		var lo: float = prices.min()
		var hi: float = prices.max()
		var span := maxf(hi - lo, 0.001)
		for i in STRIPS:
			var y := arena.end.y - 40.0 - (float(prices[i]) - lo) / span * (arena.size.y - 120.0)
			pts.append(Vector2(arena.position.x + (i + 0.5) * w, y))
		draw_polyline(pts, Palette.with_alpha(Palette.GOLD, 0.7), 4.0, true)
