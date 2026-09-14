extends Node2D
class_name CargoVan

## Reinforcement delivery. Instead of guards appearing out of thin air, a van
## screeches up to the building, sits for a beat, then unloads a squad that
## hunts the player immediately.
##
## HeistFloor spawns these at the entrance/exits when heat triggers a wave.

signal squad_deployed(enemies: Array)

@export var approach_time: float = 1.1     # seconds driving in
@export var door_delay: float = 0.45       # pause before the doors open
@export var squad_size: int = 3
@export var miniboss: bool = false         # buffs stats + marks them visually

var enemy_scene: PackedScene = null
var archetypes: Array = []                 # Enemy.Kind values to deploy
var drop_position: Vector2 = Vector2.ZERO  # where the squad ends up
var approach_from: Vector2 = Vector2.ZERO  # off-screen start

var _body: Polygon2D
var _timer: float = 0.0
var _state: int = 0                        # 0 driving, 1 waiting, 2 done

func _ready() -> void:
	z_index = 4
	_build_visual()
	global_position = approach_from
	_timer = approach_time

func _build_visual() -> void:
	# Van body, deliberately chunky so it reads at a glance.
	_body = Polygon2D.new()
	_body.polygon = PackedVector2Array([
		Vector2(-62, -30), Vector2(62, -30), Vector2(62, 30), Vector2(-62, 30)])
	_body.color = Color(0.14, 0.15, 0.2)
	add_child(_body)

	var cab := Polygon2D.new()
	cab.polygon = PackedVector2Array([
		Vector2(30, -26), Vector2(58, -26), Vector2(58, 26), Vector2(30, 26)])
	cab.color = Color(0.28, 0.3, 0.38)
	add_child(cab)

	# Roof light bar — signals "these are not friendly".
	var light := Polygon2D.new()
	light.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8), Vector2(14, 8), Vector2(-14, 8)])
	light.color = Color(1.0, 0.3, 0.25)
	add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "modulate:a", 0.25, 0.35)
	tw.tween_property(light, "modulate:a", 1.0, 0.35)

func _process(delta: float) -> void:
	if _state == 2:
		return
	_timer -= delta
	if _state == 0:
		# Drive in, easing to a stop at the drop point.
		var t: float = 1.0 - clampf(_timer / approach_time, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - t, 3.0)
		global_position = approach_from.lerp(drop_position, eased)
		if _timer <= 0.0:
			_state = 1
			_timer = door_delay
	elif _state == 1 and _timer <= 0.0:
		_deploy()

func _deploy() -> void:
	_state = 2
	var spawned: Array = []
	if enemy_scene == null:
		squad_deployed.emit(spawned)
		return
	for i in squad_size:
		var e = enemy_scene.instantiate()
		# Add to the level, not the van — the van drives off afterwards.
		get_parent().add_child(e)
		# Ring placement, but grow the radius with squad size so a big squad
		# can't pile onto one spot. Stagger the angle too.
		var ring_r: float = 40.0 + squad_size * 8.0
		var angle := TAU * float(i) / float(maxi(squad_size, 1)) \
			+ randf_range(-0.2, 0.2)
		e.global_position = global_position \
			+ Vector2(cos(angle), sin(angle)) * ring_r \
			+ Vector2(randf_range(-8, 8), randf_range(-8, 8))
		if e.has_method("apply_archetype") and not archetypes.is_empty():
			e.apply_archetype(archetypes[i % archetypes.size()])
			if miniboss:
				_make_miniboss(e)
		if "hunting" in e:
			e.hunting = true      # they were radioed in; they know where you are
		spawned.append(e)
	squad_deployed.emit(spawned)
	_drive_off()

## Toughens a reinforcement into a genuine miniboss: more health, a bit more
## damage, bigger on screen with a gold outline so it reads as a real event
## walking in, not just another guard.
func _make_miniboss(e: Node) -> void:
	if "max_health" in e:
		e.max_health = int(e.max_health * 1.8)
		e.health = e.max_health
	if "bullet_damage" in e:
		e.bullet_damage = int(e.bullet_damage) + 1
	if "currency_value" in e:
		e.currency_value *= 2
	if "sprite" in e and e.sprite:
		e.sprite.scale *= 1.25

func _drive_off() -> void:
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(self, "global_position", approach_from, 1.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
