extends CharacterBody2D
class_name Ally
## A FLIPPED boss fighting beside you against the Chairman (verdicts.gd).
## A simplified moveset: keeps near the player, shoots the nearest guard he
## can see (the Landlord a shotgun spread, the Auditor aimed single rounds,
## the Ambassador a three-round fan) and draws the guards' fire. At 0 HP he
## is DOWNED, never killed, and gets back up after 20 s.
## Collision: layer PLAYER (4) so enemy rounds hit him and yours pass
## through; mask SOLID so he walks around walls and furniture.

const FOLLOW_RANGE := 90.0
const SIGHT := 720.0
const SPEED := 170.0
## [pellets, spread (rad), damage, cooldown (s), round speed]
const GUNS := {
	&"landlord": [5, 0.5, 1, 1.1, 520.0],
	&"auditor": [1, 0.0, 2, 0.6, 700.0],
	&"ambassador": [3, 0.3, 1, 0.9, 600.0],
}

var boss_id: StringName = &"landlord"
var max_health := 10
var health := 10
var downed_left := 0.0
var faction: StringName = &"crew"
var host: Node = null
var sprite: Node2D
var kit: SpriteKit
var _fire_clock := 0.8
var _slot := 0.0                 # where around the player he stands (radians)
var _target: Node2D = null
var _scan := 0.0
var _tag: AllyTag
static var _round: PackedScene = null

func _ready() -> void:
	add_to_group("ally")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	add_child(shape)
	sprite = Node2D.new()
	sprite.name = "Sprite"
	add_child(sprite)
	kit = SpriteKit.dress(sprite, look(boss_id))
	kit.scale = Vector2.ONE * 1.15
	z_index = 9
	_tag = AllyTag.new()
	_tag.ally = self
	add_child(_tag)
	if _round == null:
		_round = load("res://bullet.tscn")

static func look(id: StringName) -> Dictionary:
	match id:
		&"auditor":
			return AuditorBoss.look()
		&"ambassador":
			return AmbassadorBoss.look()
	return LandlordBoss.look()

func display_name() -> String:
	return Story.boss_name(boss_id)

func is_dead() -> bool:
	return downed_left > 0.0

func take_damage(amount: int = 1) -> void:
	if downed_left > 0.0:
		return
	health -= amount
	if kit:
		kit.flash()
	if host and host.gore:
		host.gore.on_hit(global_position, Vector2.from_angle(randf() * TAU), amount, false, self)
	if health <= 0:
		_go_down()

func _go_down() -> void:
	health = 0
	downed_left = Verdicts.ALLY_REVIVE
	velocity = Vector2.ZERO
	if kit:
		var spec := kit.spec.duplicate()
		spec["cower"] = true
		kit.apply(spec)
		kit.modulate = Color(0.6, 0.6, 0.65)
	if host:
		host.fx.chip(global_position, "%s IS DOWN" % display_name(), Palette.DANGER)
	Audio.play("hurt", global_position, -4.0, 0.8)

func _revive() -> void:
	downed_left = 0.0
	health = max_health
	if kit:
		kit.apply(look(boss_id))
		kit.modulate = Color.WHITE
	if host:
		host.fx.chip(global_position, "%s IS BACK UP" % display_name(), Palette.GOLD)

func _physics_process(delta: float) -> void:
	if downed_left > 0.0:
		downed_left -= delta
		if downed_left <= 0.0:
			_revive()
		velocity = velocity.lerp(Vector2.ZERO, 0.3)
		move_and_slide()
		return
	var player: Node2D = host.player if host else null
	if player == null or not is_instance_valid(player):
		return
	# Keep a spot near the player, fanned out so the allies don't stack.
	var spot := player.global_position + Vector2.from_angle(_slot) * FOLLOW_RANGE
	var to_spot := spot - global_position
	velocity = to_spot.normalized() * SPEED if to_spot.length() > 24.0 else velocity.lerp(Vector2.ZERO, 0.3)
	move_and_slide()
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.3
		_target = _pick_target()
	if _target and is_instance_valid(_target):
		sprite.rotation = lerp_angle(sprite.rotation, (_target.global_position - global_position).angle(), clampf(delta * 10.0, 0.0, 1.0))
	elif velocity.length() > 10.0:
		sprite.rotation = lerp_angle(sprite.rotation, velocity.angle(), clampf(delta * 8.0, 0.0, 1.0))
	_fire_clock -= delta
	if _fire_clock <= 0.0 and _target and is_instance_valid(_target):
		_fire()

## The nearest standing, fighting enemy he can see.
func _pick_target() -> Node2D:
	if host == null or host.director == null:
		return null
	var best: Node2D = null
	var best_d := SIGHT
	for e in host.director.enemies:
		if not is_instance_valid(e) or e._dead or e.surrendered or (e is Boss and e.is_down()):
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d and _clear_shot(e):
			best_d = d
			best = e
	return best

func _clear_shot(e: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, e.global_position, Layers.SOLID)
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _fire() -> void:
	var gun: Array = GUNS.get(boss_id, GUNS[&"landlord"])
	_fire_clock = float(gun[3]) * randf_range(0.9, 1.15)
	var aim := (_target.global_position - global_position).normalized()
	var pellets: int = gun[0]
	for i in pellets:
		var k := 0.0 if pellets == 1 else float(i) / float(pellets - 1) - 0.5
		var b := BulletPool.take(self, _round)
		b.global_position = global_position + aim * 30.0
		if "damage" in b:
			b.damage = int(gun[2])
		if "speed" in b:
			b.speed = float(gun[4])
		b.setup(aim.rotated(k * float(gun[1]) + randf_range(-0.03, 0.03)), self)
	if kit:
		kit.kick(1.0)
	Audio.play("shot_shotgun" if pellets >= 5 else "shot_pistol", global_position, -6.0, 0.9)
	if host:
		host.fx.muzzle(global_position + aim * 30.0, aim, pellets > 1)


## Name and health over an ally's head; the revive clock while he's down.
class AllyTag extends Node2D:
	var ally: Ally

	func _ready() -> void:
		z_index = 30
		material = StreetArt._unshaded()

	func _process(_delta: float) -> void:
		global_rotation = 0.0
		queue_redraw()

	func _draw() -> void:
		if ally == null:
			return
		var font := VisualTheme.font("mono")
		var name_text := ally.display_name().replace("THE ", "")
		var down := ally.downed_left > 0.0
		var text := ("%s  DOWN %ds" % [name_text, ceili(ally.downed_left)]) if down else name_text
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var color := Palette.DANGER if down else Palette.STAMP_GREEN
		draw_string(font, Vector2(-w * 0.5, -40), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		if not down:
			var frac := clampf(float(ally.health) / float(maxi(ally.max_health, 1)), 0.0, 1.0)
			draw_rect(Rect2(-22, -34, 44, 4), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(-22, -34, 44 * frac, 4), color)
