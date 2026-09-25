extends Prop
class_name ExplosiveProp
## Things that go bang: gas cans, fuel drums and fuse boxes. They block
## bullets and walking like walls (collision layer 1, WALLS — never picked up
## by WallArt because they're Props). Shoot one enough and it explodes: blast
## damage to everyone around (you included), chain reactions into other
## props, gibs, a scorch mark and a noise the whole floor hears. Kills count
## as EXPLOSIVE prop kills for the combo. Short Fuse makes them hit 50% harder.

const DATA := {
	# kind: [hp, blast radius, damage to guards, damage to player, size, round]
	"gas_can": [1, 105.0, 3, 2, Vector2(26, 34), false],
	"fuel_drum": [2, 135.0, 4, 2, Vector2(40, 40), true],
	"fuse_box": [2, 85.0, 3, 1, Vector2(42, 26), false],
}
## Which props turn up per stage (Town, City, World, Doomsday).
const STAGE_KINDS := [["gas_can", "fuel_drum"], ["fuse_box", "gas_can"], ["fuel_drum", "fuse_box"], ["fuse_box"]]
const CHAIN_DELAY := 0.14

var hp := 1
var _blown := false
var _last_by_player := false

func _ready() -> void:
	add_to_group("explosive")
	var d: Array = DATA.get(kind, DATA["gas_can"])
	hp = int(d[0])
	size = d[4]
	is_round = d[5]
	z_index = -1
	collision_layer = Layers.WALLS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	if is_round:
		var circle := CircleShape2D.new()
		circle.radius = size.x * 0.5
		shape.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = size
		shape.shape = rect
	add_child(shape)
	queue_redraw()

## A round hit it.
func shot(damage: int, dir: Vector2, by_player: bool) -> void:
	if _blown:
		return
	_last_by_player = by_player
	hp -= maxi(1, damage)
	var host := get_tree().current_scene
	if host is HeistFloor:
		host.fx.spark(global_position - dir * 8.0, -dir, Palette.SODIUM if kind != "fuse_box" else Palette.NEON_CYAN)
	Audio.play("impact_wall", global_position, 0.0, 0.7)
	if hp <= 0:
		explode(by_player)
	else:
		queue_redraw()

## Caught in another blast: goes up a beat later.
func blast_hit(by_player: bool) -> void:
	if _blown:
		return
	_last_by_player = by_player
	get_tree().create_timer(CHAIN_DELAY).timeout.connect(explode.bind(by_player))

func explode(by_player: bool) -> void:
	if _blown or not is_inside_tree():
		return
	_blown = true
	var d: Array = DATA.get(kind, DATA["gas_can"])
	var dmg := int(d[2])
	if RunState.has_relic(&"short_fuse"):
		dmg = int(ceil(dmg * 1.5))
	var host := get_tree().current_scene
	remove_from_group("explosive")
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	if host is Node2D:
		Blast.fuse(host, global_position, 0.0, float(d[1]), int(d[3]), dmg, by_player, true)
	queue_free()

func _draw() -> void:
	match kind:
		"fuel_drum":
			var r := size.x * 0.5
			draw_circle(Vector2(2, 3), r, Color(0, 0, 0, 0.35))
			draw_circle(Vector2.ZERO, r, Color("8c1d1d"))
			draw_arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 28, Color("c2402f"), 2.0, true)
			draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 24, Color("5e1212"), 2.0, true)
			draw_circle(Vector2(r * 0.3, -r * 0.3), 3.0, Color("2a2a2a"))
			_hazard(Vector2(-6, 2))
		"fuse_box":
			var rr := Rect2(-size * 0.5, size)
			draw_rect(Rect2(rr.position + Vector2(2, 3), rr.size), Color(0, 0, 0, 0.35))
			draw_rect(rr, Color("5a5f66"))
			draw_rect(rr, Color("2c2f33"), false, 2.0)
			var bolt := PackedVector2Array([Vector2(-2, -9), Vector2(4, -2), Vector2(0, -1), Vector2(3, 8), Vector2(-4, 0), Vector2(0, -1)])
			draw_colored_polygon(bolt, Palette.SODIUM)
			if hp < int(DATA["fuse_box"][0]):
				draw_line(Vector2(-12, 6), Vector2(-4, -6), Palette.NEON_CYAN, 1.5)
		_:
			var cr := Rect2(-size * 0.5, size)
			draw_rect(Rect2(cr.position + Vector2(2, 3), cr.size), Color(0, 0, 0, 0.35))
			draw_rect(cr, Color("b3261e"))
			draw_rect(cr, Color("5e1212"), false, 2.0)
			draw_rect(Rect2(-6, -size.y * 0.5 - 5, 12, 5), Color("2a2a2a"))
			_hazard(Vector2(0, 4))

func _hazard(at: Vector2) -> void:
	var tri := PackedVector2Array([at + Vector2(0, -7), at + Vector2(7, 5), at + Vector2(-7, 5)])
	draw_colored_polygon(tri, Palette.SODIUM)
	draw_line(at + Vector2(0, -3), at + Vector2(0, 1), Color.BLACK, 1.5)
