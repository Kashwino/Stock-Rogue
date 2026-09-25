extends Node2D
class_name Blast
## Explosions: grenades, volatile elites, rockets. A blast hurts everyone in
## its radius who is not behind a wall — the player, guards, civilians and
## security devices alike — so a grenadier can flush you out of cover and
## thin out his own side. Blast.fuse() shows a landing/arming ring first.

var radius := 90.0
var player_damage := 2
var enemy_damage := 3
var player_caused := false
## Set by explosive props (Phase 5): kills count as prop kills.
var from_prop := false
## Show only: no damage, no chain reactions (BURN THE BOARD's fire).
var harmless := false
## Seconds left on the fuse; the ring fills as it runs down.
var fuse_time := 0.0
var _fuse_total := 0.0
var _boom := false
var _life := 0.0
var _mark: Telegraph

## Arm a charge at `at` that goes off after `delay` seconds.
static func fuse(host: Node, at: Vector2, delay: float, blast_radius: float = 90.0, to_player: int = 2, to_enemies: int = 3, by_player := false, prop := false) -> Blast:
	var b := Blast.new()
	b.from_prop = prop
	b.radius = blast_radius
	b.player_damage = to_player
	b.enemy_damage = to_enemies
	b.player_caused = by_player
	b.fuse_time = delay
	# Positioned before entering the tree: an instant blast goes off in _ready.
	b.position = (host as Node2D).to_local(at) if host is Node2D else at
	host.add_child(b)
	return b

## A blast for show (fire, flash, scorch, sound) that hurts nobody.
static func flare(host: Node, at: Vector2, delay: float, blast_radius: float = 90.0) -> Blast:
	var b := Blast.new()
	b.harmless = true
	b.radius = blast_radius
	b.fuse_time = delay
	b.position = (host as Node2D).to_local(at) if host is Node2D else at
	host.add_child(b)
	return b

## Go off right now.
static func detonate(host: Node, at: Vector2, blast_radius: float = 90.0, to_player: int = 2, to_enemies: int = 3, by_player := false) -> void:
	fuse(host, at, 0.0, blast_radius, to_player, to_enemies, by_player)

func _ready() -> void:
	z_index = 30
	_fuse_total = fuse_time
	if fuse_time > 0.0:
		_mark = Telegraph.new()
		add_child(_mark)
	else:
		_explode()

func _process(delta: float) -> void:
	if _boom:
		_life += delta
		if _life > 0.5:
			queue_free()
		queue_redraw()
		return
	fuse_time -= delta
	if _mark:
		_mark.clear()
		_mark.ring(global_position, radius, Palette.ENEMY_BULLET, 1.0 - fuse_time / maxf(_fuse_total, 0.01))
	if fuse_time <= 0.0:
		_explode()

func _explode() -> void:
	_boom = true
	if _mark:
		_mark.queue_free()
		_mark = null
	material = StreetArt._unshaded()
	var shot := KillInfo.next_shot_id()
	var tree := get_tree()
	var space := get_world_2d().direct_space_state
	# Other explosive props in the radius go up a beat later: chain reactions.
	for other in ([] if harmless else tree.get_nodes_in_group("explosive")):
		if other is Node2D and other.global_position.distance_to(global_position) <= radius + 16.0:
			other.blast_hit(player_caused)
	for group in ([] if harmless else ["player", "enemies", "civilians", "security"]):
		for target in tree.get_nodes_in_group(group):
			if not (target is Node2D) or not target.has_method("take_damage"):
				continue
			var off: Vector2 = target.global_position - global_position
			if off.length() > radius + 12.0:
				continue
			# Walls shelter; furniture does not (that is the point of a grenade).
			var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, Layers.WALLS)
			if not space.intersect_ray(query).is_empty():
				continue
			if group == "player":
				if "last_hit_dir" in target:
					target.last_hit_dir = off.normalized() if off.length() > 1.0 else Vector2.RIGHT
				target.take_damage(player_damage)
				continue
			if target.has_method("note_hit"):
				target.note_hit({
					"source": &"blast", "dir": off.normalized() if off.length() > 1.0 else Vector2.from_angle(randf() * TAU),
					"force": lerpf(820.0, 380.0, clampf(off.length() / maxf(radius, 1.0), 0.0, 1.0)),
					"by_player": player_caused, "shot": shot, "prop": from_prop,
				})
			if group == "civilians":
				target.take_blast(enemy_damage, player_caused)
			else:
				target.take_damage(enemy_damage)
				if target is CharacterBody2D and target.is_inside_tree() and not target.is_in_group("boss"):
					target.velocity += off.normalized() * 260.0
	Audio.play("explosion", global_position)
	var noise := get_node_or_null("/root/Noise")
	if noise:
		noise.emit_noise(global_position, &"gunshot", 1000.0)
	var host := get_tree().current_scene
	if host is HeistFloor:
		var player: Node2D = host.player
		var near := 1.0
		if is_instance_valid(player):
			near = clampf(1.0 - player.global_position.distance_to(global_position) / 900.0, 0.2, 1.0)
		host.fx.add_trauma(0.55 * near)
		for i in 5:
			host.fx.spark(global_position, Vector2.from_angle(TAU * i / 5.0), Palette.SODIUM)
		if host.fx.lighting:
			host.fx.lighting.muzzle_flash(global_position)
		_scorch(host.fx.world())

func _scorch(layer: Node2D) -> void:
	var mark := Scorch.new()
	mark.radius = radius * 0.55
	layer.add_child(mark)
	mark.global_position = global_position

func _draw() -> void:
	if not _boom:
		return
	var k := clampf(_life / 0.45, 0.0, 1.0)
	var flash := 0.0 if Settings.values.get("reduce_flashing", false) else 1.0 - k
	draw_circle(Vector2.ZERO, radius * (0.4 + k * 0.7), Color(1.0, 0.75, 0.35, 0.55 * (1.0 - k)))
	draw_circle(Vector2.ZERO, radius * 0.45 * (1.0 - k), Color(1.0, 0.95, 0.8, 0.9 * flash))
	draw_arc(Vector2.ZERO, radius * (0.3 + k), 0.0, TAU, 40, Color(1.0, 0.55, 0.2, 0.8 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)

## Soot left on the floor; fades after a while.
class Scorch extends Node2D:
	var radius := 45.0
	func _ready() -> void:
		z_index = -2
		var tw := create_tween()
		tw.tween_interval(14.0)
		tw.tween_property(self, "modulate:a", 0.0, 2.0)
		tw.tween_callback(queue_free)
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, Color(0.03, 0.03, 0.03, 0.45))
		for i in 9:
			var a := TAU * i / 9.0
			draw_line(Vector2.from_angle(a) * radius * 0.4, Vector2.from_angle(a + 0.2) * radius * 1.3, Color(0.03, 0.03, 0.03, 0.3), 4.0)
