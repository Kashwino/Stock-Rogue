extends StaticBody2D
class_name Shutter
## A steel roller shutter that slams across a doorway when a boss fight
## starts and rolls up when the boss falls. Solid wall (layer WALLS): it stops
## walkers, bullets and sight. Placed at a gap's wall position.

var horizontal := true            # true: the gap is in a north/south wall
var width := 110.0
var thickness := 30.0
var _drop := 0.0                  # 0 open .. 1 closed (visual only)
var _shape: CollisionShape2D

func _ready() -> void:
	collision_layer = Layers.WALLS
	collision_mask = 0
	z_index = 6
	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(width, thickness) if horizontal else Vector2(thickness, width)
	_shape.shape = box
	add_child(_shape)

## Slam shut (the collision is solid immediately; the art rolls down).
func close() -> void:
	Audio.play("shutter", global_position)
	var tw := create_tween()
	tw.tween_method(_set_drop, 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## Roll up and disappear.
func open() -> void:
	_shape.set_deferred("disabled", true)
	Audio.play("shutter", global_position, -4.0, 1.25)
	var tw := create_tween()
	tw.tween_method(_set_drop, 1.0, 0.0, 0.6).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(queue_free)

func _set_drop(v: float) -> void:
	_drop = v
	queue_redraw()

func _draw() -> void:
	var size := Vector2(width, thickness) if horizontal else Vector2(thickness, width)
	var rect := Rect2(-size * 0.5, size)
	# Rolls "down" along the doorway's length.
	if horizontal:
		rect.size.x *= _drop
	else:
		rect.size.y *= _drop
	if rect.size.x <= 0.5 or rect.size.y <= 0.5:
		return
	draw_rect(rect.grow(2.0), Color(0.03, 0.03, 0.04))
	draw_rect(rect, Color("4a5058"))
	var slats := int((rect.size.x if horizontal else rect.size.y) / 9.0)
	for i in slats:
		if horizontal:
			var x := rect.position.x + 4.0 + i * 9.0
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color("2c3036"), 2.0)
		else:
			var y := rect.position.y + 4.0 + i * 9.0
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color("2c3036"), 2.0)
	# Hazard stripe along the leading edge.
	var stripe := Rect2(rect.position, Vector2(rect.size.x, 5.0)) if not horizontal else Rect2(rect.position, Vector2(5.0, rect.size.y))
	draw_rect(stripe, Palette.GOLD)
