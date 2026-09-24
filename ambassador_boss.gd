extends Boss
class_name AmbassadorBoss
## THE AMBASSADOR (World). Diplomatic immunity is literal: her shield holds
## while any bodyguard stands. Put them down and she is fair game — until her
## second detail arrives (once).
##   rockets   a barrage of landing markers around you
##   fan       single gold-revolver shots between barrages
##   P2 (50%)  gold revolver fans: three wide volleys, lines shown first

const GUARDS := 3

var _guards: Array = []
var _waves_left := 1
var _return_clock := -1.0
var _fans := 0
var _dir := Vector2.RIGHT
var _cycle := 0

func setup_boss() -> void:
	boss_id = &"ambassador"
	display_name = "THE AMBASSADOR"
	subtitle = Story.BOSSES[&"ambassador"][1]
	max_health = 120
	thresholds = [0.5]
	phase_lines = ["Diplomacy has failed. How tiresome."]
	move_speed = 120.0
	kit = SpriteKit.dress(sprite, {"body": SpriteKit.Body.GOWN, "head": SpriteKit.Head.HAIR, "gun": SpriteKit.Gun.REVOLVER,
		"color": Color("6a1026"), "trim": Palette.GOLD, "hair": Color("1a1010"), "skin": SpriteKit.SKIN[2],
		"gun_accent": Palette.GOLD, "acc": ["sash"], "scale": 1.35})

func begin_fight() -> void:
	_call_detail()
	attack = &"reposition"
	clock = 1.0

func _call_detail() -> void:
	_guards = summon(Enemy.Kind.ENFORCER, GUARDS, 110.0)
	for g: Enemy in _guards:
		g.make_elite(&"veteran")
		g.elite_tag = "BODYGUARD"
		g.overhead.tag_color = Palette.GOLD
	_refresh_immunity()

func _refresh_immunity() -> void:
	var alive := 0
	for g in _guards:
		if is_instance_valid(g) and not g._dead:
			alive += 1
	var was := immune_reason != ""
	immune_reason = "DIPLOMATIC IMMUNITY" if alive > 0 else ""
	overhead.bubble = 1.0 if alive > 0 else 0.0
	if was and alive == 0:
		var host := heist()
		if host:
			host.fx.chip(global_position, "IMMUNITY REVOKED", Palette.GOLD)
			host.boss_says(self, "You'll hear from my government." if _waves_left > 0 else "No one is coming. Fine.")
		Audio.play("deflect", global_position, 0.0, 0.5)
		if _waves_left > 0:
			_return_clock = 14.0

func _process(delta: float) -> void:
	if not intro_done or _dead:
		return
	_refresh_immunity()
	if _return_clock > 0.0:
		_return_clock -= delta
		if _return_clock <= 0.0 and _waves_left > 0:
			_waves_left -= 1
			var host := heist()
			if host:
				host.boss_says(self, "Security! Again!")
			_call_detail()

func next_attack() -> void:
	telegraph_clear()
	if attack == &"fan_wind":
		fire_fan(_dir, 7, 1.2, 380.0)
		_fans -= 1
		if _fans > 0:
			attack = &"fan_wind"
			clock = 0.4
			_dir = face_player()
		else:
			attack = &"reposition"
			clock = 1.1
		return
	_cycle += 1
	if phase >= 2 and _cycle % 2 == 0:
		attack = &"fan_wind"
		clock = 0.45
		_fans = 3
		_dir = face_player()
		return
	if _cycle % 3 != 0:
		attack = &"rockets"
		clock = 0.9
	else:
		attack = &"pistol"
		clock = 1.4

func run_attack(_delta: float) -> void:
	var d := face_player()
	match attack:
		&"reposition":
			# Keeps her distance and circles; the detail does the close work.
			var want := global_position - d * 80.0 if to_player().length() < 340.0 else global_position + d.orthogonal() * 80.0
			velocity = _steer_toward(want, move_speed)
		&"rockets":
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			if clock <= 0.5 and clock + get_physics_process_delta_time() > 0.5:
				_barrage()
		&"pistol":
			velocity = _steer_toward(global_position + d.orthogonal() * 60.0, move_speed * 0.6)
			if fmod(clock, 0.45) < get_physics_process_delta_time():
				fire_fan(d, 1, 0.0, 520.0, 1)
		&"fan_wind":
			velocity = Vector2.ZERO
			_dir = d
			telegraph_fan(_dir, 7, 1.2, 420.0, Palette.GOLD)

## P2: the ballroom's chandeliers come down, and keep coming.
func on_phase(n: int) -> void:
	if n == 2:
		_chandeliers()

func _chandeliers() -> void:
	var host := heist()
	if host == null or _dead:
		return
	for i in 3:
		Blast.fuse(host, arena_point(140.0), 1.3 + i * 0.25, 75.0, 1 + damage_bonus, 2)
	Audio.play("door_bang", global_position, 0.0, 0.6)
	get_tree().create_timer(9.0, false).timeout.connect(_chandeliers)

## Rocket barrage: landing markers around the player, a beat to get clear.
func _barrage() -> void:
	var host := heist()
	if host == null:
		return
	Audio.play("throw", global_position, 2.0, 0.6)
	var count := 5 if phase == 1 else 6
	var center: Vector2 = _player.global_position
	for i in count:
		var at := center if i == 0 else center + Vector2.from_angle(TAU * i / (count - 1) + randf() * 0.4) * randf_range(90.0, 170.0)
		at = at.clamp(arena.position + Vector2(40, 40), arena.end - Vector2(40, 40))
		Blast.fuse(host, at, 1.1 + i * 0.08, 80.0, 1 + damage_bonus, 2)
