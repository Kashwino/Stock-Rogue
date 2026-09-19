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

func _on_reload_started(duration: float) -> void:
	# Placeholder reload animation: the sprite squashes, then pops back with a
	# spin — reads clearly as "hands off the trigger" until real art exists.
	if sprite == null or Settings.values["low_effects"]:
		return
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2(0.65, 0.65), duration * 0.35)
	tw.parallel().tween_property(sprite, "rotation",
		sprite.rotation + TAU, duration * 0.9)
	tw.tween_property(sprite, "scale", Vector2.ONE, duration * 0.55) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _ready() -> void:
	add_to_group("player")
	# Player on layer 4; still collides with walls (layer 1) for movement.
	collision_layer = 4
	collision_mask = 1
	health = max_health
	health_changed.emit(health, max_health)

func _physics_process(delta: float) -> void:
	_mercy_timer = maxf(_mercy_timer - delta, 0.0)
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	_dodge_cd_timer = maxf(_dodge_cd_timer - delta, 0.0)

	if _dodging:
		_process_dodge(delta)
	else:
		_process_move()
		_process_aim()
		_try_dodge()
		_try_fire()

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
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.muzzle(muzzle.global_position, aim)
		host.fx.shake(2.0 if pellets <= 1 else 4.0)
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
		# Diving across a room is audible, but only close by.
		if has_node("/root/Noise") and not RunState.has_perk(&"quiet_shoes"):
			get_node("/root/Noise").sprint(global_position)

func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	velocity = _dodge_dir * dodge_speed
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
	health = maxi(health - amount, 0)
	hits_taken += amount
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.shake(9.0)
	if not Settings.values["low_effects"]:
		sprite.modulate = Color(2.0, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)
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
