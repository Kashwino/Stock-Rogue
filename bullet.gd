extends Area2D
class_name Bullet
@export var speed := 600.0
@export var damage := 1
@export var lifetime := 2.0
@export_flags_2d_physics var wall_mask := Layers.SOLID
var pierce := 0
var ricochets := 0
var knockback := 0.0
var _dir := Vector2.RIGHT
var _shooter: Node = null
var _spent := false
var _hit_ids: Array[int] = []
var _excluded: Array[RID] = []

func setup(direction: Vector2, shooter: Node) -> void:
	_dir = direction.normalized()
	_shooter = shooter
	rotation = _dir.angle()
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		_excluded.append(shooter.get_rid())

func _ready() -> void:
	var tracer := get_node_or_null("Tracer")
	if tracer:
		tracer.hide()
	var art := BulletArt.new()
	art.length = clampf(speed * 0.028, 12.0, 34.0)
	add_child(art)
	collision_layer = 0
	collision_mask = wall_mask | Layers.ENEMIES | Layers.SECURITY | Layers.FLYERS
	body_entered.connect(_try_hit)

func _physics_process(delta: float) -> void:
	if _spent:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_finish()
		return
	var remaining := speed * delta
	# Resolve multiple contacts within this step: fast piercing rounds cannot
	# tunnel through a second guard or a wall behind their first hit.
	for step in 8:
		if remaining <= 0.01 or _spent:
			break
		var target := global_position + _dir * remaining
		var query := PhysicsRayQueryParameters2D.create(global_position, target, wall_mask | Layers.ENEMIES | Layers.SECURITY | Layers.FLYERS, _excluded)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			global_position = target
			break
		remaining -= global_position.distance_to(hit["position"])
		global_position = hit["position"]
		var body: Node = hit["collider"]
		if body.is_in_group("enemies") or body.is_in_group("security"):
			_try_hit(body)
			global_position += _dir * 0.5
			remaining -= 0.5
		elif ricochets > 0:
			_impact(hit["position"], hit["normal"])
			ricochets -= 1
			_dir = _dir.bounce(hit["normal"]).normalized()
			rotation = _dir.angle()
			global_position += hit["normal"] * 1.0
			remaining -= 1.0
		else:
			_impact(hit["position"], hit["normal"])
			_finish()

func _impact(at: Vector2, normal: Vector2) -> void:
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.spark(at, normal, Palette.PLAYER_BULLET)
		host.fx.bullet_hole(at - normal * 2.0)

func _try_hit(target: Node) -> void:
	if _spent or not is_instance_valid(target) or target == _shooter:
		return
	if not (target.is_in_group("enemies") or target.is_in_group("security")) or not target.has_method("take_damage"):
		return
	if target.get_instance_id() in _hit_ids:
		return
	_hit_ids.append(target.get_instance_id())
	if target is CollisionObject2D:
		_excluded.append(target.get_rid())
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.damage_number(global_position, damage, Palette.GOLD_PALE if damage >= 3 else Palette.PAPER)
		if target.is_in_group("enemies"):
			host.fx.blood(global_position, _dir)
		else:
			host.fx.spark(global_position, -_dir, Palette.NEON_CYAN)
	target.take_damage(damage)
	var push := knockback if knockback > 0.0 else 45.0
	if target is CharacterBody2D and not target is AuditorBoss and is_instance_valid(target) and target.is_inside_tree():
		target.velocity += _dir * push
		target.move_and_slide()
	if target.is_in_group("enemies") and is_instance_valid(_shooter) and _shooter.has_method("register_hit_landed"):
		_shooter.register_hit_landed()
	if pierce > 0:
		pierce -= 1
	else:
		_finish()

func _finish() -> void:
	_spent = true
	queue_free()
