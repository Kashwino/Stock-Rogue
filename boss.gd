extends Enemy
class_name Boss
## Stage boss framework. A boss waits in its arena until the player is inside;
## then the heist seals the doorways, pans the camera for a title card and the
## fight begins. Each boss is an attack state machine with telegraphs:
##   setup_boss()          name, health, look, phase thresholds and lines
##   begin_fight()         once the intro card is done
##   next_attack()         choose the next attack (sets `attack` and `clock`)
##   run_attack(delta)     drive the current attack; set velocity
##   on_phase(n)           arena change when phase n begins
## Health thresholds start new phases: brief invulnerability, one line of
## dialogue, an arena change. Health and damage scale with the quota block.
## Death: the heist runs the slow-mo, cash burst, stock shock and reward.

var boss_id: StringName = &""
var display_name := "THE BOSS"
var subtitle := ""
## Fractions of health where phase 2, 3... begin, descending.
var thresholds: Array = [0.5]
## One line per phase change (index 0 = entering phase 2).
var phase_lines: Array = []
var phase := 1
var engaged := false
var intro_done := false
var invulnerable := false
var attack: StringName = &"idle"
var clock := 1.0
## The arena (boss room) in world space.
var arena := Rect2()
## Extra bullet damage from the quota block.
var damage_bonus := 0
## Why the boss cannot be hurt right now ("" = he can), shown on the bar.
var immune_reason := ""
var _transition := 0.0

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	currency_value = 0
	sight_range = 1600.0
	setup_boss()
	var block: int = RunState.run_map.quota_block if RunState.run_map else 0
	max_health = int(round(max_health * (1.0 + 0.3 * block)))
	health = max_health
	damage_bonus = int(block / 2.0)

# ------------------------------------------------------------- overrides ----
func setup_boss() -> void:
	pass

func begin_fight() -> void:
	clock = 1.0

func next_attack() -> void:
	attack = &"idle"
	clock = 1.0

func run_attack(_delta: float) -> void:
	velocity = Vector2.ZERO

func on_phase(_n: int) -> void:
	pass

# ------------------------------------------------------------------ loop ----
func set_guard_room(rect: Rect2) -> void:
	super.set_guard_room(rect)
	arena = rect

func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _player == null or not is_instance_valid(_player):
		_acquire_player()
		return
	if not engaged:
		velocity = _steer_toward(_post, 70.0) if global_position.distance_to(_post) > 20.0 else Vector2.ZERO
		move_and_slide()
		# Engage once the player is properly inside, clear of the doorways.
		if arena.has_area() and arena.grow(-80.0).has_point(_player.global_position):
			engage()
		return
	wake_for(2.0)
	if not intro_done:
		velocity = Vector2.ZERO
		return
	if _transition > 0.0:
		_transition -= delta
		velocity = velocity.lerp(Vector2.ZERO, 0.3)
		move_and_slide()
		if _transition <= 0.0:
			invulnerable = false
		return
	_check_phase()
	clock -= delta
	run_attack(delta)
	if clock <= 0.0 and _transition <= 0.0:
		next_attack()
	move_and_slide()

## The player walked in: the heist seals the arena and plays the intro.
func engage() -> void:
	if engaged:
		return
	engaged = true
	hunting = true
	var host := heist()
	if host:
		host.start_boss_fight(self)
	else:
		finish_intro()

func finish_intro() -> void:
	intro_done = true
	begin_fight()

func _check_phase() -> void:
	var frac := float(health) / float(maxi(max_health, 1))
	var target := 1
	for i in thresholds.size():
		if frac <= float(thresholds[i]):
			target = i + 2
	if target > phase:
		phase = target
		_begin_transition()

func _begin_transition() -> void:
	invulnerable = true
	_transition = 1.3
	attack = &"idle"
	telegraph_clear()
	Audio.sting("boss_phase")
	Audio.set_boss_intensity(phase >= 2)
	var host := heist()
	var line: String = phase_lines[phase - 2] if phase - 2 < phase_lines.size() else ""
	if host:
		host.fx.add_trauma(0.35)
		host.boss_says(self, line)
	on_phase(phase)

func take_damage(amount: int = 1) -> void:
	if _dead:
		return
	if invulnerable or not intro_done or immune_reason != "":
		hit_info = {}
		var host := heist()
		if host and randf() < 0.35:
			host.fx.chip(global_position, "IMMUNE" if immune_reason != "" else "—", Palette.PAPER_DIM)
		Audio.play("deflect", global_position, -8.0)
		return
	super.take_damage(amount)

func _die() -> void:
	if _dead:
		return
	telegraph_clear()
	var host := heist()
	if host:
		host.on_boss_down(self)
	super._die()

## Bosses shrug off knockback and never go to sleep mid-fight.
func set_sleeping(value: bool) -> void:
	if engaged and value:
		return
	super.set_sleeping(value)

# --------------------------------------------------------------- helpers ----
func to_player() -> Vector2:
	return _player.global_position - global_position

func face_player() -> Vector2:
	var d := to_player().normalized()
	if sprite:
		sprite.rotation = d.angle()
	return d

## A random point inside the arena, `margin` from the walls.
func arena_point(margin: float = 110.0) -> Vector2:
	var r := arena.grow(-margin)
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))

## `count` rounds spread evenly across `spread` radians around `dir`.
func fire_fan(dir: Vector2, count: int, spread: float, speed: float, dmg: int = 1) -> void:
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		_fire_bullet(dir.rotated(t * spread), dmg + damage_bonus, speed, i == 0)
	if kit:
		kit.kick(1.2)
	Audio.play("shot_shotgun" if count > 3 else "shot_enemy", global_position, -2.0, 0.85)

## A ring of rounds with an optional safe gap centred on `gap_angle`.
func fire_ring(count: int, speed: float, gap_angle: float = INF, gap: float = 0.0, dmg: int = 1) -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		if gap > 0.0 and absf(angle_difference(a, gap_angle)) < gap:
			continue
		_fire_bullet(Vector2.from_angle(a), dmg + damage_bonus, speed, i == 0)
	Audio.play("shot_lmg", global_position, -3.0, 0.8)

## Warning lines for a fan about to be fired.
func telegraph_fan(dir: Vector2, count: int, spread: float, length: float, color: Color = Palette.DANGER) -> void:
	var t := telegraph()
	t.clear()
	for i in count:
		var k := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var d := dir.rotated(k * spread)
		t.line(global_position + d * 30.0, ray_end(global_position + d * 30.0, d, length), color, 1.5)

## Bring in helpers: they arrive hunting.
func summon(kind: int, count: int, radius: float = 90.0) -> Array:
	var out: Array = []
	var host := heist()
	if host == null:
		return out
	for i in count:
		var offset := Vector2.from_angle(TAU * i / maxf(count, 1) + randf() * 0.5) * radius
		var e := host.spawn_companion(self, kind, offset)
		if e:
			e.hunting = true
			out.append(e)
	return out

## Contact damage while charging.
func contact(dmg: int, dir: Vector2, knock: float = 320.0) -> bool:
	if global_position.distance_to(_player.global_position) < 52.0:
		melee(dmg + damage_bonus, dir, 0.0, 0.0, knock)
		return true
	return false
