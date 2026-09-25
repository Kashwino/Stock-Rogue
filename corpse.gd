extends Node2D
class_name Corpse
## A body on the floor. It doesn't just appear: it slides along the killing
## blow's direction with friction, spins a little, and its weapon skitters off
## on its own path. Explosions launch it. Walls stop it dead (and Phase 3
## paints a splat there). Once still it settles and stops processing.
## Bodies stay for the whole heist (capped per building, oldest first) —
## they're evidence (see CorpseWatch / Enemy perception).

signal settled(corpse: Corpse)
signal hit_wall(corpse: Corpse, at: Vector2, normal: Vector2)

const CAP := 40
const FRICTION := 5.5           # velocity decay per second (exponential)
const SPIN_DECAY := 4.0
const RADIUS := 12.0

var spec: Dictionary
var velocity := Vector2.ZERO
var spin := 0.0
var kill_class: StringName = KillInfo.STANDARD
var was_moving := false
var seen_by: Array = []          # guard instance ids that already noticed it
var weapon: Skitter = null
var _kit: SpriteKit
var _flash := 0.0

## Drop a body at `at` facing `facing`, moving per `info` (may be null).
static func spawn(host: Node, at: Vector2, facing: float, kit_spec: Dictionary, info: KillInfo = null) -> Corpse:
	if host == null or not host.is_inside_tree():
		return null
	var existing := host.get_tree().get_nodes_in_group("corpse")
	if existing.size() >= CAP:
		var oldest: Node = existing[0]
		if oldest.has_method("retire"):
			oldest.retire()
		else:
			oldest.queue_free()
	var c := Corpse.new()
	c.spec = kit_spec.duplicate()
	c.rotation = facing + PI * 0.5
	if info:
		c.kill_class = info.kill_class
		c.velocity = launch_velocity(info)
		c.spin = randf_range(-1.0, 1.0) * clampf(c.velocity.length() / 60.0, 0.5, 9.0)
	# Positioned before entering the tree so the dropped gun starts on him.
	c.position = (host as Node2D).to_local(at) if host is Node2D else at
	host.add_child(c)
	if info and info.by_player:
		c.confirm_flash()
	return c

## How hard the body goes: bullets push along the shot (harder with overkill
## and heavy knockback), blasts throw it, takedowns barely move it.
static func launch_velocity(info: KillInfo) -> Vector2:
	var d := info.dir.normalized() if info.dir.length() > 0.01 else Vector2.from_angle(randf() * TAU)
	var speed := 0.0
	match info.kill_class:
		KillInfo.EXPLOSIVE:
			speed = clampf(info.force, 380.0, 820.0) * randf_range(0.85, 1.15)
		KillInfo.TAKEDOWN:
			speed = 30.0 if info.stealth else 140.0
		KillInfo.BURN:
			speed = 40.0
		_:
			speed = 90.0 + info.force * 1.4 + info.excess * 55.0
			if info.overkill:
				speed += 120.0
			speed = clampf(speed, 70.0, 560.0)
	return d * speed

func _ready() -> void:
	add_to_group("corpse")
	z_index = -3
	_kit = SpriteKit.new()
	_kit.apply(spec)
	_kit.modulate = Color(0.55, 0.52, 0.52)
	add_child(_kit)
	_kit.set_process(false)
	_kit._dead = true
	scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	was_moving = velocity.length() > 5.0
	if was_moving:
		_drop_weapon.call_deferred()
	set_process(true)
	queue_redraw()

## The victim's gun leaves his hands and skitters away on its own.
func _drop_weapon() -> void:
	var gun: int = spec.get("gun", SpriteKit.Gun.PISTOL)
	if not Skitter.LENGTH.has(gun) or spec.get("body", 0) in [SpriteKit.Body.DOG, SpriteKit.Body.DRONE, SpriteKit.Body.TRIPOD]:
		return
	# The gun leaves the body: redraw him empty-handed.
	spec["gun"] = SpriteKit.Gun.NONE
	_kit.apply(spec)
	weapon = Skitter.new()
	weapon.length = Skitter.LENGTH[gun]
	weapon.velocity = velocity.rotated(randf_range(-0.9, 0.9)) * randf_range(0.8, 1.35) + Vector2.from_angle(randf() * TAU) * 40.0
	weapon.spin = randf_range(-14.0, 14.0)
	get_parent().add_child(weapon)
	weapon.global_position = global_position

## A white pop on the body: the kill registered.
func confirm_flash() -> void:
	_flash = 1.0

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		_kit.modulate = Color(0.55, 0.52, 0.52).lerp(Color(2.2, 2.0, 1.9), _flash)
	if velocity.length() > 4.0:
		var step := velocity * delta
		var space := get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step + step.normalized() * RADIUS, Layers.WALLS)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			global_position = hit["position"] - step.normalized() * RADIUS
			hit_wall.emit(self, hit["position"], hit["normal"])
			velocity = Vector2.ZERO
			spin *= 0.2
		else:
			global_position += step
		velocity *= exp(-FRICTION * delta)
		rotation += spin * delta
		spin *= exp(-SPIN_DECAY * delta)
	elif _flash <= 0.0:
		velocity = Vector2.ZERO
		set_process(false)
		_kit.modulate = Color(0.55, 0.52, 0.52)
		settled.emit(self)

## Leave the stage (over the cap): fade out.
func retire() -> void:
	remove_from_group("corpse")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
	if weapon and is_instance_valid(weapon):
		weapon.queue_free()

func is_still() -> bool:
	return not is_processing()

func _draw() -> void:
	var pool := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pool.append(Vector2.from_angle(a) * (18.0 + sin(i * 2.7) * 5.0) + Vector2(-8, 0))
	draw_colored_polygon(pool, Color(0.22, 0.02, 0.03, 0.55))


## A dropped gun sliding across the floor.
class Skitter extends Node2D:
	const LENGTH := {
		SpriteKit.Gun.PISTOL: 14.0, SpriteKit.Gun.REVOLVER: 15.0, SpriteKit.Gun.SMG: 18.0,
		SpriteKit.Gun.SHOTGUN: 22.0, SpriteKit.Gun.RIFLE: 26.0, SpriteKit.Gun.LONG_RIFLE: 30.0,
		SpriteKit.Gun.LMG: 28.0, SpriteKit.Gun.LAUNCHER: 26.0,
	}
	var velocity := Vector2.ZERO
	var spin := 0.0
	var length := 18.0

	func _ready() -> void:
		z_index = -2
		rotation = velocity.angle()
		queue_redraw()

	func _process(delta: float) -> void:
		if velocity.length() < 4.0:
			set_process(false)
			return
		var step := velocity * delta
		var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step + step.normalized() * 6.0, Layers.WALLS)
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			velocity = velocity.bounce(hit["normal"]) * 0.35
			global_position = hit["position"] + hit["normal"] * 6.0
		else:
			global_position += step
		velocity *= exp(-4.2 * delta)
		rotation += spin * delta
		spin *= exp(-3.0 * delta)

	func _draw() -> void:
		var h := length * 0.5
		draw_rect(Rect2(-h + 1, -2.0, length, 4.5), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(-h, -2.5, length, 4.5), Color(0.08, 0.08, 0.09))
		draw_rect(Rect2(-h, 2.0, 5, 5), Color(0.08, 0.08, 0.09))
		draw_line(Vector2(-h, -2.5), Vector2(h, -2.5), Color(0.35, 0.35, 0.38), 1.0)
