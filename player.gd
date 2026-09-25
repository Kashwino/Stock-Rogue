extends CharacterBody2D
class_name Player

## Twin-stick player: WASD/arrows to move, aim toward mouse, click/hold to fire,
## Space/Shift to dodge-roll (i-frames). Tracks hits taken for the grade system.

signal health_changed(current: int, max: int)
signal died
signal hit_taken(remaining: int)

@export var move_speed: float = 220.0
@export var max_health: int = 6
@export var fire_rate: float = 0.34          # seconds between shots (fallback)
@export var bullet_scene: PackedScene        # assign Bullet.tscn in Inspector
@export var damage_bonus: int = 0
@export var spread_multiplier: float = 1.0
@export var reload_multiplier: float = 1.0
@export var dodge_speed: float = 520.0
@export var dodge_time: float = 0.25
@export var dodge_cooldown: float = 0.6

@onready var muzzle: Node2D = $Muzzle        # a Node2D child marking gun tip
@onready var sprite: Node2D = $Sprite        # your visual (Sprite2D/AnimatedSprite2D)

var health: int
var kit: SpriteKit = null
var _fire_timer: float = 0.0
var _dodging: bool = false
var _dodge_timer: float = 0.0
var _dodge_cd_timer: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _invulnerable: bool = false
var _mercy_timer := 0.0
var _dead: bool = false

# --- Grade-relevant run stats (read by the grader at level end) ---
var hits_taken: int = 0
## Set by whatever hits us (bullets, blasts) just before take_damage.
var last_hit_dir := Vector2.ZERO
var _knock := Vector2.ZERO
## Recent-fire bloom for the crosshair (0..1).
var bloom := 0.0
var _ghost_clock := 0.0
var _step_clock := 0.0
## Ghost-style silent movement (no footstep sound, no movement noise).
var silent_steps := false
## Body Armor: hits absorbed before health is touched.
var armor_charges := 0
## Hair Trigger: the next shot deals double (set by RelicHooks on reload).
var hair_trigger := false
## Seconds the trigger has been held (Tommy Gun tightens, Squad LMG steadies).
var _held_fire := 0.0
## Seconds since the last shot (Cold Feet).
var _since_shot := 99.0
## Burst Carbine: rounds left in the current burst.
var _burst_left := 0
var _burst_clock := 0.0
var _laser: Telegraph
var _slow_timer := 0.0
var _slow_mult := 1.0
var shots_fired: int = 0
var shots_hit: int = 0

## Optional live stock driver. Set by the heist setup; if null, calls are skipped.
var live_stock: LiveStock = null

## Weapon loadout. If null, falls back to the hardcoded fire_rate/bullet_scene.
var loadout: Loadout = null

## Assign the loadout AND hook its reload signals for the reload animation.
## RunState.apply_to_player uses this when available.
func attach_loadout(l: Loadout) -> void:
	loadout = l
	if l and not l.reload_started.is_connected(_on_reload_started):
		l.reload_started.connect(_on_reload_started)
	if l and not l.reload_finished.is_connected(_on_reload_finished):
		l.reload_finished.connect(_on_reload_finished)
	if l and not l.active_changed.is_connected(_on_active_weapon):
		l.active_changed.connect(_on_active_weapon)
	_refresh_kit()

func _on_active_weapon(_weapon: WeaponItem, _mag: int, _reserve: int) -> void:
	_refresh_kit()

## The character holds a silhouette that matches the equipped weapon.
func _refresh_kit() -> void:
	if sprite == null:
		return
	var profile_id: StringName = RunState.character_profile.id if RunState.character_profile else &"operator"
	var weapon: WeaponItem = loadout.get_active() if loadout else null
	kit = SpriteKit.dress(sprite, SpriteKit.hero_spec(profile_id, SpriteKit.gun_for(weapon)))

func _on_reload_started(duration: float) -> void:
	if kit:
		kit.reload_pose(duration)
	Audio.play("mag_out", global_position)

func _on_reload_finished() -> void:
	Audio.play("mag_in", global_position)

func _ready() -> void:
	_refresh_kit()
	silent_steps = RunState.profile_value("silent", false)
	z_index = 10
	add_to_group("player")
	# Player on layer 4; still collides with walls (layer 1) for movement.
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	_mercy_timer = maxf(_mercy_timer - delta, 0.0)
	bloom = maxf(bloom - delta * 2.5, 0.0)
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_dodge_cd_timer = maxf(_dodge_cd_timer - delta, 0.0)
	_slow_timer = maxf(_slow_timer - delta, 0.0)
	_since_shot += delta
	_tick_burst(delta)

	if _melee_left > 0.0:
		_process_melee(delta)
	elif _dodging:
		_process_dodge(delta)
	else:
		_process_move()
		_process_aim()
		_try_dodge()
		_try_fire()
		_update_melee(delta)

	if _knock.length() > 1.0:
		velocity += _knock
		_knock = _knock.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	move_and_slide()

func _process_move() -> void:
	var dir := TouchInput.movement()
	velocity = dir * move_speed * (_slow_mult if _slow_timer > 0.0 else 1.0) * _speed_factor()
	if dir.length() > 0.2:
		_step_clock -= get_physics_process_delta_time() * dir.length()
		if _step_clock <= 0.0:
			_step_clock = 0.34
			if not silent_steps:
				Audio.play("footstep", global_position)

## Controller aim: the right stick, or the way you're walking when it rests.
var _pad_aim := Vector2.RIGHT

func aim_direction() -> Vector2:
	if TouchInput.touch_active and Settings.values["touch_mode"] != 2:
		return TouchInput.aim
	if TouchInput.last_device == "pad":
		var stick := TouchInput.pad_aim()
		if stick != Vector2.ZERO:
			_pad_aim = stick
		elif TouchInput.movement().length() > 0.3:
			_pad_aim = TouchInput.movement().normalized()
		return _pad_aim
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction.length() > 1.0 else Vector2.RIGHT

func effective_fire_interval(weapon: WeaponItem) -> float:
	var interval := (weapon.fire_rate if weapon else 0.34) * fire_rate / 0.34
	if health == 1 and RunState.has_relic(&"adrenaline_futures"):
		interval /= 1.4
	if weapon and weapon.trait_id == &"desperate" and health <= 2:
		interval *= 0.7
	return maxf(interval, 0.035)

## Relics and traits that change how fast you move right now.
func _speed_factor() -> float:
	var f := 1.0
	if health == 1 and RunState.has_relic(&"adrenaline_futures"):
		f *= 1.15
	if RunState.has_relic(&"cold_feet") and _since_shot > 1.0:
		f *= 1.25
	var w: WeaponItem = loadout.get_active() if loadout else null
	if w and w.trait_id == &"steadies" and _held_fire > 0.0:
		f *= 0.8
	return f

func _process_aim() -> void:
	sprite.rotation = aim_direction().angle()
	muzzle.position = aim_direction() * 28.0
	_update_laser()

## Laser Sight: a thin red line from the muzzle to whatever it would hit.
func _update_laser() -> void:
	var w: WeaponItem = loadout.get_active() if loadout else null
	if w == null or not w.has_mod(&"laser_sight") or _dead:
		if _laser:
			_laser.clear()
		return
	if _laser == null:
		_laser = Telegraph.new()
		add_child(_laser)
	var from := muzzle.global_position
	var to := from + aim_direction() * 700.0
	var query := PhysicsRayQueryParameters2D.create(from, to, Layers.SOLID)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		to = hit["position"]
	_laser.clear()
	_laser.line(from, to, Color(1.0, 0.15, 0.15, 0.55), 1.0)

func _try_fire() -> void:
	# Swap weapon (Q) and reload (R) if a loadout exists.
	if loadout:
		if Input.is_action_just_pressed("swap_weapon"):
			loadout.cycle()
		if Input.is_action_just_pressed("reload"):
			loadout.reload()
	if _fire_timer > 0.0:
		return
	var firing := TouchInput.firing if TouchInput.touch_active and Settings.values["touch_mode"] != 2 else Input.is_action_pressed("fire")
	if firing:
		_held_fire += get_physics_process_delta_time()
	else:
		_held_fire = 0.0
	if not firing or bullet_scene == null:
		return

	# Hands are busy: no firing mid-reload.
	if loadout and loadout.reloading:
		return

	var weapon: WeaponItem = loadout.get_active() if loadout else null

	# Determine fire rate from weapon (or fallback).
	var rate := effective_fire_interval(weapon)
	_fire_timer = rate

	# Ammo check + consume (Lucky Casing: one in five shots is free).
	var last_round := false
	if loadout and weapon:
		var free: bool = RunState.has_relic(&"lucky_casing") and randf() < 0.2 and int(loadout._active_ammo()["mag"]) > 0
		if not free and not loadout.consume_round():
			# Out of ammo in mag: auto-reload attempt, no shot this press.
			if not loadout.reloading:
				Audio.play("dry_fire", global_position)
			loadout.reload()
			return
		last_round = int(loadout._active_ammo()["mag"]) == 0
	_spawn_bullet(weapon, last_round)
	# Burst Carbine: two more rounds follow on their own.
	if weapon and weapon.trait_id == &"burst":
		_burst_left = 2
		_burst_clock = 0.07
		_fire_timer += 0.14

func _tick_burst(delta: float) -> void:
	if _burst_left <= 0:
		return
	_burst_clock -= delta
	if _burst_clock > 0.0:
		return
	_burst_clock = 0.07
	_burst_left -= 1
	var weapon: WeaponItem = loadout.get_active() if loadout else null
	if weapon == null or weapon.trait_id != &"burst" or loadout.reloading or not loadout.consume_round():
		_burst_left = 0
		return
	_spawn_bullet(weapon)

func _spawn_bullet(weapon: WeaponItem = null, last_round := false) -> void:
	var aim := aim_direction()
	var pellets := weapon.pellets if weapon else 1
	var spread := (weapon.eff_spread() if weapon else 0.0) * spread_multiplier
	var dmg := (weapon.eff_damage() if weapon else 1) + damage_bonus
	var bspeed := weapon.bullet_speed if weapon else 600.0
	if weapon:
		match weapon.trait_id:
			&"tightens":
				if _held_fire > 0.5:
					spread *= 0.4
			&"steadies":
				spread *= lerpf(1.0, 0.3, clampf(_held_fire / 1.5, 0.0, 1.0))
			&"last_round":
				if last_round:
					dmg *= 3
	var crit_shot := false
	if hair_trigger:
		hair_trigger = false
		dmg *= 2
		crit_shot = true
	# The Wolf hits 25% harder; a fraction rounds up by chance.
	var mult: float = RunState.profile_value("damage_mult", 1.0)
	if mult != 1.0:
		var scaled := dmg * mult
		dmg = int(scaled) + (1 if randf() < fmod(scaled, 1.0) else 0)
	_since_shot = 0.0
	var shot := KillInfo.next_shot_id()

	for i in pellets:
		var b := BulletPool.take(self, bullet_scene)
		b.global_position = muzzle.global_position
		if "shot_id" in b:
			b.shot_id = shot
			b.origin = global_position
			b.crit_shot = crit_shot
			b.last_round = last_round
		var dir := aim
		if spread > 0.0:
			dir = aim.rotated(randf_range(-spread, spread))
		if weapon:
			b.pierce = weapon.pierce + (1 if RunState.has_relic(&"tracer_rounds") else 0)
			b.ricochets = weapon.ricochets
			b.knockback = weapon.knockback
			b.weapon = weapon
		if RunState.has_relic(&"stopping_power"):
			b.knockback = maxf(b.knockback, 45.0) * 1.8
			b.stagger = true
		# Apply weapon stats to the bullet if it supports them.
		if "damage" in b:
			b.damage = dmg
		if "speed" in b:
			b.speed = bspeed
		b.setup(dir, self)
	shots_fired += pellets
	bloom = minf(bloom + 0.35, 1.0)
	if kit:
		kit.kick(0.5 + 0.12 * pellets + 0.15 * dmg)
	var host := get_tree().current_scene
	if host is HeistFloor:
		var heft := clampf(0.05 + dmg * 0.025 + pellets * 0.018, 0.05, 0.3)
		host.fx.muzzle(muzzle.global_position, aim, pellets > 1 or dmg >= 3)
		host.fx.add_trauma(heft)
		host.fx.recoil(aim, 4.0 + heft * 30.0)
		host.fx.casing(global_position + aim * 10.0, aim)
	Audio.play(shot_sound(weapon), global_position)
	# Every shot is heard across the floor.
	if has_node("/root/Noise"):
		var loud: float = (weapon.eff_noise() if weapon else 900.0) * float(RunState.profile_value("gunshot_noise", 1.0))
		if RunState.has_relic(&"silent_partner"):
			loud *= 0.6
		get_node("/root/Noise").emit_noise(global_position, &"gunshot", loud)

# ----------------------------------------------------------------- melee ----
## The melee target in reach right now ([Enemy, Takedown mode] or empty) and
## the takedown in progress. See takedown.gd.
var melee_target: Array = []
var takedowns := 0
var _melee_scan := 0.0
var _melee_left := 0.0
var _melee_elapsed := 0.0
var _melee_victim: Enemy = null
var _melee_mode: StringName = &""
var _melee_spot := Vector2.ZERO
var _melee_struck := false
var _melee_was_invulnerable := false

func _update_melee(delta: float) -> void:
	_melee_scan -= delta
	if _melee_scan <= 0.0:
		_melee_scan = 0.08
		_set_melee_target(Takedown.find(self))
	if not melee_target.is_empty() and Input.is_action_just_pressed("melee"):
		start_melee(melee_target[0], melee_target[1])

func _set_melee_target(target: Array) -> void:
	if not melee_target.is_empty() and is_instance_valid(melee_target[0]) and (target.is_empty() or target[0] != melee_target[0]):
		melee_target[0].overhead.prompt = ""
	melee_target = target
	if not target.is_empty():
		var key := OnboardingHints.prompt("melee", TouchInput.device())
		target[0].overhead.prompt = "%s · %s" % [key, "TAKEDOWN" if target[1] == Takedown.STEALTH else "EXECUTE"]

## Begin a takedown on `victim` (mode: Takedown.STEALTH or EXECUTION).
func start_melee(victim: Enemy, mode: StringName) -> void:
	if victim == null or victim._dead or _melee_left > 0.0:
		return
	_set_melee_target([])
	_melee_victim = victim
	_melee_mode = mode
	_melee_left = Takedown.DURATION[mode]
	_melee_elapsed = 0.0
	_melee_struck = false
	_melee_spot = Takedown.strike_spot(victim, mode, global_position)
	_melee_was_invulnerable = _invulnerable
	_invulnerable = true
	victim.hold(_melee_left + 0.1)
	if sprite:
		sprite.rotation = (victim.global_position - global_position).angle()
	if mode == Takedown.STEALTH:
		Audio.play("dodge", global_position, -10.0, 1.3)

func _process_melee(delta: float) -> void:
	_melee_left -= delta
	_melee_elapsed += delta
	var to_spot := _melee_spot - global_position
	velocity = to_spot / maxf(delta, 0.001) * 0.25 if to_spot.length() > 2.0 else Vector2.ZERO
	velocity = velocity.limit_length(420.0)
	if is_instance_valid(_melee_victim) and sprite:
		sprite.rotation = (_melee_victim.global_position - global_position).angle()
	if not _melee_struck and _melee_elapsed >= Takedown.STRIKE_AT[_melee_mode]:
		_melee_struck = true
		_strike_melee()
	if _melee_left <= 0.0:
		_melee_left = 0.0
		velocity = Vector2.ZERO
		_invulnerable = _melee_was_invulnerable or _dodging
		_melee_victim = null

func _strike_melee() -> void:
	var v := _melee_victim
	if v == null or not is_instance_valid(v) or v._dead:
		return
	var dir := (v.global_position - global_position).normalized()
	v.shield_hp = 0
	var host := get_tree().current_scene
	if _melee_mode == Takedown.STEALTH:
		if kit:
			kit.kick(1.2)
		v.note_hit({"source": &"takedown", "stealth": true, "by_player": true, "dir": dir, "force": 20.0})
		v.take_damage(v.health)
	else:
		# Point-blank with whatever you're holding: loud unless suppressed.
		var weapon: WeaponItem = loadout.get_active() if loadout else null
		Audio.play(shot_sound(weapon), global_position)
		if host is HeistFloor:
			host.fx.muzzle(muzzle.global_position, dir, true)
			host.fx.recoil(dir, 8.0)
		if kit:
			kit.kick(1.0)
		var loud: float = (weapon.eff_noise() if weapon else 900.0) * float(RunState.profile_value("gunshot_noise", 1.0))
		if has_node("/root/Noise"):
			get_node("/root/Noise").emit_noise(global_position, &"gunshot", loud)
		v.note_hit({"source": &"execution", "by_player": true, "dir": dir, "force": 260.0, "weapon": weapon.id if weapon else &""})
		v.take_damage(v.health + 3)
		if loadout:
			loadout.refund_round()
			loadout.refund_round()
	takedowns += 1
	if host is HeistFloor:
		host.on_takedown(_melee_mode)

var _last_dodge_msec := -100000

## Mid-roll, or rolled within the last `seconds` (combo bonus).
func dodged_recently(seconds: float) -> bool:
	return _dodging or Time.get_ticks_msec() - _last_dodge_msec <= int((dodge_time + seconds) * 1000.0)

func is_busy_meleeing() -> bool:
	return _melee_left > 0.0

func _try_dodge() -> void:
	if _dodge_cd_timer > 0.0:
		return
	if Input.is_action_just_pressed("dodge"):
		var dir := TouchInput.movement()
		if dir == Vector2.ZERO:
			dir = aim_direction()
		_dodging = true
		_invulnerable = true
		_dodge_timer = dodge_time
		_last_dodge_msec = Time.get_ticks_msec()
		_dodge_dir = dir
		_ghost_clock = 0.0
		_dust_puff()
		Audio.play("dodge", global_position)
		# Diving across a room is audible, but only close by.
		if has_node("/root/Noise") and not RunState.has_perk(&"quiet_shoes") and not silent_steps:
			get_node("/root/Noise").sprint(global_position)

func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	velocity = _dodge_dir * dodge_speed
	_ghost_clock -= delta
	if _ghost_clock <= 0.0 and kit and not Settings.values["low_effects"]:
		_ghost_clock = 0.045
		_spawn_afterimage()
	if _dodge_timer <= 0.0:
		_dodging = false
		_invulnerable = false
		_dodge_cd_timer = dodge_cooldown

# --- Damage ---
func take_damage(amount: int = 1) -> void:
	# Once dead, nothing lands. Bullets already in flight would otherwise keep
	# hitting the corpse, driving health negative and re-crashing the stock.
	if _dead or _invulnerable or _mercy_timer > 0.0:
		return
	if armor_charges > 0:
		armor_charges -= 1
		Audio.play("deflect", global_position)
		if kit:
			kit.flash()
		_brief_iframes()
		var host := get_tree().current_scene
		if host is HeistFloor:
			host.fx.chip(global_position, "ARMOR", Palette.PAPER)
		return
	# Practice jobs are rehearsals: every hit still costs gold, grade and
	# stock, but nobody dies in a dry run.
	var floor_hp := 1 if RunFlow.practice else 0
	# Golden Parachute: once per run, a lethal hit leaves you at 1 HP.
	if health - amount <= 0 and not RunFlow.practice and RunState.has_relic(&"golden_parachute") and not RunState.parachute_used:
		RunState.parachute_used = true
		floor_hp = 1
		if live_stock:
			live_stock.report_shock(0.8, &"parachute")
		var host_p := get_tree().current_scene
		if host_p is HeistFloor:
			host_p.fx.chip(global_position, "GOLDEN PARACHUTE", Palette.GOLD)
	health = maxi(health - amount, floor_hp)
	hits_taken += amount
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.add_trauma(0.45)
		host.fx.hit_stop(0.05)
		host.gore.on_hit(global_position, last_hit_dir, 1, false, self)
		host.on_player_hurt()
	_knock = last_hit_dir * 260.0
	if kit:
		kit.flash()
	Audio.play("hurt")
	RunEconomy.on_player_hit(amount)      # currency drops on every hit
	if live_stock:
		live_stock.report_damage_taken(amount)   # stock crashes (bigger at low HP)
	health_changed.emit(health, max_health)
	hit_taken.emit(health)
	# The Wolf is loud about getting hurt: the whole floor hears it.
	if RunState.profile_value("noisy_when_hit", false) and has_node("/root/Noise"):
		get_node("/root/Noise").emit_noise(global_position, &"gunshot", 650.0)
	# Patch Kit (Connections): the first drop to 1 HP in a run heals 1.
	if health == 1 and max_health > 1 and RunState.has_perk(&"patch_kit") and not RunState.patch_used and not RunState.profile_value("no_healing", false):
		RunState.patch_used = true
		health = 2
		health_changed.emit(health, max_health)
		var host_k := get_tree().current_scene
		if host_k is HeistFloor:
			host_k.fx.chip(global_position, "PATCH KIT +1", Palette.UP)
	if health <= 0:
		_die()
	else:
		_brief_iframes()

## Staggered by a heavy blow: move at `mult` speed for `seconds`.
func apply_slow(mult: float, seconds: float) -> void:
	_slow_mult = minf(mult, _slow_mult) if _slow_timer > 0.0 else mult
	_slow_timer = maxf(_slow_timer, seconds)
	if kit:
		var tw := kit.create_tween()
		tw.tween_property(kit, "modulate", Color(0.6, 0.75, 1.3), 0.05)
		tw.tween_property(kit, "modulate", Color.WHITE, seconds)

## A shove (shield bash, charge) that overrides the default hit knockback.
func shove(push: Vector2) -> void:
	_knock = push

func _brief_iframes() -> void:
	# Short mercy invulnerability after a hit so you don't get chain-melted.
	_mercy_timer = 0.6

func _die() -> void:
	if _dead:
		return
	_dead = true
	_invulnerable = true
	set_physics_process(false)
	velocity = Vector2.ZERO
	# Turn off the body's collision so nothing can register another hit.
	# Deferred: this often runs from inside a collision callback.
	for c in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", true)
	Audio.play("death_player")
	died.emit()
	# Level controller listens for `died` to end the heist.

func is_dead() -> bool:
	return _dead

func register_hit_landed() -> void:
	shots_hit += 1                           # bullets call this on enemy hit
	if live_stock:
		live_stock.report_hit_landed()       # stock ticks up per bullet landed

func accuracy() -> float:
	return 0.0 if shots_fired == 0 else minf(float(shots_hit) / float(shots_fired), 1.0)


## A fading gold copy of the character left behind during a dodge roll.
func _spawn_afterimage() -> void:
	var host := get_parent()
	if host == null:
		return
	var ghost := Node2D.new()
	ghost.global_position = global_position
	ghost.rotation = sprite.global_rotation
	ghost.z_index = 9
	host.add_child(ghost)
	var copy := SpriteKit.new()
	copy.apply(kit.spec)
	copy.modulate = Color(1.0, 0.85, 0.4, 0.45)
	ghost.add_child(copy)
	copy.set_process(false)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ghost.queue_free)

func _dust_puff() -> void:
	if Settings.values["low_effects"] or get_parent() == null:
		return
	for i in 4:
		var puff := Polygon2D.new()
		var pts := PackedVector2Array()
		for k in 8:
			pts.append(Vector2.from_angle(TAU * k / 8.0) * randf_range(4, 7))
		puff.polygon = pts
		puff.color = Color(0.7, 0.68, 0.62, 0.4)
		puff.z_index = -1
		get_parent().add_child(puff)
		puff.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var drift := -_dodge_dir * randf_range(10, 30) + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "position", puff.position + drift, 0.4)
		tw.tween_property(puff, "scale", Vector2(2.2, 2.2), 0.4)
		tw.tween_property(puff, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(puff.queue_free)


## Gunshot sound by weapon class; suppressed guns get the "pfft".
static func shot_sound(weapon: WeaponItem) -> String:
	if weapon and weapon.noise_radius < 400.0:
		return "shot_silenced"
	match SpriteKit.gun_for(weapon):
		SpriteKit.Gun.REVOLVER: return "shot_revolver"
		SpriteKit.Gun.SMG: return "shot_smg"
		SpriteKit.Gun.RIFLE: return "shot_rifle"
		SpriteKit.Gun.LONG_RIFLE: return "shot_sniper"
		SpriteKit.Gun.SHOTGUN: return "shot_shotgun"
		SpriteKit.Gun.LMG: return "shot_lmg"
	return "shot_pistol"
