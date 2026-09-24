extends Node2D
class_name RoomArt
var room: BuildingRoom
var footprint := Vector2.ZERO
var accent := Color("66877c")
var title := ""
var cabinets: Array[Rect2] = []

func _ready() -> void:
	z_index = -9
	footprint = room.room_size
	title = String(room.name).to_upper()
	if title.begins_with("@") or title.begins_with("ROOM"):
		title = "EXCHANGE / %02d" % (room.get_index() + 1)
	if room.has_meta("is_boss"):
		accent = Color("a98051")
		var host: Node = room
		while host != null and not host is HeistFloor:
			host = host.get_parent()
		title = "EXECUTIVE / THE AUDITOR" if host is HeistFloor and host.boss_heist else "SECURITY / CAPTAIN"
	elif room.has_meta("chest_kind"):
		accent = Color("b89b66")
	elif room.is_start_room:
		title = "MARLOWE EXCHANGE" if room.name == &"Lobby" else "EXCHANGE / ARRIVALS"
	# Wall-mounted cabinets stay clear of doorway and spawn-marker footprints.
	for rect: Rect2 in [Rect2(90, 30, 125, 34), Rect2(footprint.x - 215, 30, 125, 34)]:
		cabinets.append(rect)
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
	queue_redraw()

func _draw() -> void:
	var stone := Color("233339") if room.is_start_room else Color("202e35")
	if room.has_meta("is_boss"):
		stone = Color("2e292c")
	draw_rect(Rect2(Vector2.ZERO, footprint), stone)
	for y in range(24, int(footprint.y) - 24, 48):
		for x in range(24, int(footprint.x) - 24, 48):
			var tile := stone.lightened(0.025) if (x / 48 + y / 48) % 2 == 0 else stone.darkened(0.04)
			draw_rect(Rect2(x + 1, y + 1, minf(46, footprint.x - x - 24), minf(46, footprint.y - y - 24)), tile)
	# Inlaid border and a central carpet provide scale without obscuring bullets.
	draw_rect(Rect2(Vector2(40, 40), footprint - Vector2(80, 80)), accent.darkened(0.55), false, 2)
	var rug := Rect2(footprint * 0.24, footprint * 0.52)
	var rug_color := Color("26443f") if room.is_start_room else Color("2d3b43")
	if room.has_meta("is_boss"):
		rug_color = Color("4d3037")
	draw_rect(rug, rug_color)
	draw_rect(rug.grow(-6), accent.darkened(0.25), false, 1)
	draw_rect(rug.grow(-12), accent.darkened(0.48), false, 1)
	var center := footprint * 0.5
	if room.is_start_room or room.has_meta("is_boss"):
		draw_arc(center, 52, 0, TAU, 40, accent.darkened(0.28), 2, true)
		draw_arc(center, 44, 0, TAU, 40, accent.darkened(0.4), 1, true)
		draw_line(center + Vector2(-22, 12), center + Vector2(0, -18), accent, 4, true)
		draw_line(center + Vector2(0, -18), center + Vector2(22, 12), accent, 4, true)
		draw_line(center + Vector2(-13, 0), center + Vector2(14, 0), accent, 2, true)
	# Architectural shadows sit behind existing collision walls.
	draw_rect(Rect2(24, 24, footprint.x - 48, 10), Color(0, 0, 0, 0.28))
	draw_rect(Rect2(24, 24, 9, footprint.y - 48), Color(0, 0, 0, 0.2))
	for rect: Rect2 in cabinets:
		draw_rect(Rect2(rect.position + Vector2(0, 7), rect.size), Color(0, 0, 0, 0.22))
		draw_rect(rect, Color("131f27"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), accent)
		for x in range(8, int(rect.size.x), 24):
			draw_rect(Rect2(rect.position + Vector2(x, 12), Vector2(15, 15)), Color("3b5155"))
			draw_line(rect.position + Vector2(x + 5, 19), rect.position + Vector2(x + 10, 19), Color("9d997e"), 2)
	# Soft wall-lamp pools are static geometry, no per-frame lights or shaders.
	for at in [Vector2(46, footprint.y * 0.5 - 95), Vector2(footprint.x - 46, footprint.y * 0.5 + 95)]:
		for r in [42, 30, 18]:
			draw_circle(at, r, Color(0.67, 0.87, 0.73, 0.018))
		draw_rect(Rect2(at - Vector2(4, 12), Vector2(8, 24)), Color("a0c8b2"))
	draw_string(ThemeDB.fallback_font, Vector2(58, footprint.y - 60), title, HORIZONTAL_ALIGNMENT_LEFT, footprint.x - 116, 20, accent.lightened(0.15))
