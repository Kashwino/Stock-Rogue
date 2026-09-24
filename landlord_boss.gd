extends Boss
class_name LandlordBoss
## THE LANDLORD (Town). A shotgun bruiser in his rent office.
##   P1  shotgun volleys (cone telegraph) and calls two goons
##   P2  (50%) flips the tables into new cover; telegraphed straight charges
##       that smash through furniture and leave him dazed against a wall
##   P3  (20%) enraged: faster, wider volleys

var _volleys := 0
var _goons_called := -100.0
var _charge_dir := Vector2.RIGHT
var _hit := false
var _dir := Vector2.RIGHT

func setup_boss() -> void:
	boss_id = &"landlord"
	display_name = "THE LANDLORD"
	subtitle = Story.BOSSES[&"landlord"][1]
	max_health = 90
	thresholds = [0.5, 0.2]
	phase_lines = ["You're three months behind. Let's talk furniture.", "EVICTION NOTICE!"]
	move_speed = 95.0
	kit = SpriteKit.dress(sprite, {"body": SpriteKit.Body.TANK, "head": SpriteKit.Head.FEDORA, "gun": SpriteKit.Gun.SHOTGUN,
		"color": Color("5a3a2a"), "trim": Palette.GOLD, "hat": Color("3a2a20"), "band": Color("8a1f1f"),
		"skin": SpriteKit.SKIN[1], "acc": ["cigar", "gold_band"], "scale": 1.5})

func begin_fight() -> void:
	attack = &"recover"
	clock = 1.2

func _enraged() -> bool:
	return phase >= 3

func next_attack() -> void:
	telegraph_clear()
	var pace := 0.6 if _enraged() else 1.0
	if attack == &"volley_wind":
		attack = &"volley"
		clock = 0.01
		return
	if attack == &"charge":
		attack = &"dazed"          # ran out of steam in the open
		clock = 0.7
		return
	# Goons: at the start and again every ~18 s in the first phase.
	var now := Time.get_ticks_msec() / 1000.0
	if phase == 1 and now - _goons_called > 18.0 and _living_goons() < 2:
		attack = &"call"
		clock = 0.8
		return
	if phase >= 2 and randf() < 0.45:
		attack = &"charge_wind"
		clock = 0.8 * pace
		_charge_dir = face_player()
		return
	attack = &"volley_wind"
	clock = 0.55 * pace
	_volleys = 3 if not _enraged() else 4
	_dir = face_player()

func run_attack(delta: float) -> void:
	match attack:
		&"recover":
			face_player()
			velocity = _steer_toward(_player.global_position, move_speed) if to_player().length() > 220.0 else velocity.lerp(Vector2.ZERO, 0.2)
		&"volley_wind":
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			_dir = to_player().normalized()
			if sprite:
				sprite.rotation = _dir.angle()
			telegraph_fan(_dir, 5, 0.9 if not _enraged() else 1.1, 420.0)
		&"volley":
			telegraph_clear()
			fire_fan(_dir, 9 if _enraged() else 7, 0.9 if not _enraged() else 1.1, 360.0)
			var host := heist()
			if host:
				host.fx.add_trauma(0.25)
			_volleys -= 1
			if _volleys > 0:
				attack = &"volley_wind"
				clock = 0.32 if _enraged() else 0.45
				_dir = face_player()
			else:
				attack = &"recover"
				clock = 1.0 if _enraged() else 1.5
		&"call":
			velocity = Vector2.ZERO
			if clock <= 0.05:
				_goons_called = Time.get_ticks_msec() / 1000.0
				Audio.play("alert", global_position, 0.0, 0.7)
				var host := heist()
				if host:
					host.boss_says(self, "BOYS! Rent's due.")
				summon(Enemy.Kind.SHOTGUNNER if randf() < 0.5 else Enemy.Kind.GRUNT, 1, 120.0)
				summon(Enemy.Kind.GRUNT, 1, 120.0)
				attack = &"recover"
				clock = 1.2
		&"charge_wind":
			velocity = Vector2.ZERO
			if sprite:
				sprite.rotation = _charge_dir.angle()
			var t := telegraph()
			t.clear()
			t.line(global_position, ray_end(global_position, _charge_dir, 900.0), Palette.DANGER, 14.0)
			if clock <= 0.02:
				telegraph_clear()
				attack = &"charge"
				clock = 1.0
				_hit = false
				Audio.play("dodge", global_position, 4.0, 0.5)
		&"charge":
			velocity = _charge_dir * (600.0 if _enraged() else 520.0)
			if not _hit:
				_hit = contact(2, _charge_dir, 460.0)
			_smash_props()
			if get_slide_collision_count() > 0 and clock < 0.85:
				var host := heist()
				if host:
					host.fx.add_trauma(0.4)
				Audio.play("door_bang", global_position)
				attack = &"dazed"
				clock = 1.3
		&"dazed":
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			if clock <= 0.05:
				attack = &"recover"
				clock = 0.6

## A charging landlord goes through furniture, not around it.
func _smash_props() -> void:
	for i in get_slide_collision_count():
		var body := get_slide_collision(i).get_collider()
		if body is Prop and is_instance_valid(body):
			var host := heist()
			if host:
				host.fx.spark(body.global_position, -_charge_dir, Palette.SODIUM)
			body.queue_free()

func _living_goons() -> int:
	var n := 0
	for e in get_parent().get_children():
		if e is Enemy and e != self and not e._dead:
			n += 1
	return n

## P2: flip the tables — new cover springs up around the room.
func on_phase(n: int) -> void:
	if n == 2:
		var host := heist()
		if host:
			host.flip_tables(self, 4)
	elif n == 3 and kit:
		kit.modulate = Color(1.35, 0.8, 0.75)
		move_speed *= 1.25
