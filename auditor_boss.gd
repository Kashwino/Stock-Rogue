extends Boss
class_name AuditorBoss
## THE AUDITOR (City). The Board's accountant keeps a desk between himself
## and you.
##   levy     a ring of rounds with one safe wedge (shown in green)
##   sweep    a laser line swept across the room (start line + arc shown first)
##   drones   launches surveillance drones (at most three up)
##   AUDIT    every so often his ledger opens: while it is up, every hit you
##            take crashes the stock twice as hard
##   P2 (50%) he teleports between the desks (the landing ring shows first)

const SWEEP_ARC := 1.9
const SWEEP_TIME := 1.3
const AUDIT_EVERY := 16.0
const AUDIT_LENGTH := 5.0

var desks: Array = []
var safe_angle := 0.0
var _sweep_from := 0.0
var _sweep_t := 0.0
var _sweep_dir := 1.0
var _sweep_hit := false
var _audit_clock := 6.0
var auditing := false
var _drone_clock := 4.0
var _blink_to := Vector2.ZERO
var _cycle := 0

## The look (also worn by the ally version in the finale).
static func look() -> Dictionary:
	return {"body": SpriteKit.Body.SUIT, "head": SpriteKit.Head.SLICKED, "gun": SpriteKit.Gun.LEDGER,
		"color": Color("2a2f3a"), "trim": Palette.GOLD, "skin": SpriteKit.SKIN[4], "hair": Color("8a8a8a"),
		"acc": ["pinstripe", "tie", "glasses"], "scale": 1.45}

func setup_boss() -> void:
	boss_id = &"auditor"
	display_name = "THE AUDITOR"
	subtitle = Story.BOSSES[&"auditor"][1]
	max_health = 110
	thresholds = [0.5]
	phase_lines = ["Let's go over these numbers again. Slowly."]
	move_speed = 110.0
	kit = SpriteKit.dress(sprite, look())

func begin_fight() -> void:
	var host := heist()
	if host:
		desks = host.place_desks(self, 3)
	attack = &"reposition"
	clock = 0.8

func _process(delta: float) -> void:
	if not intro_done or is_down():
		return
	# The ledger opens on its own clock, whatever he is doing.
	_audit_clock -= delta
	if _audit_clock <= 0.0:
		_set_audit(not auditing)
		_audit_clock = AUDIT_LENGTH if auditing else AUDIT_EVERY
	_drone_clock -= delta

func _set_audit(on: bool) -> void:
	auditing = on
	overhead.tag = "AUDIT IN PROGRESS" if on else ""
	overhead.tag_color = Palette.DANGER
	var host := heist()
	if host:
		host.set_audit(on)
		if on:
			host.boss_says(self, "Every hit goes in the ledger.")
			Audio.play("paper", global_position)

## Behind the desk that covers him best from the player.
func _desk_post() -> Vector2:
	var best := global_position
	var best_d := INF
	for d: Vector2 in desks:
		var behind := d + (d - _player.global_position).normalized() * 70.0
		var dist := behind.distance_to(global_position) * 0.4 + absf(behind.distance_to(_player.global_position) - 380.0)
		if dist < best_d:
			best_d = dist
			best = behind
	return best if arena.grow(-60).has_point(best) else arena.get_center()

func next_attack() -> void:
	telegraph_clear()
	queue_redraw()
	match attack:
		&"levy_wind":
			_levy()
			attack = &"recover"
			clock = 1.3 if phase == 1 else 0.9
			return
		&"sweep_wind":
			attack = &"sweep"
			_sweep_t = 0.0
			_sweep_hit = false
			clock = SWEEP_TIME + 0.05
			return
		&"blink_out":
			attack = &"blink_in"
			clock = 0.5
			return
		&"blink_in":
			global_position = _blink_to
			if kit:
				kit.modulate.a = 1.0
			Audio.play("cloak", global_position, -2.0, 0.7)
			attack = &"recover"
			clock = 0.4
			return
	_cycle += 1
	if _drone_clock <= 0.0 and _drone_count() < 3:
		_drone_clock = 14.0
		attack = &"drones"
		clock = 0.7
		return
	if phase >= 2 and _cycle % 3 == 0 and desks.size() > 1:
		attack = &"blink_out"
		clock = 0.35
		var options: Array = desks.duplicate()
		options.shuffle()
		var pick: Vector2 = options[0]
		_blink_to = pick + (pick - _player.global_position).normalized() * 70.0
		if not arena.grow(-60).has_point(_blink_to):
			_blink_to = pick
		return
	if _cycle % 2 == 0:
		attack = &"sweep_wind"
		clock = 0.85 if phase == 1 else 0.65
		_sweep_dir = 1.0 if randf() < 0.5 else -1.0
		_sweep_from = to_player().angle() - _sweep_dir * SWEEP_ARC * 0.5
		Audio.play("laser_charge", global_position, -4.0, 1.2)
	else:
		attack = &"levy_wind"
		clock = 0.8 if phase == 1 else 0.6
		safe_angle = to_player().angle() + randf_range(-1.2, 1.2)

func run_attack(delta: float) -> void:
	match attack:
		&"reposition", &"recover":
			face_player()
			var post := _desk_post()
			velocity = _steer_toward(post, move_speed) if global_position.distance_to(post) > 24.0 else velocity.lerp(Vector2.ZERO, 0.25)
		&"levy_wind", &"sweep_wind":
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			face_player()
			queue_redraw()
		&"sweep":
			velocity = Vector2.ZERO
			_sweep_t += delta
			var a := _sweep_from + _sweep_dir * SWEEP_ARC * clampf(_sweep_t / SWEEP_TIME, 0.0, 1.0)
			var dir := Vector2.from_angle(a)
			if sprite:
				sprite.rotation = a
			var from := global_position + dir * 36.0
			var to := ray_end(from, dir, 1400.0)
			var t := telegraph()
			t.clear()
			t.line(from, to, Palette.DANGER, 7.0)
			if not _sweep_hit and _near_segment(_player.global_position, from, to, 18.0):
				_sweep_hit = true
				melee(1 + damage_bonus, dir.orthogonal(), 0.0, 0.0, 200.0)
		&"drones":
			velocity = Vector2.ZERO
			if clock <= 0.05:
				summon(Enemy.Kind.DRONE, 2, 70.0)
				Audio.play("drone", global_position)
				attack = &"recover"
				clock = 0.8
		&"blink_out":
			velocity = Vector2.ZERO
			if kit:
				kit.modulate.a = clampf(clock / 0.35, 0.0, 1.0)
		&"blink_in":
			var t := telegraph()
			t.clear()
			t.ring(_blink_to, 46.0, Palette.NEON_CYAN, 1.0 - clock / 0.5)

func _near_segment(p: Vector2, a: Vector2, b: Vector2, r: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < r

func _drone_count() -> int:
	var n := 0
	for e in get_parent().get_children():
		if e is Enemy and e.kind == Enemy.Kind.DRONE and not e._dead:
			n += 1
	return n

func _levy() -> void:
	fire_ring(18 if phase == 2 else 14, 300.0 if phase == 2 else 240.0, safe_angle, 0.5)

func on_phase(_n: int) -> void:
	# The second act: the ledger slams open and two more desks are wheeled
	# in for him to hop between.
	_audit_clock = 0.5
	var host := heist()
	if host:
		desks += host.place_desks(self, 2, 3)

func _die() -> void:
	if auditing:
		_set_audit(false)
	super._die()

func _draw() -> void:
	if attack == &"levy_wind":
		draw_arc(Vector2.ZERO, 125.0, safe_angle + 0.5, safe_angle + TAU - 0.5, 48, Color(1.0, 0.28, 0.35, 0.8), 6.0)
		draw_arc(Vector2.ZERO, 125.0, safe_angle - 0.5, safe_angle + 0.5, 12, Color(0.35, 1.0, 0.6), 6.0)
	elif attack == &"sweep_wind":
		var start := Vector2.from_angle(_sweep_from)
		draw_line(start * 36.0, start * 520.0, Color(1.0, 0.22, 0.3, 0.8), 3.0)
		draw_arc(Vector2.ZERO, 180.0, _sweep_from, _sweep_from + _sweep_dir * SWEEP_ARC, 32, Color(1.0, 0.22, 0.3, 0.55), 4.0)
