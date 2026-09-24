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

func _ready() -> void:
	_refresh_kit()
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

	if _dodging:
		_process_dodge(delta)
	else:
		_process_move()
		_process_aim()
		_try_dodge()
		_try_fire()

	if _knock.length() > 1.0:
		velocity += _knock
		_knock = _knock.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))
	move_and_slide()

func _process_move() -> void:
	var dir := TouchInput.movement()
	velocity = dir * move_speed

func aim_direction() -> Vector2:
	if TouchInput.touch_active and Settings.values["touch_mode"] != 2:
		return TouchInput.aim
	var direction := get_global_mouse_position() - global_position
	return direction.normalized() if direction.length() > 1.0 else Vector2.RIGHT

func effective_fire_interval(weapon: WeaponItem) -> float:
	return maxf((weapon.fire_rate if weapon else 0.34) * fire_rate / 0.34, 0.035)

func _process_aim() -> void:
	sprite.rotation = aim_direction().angle()
	muzzle.position = aim_direction() * 28.0

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
	if not firing or bullet_scene == null:
		return

	# Hands are busy: no firing mid-reload.
	if loadout and loadout.reloading:
		return

	var weapon: WeaponItem = loadout.get_active() if loadout else null

	# Determine fire rate from weapon (or fallback).
	var rate := effective_fire_interval(weapon)
	_fire_timer = rate

	# Ammo check + consume.
	if loadout and weapon:
		if not loadout.consume_round():
			# Out of ammo in mag: auto-reload attempt, no shot this press.
			loadout.reload()
			return

	_spawn_bullet(weapon)

func _spawn_bullet(weapon: WeaponItem = null) -> void:
	var aim := aim_direction()
	var pellets := weapon.pellets if weapon else 1
	var spread := (weapon.spread if weapon else 0.0) * spread_multiplier
	var dmg := (weapon.damage if weapon else 1) + damage_bonus
	var bspeed := weapon.bullet_speed if weapon else 600.0

	for i in pellets:
		var b := bullet_scene.instantiate()
		get_tree().current_scene.add_child(b)
		b.global_position = muzzle.global_position
		var dir := aim
		if spread > 0.0:
			dir = aim.rotated(randf_range(-spread, spread))
		b.setup(dir, self)
		if weapon:
			b.pierce = weapon.pierce
			b.ricochets = weapon.ricochets
			b.knockback = weapon.knockback
		# Apply weapon stats to the bullet if it supports them.
		if "damage" in b:
			b.damage = dmg
		if "speed" in b:
			b.speed = bspeed
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
	Sfx.play_sound("shot")
	# Every shot is heard across the floor.
	if has_node("/root/Noise"):
		get_node("/root/Noise").emit_noise(global_position, &"gunshot", weapon.noise_radius if weapon else 900.0)

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
		_dodge_dir = dir
		_ghost_clock = 0.0
		_dust_puff()
		# Diving across a room is audible, but only close by.
		if has_node("/root/Noise") and not RunState.has_perk(&"quiet_shoes"):
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
	# Practice jobs are rehearsals: every hit still costs gold, grade and
	# stock, but nobody dies in a dry run.
	health = maxi(health - amount, 1 if RunFlow.practice else 0)
	hits_taken += amount
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.add_trauma(0.45)
		host.fx.hit_stop(0.05)
		host.fx.blood(global_position, last_hit_dir)
		host.on_player_hurt()
	_knock = last_hit_dir * 260.0
	if kit:
		kit.flash()
	Sfx.play_sound("hit")
	RunEconomy.on_player_hit(amount)      # currency drops on every hit
	if live_stock:
		live_stock.report_damage_taken(amount)   # stock crashes (bigger at low HP)
	health_changed.emit(health, max_health)
	hit_taken.emit(health)
	if health <= 0:
		_die()
	else:
		_brief_iframes()

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
