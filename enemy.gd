extends CharacterBody2D
class_name Enemy

## A guard. Chases and shoots the player, takes damage, dies.
## Must be in the "enemies" group (added in _ready).
##
## ROLES:
##   PATROL  — investigates noises, then returns to its post.
##   SENTRY  — guards valuables and NEVER leaves its post. It will shoot at
##             anything it can see, but it won't walk off to chase a sound.
##
## ALERT STATES:
##   IDLE          holding post, unaware
##   INVESTIGATING heard something, walking to where the noise came from
##   HUNTING       has seen the player; chases and shoots
## A guard that loses the player relaxes back to INVESTIGATING, then IDLE.

signal died(enemy: Enemy)

enum Role { PATROL, SENTRY }
enum Alert { IDLE, INVESTIGATING, HUNTING }

## Guard archetypes. Applied via apply_archetype(); each one retunes health,
## weapon behaviour and movement so a building has a readable mix of threats
## rather than fifteen identical shooters. SPRINTER, TURRET and MEDIC also get
## distinct MOVEMENT behaviour, not just different numbers — see _do_hunt.
enum Kind { GRUNT, ENFORCER, SHOTGUNNER, MARKSMAN, BRUTE, SPRINTER, TURRET, MEDIC }

const ARCHETYPES := {
	Kind.GRUNT: {
		"health": 3, "speed": 90.0, "fire_rate": 1.2, "range": 400.0,
		"keep": 180.0, "damage": 1, "pellets": 1, "spread": 0.05,
		"bullet_speed": 320.0, "colour": Color(0.85, 0.35, 0.35),
	},
	Kind.ENFORCER: {   # steady rifle fire, pushes in
		"health": 5, "speed": 105.0, "fire_rate": 0.75, "range": 480.0,
		"keep": 200.0, "damage": 1, "pellets": 1, "spread": 0.03,
		"bullet_speed": 400.0, "colour": Color(0.95, 0.55, 0.2),
	},
	Kind.SHOTGUNNER: { # deadly close, harmless far — forces you to keep distance
		"health": 4, "speed": 120.0, "fire_rate": 1.6, "range": 240.0,
		"keep": 90.0, "damage": 1, "pellets": 5, "spread": 0.30,
		"bullet_speed": 340.0, "colour": Color(0.9, 0.75, 0.25),
	},
	Kind.MARKSMAN: {   # slow, accurate, long range; hangs back
		"health": 2, "speed": 70.0, "fire_rate": 2.2, "range": 700.0,
		"keep": 420.0, "damage": 2, "pellets": 1, "spread": 0.0,
		"bullet_speed": 620.0, "colour": Color(0.55, 0.75, 1.0),
	},
	Kind.BRUTE: {      # slow tank, hits hard, soaks a magazine
		"health": 10, "speed": 62.0, "fire_rate": 1.9, "range": 300.0,
		"keep": 60.0, "damage": 2, "pellets": 3, "spread": 0.18,
		"bullet_speed": 280.0, "colour": Color(0.65, 0.3, 0.75),
	},
	Kind.SPRINTER: {   # hit-and-run: dashes in close, fires, then bolts back out
		"health": 3, "speed": 175.0, "fire_rate": 1.1, "range": 260.0,
		"keep": 140.0, "damage": 1, "pellets": 1, "spread": 0.08,
		"bullet_speed": 360.0, "colour": Color(0.95, 0.35, 0.65),
	},
	Kind.TURRET: {     # never moves an inch, but hits hard and far — a threat
		"health": 6, "speed": 0.0, "fire_rate": 1.0, "range": 620.0,
		"keep": 0.0, "damage": 2, "pellets": 1, "spread": 0.02,
		"bullet_speed": 480.0, "colour": Color(0.6, 0.62, 0.68),
	},
	Kind.MEDIC: {      # weak and unarmed-ish; heals allies, runs from a fight
		"health": 3, "speed": 100.0, "fire_rate": 1.8, "range": 260.0,
		"keep": 260.0, "damage": 1, "pellets": 1, "spread": 0.1,
		"bullet_speed": 300.0, "colour": Color(0.5, 0.95, 0.65),
	},
}

@export var move_speed: float = 90.0
@export var max_health: int = 3
@export var fire_rate: float = 1.2           # seconds between shots
@export var fire_range: float = 400.0        # only shoots if player within range
@export var keep_distance: float = 180.0     # tries to hold this gap
@export var contact_damage: int = 1
@export var currency_value: int = 15         # currency awarded to the player on death
@export var sight_range: float = 420.0       # sees the player this far, line-of-sight
@export var hearing_multiplier: float = 1.0  # scales how far this guard hears
@export var role: Role = Role.PATROL
@export var enemy_bullet_scene: PackedScene  # assign EnemyBullet.tscn

## Weapon shape, set by the archetype.
var bullet_damage: int = 1
var pellets: int = 1
var spread: float = 0.05
var bullet_speed: float = 320.0
var kind: Kind = Kind.GRUNT

## Apply an archetype's stats. Call BEFORE the node enters the tree if possible;
## it also refreshes health so it works after _ready().
func apply_archetype(k: Kind) -> void:
	kind = k
	var a: Dictionary = ARCHETYPES[k]
	max_health = a["health"]
	health = max_health
	move_speed = a["speed"]
	fire_rate = a["fire_rate"]
	fire_range = a["range"]
	keep_distance = a["keep"]
	bullet_damage = a["damage"]
	pellets = a["pellets"]
	spread = a["spread"]
	bullet_speed = a["bullet_speed"]
	# Marksmen are watchful; brutes are half-deaf.
	match k:
		Kind.MARKSMAN:
			sight_range = 720.0
			hearing_multiplier = 1.2
		Kind.BRUTE:
			hearing_multiplier = 0.7
		Kind.TURRET:
			sight_range = 620.0
			hearing_multiplier = 0.0      # can't hear a thing, must be seen
		Kind.MEDIC:
			hearing_multiplier = 1.4      # skittish, notices everything
		Kind.SPRINTER:
			hearing_multiplier = 1.1
		_:
			pass
	_apply_archetype_visual()

## Sprite is @onready, so archetypes applied before the node is in the tree
## must defer their visual change until _ready().
func _apply_archetype_visual() -> void:
	if sprite == null:
		return
	var a: Dictionary = ARCHETYPES[kind]
	if sprite is CanvasItem:
		sprite.modulate = a["colour"]
	var scale_mult := 1.0
	match kind:
		Kind.BRUTE: scale_mult = 1.35
		Kind.TURRET: scale_mult = 1.15    # reads as a fixed emplacement
		Kind.MEDIC: scale_mult = 0.9      # smaller, clearly non-frontline
	sprite.scale = Vector2.ONE * scale_mult

## Reinforcements are spawned with hunting = true: they always know where you
## are and never idle.
var hunting: bool = false:
	set(value):
		hunting = value
		if value:
			_alert = Alert.HUNTING
			_provoked = true

@onready var sprite: Node2D = $Sprite
@onready var muzzle: Node2D = $Muzzle

var health: int
var _player: Node2D = null
var _fire_timer: float = 0.0
var _dead: bool = false
var sleeping := false
var wake_until_msec: int = 0
var _director: EnemyDirector = null

func set_sleeping(value: bool) -> void:
	if _dead:
		return
	sleeping = value
	set_physics_process(not value)
	if value:
		velocity = Vector2.ZERO

func wake_for(seconds: float = 2.0) -> void:
	wake_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	set_sleeping(false)

func _exit_tree() -> void:
	if is_instance_valid(_director):
		_director.unregister(self)


var _alert: int = Alert.IDLE
var _post: Vector2 = Vector2.ZERO         # where this guard belongs
var _investigate_target: Vector2 = Vector2.ZERO
var _lose_timer: float = 0.0              # counts down once the player is unseen
var _guard_rect: Rect2 = Rect2()
var _has_guard_rect: bool = false

## SPRINTER dash-cycle state.
var _dashing_in: bool = true
var _dash_timer: float = 0.0

## MEDIC support state.
var _medic_target: Node = null
var _medic_scan_timer: float = 0.0
var _medic_heal_timer: float = 0.0
## Set true once the guard is roused (entered room, heard/took a shot). Only
## then will it chase and open fire.
var _provoked: bool = false

const LOSE_INTEREST_TIME := 4.0

func _ready() -> void:
	add_to_group("enemies")                  # ensures bullets can find us
	# Set collision in code so a mis-set enemy.tscn can't let guards walk
	# through walls. Layer 2 = enemies; mask 1 (walls) + 2 (other enemies) so
	# guards physically can't overlap and pile onto one spot.
	collision_layer = 2
	collision_mask = 1 | 2
	health = max_health
	_apply_archetype_visual()
	_fire_timer = randf() * fire_rate        # stagger so they don't all fire in sync
	_post = global_position
	# Reinforcements set `hunting` before _ready() runs, so honour it here.
	if hunting:
		_alert = Alert.HUNTING
		_lose_timer = LOSE_INTEREST_TIME
		_provoked = true
	_acquire_player()
	_director = get_tree().get_first_node_in_group("enemy_director") as EnemyDirector
	if _director:
		_director.register(self)
	# Listen for gunshots, deaths, footsteps.
	if has_node("/root/Noise"):
		get_node("/root/Noise").heard.connect(_on_noise)

func _acquire_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]

# --------------------------------------------------------------- hearing ----
func _on_noise(pos: Vector2, radius: float, kind: StringName) -> void:
	if _dead:
		return
	if global_position.distance_to(pos) > radius * hearing_multiplier:
		return
	wake_for()
	if _alert == Alert.HUNTING:
		return
	# A sound in earshot rouses the guard — now sight will make it hunt.
	if kind == &"gunshot" or kind == &"death":
		_provoked = true
	# Sentries never abandon their post — they just face the noise and get
	# twitchy. Patrols go and look.
	if role == Role.SENTRY:
		_alert = Alert.INVESTIGATING
		_investigate_target = _post
		if sprite:
			sprite.rotation = (pos - global_position).angle()
		return
	_alert = Alert.INVESTIGATING
	_investigate_target = pos

# ----------------------------------------------------------------- sight ----
## True if the player is within range AND nothing solid is in the way.
func _can_see_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	if _player.has_method("is_dead") and _player.is_dead():
		return false
	var to_player := _player.global_position - global_position
	if to_player.length() > sight_range:
		return false
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, _player.global_position)
	query.collision_mask = 1                 # layer 1 = walls
	query.collide_with_areas = false
	query.exclude = [get_rid(), _player.get_rid()]
	var hit := space.intersect_ray(query)
	# Anything static between us blocks the view.
	return hit.is_empty() or (hit["collider"] is CharacterBody2D)

# ----------------------------------------------------------------- brain ----
func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _player == null or not is_instance_valid(_player):
		_acquire_player()
		return

	# Sight only triggers hunting once the guard is PROVOKED — the player has
	# entered its room, fired a shot it heard, or shot it. Until then a guard
	# that can see the player just watches: no chasing, no shooting. This stops
	# the whole building opening fire the instant you're visible down a hallway.
	var sees := _can_see_player()
	if sees and _provoked:
		_alert = Alert.HUNTING
		_lose_timer = LOSE_INTEREST_TIME
	elif _alert == Alert.HUNTING:
		# Lost line of sight: keep pushing to the last known spot for a while.
		_lose_timer -= delta
		if _lose_timer <= 0.0:
			_alert = Alert.INVESTIGATING
			_investigate_target = _player.global_position

	# Being seen while in the player's room counts as provocation on its own.
	if sees and not _provoked and _player_in_my_room():
		_provoked = true

	match _alert:
		Alert.HUNTING:      _do_hunt(delta, sees)
		Alert.INVESTIGATING: _do_investigate(delta)
		_:                   _do_idle(delta)

	# Gentle separation: push apart from any very close neighbour so groups
	# spread into a loose formation instead of collapsing onto one point.
	velocity += _separation() * move_speed
	move_and_slide()

## Sum of small pushes away from nearby enemies (boids-style separation).
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in (_director.neighbours(global_position) if _director else []):
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector2 = global_position - other.global_position
		var d := away.length()
		if d < 46.0 and d > 0.01:
			push += away.normalized() * (1.0 - d / 46.0)
	return push.limit_length(1.0)

## Steer toward `target` while sliding around walls. Casts three whiskers
## (ahead, and 40 degrees either side); if the direct path is blocked it picks
## the clearest open angle instead of grinding into the wall.
func _steer_toward(target: Vector2, speed: float) -> Vector2:
	var desired := (target - global_position)
	if desired.length() < 1.0:
		return Vector2.ZERO
	desired = desired.normalized()
	if _is_clear(desired, 90.0):
		return desired * speed

	# Blocked ahead: fan out and take the best open direction.
	var best := Vector2.ZERO
	var best_score := -1.0
	for step in [-1, 1]:
		for angle in [0.4, 0.8, 1.3, 2.0]:
			var candidate := desired.rotated(angle * step)
			if not _is_clear(candidate, 80.0):
				continue
			# Prefer directions closest to where we actually want to go.
			var score := candidate.dot(desired)
			if score > best_score:
				best_score = score
				best = candidate
	if best == Vector2.ZERO:
		return Vector2.ZERO
	return best * speed

## True if nothing solid is within `dist` along `dir`.
func _is_clear(dir: Vector2, dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, global_position + dir * dist)
	query.collision_mask = 1                 # walls only
	query.collide_with_areas = false
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()

func _do_idle(_delta: float) -> void:
	# Drift back to post if shoved off it, otherwise hold still.
	if global_position.distance_to(_post) > 24.0:
		velocity = _steer_toward(_post, move_speed * 0.5)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

func _do_investigate(delta: float) -> void:
	var to_target := _investigate_target - global_position
	if sprite and to_target.length() > 1.0:
		sprite.rotation = to_target.angle()
	if to_target.length() > 40.0:
		velocity = _steer_toward(_investigate_target, move_speed * 0.8)
	else:
		# Arrived and found nothing — stand down.
		velocity = velocity.lerp(Vector2.ZERO, 0.2)
		_lose_timer -= delta
		if _lose_timer <= 0.0:
			_alert = Alert.IDLE
			_investigate_target = _post

## Move this guard's post (where it stands and returns to).
func set_post(pos: Vector2) -> void:
	_post = pos

## The room this guard belongs to, as a world-space rect. Sentries won't budge
## until the player is actually inside it.
func set_guard_room(rect: Rect2) -> void:
	_guard_rect = rect
	_has_guard_rect = true

## True if the player has entered this sentry's room.
func _player_in_my_room() -> bool:
	if not _has_guard_rect or _player == null:
		return false
	return _guard_rect.has_point(_player.global_position)

func _do_hunt(delta: float, sees: bool) -> void:
	var to_player := _player.global_position - global_position
	var dist := to_player.length()
	if sprite and dist > 1.0:
		sprite.rotation = to_player.angle()

	if kind == Kind.TURRET:
		# Never moves, at all — it's an emplacement, not a guard. Pure line-
		# of-sight threat that punishes a straight-line approach and rewards
		# using cover or flanking around its firing arc.
		velocity = Vector2.ZERO
	elif kind == Kind.SPRINTER:
		_do_sprinter(delta, to_player, dist)
	elif kind == Kind.MEDIC:
		_do_medic(delta, to_player, dist)
	elif role == Role.SENTRY:
		# Sentries are rooted to what they're guarding. They only give chase
		# once the player is in the room with them, and even then they stay
		# close to the post rather than following you across the building.
		if _player_in_my_room() and dist > keep_distance:
			var leash := global_position.distance_to(_post)
			if leash < 260.0:
				velocity = _steer_toward(_player.global_position, move_speed * 0.75)
			else:
				velocity = _steer_toward(_post, move_speed * 0.6)
		elif global_position.distance_to(_post) > 24.0:
			velocity = _steer_toward(_post, move_speed * 0.6)
		else:
			velocity = velocity.lerp(Vector2.ZERO, 0.25)
	elif dist > keep_distance:
		velocity = _steer_toward(_player.global_position, move_speed)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

	# Only shoot at what you can actually see. Medics hold fire while healing.
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	var may_fire := sees and dist <= fire_range and _fire_timer <= 0.0
	if kind == Kind.MEDIC and _medic_target != null:
		may_fire = false
	if may_fire:
		_fire_timer = fire_rate
		_shoot(to_player.normalized())

## Hit-and-run: closes to point-blank, unloads, then bolts back out to range
## before closing in again. Cycles on _dash_timer so it reads as a rhythm you
## can learn, not random jitter.
func _do_sprinter(delta: float, to_player: Vector2, dist: float) -> void:
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_dashing_in = not _dashing_in
		_dash_timer = 1.1 if _dashing_in else 0.9
	if _dashing_in and dist > 50.0:
		velocity = _steer_toward(_player.global_position, move_speed)
	elif not _dashing_in:
		velocity = _steer_toward(
			global_position - to_player.normalized() * 300.0, move_speed)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.3)

## Stays at range, tags the nearest hurt ally, and RUNS to it to heal — a
## priority kill target: leaving one alive keeps its friends topped up.
func _do_medic(delta: float, to_player: Vector2, dist: float) -> void:
	_medic_scan_timer -= delta
	if _medic_scan_timer <= 0.0:
		_medic_scan_timer = 0.5
		_medic_target = _find_hurt_ally()

	if _medic_target != null and is_instance_valid(_medic_target):
		var to_ally: Vector2 = _medic_target.global_position - global_position
		if to_ally.length() > 60.0:
			velocity = _steer_toward(_medic_target.global_position, move_speed * 1.1)
		else:
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
			_medic_heal_timer -= delta
			if _medic_heal_timer <= 0.0:
				_medic_heal_timer = 1.2
				if _medic_target.has_method("heal"):
					_medic_target.heal(2)
		return

	# No one to heal: keep distance from the player like a marksman would.
	if dist > keep_distance:
		velocity = _steer_toward(_player.global_position, move_speed)
	elif dist < keep_distance * 0.6:
		velocity = _steer_toward(
			global_position - to_player.normalized() * 200.0, move_speed)
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

func _find_hurt_ally() -> Node:
	var best: Node = null
	var best_d := 360.0
	for other in (_director.neighbours(global_position, 360.0) if _director else []):
		if other == self or not is_instance_valid(other):
			continue
		if "health" not in other or "max_health" not in other:
			continue
		if other.health >= other.max_health or other.health <= 0:
			continue
		var d := global_position.distance_to(other.global_position)
		if d < best_d:
			best_d = d
			best = other
	return best

func _shoot(dir: Vector2) -> void:
	if enemy_bullet_scene == null:
		return
	for i in maxi(pellets, 1):
		var offset := 0.0
		if pellets > 1:
			# Spread the pellets evenly across the cone, plus a little jitter.
			offset = lerpf(-spread, spread, float(i) / float(pellets - 1))
			offset += randf_range(-spread, spread) * 0.25
		elif spread > 0.0:
			offset = randf_range(-spread, spread)
		var b := enemy_bullet_scene.instantiate()
		get_tree().current_scene.add_child(b)
		b.global_position = global_position + dir * 28.0
		b.setup(dir.rotated(offset), self)
		if "damage" in b:
			b.damage = bullet_damage
		if "speed" in b:
			b.speed = bullet_speed
	# Gunfire draws every guard in earshot.
	if has_node("/root/Noise"):
		get_node("/root/Noise").gunshot(global_position)

# ---------------------------------------------------------------- damage ----
## Called by a MEDIC on a nearby wounded ally. Small floating "+N" so a heal
## reads clearly — and tells the player their damage just got undone.
func heal(amount: int) -> void:
	if _dead or health <= 0:
		return
	var before := health
	health = mini(health + amount, max_health)
	if health == before:
		return
	if sprite:
		var flash := create_tween()
		flash.tween_property(sprite, "modulate", Color(0.5, 1.0, 0.6), 0.1)
		flash.tween_property(sprite, "modulate", ARCHETYPES[kind]["colour"], 0.25)

func take_damage(amount: int = 1) -> void:
	# queue_free() only frees at end of frame, so without this guard several
	# bullets landing on the same frame would each count as a separate kill.
	if _dead:
		return
	wake_for(3.0)
	health -= amount
	# Being shot: you know where it came from and you're now hostile.
	_provoked = true
	_alert = Alert.HUNTING
	_lose_timer = LOSE_INTEREST_TIME
	_flash()
	if health <= 0:
		_die()

func _flash() -> void:
	# Quick white flash to telegraph the hit.
	if sprite is CanvasItem and not Settings.values["low_effects"]:
		sprite.modulate = Color(3, 3, 3)     # over-bright
		await get_tree().create_timer(0.06, false).timeout
		if is_instance_valid(sprite):
			sprite.modulate = ARCHETYPES[kind]["colour"]

func _die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	for c in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred("disabled", true)
	# A body hitting the floor is heard by anyone nearby.
	if has_node("/root/Noise"):
		get_node("/root/Noise").death(global_position)
	died.emit(self)
	queue_free()
