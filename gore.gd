extends Node2D
class_name Gore
## Stylised gore for one heist (Settings "gore": off / low / full; "blood_style":
## red / noir — ink-black with a red rim).
##
##   OFF   sparks and dust puffs instead of blood; bodies fade after 3 s
##   LOW   spray particles and short-lived marks; no gibs, no pools
##   FULL  everything: sprays, exit sprays, floor and wall splats, pools
##         growing under bodies, smears where bodies slid, drip trails,
##         gibs on overkills and explosions, bloody footprints
##
## The building remembers: settled FULL marks are baked into one texture per
## room (floor layer under the bodies, wall layer over the wall art), so
## hundreds of marks cost about one draw call per room. Marks outside any
## room (the street) and LOW marks are live nodes, capped, oldest first.
##
## Physics: nothing here collides. Sprays, gibs and bodies ray-check the
## wall layer (Layers.WALLS, 1) to stop or bounce; no new layers.

const DECAL_SCALE := 0.5          # decal texture pixels per world pixel
const LIVE_CAP := 60              # live marks (LOW, or outside rooms)
const LOW_LIFE := 8.0             # seconds a LOW mark lasts
const GIB_CAP := 80
const SPRAY_CAP := 36
const FOOTPRINT_STEPS := 12
const STEP_LENGTH := 18.0
const UPLOAD_EVERY := 0.2         # decal textures upload at most this often

var host: Node
var level := Settings.GORE_FULL
var noir := false
## Totals for tests and the debug menu.
var stamps := 0
var gibs_spawned := 0

var _layers: Array = []           # RoomLayer, floor
var _walls: Array = []            # RoomLayer, wall splats
var _live: Array = []             # LiveMark
var _gibs: Array = []             # Gib (pooled)
var _sprays: Array = []           # Spray (pooled)
var _sliding: Array = []          # [Corpse, last position]
var _pools: Array = []            # [position, radius]
var _tracks: Dictionary = {}      # instance id -> [last position, steps left, side]
var _brushes: Dictionary = {}
var _upload_clock := 0.0
var _drip_clock := 0.0
var _track_clock := 0.0
var _rng := RandomNumberGenerator.new()

# ------------------------------------------------------------------ setup --
func _ready() -> void:
	_rng.randomize()
	_read_settings()
	Settings.changed.connect(_read_settings)

func _read_settings() -> void:
	level = int(Settings.values.get("gore", Settings.GORE_FULL))
	noir = int(Settings.values.get("blood_style", 0)) == 1

## One floor layer and one wall layer per building room.
func setup(floor_host: Node) -> void:
	host = floor_host
	if host == null or host.get("generator") == null:
		return
	for room: Node2D in host.generator.rooms:
		var size: Vector2 = room.get("room_size")
		var floor_layer := RoomLayer.new()
		floor_layer.room_size = size
		floor_layer.z_index = -8
		room.add_child(floor_layer)
		_layers.append(floor_layer)
		var wall_layer := RoomLayer.new()
		wall_layer.room_size = size
		wall_layer.z_index = -1
		room.add_child(wall_layer)
		_walls.append(wall_layer)

func core_color() -> Color:
	return Color(0.05, 0.035, 0.045, 0.92) if noir else Color(0.46, 0.03, 0.05, 0.9)

func rim_color() -> Color:
	return Color(0.62, 0.04, 0.07, 0.85) if noir else Color(0.3, 0.01, 0.03, 0.9)

## Things that don't bleed.
static func bleeds(victim: Node) -> bool:
	if victim == null or not is_instance_valid(victim):
		return true
	if "kind" in victim and victim is Enemy:
		return not (int(victim.kind) in [Enemy.Kind.DRONE, Enemy.Kind.TURRET])
	return true

# ---------------------------------------------------------------- stamping --
func _layer_at(world: Vector2, wall: bool) -> RoomLayer:
	for layer: RoomLayer in (_walls if wall else _layers):
		if is_instance_valid(layer) and layer.rect().has_point(world):
			return layer
	return null

func _brush(radius: int, col: Color) -> Image:
	var key := "%d:%s" % [radius, col.to_html()]
	if _brushes.has(key):
		return _brushes[key]
	var size := radius * 2 + 1
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - radius, y - radius).length()
			var a := clampf((radius + 0.5 - d) / 1.3, 0.0, 1.0)
			if a > 0.0:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * a))
	_brushes[key] = img
	return img

## Paint one soft round mark into a baked layer. False when outside rooms.
func _stamp(world: Vector2, radius: float, col: Color, wall := false) -> bool:
	var layer := _layer_at(world, wall)
	if layer == null:
		return false
	var r := clampi(roundi(radius * DECAL_SCALE), 1, 18)
	var brush := _brush(r, col)
	var local := (world - layer.global_position) * DECAL_SCALE
	layer.image.blend_rect(brush, Rect2i(0, 0, brush.get_width(), brush.get_height()), Vector2i(roundi(local.x) - r, roundi(local.y) - r))
	layer.dirty = true
	stamps += 1
	return true

## A set of blood blots [[world position, radius], ...]: baked in FULL
## inside rooms, otherwise one live mark (short-lived in LOW).
func splat(blots: Array, alpha := 1.0, wall := false, color_override := Color(0, 0, 0, 0)) -> void:
	if level == Settings.GORE_OFF or blots.is_empty():
		return
	var core := core_color() if color_override.a <= 0.0 else color_override
	core.a *= alpha
	var rim := rim_color()
	rim.a *= alpha
	var leftovers: Array = []
	if level == Settings.GORE_FULL:
		for b: Array in blots:
			var ok := true
			if noir and color_override.a <= 0.0:
				ok = _stamp(b[0], float(b[1]) + 1.6, rim, wall)
			if ok:
				ok = _stamp(b[0], float(b[1]), core, wall)
			if not ok:
				leftovers.append(b)
	else:
		leftovers = blots
	if leftovers.is_empty():
		return
	var mark := LiveMark.new()
	mark.blots = leftovers
	mark.core = core
	mark.rim = rim if noir and color_override.a <= 0.0 else Color(0, 0, 0, 0)
	mark.life = LOW_LIFE if level == Settings.GORE_LOW else -1.0
	mark.z_index = -1 if wall else -7
	add_child(mark)
	_live.append(mark)
	while _live.size() > LIVE_CAP:
		var old: Node = _live.pop_front()
		if is_instance_valid(old):
			old.fade()

# ------------------------------------------------------------------- hits --
## A round landing in someone: spray along the shot (an exit spray keeps
## going out the far side of a pierced body). `amount` is the damage.
func on_hit(at: Vector2, dir: Vector2, amount: int, exit := false, victim: Node = null) -> void:
	if not bleeds(victim):
		if host:
			host.fx.spark(at, -dir, Palette.NEON_CYAN)
		return
	if level == Settings.GORE_OFF:
		if host:
			host.fx.spark(at, -dir, Color(0.7, 0.68, 0.62))
			_dust(at)
		return
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var count := clampi(4 + amount * 3 + (4 if exit else 0), 4, 22)
	_spray(at, d, count, 0.5 if exit else 0.75, (1.35 if exit else 1.0) * (1.0 + amount * 0.12))
	# Spray that reaches a wall paints it.
	var reach := 40.0 + amount * 22.0 + (30.0 if exit else 0.0)
	_wall_splat_along(at, d, reach, 0.6 + amount * 0.15)

func _spray(at: Vector2, dir: Vector2, count: int, cone: float, speed_scale: float) -> void:
	var s: Spray = null
	for existing: Spray in _sprays:
		if not existing.active:
			s = existing
			break
	if s == null:
		if _sprays.size() < SPRAY_CAP:
			s = Spray.new()
			add_child(s)
			_sprays.append(s)
		else:
			s = _sprays.pop_front()
			s.land(self)
			_sprays.append(s)
	s.start(at, dir, count, cone, speed_scale, core_color(), _rng)

func _wall_splat_along(at: Vector2, dir: Vector2, reach: float, size: float) -> void:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(at, at + dir * reach, Layers.WALLS)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	var p: Vector2 = hit["position"] - Vector2(hit["normal"]) * 3.0
	var blots: Array = [[p, 3.0 + size * 3.0]]
	var along := Vector2(hit["normal"]).orthogonal()
	for i in _rng.randi_range(2, 5):
		blots.append([p + along * _rng.randf_range(-10, 10) * size - Vector2(hit["normal"]) * _rng.randf_range(0, 4), _rng.randf_range(1.2, 2.8)])
	splat(blots, 0.9, true)

## A body slamming into a wall.
func on_corpse_wall(_corpse: Node, at: Vector2, normal: Vector2) -> void:
	if level == Settings.GORE_OFF:
		return
	var p := at - normal * 3.0
	var along := normal.orthogonal()
	var blots: Array = [[p, 7.0]]
	for i in 7:
		blots.append([p + along * _rng.randf_range(-18, 18) - normal * _rng.randf_range(0, 6), _rng.randf_range(1.5, 4.0)])
	splat(blots, 1.0, true)
	var floor_blots: Array = []
	for i in 4:
		floor_blots.append([at + normal * _rng.randf_range(4, 16) + along * _rng.randf_range(-12, 12), _rng.randf_range(2.0, 4.5)])
	splat(floor_blots)

## Off: a puff of dust where the round landed.
func _dust(at: Vector2) -> void:
	var puff := LiveMark.new()
	puff.position = at
	puff.blots = [[at, 6.0]]
	puff.core = Color(0.62, 0.6, 0.55, 0.35)
	puff.life = 0.5
	puff.grow = 2.2
	puff.z_index = 5
	add_child(puff)

# ------------------------------------------------------------------ kills --
func on_kill(info: KillInfo) -> void:
	var victim := info.victim
	if not bleeds(victim):
		return
	if level == Settings.GORE_OFF:
		if host:
			for i in 3:
				host.fx.spark(info.position, Vector2.from_angle(_rng.randf() * TAU), Color(0.7, 0.68, 0.62))
		_dust(info.position)
		return
	var d := info.dir.normalized() if info.dir.length() > 0.01 else Vector2.from_angle(_rng.randf() * TAU)
	match info.kill_class:
		KillInfo.EXPLOSIVE:
			for i in 5:
				_spray(info.position, Vector2.from_angle(TAU * i / 5.0 + _rng.randf() * 0.5), 9, 0.9, 1.5)
		KillInfo.BURN:
			pass
		_:
			_spray(info.position, d, 12 if info.is_violent() else 7, 0.7, 1.4 if info.is_violent() else 1.1)
	if level == Settings.GORE_FULL and info.is_violent():
		_gib_burst(info, d)
	var corpse := info.corpse
	if corpse and is_instance_valid(corpse):
		if not corpse.hit_wall.is_connected(on_corpse_wall):
			corpse.hit_wall.connect(on_corpse_wall)
		if level == Settings.GORE_FULL:
			_sliding.append([corpse, corpse.global_position])
			corpse.settled.connect(_on_corpse_settled.bind(info.kill_class))

func _on_corpse_settled(corpse: Corpse, kill_class: StringName) -> void:
	if level != Settings.GORE_FULL or not is_instance_valid(corpse):
		return
	var pool := Pool.new()
	pool.target = 30.0 if kill_class in [KillInfo.OVERKILL, KillInfo.EXPLOSIVE] else 22.0
	pool.core = core_color()
	pool.rim = rim_color() if noir else Color(0, 0, 0, 0)
	pool.gore = self
	pool.z_index = -7
	add_child(pool)
	pool.global_position = corpse.global_position + Vector2(-6, 0).rotated(corpse.rotation)

## A pool finished growing: bake it and remember it for footprints.
func bake_pool(at: Vector2, radius: float) -> void:
	var blots: Array = [[at, radius * 0.72]]
	for i in 6:
		blots.append([at + Vector2.from_angle(TAU * i / 6.0 + _rng.randf() * 0.6) * radius * _rng.randf_range(0.35, 0.55), radius * _rng.randf_range(0.3, 0.45)])
	splat(blots)
	_pools.append([at, radius])
	if _pools.size() > 80:
		_pools.pop_front()

## A body over the cap leaves only a dark shape behind.
func bake_body(at: Vector2) -> void:
	if level == Settings.GORE_OFF:
		return
	splat([[at, 13.0], [at + Vector2(9, 0), 9.0], [at + Vector2(-9, 2), 8.0]], 0.8, false, Color(0.06, 0.05, 0.05, 0.75))

# ------------------------------------------------------------------- gibs --
func _gib_burst(info: KillInfo, dir: Vector2) -> void:
	var coat: Color = Color(0.25, 0.27, 0.32)
	if info.victim and is_instance_valid(info.victim) and info.victim.get("kit") and info.victim.kit:
		coat = info.victim.kit.spec.get("color", coat)
	var count := _rng.randi_range(5, 10)
	for i in count:
		var g := _take_gib()
		var v: Vector2
		if info.kill_class == KillInfo.EXPLOSIVE:
			v = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(160.0, 470.0)
		else:
			v = dir.rotated(_rng.randf_range(-0.75, 0.75)) * _rng.randf_range(130.0, 380.0)
		var col: Color = [coat, coat.darkened(0.3), core_color(), rim_color()][i % 4]
		g.start(info.position + Vector2.from_angle(_rng.randf() * TAU) * 4.0, v, col, _rng)
		gibs_spawned += 1

func _take_gib() -> Gib:
	for g: Gib in _gibs:
		if not g.active:
			return g
	if _gibs.size() < GIB_CAP:
		var fresh := Gib.new()
		fresh.z_index = -6
		add_child(fresh)
		_gibs.append(fresh)
		return fresh
	# Over the cap: the oldest gib settles on the spot.
	var oldest: Gib = _gibs.pop_front()
	_settle_gib(oldest)
	_gibs.append(oldest)
	return oldest

## Live (not yet baked) blood marks, for the perf bench.
func live_marks() -> int:
	return _live.size()

func active_gibs() -> int:
	var n := 0
	for g: Gib in _gibs:
		if g.active:
			n += 1
	return n

func _settle_gib(g: Gib) -> void:
	if not g.active:
		return
	g.active = false
	g.hide()
	splat([[g.global_position, 2.4]], 0.9, false, g.color.darkened(0.2))
	splat([[g.global_position + Vector2(2, 1), 1.6]], 0.8)

func _tick_gibs(delta: float) -> void:
	var space := get_world_2d().direct_space_state
	for g: Gib in _gibs:
		if not g.active:
			continue
		var speed := g.velocity.length()
		if speed < 8.0:
			_settle_gib(g)
			continue
		var step := g.velocity * delta
		if speed > 20.0:
			var query := PhysicsRayQueryParameters2D.create(g.global_position, g.global_position + step * 1.5, Layers.WALLS)
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				g.velocity = g.velocity.bounce(hit["normal"]) * 0.4
				g.global_position = Vector2(hit["position"]) + Vector2(hit["normal"]) * 2.0
				splat([[Vector2(hit["position"]) - Vector2(hit["normal"]) * 2.0, 2.2]], 0.8, true)
				continue
		g.position += step
		g.velocity *= exp(-3.4 * delta)
		g.rotation += g.spin * delta
		g.spin *= exp(-2.5 * delta)
		g.trail += step.length()
		if g.trail >= 10.0 and level == Settings.GORE_FULL:
			g.trail = 0.0
			splat([[g.global_position, 1.1]], 0.7)

# --------------------------------------------------------------- per frame --
func _process(delta: float) -> void:
	if _gibs.size() > 0:
		_tick_gibs(delta)
	for s: Spray in _sprays:
		if s.active and s.tick(delta):
			s.land(self)
	_tick_smears()
	_track_clock -= delta
	if _track_clock <= 0.0:
		_track_clock = 0.1
		_tick_footprints()
	_drip_clock -= delta
	if _drip_clock <= 0.0:
		_drip_clock = 0.35
		_tick_drips()
	_upload_clock -= delta
	if _upload_clock <= 0.0:
		_upload_clock = UPLOAD_EVERY
		for layer: RoomLayer in _layers + _walls:
			if layer.dirty:
				layer.upload()

## Bodies still sliding leave a smear.
func _tick_smears() -> void:
	for i in range(_sliding.size() - 1, -1, -1):
		var entry: Array = _sliding[i]
		var corpse: Node2D = entry[0]
		if not is_instance_valid(corpse) or not corpse.is_processing():
			_sliding.remove_at(i)
			continue
		var moved: Vector2 = corpse.global_position - entry[1]
		if moved.length() >= 5.0:
			var side := moved.orthogonal().normalized()
			splat([[corpse.global_position + side * _rng.randf_range(-5, 5), _rng.randf_range(2.5, 4.5)]], 0.75)
			entry[1] = corpse.global_position

func _in_pool(at: Vector2) -> bool:
	for p: Array in _pools:
		if at.distance_squared_to(p[0]) <= float(p[1]) * float(p[1]) * 0.8:
			return true
	return false

## Walking through a pool leaves ~12 fading prints (player and guards).
func _tick_footprints() -> void:
	if level != Settings.GORE_FULL or _pools.is_empty() or host == null:
		return
	var walkers: Array = []
	if is_instance_valid(host.player):
		walkers.append(host.player)
	if host.director:
		for e in host.director.enemies:
			if is_instance_valid(e) and not e.sleeping and not e._dead:
				walkers.append(e)
	for body: Node2D in walkers:
		var id := body.get_instance_id()
		var t: Array = _tracks.get(id, [])
		if t.is_empty():
			t = [body.global_position, 0, 1]
			_tracks[id] = t
		if _in_pool(body.global_position):
			t[1] = FOOTPRINT_STEPS
		var moved: Vector2 = body.global_position - t[0]
		if moved.length() < STEP_LENGTH:
			continue
		t[0] = body.global_position
		if int(t[1]) <= 0:
			continue
		var fwd := moved.normalized()
		var side := fwd.orthogonal() * 4.0 * float(t[2])
		var a := 0.75 * float(t[1]) / FOOTPRINT_STEPS
		splat([[body.global_position + side - fwd * 3.0, 2.2], [body.global_position + side + fwd * 3.0, 2.6]], a)
		t[1] = int(t[1]) - 1
		t[2] = -int(t[2])

## Wounded people bleed as they move; the player drips at 1 HP.
func _tick_drips() -> void:
	if level == Settings.GORE_OFF or host == null:
		return
	var drips: Array = []
	var player: Node2D = host.player
	if is_instance_valid(player) and int(player.get("health")) == 1 and not player.is_dead():
		drips.append(player.global_position)
	if host.director:
		for e in host.director.enemies:
			if is_instance_valid(e) and not e._dead and not e.sleeping and bleeds(e) \
					and e.health <= e.max_health * 0.3 and e.velocity.length() > 20.0:
				drips.append(e.global_position)
	for c in get_tree().get_nodes_in_group("civilians"):
		if c.get("_dead") == false and float(c.get("health")) <= float(c.get("max_health")) * 0.3 and c.velocity.length() > 20.0:
			drips.append(c.global_position)
	for at: Vector2 in drips:
		splat([[at + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)), _rng.randf_range(1.2, 2.2)]], 0.85)


# ============================================================ inner classes ==
## One room's baked marks: an Image blitted into, uploaded when dirty.
class RoomLayer extends Node2D:
	var room_size := Vector2.ZERO
	var image: Image
	var texture: ImageTexture
	var dirty := false

	func _ready() -> void:
		var w := maxi(1, ceili(room_size.x * Gore.DECAL_SCALE))
		var h := maxi(1, ceili(room_size.y * Gore.DECAL_SCALE))
		image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		texture = ImageTexture.create_from_image(image)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func rect() -> Rect2:
		return Rect2(global_position, room_size)

	func upload() -> void:
		texture.update(image)
		dirty = false
		queue_redraw()

	func _draw() -> void:
		draw_texture_rect(texture, Rect2(Vector2.ZERO, room_size), false)


## Marks that aren't baked: LOW marks (they fade) and marks in the street.
class LiveMark extends Node2D:
	var blots: Array = []
	var core := Color.RED
	var rim := Color(0, 0, 0, 0)
	var life := -1.0             # < 0: stays until the cap retires it
	var grow := 0.0              # dust puffs swell as they fade
	var _age := 0.0

	func _ready() -> void:
		set_process(life > 0.0)
		queue_redraw()

	func _process(delta: float) -> void:
		_age += delta
		if _age >= life:
			queue_free()
			return
		modulate.a = clampf((life - _age) / minf(life * 0.4, 2.0), 0.0, 1.0)
		if grow > 0.0:
			scale = Vector2.ONE * (1.0 + grow * _age / life)
			queue_redraw()

	func fade() -> void:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 1.0)
		tw.tween_callback(queue_free)

	func _draw() -> void:
		for b: Array in blots:
			var p: Vector2 = to_local(b[0])
			if rim.a > 0.0:
				draw_circle(p, float(b[1]) + 1.6, rim)
			draw_circle(p, float(b[1]), core)


## A pool spreading under a body over ~2 s, then baked.
class Pool extends Node2D:
	var target := 22.0
	var core := Color.RED
	var rim := Color(0, 0, 0, 0)
	var gore: Gore
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= 2.0:
			if gore and is_instance_valid(gore):
				gore.bake_pool(global_position, target)
			queue_free()

	func _draw() -> void:
		var k := ease(clampf(_t / 2.0, 0.0, 1.0), 0.4)
		var r := 4.0 + (target - 4.0) * k
		if rim.a > 0.0:
			draw_circle(Vector2.ZERO, r * 0.78 + 1.6, rim)
		draw_circle(Vector2.ZERO, r * 0.78, core)
		for i in 6:
			draw_circle(Vector2.from_angle(TAU * i / 6.0 + 0.4) * r * 0.45, r * 0.38, core)


## Blood droplets flying out along a shot; they land as a splatter.
class Spray extends Node2D:
	var active := false
	var _drops: Array = []        # [position (local), velocity, radius]
	var _age := 0.0
	var _col := Color.RED

	func start(at: Vector2, dir: Vector2, count: int, cone: float, speed_scale: float, col: Color, rng: RandomNumberGenerator) -> void:
		global_position = at
		_col = col
		_age = 0.0
		_drops.clear()
		for i in count:
			var v := dir.rotated(rng.randf_range(-cone, cone)) * rng.randf_range(60.0, 230.0) * speed_scale
			_drops.append([Vector2.ZERO, v, rng.randf_range(0.9, 2.6)])
		active = true
		show()
		queue_redraw()

	## True when the droplets have landed.
	func tick(delta: float) -> bool:
		_age += delta
		for d: Array in _drops:
			d[0] += Vector2(d[1]) * delta
			d[1] = Vector2(d[1]) * exp(-7.0 * delta)
		queue_redraw()
		return _age >= 0.24

	func land(gore: Gore) -> void:
		if not active:
			return
		active = false
		hide()
		var blots: Array = []
		for d: Array in _drops:
			blots.append([global_position + Vector2(d[0]), float(d[2])])
		gore.splat(blots)

	func _draw() -> void:
		if not active:
			return
		for d: Array in _drops:
			var p: Vector2 = d[0]
			var tail: Vector2 = Vector2(d[1]) * 0.02
			draw_line(p - tail, p, _col, float(d[2]))


## A chunk: a small shard in the victim's coat colour or blood.
class Gib extends Node2D:
	var active := false
	var velocity := Vector2.ZERO
	var spin := 0.0
	var trail := 0.0
	var color := Color.RED
	var _shape := PackedVector2Array()

	func start(at: Vector2, v: Vector2, col: Color, rng: RandomNumberGenerator) -> void:
		global_position = at
		velocity = v
		spin = rng.randf_range(-12.0, 12.0)
		trail = 0.0
		color = col
		_shape.clear()
		var points := rng.randi_range(3, 5)
		var size := rng.randf_range(3.0, 7.0)
		for i in points:
			_shape.append(Vector2.from_angle(TAU * i / points + rng.randf_range(-0.3, 0.3)) * size * rng.randf_range(0.6, 1.0))
		active = true
		show()
		queue_redraw()

	func _draw() -> void:
		if _shape.size() >= 3:
			draw_colored_polygon(_shape, color)
			draw_polyline(_shape + PackedVector2Array([_shape[0]]), color.darkened(0.45), 1.0)
