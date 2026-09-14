extends Area2D
class_name Bullet

## Player projectile. Call setup(direction, shooter) right after instantiating.
## Damages anything in the "enemies" group that has take_damage().
##
## WALLS: bullets are swept with a raycast each frame instead of relying on
## Area2D overlap. At 600+ px/s a bullet moves ~10px per frame, and walls are
## only 24px thick — overlap detection misses them at high speeds or shallow
## angles ("tunnelling"). The raycast catches every wall crossing, and it hits
## ANY body on the collision layer rather than requiring a "walls" group.

@export var speed: float = 600.0
@export var damage: int = 1
@export var lifetime: float = 2.0            # seconds before auto-despawn
## Physics layers treated as solid cover. Layer 1 = room walls.
@export_flags_2d_physics var wall_mask: int = 1

var _dir: Vector2 = Vector2.RIGHT
var _shooter: Node = null

func setup(direction: Vector2, shooter: Node) -> void:
	_dir = direction.normalized()
	_shooter = shooter
	rotation = _dir.angle()

func _ready() -> void:
	# The bullet is an Area2D: body_entered only fires for bodies whose layer is
	# in this mask. Enemies live on layer 2, walls on layer 1 — include both, or
	# hits silently never register.
	collision_mask = wall_mask | 2      # walls + enemies
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	await get_tree().create_timer(lifetime).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta: float) -> void:
	var step := _dir * speed * delta
	var target := global_position + step

	# Sweep for walls between here and the next position.
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, target)
	query.collision_mask = wall_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	# Exclude the shooter, and skip characters — only static cover stops a
	# bullet. CharacterBody2D/RigidBody2D are handled by the Area2D overlap.
	if _shooter and _shooter is CollisionObject2D:
		query.exclude = [_shooter.get_rid()]
	var hit := space.intersect_ray(query)
	if hit and not (hit["collider"] is CharacterBody2D):
		# Stop at the wall surface so the impact reads correctly.
		global_position = hit["position"]
		queue_free()
		return

	global_position = target

func _on_body_entered(body: Node) -> void:
	_try_hit(body)

func _on_area_entered(area: Node) -> void:
	_try_hit(area)

func _try_hit(target: Node) -> void:
	if target == _shooter:
		return
	if target.is_in_group("enemies") and target.has_method("take_damage"):
		target.take_damage(damage)
		if _shooter and _shooter.has_method("register_hit_landed"):
			_shooter.register_hit_landed()
		queue_free()
