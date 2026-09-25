extends Area2D
class_name Bullet
@export var speed := 600.0
@export var damage := 1
@export var lifetime := 2.0
@export_flags_2d_physics var wall_mask := Layers.SOLID
var pierce := 0
var ricochets := 0
var knockback := 0.0
## The weapon that fired this round (traits and mods act on hit).
var weapon: WeaponItem = null
## Stopping Power: a hit guard loses his next shot.
var stagger := false
## One trigger pull shares an id (multi-kills from one shot), where it left
## the muzzle (point-blank checks) and whether it's a guaranteed crit.
var shot_id := 0
var origin := Vector2.ZERO
var crit_shot := false
var _dir := Vector2.RIGHT
var _shooter: Node = null
var _spent := false
var _hit_ids: Array[int] = []
var _excluded: Array[RID] = []
## Set by BulletPool; spent rounds park there instead of being freed.
var pool: BulletPool = null
var _art: BulletArt
var _base_lifetime := 2.0

func setup(direction: Vector2, shooter: Node) -> void:
	_dir = direction.normalized()
	_shooter = shooter
	rotation = _dir.angle()
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		_excluded.append(shooter.get_rid())
	if _art:
		_art.length = clampf(speed * 0.028, 12.0, 34.0)
		# Guards and rival crews shooting each other use these rounds too;
		# they stay red so gold always means the player's fire.
		_art.hostile = not (shooter is Player)
		_art.queue_redraw()

## Back from the pool: a fresh round.
func revive() -> void:
	_spent = false
	lifetime = _base_lifetime
	pierce = 0
	ricochets = 0
	knockback = 0.0
	weapon = null
	stagger = false
	shot_id = 0
	crit_shot = false
	_hit_ids.clear()
	_excluded.clear()
	show()
	set_physics_process(true)
	set_deferred("monitoring", true)

func _ready() -> void:
	_base_lifetime = lifetime
	var tracer := get_node_or_null("Tracer")
	if tracer:
		tracer.hide()
	_art = BulletArt.new()
	_art.length = clampf(speed * 0.028, 12.0, 34.0)
	add_child(_art)
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
		if body.is_in_group("enemies") and body.has_method("deflects") and body.deflects(_dir):
			# Riot shield: sparks, a ping, and the round is gone.
			Audio.play("deflect", hit["position"])
			var host := get_tree().current_scene
			if host is HeistFloor:
				host.fx.spark(hit["position"], -_dir, Palette.NEON_CYAN)
			_finish()
		elif body.is_in_group("enemies") or body.is_in_group("security") or body.is_in_group("civilians"):
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
	Audio.play("impact_wall", at)
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.spark(at, normal, Palette.PLAYER_BULLET)
		host.fx.bullet_hole(at - normal * 2.0)

func _try_hit(target: Node) -> void:
	if _spent or not is_instance_valid(target) or target == _shooter:
		return
	if not (target.is_in_group("enemies") or target.is_in_group("security") or target.is_in_group("civilians")) or not target.has_method("take_damage"):
		return
	if target.has_method("deflects") and target.deflects(_dir):
		return
	if target.get_instance_id() in _hit_ids:
		return
	# No friendly fire between guards, or between rival crew members.
	if is_instance_valid(_shooter) and "faction" in _shooter and "faction" in target and _shooter.faction == target.faction:
		if target is CollisionObject2D:
			_excluded.append(target.get_rid())
		return
	_hit_ids.append(target.get_instance_id())
	if target is CollisionObject2D:
		_excluded.append(target.get_rid())
	var dmg := _damage_against(target)
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.damage_number(global_position, dmg, Palette.GOLD_PALE if dmg >= 3 else Palette.PAPER)
		if target.is_in_group("enemies") or target.is_in_group("civilians"):
			host.fx.blood(global_position, _dir)
			Audio.play("impact_body", global_position)
		else:
			host.fx.spark(global_position, -_dir, Palette.NEON_CYAN)
	var push := knockback if knockback > 0.0 else 45.0
	if target.has_method("note_hit"):
		var enemy := target as Enemy
		var assassin := weapon != null and weapon.trait_id == &"assassin" and enemy != null and not enemy._provoked
		target.note_hit({
			"source": &"bullet", "dir": _dir, "force": push, "by_player": _shooter is Player,
			"weapon": weapon.id if weapon else &"", "shot": shot_id,
			"pellets": weapon.pellets if weapon else 1,
			"point_blank": origin != Vector2.ZERO and origin.distance_to(global_position) <= KillInfo.POINT_BLANK,
			"crit": crit_shot or assassin,
		})
	if target.is_in_group("civilians") and target.has_method("take_blast"):
		target.take_blast(dmg, _shooter is Player)
	else:
		target.take_damage(dmg)
	_after_hit(target, host)
	if target is CharacterBody2D and not target.is_in_group("boss") and is_instance_valid(target) and target.is_inside_tree():
		target.velocity += _dir * push
		target.move_and_slide()
	if target.is_in_group("enemies") and is_instance_valid(_shooter) and _shooter.has_method("register_hit_landed"):
		_shooter.register_hit_landed()
		if host is HeistFloor and host.crosshair:
			host.crosshair.hit()
	if pierce > 0:
		pierce -= 1
	else:
		_finish()

## Weapon traits and mods that change what one hit is worth.
func _damage_against(target: Node) -> int:
	var dmg := damage
	if weapon == null:
		return dmg
	var enemy := target as Enemy
	match weapon.trait_id:
		&"assassin":
			if enemy and not enemy._provoked and not enemy._dead:
				dmg *= 3
		&"elite_hunter":
			if enemy and (enemy.elite or enemy.lieutenant or enemy is Boss):
				dmg *= 2
		&"fries_electronics":
			if target.is_in_group("security") or (enemy and enemy.kind == Enemy.Kind.DRONE):
				dmg = maxi(dmg, 99)
	if enemy and weapon.has_mod(&"hollow_points"):
		dmg = maxi(1, dmg + (-1 if enemy.armored else 1))
	return dmg

func _after_hit(target: Node, host: Node) -> void:
	var enemy := target as Enemy
	if enemy == null or not is_instance_valid(enemy):
		return
	if stagger and not enemy._dead:
		enemy._fire_timer += 0.35
	if weapon == null:
		return
	if weapon.has_mod(&"incendiary") and not enemy._dead:
		enemy.ignite(3.0)
	match weapon.trait_id:
		&"red_mark":
			enemy.red_marked = true
		&"paying_pellets":
			RunEconomy.add_bonus(1)
		&"gavel":
			if enemy._dead and host is HeistFloor and host.live:
				host.live.report_shock(0.98 if host.live.inverted() else 1.02, &"gavel")

func _finish() -> void:
	if _spent and pool:
		return
	_spent = true
	if pool:
		hide()
		set_physics_process(false)
		set_deferred("monitoring", false)
		pool.park(self)
	else:
		queue_free()
