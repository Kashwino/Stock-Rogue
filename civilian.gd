extends CharacterBody2D
class_name Civilian
## Bystanders: clerks, gamblers, aides, floor traders. They never fight.
## Gunfire panics them — most cower or bolt for the street, and the brave ones
## run for an alarm panel. Aim at a runner for a second and they drop and
## cower. Killing one is a heat spike, a venue crash and a grade penalty.
## Layer: ENEMIES (bullets hit them; guards ignore them).

enum State { CALM, COWER, FLEE, ALARM }

const AIM_TO_STOP := 1.0
const PANIC_HEARING := 0.85

var state := State.CALM
var health := 2
var runner := false               # heads for an alarm panel when panicked
var stage := 0
var look_seed := 0
var kit: SpriteKit
var sprite: Node2D
var _post := Vector2.ZERO
var _wander_to := Vector2.ZERO
var _wander_clock := 0.0
var _aim_hold := 0.0
var _panel: SecurityDevice = null
var _flee_to := Vector2.ZERO
var _stuck := 0.0
var _dead := false
var _alarm_icon: EnemyOverhead

func _ready() -> void:
	add_to_group("civilians")
	collision_layer = Layers.ENEMIES
	collision_mask = Layers.SOLID
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	sprite = Node2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	kit = SpriteKit.dress(sprite, look())
	sprite.rotation = randf() * TAU
	_alarm_icon = EnemyOverhead.new()
	add_child(_alarm_icon)
	_post = global_position
	_wander_to = _post
	_wander_clock = randf_range(1.0, 4.0)
	var noise := get_node_or_null("/root/Noise")
	if noise:
		noise.heard.connect(_on_noise)

## Dress by stage: street clothes in Town, office wear in the City, evening
## wear in the World, floor traders' jackets at the Exchange.
func look() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	var S := SpriteKit
	var skin: Color = S.SKIN[rng.randi() % S.SKIN.size()]
	var hair: Color = [Color("2a1a12"), Color("0f0f0f"), Color("6a4a2a"), Color("a8a8a8"), Color("c9a25a")][rng.randi() % 5]
	match stage:
		1:
			var suit: Color = [Color("3b4252"), Color("4a4038"), Color("2f3a33")][rng.randi() % 3]
			return {"body": S.Body.SUIT, "head": S.Head.HAIR, "gun": S.Gun.NONE, "color": suit, "trim": Color("d8d8d8"), "skin": skin, "hair": hair, "acc": ["tie"], "scale": 0.94}
		2:
			if rng.randf() < 0.5:
				return {"body": S.Body.GOWN, "head": S.Head.HAIR, "gun": S.Gun.NONE, "color": [Color("7a1f3a"), Color("1f3a7a"), Color("2a2a2a")][rng.randi() % 3], "trim": Palette.GOLD_PALE, "skin": skin, "hair": hair, "scale": 0.92}
			return {"body": S.Body.SUIT, "head": S.Head.SLICKED, "gun": S.Gun.NONE, "color": Color("141418"), "trim": Color("f0f0f0"), "skin": skin, "hair": hair, "acc": ["tie"], "scale": 0.94}
		3:
			return {"body": S.Body.CIVILIAN, "head": S.Head.HAIR, "gun": S.Gun.NONE, "color": [Color("c9a227"), Color("2f6bff"), Color("c73833")][rng.randi() % 3], "trim": Color("f0f0f0"), "skin": skin, "hair": hair, "scale": 0.94}
	return {"body": S.Body.CIVILIAN, "head": [S.Head.CAP, S.Head.HAIR, S.Head.BARE][rng.randi() % 3], "gun": S.Gun.NONE, "color": [Color("5a4a3a"), Color("3a4a5a"), Color("6a3a3a")][rng.randi() % 3], "trim": Color("a0a0a0"), "hat": Color("2a2a2a"), "skin": skin, "hair": hair, "scale": 0.94}

func heist() -> HeistFloor:
	return get_tree().current_scene as HeistFloor if is_inside_tree() else null

func _on_noise(pos: Vector2, radius: float, kind: StringName) -> void:
	if _dead or state != State.CALM:
		return
	if kind != &"gunshot" and kind != &"death":
		return
	if global_position.distance_to(pos) > radius * PANIC_HEARING:
		return
	panic(pos)

## Gunfire nearby: cower, flee, or (runners) go for the alarm.
func panic(source: Vector2) -> void:
	if _dead or state != State.CALM:
		return
	var host := heist()
	Audio.play("scream", global_position, -6.0, randf_range(0.85, 1.2))
	if runner and host:
		_panel = host.nearest_alarm_panel(global_position)
		if _panel:
			state = State.ALARM
			_alarm_icon.alarm = true
			return
	if randf() < 0.5:
		_cower()
		return
	state = State.FLEE
	_flee_to = global_position + (global_position - source).normalized() * 600.0
	if host:
		_flee_to = host.nearest_way_out(global_position)

func _cower() -> void:
	state = State.COWER
	_alarm_icon.alarm = false
	velocity = Vector2.ZERO
	var spec := kit.spec.duplicate()
	spec["cower"] = true
	kit = SpriteKit.dress(sprite, spec)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	match state:
		State.CALM:
			_wander(delta)
		State.COWER:
			velocity = velocity.lerp(Vector2.ZERO, 0.3)
		State.FLEE:
			_run_to(_flee_to, 175.0)
			if global_position.distance_to(_flee_to) < 40.0:
				_escape()
				return
			_watch_aim(delta)
		State.ALARM:
			if not is_instance_valid(_panel) or _panel.disabled:
				_cower()
			else:
				_run_to(_panel.global_position, 165.0)
				if global_position.distance_to(_panel.global_position) < 56.0:
					var host := heist()
					if host:
						host.raise_alarm("Civilian pulled the alarm", _panel)
					_cower()
				else:
					_watch_aim(delta)
	move_and_slide()
	# Wedged against a wall for too long: give up and hide.
	if state == State.FLEE or state == State.ALARM:
		_stuck = _stuck + delta if velocity.length() < 30.0 else 0.0
		if _stuck > 2.5:
			_cower()

func _wander(delta: float) -> void:
	_wander_clock -= delta
	if _wander_clock <= 0.0:
		_wander_clock = randf_range(2.5, 5.5)
		_wander_to = _post + Vector2(randf_range(-70, 70), randf_range(-60, 60))
	if global_position.distance_to(_wander_to) > 10.0:
		velocity = (_wander_to - global_position).normalized() * 45.0
		sprite.rotation = velocity.angle()
	else:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)

func _run_to(target: Vector2, speed: float) -> void:
	var dir := (target - global_position).normalized()
	# Slide around corners with a couple of whiskers.
	var space := get_world_2d().direct_space_state
	for turn in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var d: Vector2 = dir.rotated(turn)
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + d * 60.0, Layers.SOLID)
		query.exclude = [get_rid()]
		if space.intersect_ray(query).is_empty():
			dir = d
			break
	velocity = dir * speed
	sprite.rotation = dir.angle()

## Hold your aim on a running civilian for a second and they hit the floor.
func _watch_aim(delta: float) -> void:
	var host := heist()
	if host == null or not is_instance_valid(host.player):
		return
	var p: Player = host.player
	var to_me := global_position - p.global_position
	var on_me := to_me.length() < 460.0 and absf(angle_difference(p.aim_direction().angle(), to_me.angle())) < 0.2
	if on_me:
		var query := PhysicsRayQueryParameters2D.create(p.global_position, global_position, Layers.SOLID)
		on_me = get_world_2d().direct_space_state.intersect_ray(query).is_empty()
	_aim_hold = _aim_hold + delta if on_me else maxf(_aim_hold - delta * 2.0, 0.0)
	if _aim_hold >= AIM_TO_STOP:
		host.fx.chip(global_position, "GET DOWN!", Palette.PAPER)
		_cower()

## Out of the building: gone, no harm done.
func _escape() -> void:
	_dead = true
	queue_free()

func take_damage(amount: int = 1) -> void:
	_hurt(amount, true)

## Explosions: only the player's own blasts count against the job's grade.
func take_blast(amount: int, player_caused: bool) -> void:
	_hurt(amount, player_caused)

func _hurt(amount: int, player_caused: bool) -> void:
	if _dead:
		return
	health -= amount
	kit.flash()
	if health > 0:
		if state == State.CALM:
			panic(global_position)
		return
	_dead = true
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	if get_parent():
		SpriteKit.drop_corpse(get_parent(), global_position, sprite.global_rotation, kit.spec)
	Audio.play("death_enemy", global_position, 0.0, 1.3)
	var noise := get_node_or_null("/root/Noise")
	if noise:
		noise.death(global_position)
	var host := heist()
	if host:
		host.on_civilian_killed(self, player_caused)
	queue_free()
