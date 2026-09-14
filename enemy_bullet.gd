extends Area2D
class_name EnemyBullet

## Enemy projectile. Mirrors Bullet but damages the player instead of enemies.
## Uses the same raycast sweep so enemies can't shoot you through walls.

@export var speed: float = 320.0
@export var damage: int = 1
@export var lifetime: float = 3.0
## Physics layers treated as solid cover. Layer 1 = room walls.
@export_flags_2d_physics var wall_mask: int = 1

var _dir: Vector2 = Vector2.RIGHT
var _shooter: Node = null
var _spent := false

func setup(direction: Vector2, shooter: Node) -> void:
	_dir = direction.normalized()
	_shooter = shooter
	rotation = _dir.angle()

func _ready() -> void:
	# Walls (layer 1) + player (layer 4). NOT layer 2, so enemy bullets pass
	# harmlessly through other enemies.
	collision_mask = wall_mask | 4
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_spent = true
		queue_free()
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
		queue_free()
		return

	global_position = target

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Node) -> void:
	_try_hit(area)

func _try_hit(target: Node) -> void:
	if _spent or target == _shooter:
		return
	if target.is_in_group("player") and target.has_method("take_damage"):
		_spent = true
		target.take_damage(damage)
		queue_free()
