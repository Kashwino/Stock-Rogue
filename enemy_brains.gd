extends RefCounted
class_name EnemyBrains
## The newer guard archetypes. Each one has a readable telegraph and a counter:
##   Riot Shield   frontal shield (100°) turns slowly: flank him, or punish the bash
##   Grenadier     lobs grenades with a landing ring: keep moving
##   K9 Handler    releases a fast, fragile dog with a telegraphed lunge
##   Dog           crouch (lane shown) -> lunge -> recover
##   Security Tech runs for an alarm panel when provoked: priority target
##   Laser Sniper  1.2 s laser track, then a heavy shot: break line of sight
##   Bouncer       fists, a telegraphed charge lane, slows you on hit
##   Drone         hovers over furniture, fires bursts (walls still stop it)
##   Cleaner       cloaked until he fires


class Riot extends EnemyBrain:
	const ARC := 0.873          # half of the ~100° shield arc, radians
	const TURN := 1.9           # rad/s: slow enough to flank
	var facing := 0.0
	var state := 0              # 0 guard, 1 wind-up, 2 bash, 3 recover
	var clock := 0.0
	var bash_cd := 1.2
	var bash_dir := Vector2.RIGHT
	var landed := false

	func tick(_delta: float) -> void:
		if e._alert != Enemy.Alert.HUNTING and e.sprite:
			facing = e.sprite.rotation

	func deflects(dir: Vector2) -> bool:
		if state == 1 or state == 2:
			return false        # the shield swings aside for the bash
		return absf(angle_difference(facing, (-dir).angle())) < ARC

	func hunt(delta: float, sees: bool, to_player: Vector2, dist: float) -> bool:
		bash_cd -= delta
		match state:
			0:
				facing = rotate_toward(facing, to_player.angle(), TURN * delta)
				if dist > e.keep_distance:
					e.velocity = e._steer_toward(e._player.global_position, e.move_speed)
				else:
					e.velocity = e.velocity.lerp(Vector2.ZERO, 0.25)
				if sees and dist < 130.0 and bash_cd <= 0.0:
					state = 1
					clock = 0.45
					bash_dir = to_player.normalized()
				e._fire_timer = maxf(e._fire_timer - delta, 0.0)
				# Fires around the shield only when squared up.
				if sees and dist <= e.fire_range and e._fire_timer <= 0.0 and absf(angle_difference(facing, to_player.angle())) < 0.3:
					e._fire_timer = e.fire_rate
					e._shoot(Vector2.from_angle(facing))
			1:
				facing = bash_dir.angle()
				e.velocity = e.velocity.lerp(Vector2.ZERO, 0.3)
				clock -= delta
				var t := e.telegraph()
				t.clear()
				t.line(e.global_position, e.global_position + bash_dir * 120.0, Palette.DANGER, 5.0)
				if clock <= 0.0:
					state = 2
					clock = 0.22
					landed = false
					Audio.play("dodge", e.global_position, 0.0, 0.7)
			2:
				e.velocity = bash_dir * 440.0
				clock -= delta
				if not landed and dist < 46.0:
					landed = true
					e.melee(1, bash_dir, 0.0, 0.0, 340.0)
				if clock <= 0.0:
					state = 3
					clock = 0.6
			3:
				e.velocity = e.velocity.lerp(Vector2.ZERO, 0.3)
				clock -= delta
				if clock <= 0.0:
					state = 0
					bash_cd = 2.4
		if state != 1:
			e.telegraph_clear()
		e.sprite.rotation = facing
		return true


class Grenadier extends EnemyBrain:
	var throw_cd := 1.0

	func hunt(delta: float, sees: bool, to_player: Vector2, dist: float) -> bool:
		e.sprite.rotation = to_player.angle()
		e.keep_range(to_player, dist, e.keep_distance * 0.7, e.fire_range * 0.85)
		throw_cd -= delta
		if sees and throw_cd <= 0.0 and dist <= e.fire_range and dist > 110.0:
			throw_cd = e.fire_rate
			var lead: Vector2 = e._player.velocity * 0.25
			e.throw_grenade(e._player.global_position + lead)
		return true


class Handler extends EnemyBrain:
	var dog: Enemy = null
	var _spawned := false

	func tick(_delta: float) -> void:
		if _spawned:
			return
		_spawned = true
		var host := e.heist()
		if host == null:
			return
		dog = host.spawn_companion(e, Enemy.Kind.DOG, Vector2(-34, 26))
		if dog and dog.brain:
			dog.brain.handler = e
			if e._provoked:
				dog.hunting = true

	func on_provoked() -> void:
		if is_instance_valid(dog) and not dog._dead:
			dog._provoked = true
			Audio.play("dog_bark", dog.global_position)

	func on_death() -> void:
		if is_instance_valid(dog) and not dog._dead:
			dog.hunting = true


class Dog extends EnemyBrain:
	var handler: Enemy = null
	var state := 0              # 0 run, 1 crouch, 2 lunge, 3 recover
	var clock := 0.0
	var cd := 0.4
	var lunge_dir := Vector2.RIGHT
	var bit := false

	func calm(_delta: float) -> bool:
		if e._provoked or not is_instance_valid(handler) or handler._dead:
			return false
		# At heel until released.
		var heel := handler.global_position + Vector2.from_angle(handler.sprite.rotation + 2.3) * 36.0
		if e.global_position.distance_to(heel) > 18.0:
			e.velocity = e._steer_toward(heel, handler.move_speed + 60.0)
		else:
			e.velocity = e.velocity.lerp(Vector2.ZERO, 0.3)
		e.sprite.rotation = handler.sprite.rotation
		return true

	func on_provoked() -> void:
		if is_instance_valid(handler) and not handler._dead:
			handler._provoked = true

	func hunt(delta: float, sees: bool, to_player: Vector2, dist: float) -> bool:
		cd -= delta
		match state:
			0:
				e.sprite.rotation = to_player.angle()
				e.velocity = e._steer_toward(e._player.global_position, e.move_speed)
				if sees and dist < e.fire_range and cd <= 0.0:
					state = 1
					clock = 0.4
					lunge_dir = to_player.normalized()
					Audio.play("dog_bark", e.global_position)
			1:
				e.velocity = Vector2.ZERO
				clock -= delta
				var t := e.telegraph()
				t.clear()
				t.line(e.global_position, e.global_position + lunge_dir * 165.0, Palette.ENEMY_BULLET, 3.0)
				if clock <= 0.0:
					state = 2
					clock = 0.3
					bit = false
			2:
				e.velocity = lunge_dir * 560.0
				clock -= delta
				if not bit and dist < 38.0:
					bit = true
					e.melee(1, lunge_dir, 0.0, 0.0, 180.0)
				if clock <= 0.0:
					state = 3
					clock = 0.7
			3:
				e.velocity = e.velocity.lerp(Vector2.ZERO, 0.25)
				clock -= delta
				if clock <= 0.0:
					state = 0
					cd = e.fire_rate
		if state != 1:
			e.telegraph_clear()
		return true


class Tech extends EnemyBrain:
	var panel: SecurityDevice = null
	var running := false
	var done := false
	var drone_out := false
	var _check := 0.0
	var _last_dist := INF
	var _stuck := 0

	func on_provoked() -> void:
		var host := e.heist()
		if host == null:
			return
		if not drone_out and host.stage_index() >= 1:
			drone_out = true
			# Deferred: provocation often arrives inside a physics callback.
			_deploy_drone.call_deferred()
		if not done:
			panel = host.nearest_alarm_panel(e.global_position)
			running = panel != null
			e.overhead.alarm = running
			if running:
				Audio.play("beep", e.global_position)

	func _deploy_drone() -> void:
		var host := e.heist() if is_instance_valid(e) and not e._dead else null
		if host == null:
			return
		var drone := host.spawn_companion(e, Enemy.Kind.DRONE, Vector2(0, -34))
		if drone:
			drone.hunting = true
			Audio.play("drone", drone.global_position)

	func _give_up() -> void:
		running = false
		e.overhead.alarm = false

	func _run(delta: float) -> bool:
		if done or not running:
			return false
		if not is_instance_valid(panel) or panel.disabled:
			var host := e.heist()
			panel = host.nearest_alarm_panel(e.global_position) if host else null
			if panel == null:
				_give_up()
				return false
		var to: Vector2 = panel.global_position - e.global_position
		e.sprite.rotation = to.angle()
		if to.length() < 56.0:
			done = true
			_give_up()
			e.velocity = Vector2.ZERO
			var host := e.heist()
			if host:
				host.raise_alarm("Security tech hit the alarm", panel)
			return true
		# Whisker steering has no pathfinding: a tech who makes no progress
		# for a few seconds gives up and hides instead.
		_check -= delta
		if _check <= 0.0:
			_check = 1.0
			if to.length() > _last_dist - 20.0:
				_stuck += 1
				if _stuck >= 3:
					_give_up()
					return false
			else:
				_stuck = 0
			_last_dist = to.length()
		e.velocity = e._steer_toward(panel.global_position, e.move_speed)
		return true

	func calm(delta: float) -> bool:
		return _run(delta)

	func hunt(delta: float, _sees: bool, to_player: Vector2, dist: float) -> bool:
		if _run(delta):
			return true
		# Nothing left to run for: stay away from the gun.
		e.sprite.rotation = to_player.angle()
		if dist < e.keep_distance:
			e.velocity = e._steer_toward(e.global_position - to_player.normalized() * 220.0, e.move_speed)
		else:
			e.velocity = e.velocity.lerp(Vector2.ZERO, 0.25)
		return true

	func on_death() -> void:
		e.overhead.alarm = false


class Sniper extends EnemyBrain:
	const AIM_TIME := 1.2
	const LOCK_AT := 1.02       # the last beat is locked: dodge now
	var aim := 0.0
	var cd := 0.6
	var locked := Vector2.RIGHT

	func hunt(delta: float, sees: bool, to_player: Vector2, dist: float) -> bool:
		cd -= delta
		if sees and dist <= e.fire_range and cd <= 0.0:
			if aim == 0.0:
				Audio.play("laser_charge", e.global_position)
			aim += delta
			if aim < LOCK_AT:
				locked = to_player.normalized()
			e.sprite.rotation = locked.angle()
			e.velocity = e.velocity.lerp(Vector2.ZERO, 0.3)
			var from := e.global_position + locked * 30.0
			var t := e.telegraph()
			t.clear()
			var col := Color.WHITE if aim >= LOCK_AT else Palette.DANGER
			t.line(from, e.ray_end(from, locked, e.fire_range + 80.0), col, 1.2 + aim / AIM_TIME * 2.4)
			if aim >= AIM_TIME:
				aim = 0.0
				cd = e.fire_rate
				e.telegraph_clear()
				e._fire_bullet(locked, e.bullet_damage, e.bullet_speed)
				Audio.play("shot_sniper", e.global_position, -4.0)
				if e.kit:
					e.kit.kick(1.4)
			return true
		# Line of sight broken: the shot is cancelled.
		aim = 0.0
		e.telegraph_clear()
		e.sprite.rotation = to_player.angle()
		e.keep_range(to_player, dist, e.keep_distance * 0.6, e.fire_range * 0.9)
		return true


class Bouncer extends EnemyBrain:
	var state := 0              # 0 close in, 1 wind-up, 2 charge, 3 dazed
	var clock := 0.0
	var dir := Vector2.RIGHT
	var cd := 1.2
	var punch_cd := 0.0
	var landed := false

	func hunt(delta: float, sees: bool, to_player: Vector2, dist: float) -> bool:
		cd -= delta
		punch_cd -= delta
		match state:
			0:
				e.sprite.rotation = to_player.angle()
				if dist > 40.0:
					e.velocity = e._steer_toward(e._player.global_position, e.move_speed)
				else:
					e.velocity = e.velocity.lerp(Vector2.ZERO, 0.4)
				if dist < 54.0 and punch_cd <= 0.0:
					punch_cd = e.fire_rate
					if e.kit:
						e.kit.kick(1.3)
					Audio.play("punch", e.global_position)
					e.melee(1, to_player.normalized(), 0.6, 0.8, 200.0)
				elif sees and dist > 120.0 and dist < e.fire_range and cd <= 0.0:
					state = 1
					clock = 0.6
					dir = to_player.normalized()
			1:
				e.velocity = Vector2.ZERO
				e.sprite.rotation = dir.angle()
				clock -= delta
				var t := e.telegraph()
				t.clear()
				var lane_end := e.ray_end(e.global_position, dir, 360.0)
				t.line(e.global_position, lane_end, Palette.DANGER, 10.0)
				if clock <= 0.0:
					state = 2
					clock = 0.5
					landed = false
					Audio.play("dodge", e.global_position, 2.0, 0.55)
			2:
				e.velocity = dir * 470.0
				clock -= delta
				if not landed and dist < 48.0:
					landed = true
					Audio.play("punch", e.global_position, 2.0, 0.8)
					e.melee(1, dir, 0.5, 1.2, 380.0)
				if clock <= 0.0 or (clock < 0.4 and e.get_slide_collision_count() > 0):
					state = 3
					clock = 0.8 if landed else 1.1
			3:
				e.velocity = e.velocity.lerp(Vector2.ZERO, 0.35)
				clock -= delta
				if clock <= 0.0:
					state = 0
					cd = 2.6
		if state != 1:
			e.telegraph_clear()
		return true


class Drone extends EnemyBrain:
	var orbit := 1.0
	var burst := 0
	var burst_clock := 0.0

	func setup() -> void:
		orbit = 1.0 if randf() < 0.5 else -1.0

	func solid_mask() -> int:
		return Layers.WALLS

	func hunt(delta: float, sees: bool, to_player: Vector2, dist: float) -> bool:
		var n := to_player.normalized()
		e.sprite.rotation = n.angle()
		var want := Vector2(-n.y, n.x) * orbit * 0.8
		if dist > e.keep_distance + 60.0:
			want += n
		elif dist < e.keep_distance - 60.0:
			want -= n
		e.velocity = e.velocity.lerp(want.normalized() * e.move_speed, 0.08)
		if e.get_slide_collision_count() > 0:
			orbit = -orbit
		e._fire_timer = maxf(e._fire_timer - delta, 0.0)
		if burst > 0:
			burst_clock -= delta
			if burst_clock <= 0.0:
				burst -= 1
				burst_clock = 0.11
				e._shoot(n)
		elif sees and dist <= e.fire_range and e._fire_timer <= 0.0:
			burst = 3
			burst_clock = 0.0
			e._fire_timer = e.fire_rate
		return true


class Cleaner extends EnemyBrain:
	var reveal := 0.0
	var burst := 0
	var burst_clock := 0.0
	var strafe := 1.0
	var _t := 0.0

	func setup() -> void:
		strafe = 1.0 if randf() < 0.5 else -1.0

	func tick(delta: float) -> void:
		_t += delta
		var was := reveal > 0.0
		reveal = maxf(reveal - delta, 0.0)
		if was and reveal <= 0.0:
			Audio.play("cloak", e.global_position, -6.0, 1.3)
		var target := 1.0 if reveal > 0.0 else 0.09 + 0.05 * sin(_t * 11.0)
		if e.kit:
			e.kit.modulate.a = lerpf(e.kit.modulate.a, target, 0.25)
			e.self_modulate.a = e.kit.modulate.a     # an elite glow must not give him away
		e.overhead.visible = reveal > 0.0

	func on_hurt() -> void:
		_reveal(1.0)

	func _reveal(seconds: float) -> void:
		if reveal <= 0.0:
			Audio.play("cloak", e.global_position, -4.0)
		reveal = maxf(reveal, seconds)

	func hunt(delta: float, sees: bool, to_player: Vector2, dist: float) -> bool:
		var n := to_player.normalized()
		e.sprite.rotation = n.angle()
		# Flanks: circles at mid range instead of walking straight in.
		var want := Vector2(-n.y, n.x) * strafe
		if dist > e.keep_distance + 80.0:
			want = (want * 0.4 + n).normalized()
		elif dist < e.keep_distance - 60.0:
			want = (want * 0.4 - n).normalized()
		e.velocity = e._steer_toward(e.global_position + want * 90.0, e.move_speed)
		if e.get_slide_collision_count() > 0 and randf() < 0.05:
			strafe = -strafe
		e._fire_timer = maxf(e._fire_timer - delta, 0.0)
		if burst > 0:
			burst_clock -= delta
			if burst_clock <= 0.0:
				burst -= 1
				burst_clock = 0.09
				e._shoot(n)
				_reveal(1.8)
		elif sees and dist <= e.fire_range and e._fire_timer <= 0.0:
			burst = 3
			burst_clock = 0.25       # a beat after decloaking before the first round
			e._fire_timer = e.fire_rate
			_reveal(1.8)
		return true
