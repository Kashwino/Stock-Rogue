extends Node2D
class_name ActorArt
var hero := false
var boss := false
var archetype := 0
var tint := Color("bd7074")

static func dress(sprite: Node2D, is_hero: bool, is_boss: bool, role: int = 0, color: Color = Color("bd7074")) -> void:
	var art := sprite.get_node_or_null("Illustration") as ActorArt
	if art == null:
		for child in sprite.get_children():
			if child is CanvasItem:
				child.hide()
		art = ActorArt.new()
		art.name = "Illustration"
		sprite.add_child(art)
	art.hero = is_hero
	art.boss = is_boss
	art.archetype = role
	art.tint = color
	art.queue_redraw()

func _draw() -> void:
	if archetype == 6 and not hero and not boss:
		draw_circle(Vector2(0, 3), 25, Color(0, 0, 0, 0.4))
		for angle in [0.0, 2.1, 4.2]:
			draw_line(Vector2.ZERO, Vector2.from_angle(angle) * 23, Color("647783"), 7, true)
		draw_circle(Vector2.ZERO, 17, Color("364d59"))
		draw_arc(Vector2.ZERO, 14, 0, TAU, 24, tint, 2)
		draw_rect(Rect2(0, -5, 34, 10), Color("8d9b98"))
		draw_rect(Rect2(27, -6, 9, 12), Color("17252d"))
		return
	var outline := Color("080e15")
	var suit := Color("315663") if hero else Color("3d4658")
	if boss:
		suit = Color("584339")
	var shoulder := Color("79d9c9") if hero else tint
	var radius := 23.0 if boss else 18.0
	# Shadow, shoes, tailored jacket and arms make facing direction unambiguous.
	draw_circle(Vector2(-2, 5), radius + 4, Color(0, 0, 0, 0.42))
	if hero:
		draw_arc(Vector2.ZERO, 24, 0, TAU, 28, Color(0.42, 0.85, 0.77, 0.65), 2, true)
	draw_line(Vector2(-13, -10), Vector2(-20, -11), outline, 9, true)
	draw_line(Vector2(-13, 10), Vector2(-20, 11), outline, 9, true)
	var body := PackedVector2Array([Vector2(-17, -12), Vector2(-7, -20), Vector2(9, -15), Vector2(12, 15), Vector2(-7, 20), Vector2(-17, 12)])
	if boss:
		body = Transform2D(0, Vector2(1.2, 1.2), 0, Vector2.ZERO) * body
	draw_colored_polygon(body, suit)
	draw_polyline(body + PackedVector2Array([body[0]]), outline, 3, true)
	draw_line(Vector2(-7, -16), Vector2(5, -13), shoulder, 4, true)
	draw_line(Vector2(-7, 16), Vector2(5, 13), shoulder, 4, true)
	draw_line(Vector2(6, -12), Vector2(17, -6), suit.lightened(0.2), 9, true)
	draw_line(Vector2(6, 12), Vector2(22, 4), suit.lightened(0.2), 9, true)
	draw_circle(Vector2(17, -5), 4, Color("cab59d"))
	draw_circle(Vector2(22, 3), 4, Color("cab59d"))
	# Head and a mask for the player; guards wear a dark security visor.
	draw_circle(Vector2(-3, 0), 10, outline)
	draw_circle(Vector2(-3, -1), 8, Color("e0dac1") if hero else Color("9d877d"))
	draw_line(Vector2(0, -6), Vector2(3, 5), Color("304c55") if hero else Color("121c29"), 5, true)
	var length := 38.0 if archetype in [2, 3, 4] or boss else 30.0
	draw_rect(Rect2(13, -5, length - 10, 8), outline)
	draw_rect(Rect2(14, -5, length - 12, 3), Color("9ba9a4"))
	draw_rect(Rect2(16, 1, 7, 6), Color("3c3029"))
	draw_rect(Rect2(length, -4, 5, 6), Color("d9bb76") if hero or boss else Color("526673"))
	if archetype == 7:
		draw_line(Vector2(-12, -5), Vector2(-12, 5), Color("88e2b0"), 3)
		draw_line(Vector2(-17, 0), Vector2(-7, 0), Color("88e2b0"), 3)
