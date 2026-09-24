extends Node2D
class_name SpriteKit
## Procedural, layered top-down character. Faces +X; the owner rotates the
## parent "Sprite" node to aim. Each layer is drawn once and animated only by
## transform, so fifty guards cost almost nothing per frame:
##   shadow (world-aligned) · feet · body · arms + weapon · head
## Readability rules: silhouette first (body/head/gun shapes differ per
## archetype), colour second; the player gets a gold rim so they always pop.

enum Body { SUIT, COAT, VEST, ARMOR, BULKY, LEAN, TRIPOD, DRONE, DOG, CIVILIAN, GOWN, HOODIE, TANK }
enum Head { BARE, CAP, FEDORA, HELMET, BERET, HOOD, BALACLAVA, BALD, HAIR, VISOR, SLICKED }
enum Gun { NONE, PISTOL, REVOLVER, SMG, RIFLE, LONG_RIFLE, SHOTGUN, LMG, LAUNCHER, TABLET, CANE, LEDGER }

const SKIN := [Color("e0b48c"), Color("c68c62"), Color("9a6445"), Color("6b4430"), Color("f0cfae")]

var spec: Dictionary = {}
var hero := false

var _t := 0.0
var _walk := 0.0
var _recoil := 0.0
var _hurt := 0.0
var _dead := false
var _reload_left := 0.0
var _reload_len := 0.0
var _body_node: Node2D = null
var _layers: Dictionary = {}
var _notifier: VisibleOnScreenNotifier2D
var _flash_tween: Tween

class Layer extends Node2D:
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

## Dress `sprite` (a Node2D) with a kit built from `spec`, replacing any older
## art. Returns the kit. Hides legacy Polygon2D children from .tscn files.
static func dress(sprite: Node2D, kit_spec: Dictionary) -> SpriteKit:
	var kit := sprite.get_node_or_null("Kit") as SpriteKit
	if kit == null:
		for child in sprite.get_children():
			if child is CanvasItem:
				child.hide()
		kit = SpriteKit.new()
		kit.name = "Kit"
		sprite.add_child(kit)
	kit.apply(kit_spec)
	return kit

func _ready() -> void:
	_notifier = VisibleOnScreenNotifier2D.new()
	_notifier.rect = Rect2(-60, -60, 120, 120)
	add_child(_notifier)
	_notifier.screen_entered.connect(set_process.bind(true))
	_notifier.screen_exited.connect(set_process.bind(false))
	_body_node = _find_body()
	if _layers.is_empty():
		_build()

func _find_body() -> Node2D:
	var n: Node = get_parent()
	while n != null:
		if n is CharacterBody2D:
			return n
		n = n.get_parent()
	return null

func apply(kit_spec: Dictionary) -> void:
	spec = kit_spec.duplicate()
	hero = spec.get("hero", false)
	if is_inside_tree():
		_build()

func _build() -> void:
	for child in get_children():
		if child is Layer:
			child.queue_free()
	_layers.clear()
	for id in ["shadow", "feet_l", "feet_r", "body", "arms", "head", "extra"]:
		var layer := Layer.new()
		layer.name = id
		layer.painter = Callable(self, "_paint_" + id)
		add_child(layer)
		_layers[id] = layer
	scale = Vector2.ONE * float(spec.get("scale", 1.0))

# ------------------------------------------------------------- animation ----
func _process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	var speed := 0.0
	if is_instance_valid(_body_node):
		speed = _body_node.velocity.length()
	var body_kind: int = spec.get("body", Body.SUIT)
	# Shadow stays world-aligned regardless of facing.
	var shadow: Node2D = _layers.get("shadow")
	if shadow:
		shadow.global_rotation = 0.0
		shadow.global_position = global_position + Vector2(4, 7) * scale.x
	if body_kind == Body.DRONE:
		_layers["extra"].rotation += delta * 30.0
		_layers["body"].position.y = sin(_t * 5.0) * 1.5
		return
	if body_kind == Body.TRIPOD:
		_layers["arms"].position.x = -_recoil * 5.0
		_recoil = move_toward(_recoil, 0.0, delta * 8.0)
		return
	var moving := speed > 12.0
	if moving:
		_walk += delta * clampf(speed / 60.0, 1.2, 4.0) * 3.2
	else:
		_walk = lerpf(_walk, roundf(_walk / PI) * PI, clampf(delta * 8.0, 0.0, 1.0))
	var stride := sin(_walk) * (7.0 if moving else 0.0)
	_layers["feet_l"].position.x = stride
	_layers["feet_r"].position.x = -stride
	var bob := absf(sin(_walk)) * 1.2 if moving else 0.0
	var breathe := sin(_t * 2.1) * 0.022 if not moving else 0.0
	_layers["body"].scale = Vector2(1.0 + breathe * 0.4, 1.0 + breathe)
	_layers["body"].position.x = -bob * 0.4
	_layers["head"].position.x = -bob * 0.3 + (sin(_t * 1.3) * 0.4 if not moving else 0.0)
	_recoil = move_toward(_recoil, 0.0, delta * 7.0)
	var reload_tilt := 0.0
	if _reload_left > 0.0:
		_reload_left = maxf(_reload_left - delta, 0.0)
		reload_tilt = sin(PI * (1.0 - _reload_left / maxf(_reload_len, 0.01))) * 0.55
	_layers["arms"].position.x = -_recoil * 7.0 - reload_tilt * 6.0
	_layers["arms"].rotation = sin(_walk) * 0.03 - _recoil * 0.08 + reload_tilt
	if _hurt > 0.0:
		_hurt = maxf(_hurt - delta, 0.0)
		_layers["body"].rotation = sin(_hurt * 60.0) * _hurt * 0.4

## Weapon kick; `strength` 0..1.5.
func kick(strength: float = 1.0) -> void:
	_recoil = clampf(_recoil + strength, 0.0, 1.6)

## Lower the weapon while reloading (hands off the trigger).
func reload_pose(duration: float) -> void:
	_reload_len = maxf(duration, 0.05)
	_reload_left = _reload_len

## White hit flash plus a small jolt.
func flash() -> void:
	_hurt = 0.18
	if Settings.values.get("low_effects", false):
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = Color(3.0, 3.0, 3.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, 0.08)

func set_tint(color: Color) -> void:
	modulate = color

# ----------------------------------------------------------- death decal ----
## Leaves a fallen body on the floor that fades after a while. Capped so long
## firefights don't pile up draw calls.
static func drop_corpse(host: Node, at: Vector2, facing: float, kit_spec: Dictionary) -> void:
	if host == null or not host.is_inside_tree():
		return
	var existing := host.get_tree().get_nodes_in_group("corpse")
	if existing.size() >= 40:
		existing[0].queue_free()
	var corpse := Corpse.new()
	corpse.spec = kit_spec
	corpse.global_position = at
	corpse.rotation = facing + PI * 0.5
	host.add_child(corpse)

class Corpse extends Node2D:
	var spec: Dictionary
	func _ready() -> void:
		add_to_group("corpse")
		z_index = -3
		var kit := SpriteKit.new()
		kit.apply(spec)
		kit.modulate = Color(0.55, 0.52, 0.52)
		add_child(kit)
		kit.set_process(false)
		kit._dead = true
		scale = Vector2(0.4, 0.4)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(22.0)
		tw.tween_property(self, "modulate:a", 0.0, 2.0)
		tw.tween_callback(queue_free)
		queue_redraw()
	func _draw() -> void:
		var pool := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			pool.append(Vector2.from_angle(a) * (18.0 + sin(i * 2.7) * 5.0) + Vector2(-8, 0))
		draw_colored_polygon(pool, Color(0.22, 0.02, 0.03, 0.55))

# ------------------------------------------------------------- painting -----
func _c(key: String, fallback: Color) -> Color:
	return spec.get(key, fallback)

func _paint_shadow(c: Node2D) -> void:
	var body_kind: int = spec.get("body", Body.SUIT)
	var r := 20.0
	if body_kind in [Body.BULKY, Body.TANK, Body.ARMOR]:
		r = 25.0
	elif body_kind == Body.DOG:
		r = 16.0
	var pts := PackedVector2Array()
	var squash := 0.72 if body_kind != Body.DRONE else 0.55
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * r * 1.1, sin(a) * r * squash))
	c.draw_colored_polygon(pts, Color(0, 0, 0, 0.38 if body_kind != Body.DRONE else 0.22))

func _paint_feet_l(c: Node2D) -> void:
	_paint_foot(c, -1)

func _paint_feet_r(c: Node2D) -> void:
	_paint_foot(c, 1)

func _paint_foot(c: Node2D, side: int) -> void:
	var body_kind: int = spec.get("body", Body.SUIT)
	if body_kind in [Body.TRIPOD, Body.DRONE]:
		return
	var shoe := _c("shoe", Color("15141a"))
	if body_kind == Body.DOG:
		# Paws: front and back pair.
		for x in [9.0, -9.0]:
			c.draw_circle(Vector2(x + side * 1.5, side * 6.5), 3.2, _c("color", Color("5a4632")).darkened(0.35))
		return
	var y := side * 8.0
	c.draw_rect(Rect2(Vector2(-6, y - 3.5), Vector2(13, 7)), shoe)
	c.draw_rect(Rect2(Vector2(3, y - 3.5), Vector2(4, 7)), shoe.lightened(0.12))

func _paint_body(c: Node2D) -> void:
	var body_kind: int = spec.get("body", Body.SUIT)
	var col := _c("color", Color("3d4658"))
	var trim := _c("trim", col.lightened(0.25))
	var outline := Color("08080b")
	match body_kind:
		Body.TRIPOD:
			for a in [PI * 0.25, PI, PI * 1.75]:
				c.draw_line(Vector2.ZERO, Vector2.from_angle(a) * 26.0, outline, 7.0, true)
				c.draw_line(Vector2.ZERO, Vector2.from_angle(a) * 25.0, Color("5b6570"), 4.0, true)
				c.draw_circle(Vector2.from_angle(a) * 25.0, 3.5, Color("2b3036"))
			c.draw_circle(Vector2.ZERO, 15.0, outline)
			c.draw_circle(Vector2.ZERO, 13.0, col)
			c.draw_arc(Vector2.ZERO, 11.0, 0, TAU, 24, trim, 2.0, true)
			return
		Body.DRONE:
			var frame := Color("2a2d33")
			for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
				c.draw_line(Vector2.ZERO, Vector2.from_angle(a) * 17.0, frame, 4.0, true)
			c.draw_rect(Rect2(-8, -7, 16, 14), col)
			c.draw_rect(Rect2(-8, -7, 16, 14), outline, false, 1.5)
			c.draw_circle(Vector2(6, 0), 3.5, Color("101216"))
			c.draw_circle(Vector2(6.5, 0), 1.8, _c("eye", Palette.DANGER))
			return
		Body.DOG:
			var fur := col
			var dog := PackedVector2Array([Vector2(-16, -5), Vector2(-4, -8), Vector2(10, -6), Vector2(14, 0), Vector2(10, 6), Vector2(-4, 8), Vector2(-16, 5)])
			c.draw_colored_polygon(dog, fur)
			c.draw_polyline(dog + PackedVector2Array([dog[0]]), outline, 2.0, true)
			c.draw_line(Vector2(-16, 0), Vector2(-25, 3), fur.darkened(0.2), 3.0, true)
			c.draw_line(Vector2(-4, -7), Vector2(-4, 7), trim, 2.0)
			return
	var pts: PackedVector2Array
	match body_kind:
		Body.COAT:
			# Long coat: shoulders plus a skirt that flares out behind.
			pts = _blob(9.0, 20.0, 17.5, 2.3)
		Body.BULKY:
			pts = _blob(11.0, 12.0, 20.5, 2.8)
		Body.TANK:
			pts = _blob(12.0, 12.0, 23.0, 3.2)
		Body.ARMOR:
			pts = _blob(11.0, 11.0, 18.5, 3.4)
		Body.LEAN, Body.HOODIE:
			pts = _blob(8.5, 9.5, 14.5, 2.2)
		Body.GOWN:
			pts = _blob(9.0, 21.0, 15.0, 2.0)
		Body.VEST:
			pts = _blob(9.5, 10.0, 16.5, 2.6)
		_:
			pts = _blob(9.5, 10.5, 16.5, 2.5)
	c.draw_colored_polygon(pts, col)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 2.0, true)
	# Rim light: a lit arc along the leading (front-left) shoulder edge.
	var rim := PackedVector2Array()
	for i in range(1, 6):
		rim.append(pts[i] * 0.93)
	c.draw_polyline(rim, col.lightened(0.38), 1.6, true)
	for accessory: String in spec.get("acc", []):
		_paint_accessory(c, accessory, col, trim)
	match body_kind:
		Body.COAT:
			c.draw_line(Vector2(-6, -17), Vector2(8, -13), trim, 2.5, true)
			c.draw_line(Vector2(-6, 17), Vector2(8, 13), trim, 2.5, true)
			c.draw_line(Vector2(-19, -8), Vector2(-19, 8), trim.darkened(0.2), 2.0)
		Body.SUIT, Body.CIVILIAN:
			c.draw_line(Vector2(-4, -15), Vector2(6, -12), trim, 2.0, true)
			c.draw_line(Vector2(-4, 15), Vector2(6, 12), trim, 2.0, true)
		Body.ARMOR:
			c.draw_rect(Rect2(-7, -12, 14, 24), col.darkened(0.25))
			c.draw_rect(Rect2(-7, -12, 14, 24), trim, false, 1.5)
		Body.VEST:
			c.draw_rect(Rect2(-6, -13, 11, 26), col.darkened(0.3))
		Body.HOODIE:
			c.draw_arc(Vector2(-4, 0), 11, PI * 0.6, PI * 1.4, 10, col.darkened(0.3), 3.0)
		Body.TANK:
			c.draw_line(Vector2(-8, -18), Vector2(6, -16), trim, 3.0, true)
			c.draw_line(Vector2(-8, 18), Vector2(6, 16), trim, 3.0, true)
	if hero:
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), Palette.with_alpha(Palette.GOLD, 0.5), 1.1, true)

## Superellipse torso: front depth, back depth, half shoulder width, squareness.
func _blob(front: float, back: float, half_width: float, power: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 28
	for i in n:
		var a := -PI * 0.5 + TAU * i / n
		var ca := cos(a)
		var sa := sin(a)
		var x := signf(ca) * pow(absf(ca), 2.0 / power) * (front if ca > 0.0 else back)
		var y := signf(sa) * pow(absf(sa), 2.0 / power) * half_width
		pts.append(Vector2(x, y))
	return pts

func _paint_accessory(c: Node2D, id: String, col: Color, trim: Color) -> void:
	match id:
		"cross":
			c.draw_rect(Rect2(-6, 13, 8, 5), Color.WHITE)
			c.draw_line(Vector2(-2, 12), Vector2(-2, 19), Palette.DANGER, 2.0)
			c.draw_line(Vector2(-6, 15.5), Vector2(2, 15.5), Palette.DANGER, 2.0)
		"hivis":
			c.draw_line(Vector2(-9, -15), Vector2(-9, 15), Color("e8e03a"), 3.0)
			c.draw_line(Vector2(0, -16), Vector2(0, 16), Color("e8e03a"), 3.0)
		"bandolier":
			c.draw_line(Vector2(-9, -14), Vector2(7, 13), Color("3a2c1c"), 4.0, true)
			for i in 4:
				c.draw_circle(Vector2(-7 + i * 4.5, -11 + i * 7.5), 2.0, Color("c69a3b"))
		"radio":
			c.draw_rect(Rect2(-12, -17, 6, 5), Color("111111"))
			c.draw_line(Vector2(-9, -17), Vector2(-9, -23), Color("111111"), 1.5)
		"sash":
			c.draw_line(Vector2(-10, -14), Vector2(8, 14), Palette.GOLD, 4.0, true)
		"tie":
			c.draw_line(Vector2(0, 0), Vector2(10, 0), trim, 3.0)
		"pinstripe":
			for y in [-10.0, -5.0, 5.0, 10.0]:
				c.draw_line(Vector2(-9, y), Vector2(8, y * 0.85), col.lightened(0.18), 1.0)
		"leash":
			c.draw_line(Vector2(6, 10), Vector2(-4, 26), Color("7a5a2a"), 1.5)
		"plates":
			c.draw_rect(Rect2(-4, -16, 8, 5), col.darkened(0.4))
			c.draw_rect(Rect2(-4, 11, 8, 5), col.darkened(0.4))
		"gold_band":
			c.draw_line(Vector2(-10, -17), Vector2(-10, 17), Palette.GOLD, 3.0)

func _paint_arms(c: Node2D) -> void:
	var body_kind: int = spec.get("body", Body.SUIT)
	var gun: int = spec.get("gun", Gun.PISTOL)
	if body_kind == Body.DRONE:
		c.draw_line(Vector2(8, 0), Vector2(16, 0), Color("111318"), 3.0)
		return
	if body_kind == Body.DOG:
		# Head + snout.
		var fur := _c("color", Color("5a4632"))
		c.draw_circle(Vector2(15, 0), 6.5, fur.darkened(0.1))
		c.draw_rect(Rect2(18, -3, 7, 6), fur.darkened(0.25))
		c.draw_circle(Vector2(25, 0), 1.8, Color("0c0c0c"))
		c.draw_line(Vector2(12, -5), Vector2(10, -10), fur.darkened(0.3), 3.0)
		c.draw_line(Vector2(12, 5), Vector2(10, 10), fur.darkened(0.3), 3.0)
		return
	if body_kind == Body.TRIPOD:
		c.draw_rect(Rect2(4, -5, 30, 10), Color("0b0b0e"))
		c.draw_rect(Rect2(4, -4, 28, 4), Color("7d8790"))
		c.draw_rect(Rect2(30, -6, 8, 12), Color("15171b"))
		c.draw_rect(Rect2(-8, -9, 14, 18), Color("3a3f46"))
		return
	var sleeve := _c("color", Color("3d4658")).lightened(0.12)
	if body_kind == Body.TANK:
		sleeve = _c("skin", SKIN[1])
	var hand := _c("skin", SKIN[0])
	var outline := Color("08080b")
	if spec.get("cower", false):
		# Hands up over the head.
		c.draw_line(Vector2(-2, -12), Vector2(8, -6), sleeve, 7.0, true)
		c.draw_line(Vector2(-2, 12), Vector2(8, 6), sleeve, 7.0, true)
		c.draw_circle(Vector2(9, -5), 3.6, hand)
		c.draw_circle(Vector2(9, 5), 3.6, hand)
		return
	if gun == Gun.NONE:
		# Fists up, boxer stance.
		c.draw_line(Vector2(2, -13), Vector2(15, -8), outline, 9.0, true)
		c.draw_line(Vector2(2, 13), Vector2(15, 8), outline, 9.0, true)
		c.draw_line(Vector2(2, -13), Vector2(15, -8), sleeve, 6.5, true)
		c.draw_line(Vector2(2, 13), Vector2(15, 8), sleeve, 6.5, true)
		c.draw_circle(Vector2(17, -7), 5.0, hand)
		c.draw_circle(Vector2(17, 7), 5.0, hand)
		return
	# Two-handed long guns reach further forward than pistols.
	var long := gun in [Gun.SMG, Gun.RIFLE, Gun.LONG_RIFLE, Gun.SHOTGUN, Gun.LMG, Gun.LAUNCHER]
	var front := Vector2(22, 1) if long else Vector2(19, 1)
	var back := Vector2(10, 4) if long else Vector2(17, -2)
	c.draw_line(Vector2(3, -12), back, outline, 8.0, true)
	c.draw_line(Vector2(3, 12), front, outline, 8.0, true)
	c.draw_line(Vector2(3, -12), back, sleeve, 5.5, true)
	c.draw_line(Vector2(3, 12), front, sleeve, 5.5, true)
	_paint_gun(c, gun)
	c.draw_circle(back, 3.6, hand)
	c.draw_circle(front, 3.6, hand)
	if spec.get("shield", false):
		var shield := PackedVector2Array([Vector2(24, -26), Vector2(30, -14), Vector2(31, 0), Vector2(30, 14), Vector2(24, 26), Vector2(20, 26), Vector2(26, 0), Vector2(20, -26)])
		c.draw_colored_polygon(shield, Color("1d2733"))
		c.draw_polyline(shield + PackedVector2Array([shield[0]]), Color("8aa4c0"), 2.0, true)
		c.draw_line(Vector2(27, -18), Vector2(28, -6), Color(0.7, 0.85, 1.0, 0.6), 2.0)

func _paint_gun(c: Node2D, gun: int) -> void:
	var metal := Color("2a2c31")
	var hi := Color("8d949c")
	var wood := Color("6b4a31")
	var accent := _c("gun_accent", hi)
	match gun:
		Gun.PISTOL:
			c.draw_rect(Rect2(15, -3, 17, 6), metal)
			c.draw_rect(Rect2(16, -3, 15, 2), accent)
		Gun.REVOLVER:
			c.draw_rect(Rect2(15, -3, 21, 6), metal)
			c.draw_circle(Vector2(20, 0), 4.0, accent.darkened(0.2))
			c.draw_rect(Rect2(22, -2, 14, 2), accent)
		Gun.SMG:
			c.draw_rect(Rect2(8, -4, 26, 8), metal)
			c.draw_rect(Rect2(14, 3, 5, 8), metal.lightened(0.1))
			c.draw_rect(Rect2(9, -4, 24, 2), accent)
		Gun.RIFLE:
			c.draw_rect(Rect2(2, -3, 38, 7), metal)
			c.draw_rect(Rect2(2, -3, 10, 7), wood)
			c.draw_rect(Rect2(16, 3, 4, 8), metal)
			c.draw_rect(Rect2(12, -3, 27, 2), accent)
		Gun.LONG_RIFLE:
			c.draw_rect(Rect2(0, -3, 50, 6), metal)
			c.draw_rect(Rect2(0, -3, 12, 6), wood)
			c.draw_rect(Rect2(16, -6, 13, 4), Color("101114"))
			c.draw_circle(Vector2(29, -4), 2.2, Color("4a90b0"))
			c.draw_rect(Rect2(12, -3, 38, 1.5), accent)
		Gun.SHOTGUN:
			c.draw_rect(Rect2(4, -4, 36, 9), metal)
			c.draw_rect(Rect2(4, -4, 11, 9), wood)
			c.draw_rect(Rect2(20, 3, 12, 4), wood.darkened(0.2))
			c.draw_rect(Rect2(15, -4, 25, 2.5), accent)
		Gun.LMG:
			c.draw_rect(Rect2(0, -5, 46, 10), metal)
			c.draw_rect(Rect2(14, 4, 12, 10), Color("3d4a33"))
			c.draw_rect(Rect2(34, -6, 3, 12), metal.lightened(0.2))
			c.draw_rect(Rect2(2, -5, 44, 2.5), accent)
		Gun.LAUNCHER:
			c.draw_rect(Rect2(4, -6, 32, 12), Color("3b4431"))
			c.draw_circle(Vector2(36, 0), 6.0, Color("20241a"))
			c.draw_rect(Rect2(12, 5, 5, 8), metal)
		Gun.TABLET:
			c.draw_rect(Rect2(14, -8, 11, 16), Color("15161a"))
			c.draw_rect(Rect2(15, -7, 9, 14), Color("3fb6d8"))
		Gun.CANE:
			c.draw_line(Vector2(14, 0), Vector2(38, 0), Color("1a1512"), 3.0)
			c.draw_circle(Vector2(14, 0), 3.5, Palette.GOLD)
		Gun.LEDGER:
			c.draw_rect(Rect2(13, -9, 14, 18), Color("5a1f22"))
			c.draw_rect(Rect2(14, -8, 12, 16), Color("e9dfc4"))
			c.draw_line(Vector2(15, -4), Vector2(25, -4), Color("444444"), 1.0)
			c.draw_line(Vector2(15, 0), Vector2(25, 0), Color("444444"), 1.0)

func _paint_head(c: Node2D) -> void:
	var body_kind: int = spec.get("body", Body.SUIT)
	if body_kind in [Body.TRIPOD, Body.DRONE, Body.DOG]:
		return
	var head: int = spec.get("head", Head.BARE)
	var skin := _c("skin", SKIN[0])
	var hat := _c("hat", Color("1c1b20"))
	var outline := Color("08080b")
	var r := 8.5
	c.draw_circle(Vector2(-2, 0), r + 1.8, outline)
	c.draw_circle(Vector2(-2, 0), r, skin)
	# Nose pointing forward marks facing even without a hat brim.
	c.draw_circle(Vector2(5.5, 0), 2.2, skin.darkened(0.12))
	match head:
		Head.CAP:
			c.draw_circle(Vector2(-3, 0), r - 0.5, hat)
			c.draw_rect(Rect2(3, -6, 7, 12), hat.darkened(0.2))
		Head.FEDORA:
			var brim := PackedVector2Array()
			for i in 18:
				var a := TAU * i / 18.0
				brim.append(Vector2(cos(a) * 14.0 - 2.0, sin(a) * 12.5))
			c.draw_colored_polygon(brim, hat.darkened(0.15))
			c.draw_circle(Vector2(-3, 0), 8.5, hat)
			c.draw_arc(Vector2(-3, 0), 8.6, 0, TAU, 20, _c("band", Palette.GOLD_DIM), 1.4, true)
			c.draw_line(Vector2(-10, 0), Vector2(4, 0), hat.darkened(0.35), 1.5)
		Head.HELMET:
			c.draw_circle(Vector2(-3, 0), r + 1.5, hat)
			c.draw_arc(Vector2(-3, 0), r + 1.5, -1.0, 1.0, 10, hat.lightened(0.3), 2.0, true)
			c.draw_rect(Rect2(3, -5, 4, 10), Color("0d1116"))
		Head.BERET:
			c.draw_circle(Vector2(-5, -1), r - 1.0, hat)
			c.draw_circle(Vector2(-8, -3), 2.0, hat.lightened(0.2))
		Head.HOOD:
			c.draw_circle(Vector2(-4, 0), r + 2.0, hat)
			c.draw_arc(Vector2(-2, 0), r - 1.0, -1.1, 1.1, 10, skin.darkened(0.35), 3.0, true)
		Head.BALACLAVA:
			c.draw_circle(Vector2(-2, 0), r, hat)
			c.draw_rect(Rect2(1.5, -4.5, 3.5, 9), skin.darkened(0.1))
			c.draw_line(Vector2(3, -3), Vector2(3, 3), Color("0a0a0a"), 1.5)
		Head.BALD:
			c.draw_arc(Vector2(-4, -2), r - 3, PI, PI * 1.6, 8, skin.lightened(0.25), 2.0, true)
		Head.HAIR:
			var hair := _c("hair", Color("2a1a12"))
			c.draw_arc(Vector2(-3, 0), r - 1.5, PI * 0.45, PI * 1.55, 14, hair, 6.0, true)
		Head.VISOR:
			c.draw_circle(Vector2(-3, 0), r, hat)
			c.draw_arc(Vector2(-2, 0), r - 1.5, -0.9, 0.9, 10, _c("visor", Color("58d0ff")), 3.0, true)
		Head.SLICKED:
			var slick := _c("hair", Color("121212"))
			c.draw_arc(Vector2(-4, 0), r - 2.0, PI * 0.35, PI * 1.65, 16, slick, 7.0, true)
			c.draw_line(Vector2(-10, -2), Vector2(-2, -3), slick.lightened(0.25), 1.0)
	for accessory: String in spec.get("acc", []):
		if accessory == "cigar":
			c.draw_line(Vector2(6, 2), Vector2(12, 4), Color("5a3a22"), 2.5)
			c.draw_circle(Vector2(12.5, 4.2), 1.3, Color("ff7a2a"))
		elif accessory == "glasses":
			c.draw_line(Vector2(3, -5), Vector2(3, 5), Color("dfe8f0"), 2.0)
		elif accessory == "scar":
			c.draw_line(Vector2(-6, -6), Vector2(1, -2), Color("7a2c2c"), 1.5)

func _paint_extra(c: Node2D) -> void:
	# Drone rotors spin on this layer; other bodies leave it empty.
	var body_kind: int = spec.get("body", Body.SUIT)
	if body_kind != Body.DRONE:
		return
	for a in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		var at := Vector2.from_angle(a) * 17.0
		c.draw_circle(at, 7.5, Color(0.8, 0.85, 0.9, 0.18))
		c.draw_line(at - Vector2(7, 0), at + Vector2(7, 0), Color(0.85, 0.9, 0.95, 0.55), 1.5)

# ----------------------------------------------------------------- specs ----
## Kit specs for the player's specialists.
static func hero_spec(profile_id: StringName, gun: int = Gun.PISTOL) -> Dictionary:
	var s := {"hero": true, "gun": gun, "body": Body.COAT, "head": Head.FEDORA,
		"color": Color("3a3640"), "trim": Palette.GOLD, "hat": Color("24222a"),
		"band": Palette.GOLD_DIM, "skin": SKIN[0], "acc": []}
	match profile_id:
		&"ghost":
			s.merge({"body": Body.HOODIE, "head": Head.BALACLAVA, "color": Color("26272c"),
				"trim": Color("5a6070"), "hat": Color("121216")}, true)
		&"wolf":
			s.merge({"body": Body.BULKY, "head": Head.BALD, "color": Color("4a3226"),
				"trim": Color("b8864a"), "skin": SKIN[1], "acc": ["scar"]}, true)
		&"broker":
			s.merge({"body": Body.SUIT, "head": Head.SLICKED, "color": Color("1f2a44"),
				"trim": Palette.GOLD, "acc": ["pinstripe", "tie", "glasses"], "skin": SKIN[4]}, true)
		&"legend":
			s.merge({"body": Body.COAT, "head": Head.FEDORA, "color": Color("d8d0bd"),
				"trim": Color("8c7333"), "hat": Color("e8e2d0"), "band": Color("1a1a1a"),
				"skin": SKIN[2], "acc": ["scar"]}, true)
	# A coat from the Connections board overrides the specialist's own.
	var coat: Color = Meta.coat_color()
	if coat.a > 0.0:
		s["color"] = coat
	return s

## Map a weapon to the silhouette the character holds.
static func gun_for(weapon: WeaponItem) -> int:
	if weapon == null:
		return Gun.PISTOL
	match weapon.id:
		&"snub38", &"handcannon", &"margin_call":
			return Gun.REVOLVER
		&"pistol", &"silenced9mm", &"ricochet":
			return Gun.PISTOL
		&"tommygun", &"smg", &"circuit_smg", &"ghost_wire":
			return Gun.SMG
		&"burstcarbine", &"nailgun":
			return Gun.RIFLE
		&"rifle", &"rail_dividend":
			return Gun.LONG_RIFLE
		&"squadlmg":
			return Gun.LMG
		&"shotgun", &"combatshotgun", &"breacher", &"scatter_note", &"hostile_takeover":
			return Gun.SHOTGUN
	return Gun.SMG if weapon.slot == WeaponItem.Slot.BIG else Gun.PISTOL
