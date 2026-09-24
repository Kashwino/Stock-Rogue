extends Node2D
class_name Grenade
## A lobbed grenade. Arcs over furniture to its landing point while a warning
## ring fills there (~0.9 s), then goes off as a Blast. Thrown by Grenadiers.

var from := Vector2.ZERO
var to := Vector2.ZERO
var flight := 0.9
var radius := 85.0
var player_damage := 2
var enemy_damage := 3
var _t := 0.0
var _height := 0.0
var _mark: Telegraph

func _ready() -> void:
	z_index = 28
	material = StreetArt._unshaded()
	global_position = from
	_mark = Telegraph.new()
	add_child(_mark)
	Audio.play("throw", from)

func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / flight, 0.0, 1.0)
	global_position = from.lerp(to, k)
	_height = sin(k * PI) * 70.0
	rotation += delta * 9.0
	_mark.clear()
	_mark.ring(to, radius, Palette.ENEMY_BULLET, k)
	queue_redraw()
	if k >= 1.0:
		Blast.detonate(get_parent(), to, radius, player_damage, enemy_damage)
		queue_free()

func _draw() -> void:
	# Shadow on the floor, the grenade raised above it by the arc height.
	# Offsets are world-space; the node itself spins.
	draw_circle(Vector2(3, 4).rotated(-rotation), 5.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(0, -_height).rotated(-rotation), 0.0)
	draw_circle(Vector2.ZERO, 6.5, Color("0d0f0a"))
	draw_circle(Vector2.ZERO, 5.0, Color("4d5a33"))
	draw_rect(Rect2(-2, -9, 4, 4), Color("8d949c"))
	draw_circle(Vector2(-1.5, -1.5), 1.6, Color(1, 1, 1, 0.5))
