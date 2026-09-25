extends Area2D
class_name EnemyBullet

## Enemy projectile. Mirrors Bullet but damages the player instead of enemies.
## Uses the same raycast sweep so enemies can't shoot you through walls.

@export var speed: float = 320.0
@export var damage: int = 1
@export var lifetime: float = 3.0
## Physics layers treated as solid cover. Layer 1 = room walls.
@export_flags_2d_physics var wall_mask: int = Layers.SOLID

var _dir: Vector2 = Vector2.RIGHT
var _shooter: Node = null
var _spent := false
## Set by BulletPool; spent rounds park there instead of being freed.
var pool: BulletPool = null
var _art: BulletArt
var _base_lifetime := 3.0

func setup(direction: Vector2, shooter: Node) -> void:
	_dir = direction.normalized()
	_shooter = shooter
	rotation = _dir.angle()
	if _art:
		_art.length = clampf(speed * 0.03, 8.0, 22.0)
		_art.queue_redraw()

func revive() -> void:
	_spent = false
	lifetime = _base_lifetime
	show()
	set_physics_process(true)
	set_deferred("monitoring", true)

func _ready() -> void:
	_base_lifetime = lifetime
	var tracer := get_node_or_null("Tracer")
	if tracer:
		tracer.hide()
	_art = BulletArt.new()
	_art.hostile = true
	_art.length = clampf(speed * 0.03, 8.0, 22.0)
	add_child(_art)
	# Walls (layer 1) + player (layer 4). NOT layer 2, so enemy bullets pass
	# harmlessly through other enemies.
	collision_mask = wall_mask | Layers.PLAYER
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_finish()
		return
	var step := _dir * speed * delta
	var target := global_position + step

	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target)
	query.collision_mask = wall_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# Exclude the shooter, and skip characters — only static cover stops a
	# bullet. CharacterBody2D/RigidBody2D are handled by the Area2D overlap.
	if is_instance_valid(_shooter) and _shooter is CollisionObject2D:
		query.exclude = [_shooter.get_rid()]
	var hit := space.intersect_ray(query)
	if hit and not (hit["collider"] is CharacterBody2D):
		global_position = hit["position"]
		# Guards can set off a gas can too.
		if hit["collider"].is_in_group("explosive") and hit["collider"].has_method("shot"):
			hit["collider"].shot(damage, _dir, false)
		var host := get_tree().current_scene
		if host is HeistFloor:
			host.fx.spark(hit["position"], hit["normal"], Palette.ENEMY_BULLET)
			host.fx.bullet_hole(hit["position"] - hit["normal"] * 2.0)
		_finish()
		return

	global_position = target

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Node) -> void:
	_try_hit(area)

func _try_hit(target: Node) -> void:
	if _spent or target == _shooter:
		return
	if (target.is_in_group("player") or target.is_in_group("ally")) and target.has_method("take_damage"):
		if "last_hit_dir" in target:
			target.last_hit_dir = _dir
		if "last_hit_by" in target:
			target.last_hit_by = Player.blame_of(_shooter)
		target.take_damage(damage)
		_finish()

func _finish() -> void:
	if _spent:
		return
	_spent = true
	if pool:
		hide()
		set_physics_process(false)
		set_deferred("monitoring", false)
		pool.park(self)
	else:
		queue_free()
