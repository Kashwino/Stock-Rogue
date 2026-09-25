extends Node2D
class_name BulletArt
## Projectile look. Player rounds: white-hot core in a gold streak. Enemy
## rounds: fat orange-red slugs with a glow — readable against any floor.
## Unshaded so night lighting never hides a bullet.

var hostile := false
var length := 18.0

func _ready() -> void:
	material = StreetArt._unshaded()
	z_index = 16
	queue_redraw()

func _draw() -> void:
	if hostile:
		draw_circle(Vector2.ZERO, 9.0, Palette.with_alpha(Palette.ENEMY_BULLET, 0.22))
		draw_line(Vector2(-length, 0), Vector2.ZERO, Palette.with_alpha(Palette.DANGER, 0.55), 5.0)
		draw_circle(Vector2.ZERO, 5.0, Palette.ENEMY_BULLET)
		draw_circle(Vector2(1, -1), 2.2, Color("ffe2c0"))
	else:
		draw_line(Vector2(-length, 0), Vector2(2, 0), Palette.with_alpha(Palette.GOLD, 0.6), 4.0)
		draw_line(Vector2(-length * 0.5, 0), Vector2(4, 0), Palette.PLAYER_BULLET, 2.4)
		draw_circle(Vector2(4, 0), 2.2, Color.WHITE)
