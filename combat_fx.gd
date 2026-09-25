extends Node
class_name CombatFX
## The heist's feel hub: trauma-based camera shake, camera recoil and aim lead,
## hit-stop and slow-motion (real-time managed, always restored), muzzle
## flashes, pooled sparks, shell casings, bullet holes, blood, damage numbers
## and market chips. Everything respects Settings (low effects, shake slider,
## damage numbers, reduce flashing).

const MAX_OFFSET := 20.0
const MAX_ROLL := 0.035
const HOLE_CAP := 80
const CASING_CAP := 40

var camera: Camera2D
var lighting: HeistLighting
var trauma := 0.0
var lead := Vector2.ZERO
var _kick := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _t := 0.0
var _holes: Array = []
var _casings: Array = []
var _numbers: Array = []
var _sparks: Array = []
var _blood: Array = []
var _layer: Node2D            # world-space FX parent (set by the heist)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_noise.frequency = 2.2
	_noise.seed = 1234

func _low() -> bool:
	return Settings.values.get("low_effects", false)

func world() -> Node2D:
	if _layer == null or not is_instance_valid(_layer):
		_layer = Node2D.new()
		_layer.z_index = 12
		get_parent().add_child(_layer)
	return _layer

# ---------------------------------------------------------------- camera ----
## Trauma is 0..1; shake grows with its square so small hits stay subtle.
func add_trauma(amount: float) -> void:
	if _low():
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

## Back-compat with pixel-ish amounts (2 = small shot, 9 = taking a hit).
func shake(amount: float) -> void:
	add_trauma(amount / 22.0)

## Throw the camera a few pixels toward something that just happened.
func punch(direction: Vector2, strength: float) -> void:
	if _low() or direction.length() < 0.01:
		return
	_kick += direction.normalized() * strength * float(Settings.values.get("shake", 1.0))

func recoil(direction: Vector2, strength: float) -> void:
	if _low():
		return
	_kick -= direction.normalized() * strength

func _process(delta: float) -> void:
	_t += delta
	# Time scale belongs to TimeController; the camera works in real time.
	if not is_instance_valid(camera):
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.01) if Engine.time_scale < 1.0 else delta
	trauma = maxf(trauma - real_delta * 1.3, 0.0)
	_kick = _kick.lerp(Vector2.ZERO, clampf(real_delta * 14.0, 0.0, 1.0))
	var amount: float = trauma * trauma * float(Settings.values.get("shake", 1.0))
	var shake_offset := Vector2(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0)) * MAX_OFFSET * amount
	camera.offset = shake_offset + _kick + lead
	camera.rotation = _noise.get_noise_2d(_t * 40.0, 99.0) * MAX_ROLL * amount

# ------------------------------------------------------------------ time ----
## Kept as thin wrappers: TimeController owns Engine.time_scale.
func hit_stop(seconds: float = 0.06) -> void:
	TimeController.hit_stop(seconds)

func slow_mo(seconds: float, scale: float) -> void:
	TimeController.slow_mo(seconds, scale)

var slow_active: bool:
	get:
		return TimeController.is_slowed()

## Last guard in a room: a short slow beat.
func last_kill() -> void:
	add_trauma(0.25)
	if TimeController.is_slowed() or _low():
		return
	TimeController.slow_mo(0.22, 0.35, &"last_kill")

func _exit_tree() -> void:
	TimeController.clear()
	if is_instance_valid(camera):
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0

# ----------------------------------------------------------------- flashes --
func muzzle(at: Vector2, direction: Vector2, big := false) -> void:
	if lighting:
		lighting.muzzle_flash(at)
	if _low():
		return
	var flash := Polygon2D.new()
	var l := 34.0 if big else 24.0
	flash.polygon = PackedVector2Array([Vector2(-3, -7), Vector2(l, 0), Vector2(-3, 7), Vector2(6, 0)])
	flash.color = Color(1.0, 0.9, 0.55)
	flash.material = StreetArt._unshaded()
	world().add_child(flash)
	flash.global_position = at
	flash.rotation = direction.angle() + randf_range(-0.15, 0.15)
	flash.z_index = 20
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([Vector2(0, -3), Vector2(l * 0.5, 0), Vector2(0, 3)])
	core.color = Color.WHITE
	flash.add_child(core)
	var t := flash.create_tween()
	t.tween_property(flash, "modulate:a", 0.0, 0.06)
	t.tween_callback(flash.queue_free)

# ----------------------------------------------------------------- debris ---
# Sparks, bullet holes, casings and blood are pooled: each kind keeps a fixed
# set of nodes and reuses the oldest when it runs out, so a long firefight
# never allocates or frees FX nodes.
const SPARK_CAP := 48
const BLOOD_CAP := 40

enum Debris { SPARK, HOLE, CASING, BLOOD }

## A fresh FX node. (Built here, not via a `Spark.new` Callable: exported
## release builds can't resolve `new` as a member of an inner class.)
func _make(kind: Debris) -> Node2D:
	match kind:
		Debris.SPARK:
			return Spark.new()
		Debris.HOLE:
			return Hole.new()
		Debris.CASING:
			return Casing.new()
	return Blood.new()

func _reuse(pool: Array, cap: int, kind: Debris) -> Node2D:
	for i in range(pool.size() - 1, -1, -1):
		if not is_instance_valid(pool[i]):
			pool.remove_at(i)
	for n: Node2D in pool:
		if not n.visible:
			pool.erase(n)
			pool.append(n)
			return n
	if pool.size() < cap:
		var fresh: Node2D = _make(kind)
		world().add_child(fresh)
		pool.append(fresh)
		return fresh
	var oldest: Node2D = pool.pop_front()
	pool.append(oldest)
	return oldest

func spark(at: Vector2, normal: Vector2, color: Color = Color(1.0, 0.8, 0.4)) -> void:
	if _low():
		return
	var s := _reuse(_sparks, SPARK_CAP, Debris.SPARK) as Spark
	s.restart(color, normal if normal != Vector2.ZERO else Vector2.from_angle(randf() * TAU))
	s.global_position = at

func bullet_hole(at: Vector2) -> void:
	var hole := _reuse(_holes, HOLE_CAP, Debris.HOLE)
	hole.global_position = at
	hole.z_index = -2
	hole.show()

func casing(at: Vector2, direction: Vector2) -> void:
	if _low():
		return
	var c := _reuse(_casings, CASING_CAP, Debris.CASING) as Casing
	var side := Vector2(-direction.y, direction.x)
	c.restart(side * randf_range(90, 160) - direction * randf_range(10, 40))
	c.global_position = at

func blood(at: Vector2, direction: Vector2) -> void:
	if _low():
		return
	var b := _reuse(_blood, BLOOD_CAP, Debris.BLOOD) as Blood
	b.z_index = -3
	b.global_position = at
	b.restart(direction)

# ---------------------------------------------------------------- numbers ---
func damage_number(at: Vector2, amount: int, color: Color = Palette.PAPER) -> void:
	if not Settings.values.get("damage_numbers", true):
		return
	_float_label(at + Vector2(randf_range(-10, 10), -20), str(amount), color, 20)

## The market reacting to what you just did: "+2.3%" near the player.
func chip(at: Vector2, text: String, color: Color) -> void:
	_float_label(at + Vector2(randf_range(-20, 20), -46), text, color, 18, true)

func _float_label(at: Vector2, text: String, color: Color, size: int, boxed := false) -> void:
	var l: Label = null
	for existing: Label in _numbers:
		if is_instance_valid(existing) and not existing.visible:
			l = existing
			break
	if l == null:
		if _numbers.size() >= 28:
			l = _numbers.pop_front()
			_numbers.append(l)
		else:
			l = Label.new()
			l.add_theme_font_override("font", VisualTheme.font("mono"))
			l.material = StreetArt._unshaded()
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.z_index = 60
			l.z_as_relative = false
			world().add_child(l)
			_numbers.append(l)
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	if boxed:
		l.add_theme_stylebox_override("normal", VisualTheme.box(Color(0, 0, 0, 0.7), color, 1, 3, 3))
	else:
		l.remove_theme_stylebox_override("normal")
	l.reset_size()
	l.global_position = at - l.size * 0.5
	l.visible = true
	l.modulate.a = 1.0
	l.scale = Vector2(1.25, 1.25)
	l.pivot_offset = l.size * 0.5
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_property(l, "global_position:y", l.global_position.y - 36.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tw.chain().tween_callback(l.hide)


class Spark extends Node2D:
	var color := Color.WHITE
	var normal := Vector2.RIGHT
	var _life := 0.0
	var _dirs: Array = []
	func _ready() -> void:
		material = StreetArt._unshaded()
		z_index = 22
	func restart(tint: Color, toward: Vector2) -> void:
		color = tint
		normal = toward
		_life = 0.0
		_dirs.clear()
		for i in 6:
			_dirs.append(normal.rotated(randf_range(-1.0, 1.0)) * randf_range(40, 140))
		show()
		set_process(true)
		queue_redraw()
	func _process(delta: float) -> void:
		_life += delta
		if _life > 0.18:
			hide()
			set_process(false)
			return
		queue_redraw()
	func _draw() -> void:
		var k := _life / 0.18
		for d: Vector2 in _dirs:
			draw_line(d * k * 0.2, d * k * 0.2 + d * 0.08, Palette.with_alpha(color, 1.0 - k), 1.6)
		draw_circle(Vector2.ZERO, 4.0 * (1.0 - k), Palette.with_alpha(Color.WHITE, 1.0 - k))

class Hole extends Node2D:
	func _ready() -> void:
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 3.2, Color(0.05, 0.04, 0.04, 0.85))
		draw_circle(Vector2(0.8, 0.8), 1.4, Color(0.3, 0.28, 0.25, 0.6))

class Casing extends Node2D:
	var velocity := Vector2.ZERO
	var _spin := 0.0
	var _age := 0.0
	func _ready() -> void:
		z_index = -1
		queue_redraw()
	func restart(kick: Vector2) -> void:
		velocity = kick
		_spin = randf_range(-20, 20)
		_age = 0.0
		rotation = 0.0
		modulate.a = 1.0
		show()
		set_process(true)
	func _process(delta: float) -> void:
		_age += delta
		if _age < 0.35:
			position += velocity * delta
			velocity = velocity.lerp(Vector2.ZERO, clampf(delta * 6.0, 0, 1))
			rotation += _spin * delta
		elif _age > 3.0:
			modulate.a = maxf(0.0, 1.0 - (_age - 3.0))
			if _age > 4.0:
				hide()
				set_process(false)
	func _draw() -> void:
		draw_rect(Rect2(-3, -1.5, 6, 3), Color("c9a24a"))
		draw_rect(Rect2(-3, -1.5, 2, 3), Color("8a6a2a"))

class Blood extends Node2D:
	var direction := Vector2.RIGHT
	var _drops: Array = []
	var _fade: Tween
	func restart(toward: Vector2) -> void:
		direction = toward
		_drops.clear()
		for i in 5:
			_drops.append([direction.normalized().rotated(randf_range(-0.6, 0.6)) * randf_range(4, 22), randf_range(1.5, 4.0)])
		modulate.a = 1.0
		show()
		queue_redraw()
		if _fade:
			_fade.kill()
		_fade = create_tween()
		_fade.tween_interval(8.0)
		_fade.tween_property(self, "modulate:a", 0.0, 2.0)
		_fade.tween_callback(hide)
	func _draw() -> void:
		for d: Array in _drops:
			draw_circle(d[0], d[1], Color(0.35, 0.03, 0.04, 0.8))
