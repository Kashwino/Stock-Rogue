extends Node2D
class_name RoomArt
## Static floor art for one building room, drawn once: the stage's material
## (concrete slabs, office carpet, marble, dark trading-floor glass) plus
## room-type dressing (hazard lines, rugs, stencilled room names).
## WallArt (below) repaints the room's walls with a top face, a darker front
## face and a baseboard so the building reads as having height.

var room: BuildingRoom
var theme: EnvTheme
var room_type := "office"
var footprint := Vector2.ZERO
var title := ""
var open_gaps: Array = []        # local positions of doorways, for thresholds

func _ready() -> void:
	z_index = -9
	footprint = room.room_size
	if theme == null:
		theme = EnvTheme.for_stage(0)
	title = _title_for(room_type)
	var label := room.get_node_or_null("RoomName")
	if label:
		label.hide()
	var old_floor := room.get_node_or_null("Floor")
	if old_floor:
		old_floor.hide()
	queue_redraw()

func _title_for(kind: String) -> String:
	var names := {
		"lobby": "RECEPTION", "boss_office": "PRIVATE OFFICE", "vault": "STRONGROOM",
		"warehouse": "WAREHOUSE", "pawnshop": "PAWN COUNTER", "garage": "GARAGE",
		"backoffice": "BACK OFFICE", "storage": "STORAGE", "office": "OFFICES",
		"cubicles": "OPEN PLAN", "bank_hall": "BANKING HALL", "meeting": "BOARDROOM",
		"records": "RECORDS", "casino": "GAMING FLOOR", "lounge": "LOUNGE",
		"gallery": "GALLERY", "embassy_hall": "STATE HALL", "bar": "BAR",
		"trading_floor": "TRADING FLOOR", "server_room": "SERVER ROOM",
		"exec_office": "EXECUTIVE SUITE", "glass_hall": "ATRIUM",
	}
	return names.get(kind, kind.to_upper())

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(room.get_meta("cell", Vector2i.ZERO)) + room_type)
	return rng

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, footprint)
	draw_rect(r, theme.floor_a)
	match theme.floor_style:
		"concrete": _concrete()
		"carpet": _carpet()
		"marble": _marble()
		"glass": _glass()
	_dress()
	_thresholds()
	# Ambient occlusion: floors darken towards the walls.
	for i in 4:
		var inset := 24.0 + i * 6.0
		draw_rect(Rect2(Vector2(inset, inset), footprint - Vector2(inset, inset) * 2.0), Color(0, 0, 0, 0.07), false, 6.0)
	var f := VisualTheme.font("heading")
	draw_string(f, Vector2(48, footprint.y - 48), title, HORIZONTAL_ALIGNMENT_LEFT, footprint.x - 96, 26, Palette.with_alpha(theme.accent, 0.22))

func _concrete() -> void:
	var rng := _rng()
	var slab := 150.0
	for x in range(0, int(footprint.x), int(slab)):
		for y in range(0, int(footprint.y), int(slab)):
			var tone := theme.floor_a.lerp(theme.floor_b, rng.randf())
			draw_rect(Rect2(x + 1, y + 1, slab - 2, slab - 2), tone)
	for x in range(0, int(footprint.x) + 1, int(slab)):
		draw_line(Vector2(x, 0), Vector2(x, footprint.y), theme.floor_b.darkened(0.3), 1.5)
	for y in range(0, int(footprint.y) + 1, int(slab)):
		draw_line(Vector2(0, y), Vector2(footprint.x, y), theme.floor_b.darkened(0.3), 1.5)
	for i in 4:
		var at := Vector2(rng.randf_range(60, footprint.x - 60), rng.randf_range(60, footprint.y - 60))
		_blot(at, rng.randf_range(14, 34), Color(0.05, 0.04, 0.03, 0.28))
	for i in 3:
		var p := Vector2(rng.randf_range(40, footprint.x - 40), rng.randf_range(40, footprint.y - 40))
		var crack := PackedVector2Array([p])
		for s in 5:
			p += Vector2(rng.randf_range(-18, 18), rng.randf_range(8, 22)).rotated(rng.randf() * TAU * 0.2)
			crack.append(p)
		draw_polyline(crack, theme.floor_b.darkened(0.45), 1.2, true)

func _carpet() -> void:
	var rng := _rng()
	var tile := 60.0
	for x in range(0, int(footprint.x), int(tile)):
		for y in range(0, int(footprint.y), int(tile)):
			var alt := (int(x / tile) + int(y / tile)) % 2 == 0
			draw_rect(Rect2(x, y, tile, tile), theme.floor_a if alt else theme.floor_b)
			# Woven texture: short parallel strokes, rotated per tile.
			var dir := Vector2(1, 0) if alt else Vector2(0, 1)
			for k in 4:
				var o := Vector2(x, y) + Vector2(10 + k * 12, 10 + k * 12)
				draw_line(o, o + dir * 8.0, Palette.with_alpha(theme.accent, 0.05), 1.0)
	if room_type in ["bank_hall", "lobby"]:
		# Polished stone hall with a reflected light streak.
		draw_rect(Rect2(Vector2.ZERO, footprint), Color("3a4150"))
		for x in range(0, int(footprint.x), 75):
			for y in range(0, int(footprint.y), 75):
				if (x / 75 + y / 75) % 2 == 0:
					draw_rect(Rect2(x, y, 75, 75), Color("333a47"))
		draw_colored_polygon(PackedVector2Array([Vector2(footprint.x * 0.3, 0), Vector2(footprint.x * 0.42, 0), Vector2(footprint.x * 0.2, footprint.y), Vector2(footprint.x * 0.08, footprint.y)]), Color(1, 1, 1, 0.035))
	rng.randf()

func _marble() -> void:
	var rng := _rng()
	var tile := 100.0
	for x in range(0, int(footprint.x), int(tile)):
		for y in range(0, int(footprint.y), int(tile)):
			var alt := (int(x / tile) + int(y / tile)) % 2 == 0
			draw_rect(Rect2(x + 1, y + 1, tile - 2, tile - 2), theme.floor_a if alt else theme.floor_b)
			var vein := PackedVector2Array()
			var p := Vector2(x, y) + Vector2(rng.randf_range(0, tile), 0)
			for s in 6:
				vein.append(p)
				p += Vector2(rng.randf_range(-14, 14), tile / 5.0)
			draw_polyline(vein, Color(1, 1, 1, 0.07), 1.2, true)
	for x in range(0, int(footprint.x) + 1, int(tile)):
		draw_line(Vector2(x, 0), Vector2(x, footprint.y), Color(0, 0, 0, 0.25), 1.5)
	for y in range(0, int(footprint.y) + 1, int(tile)):
		draw_line(Vector2(0, y), Vector2(footprint.x, y), Color(0, 0, 0, 0.25), 1.5)

func _glass() -> void:
	var tile := 60.0
	for x in range(0, int(footprint.x), int(tile)):
		for y in range(0, int(footprint.y), int(tile)):
			var alt := (int(x / tile) + int(y / tile)) % 2 == 0
			draw_rect(Rect2(x, y, tile, tile), theme.floor_a if alt else theme.floor_b)
	for x in range(0, int(footprint.x) + 1, int(tile)):
		draw_line(Vector2(x, 0), Vector2(x, footprint.y), Palette.with_alpha(theme.accent, 0.07), 1.0)
	for y in range(0, int(footprint.y) + 1, int(tile)):
		draw_line(Vector2(0, y), Vector2(footprint.x, y), Palette.with_alpha(theme.accent, 0.07), 1.0)

func _blot(at: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		pts.append(at + Vector2.from_angle(a) * radius * (0.75 + 0.35 * sin(i * 1.9 + radius)))
	draw_colored_polygon(pts, color)

func _rug(rect: Rect2, base: Color, border: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0, 0, 0, 0.25))
	draw_rect(rect, base)
	draw_rect(rect.grow(-7), border, false, 2.0)
	draw_rect(rect.grow(-13), Palette.with_alpha(border, 0.5), false, 1.0)

func _dress() -> void:
	var c := footprint * 0.5
	match room_type:
		"warehouse", "garage", "storage":
			# Painted safety lanes along the working floor.
			var lane := Palette.with_alpha(Color("d9b12c"), 0.55)
			draw_rect(Rect2(90, 90, footprint.x - 180, 5), lane)
			draw_rect(Rect2(90, footprint.y - 95, footprint.x - 180, 5), lane)
			for x in range(100, int(footprint.x) - 100, 44):
				draw_colored_polygon(PackedVector2Array([Vector2(x, footprint.y - 125), Vector2(x + 18, footprint.y - 125), Vector2(x + 28, footprint.y - 105), Vector2(x + 10, footprint.y - 105)]), Palette.with_alpha(Color("d9b12c"), 0.18))
			if room_type == "garage":
				_blot(c + Vector2(40, 10), 44, Color(0.02, 0.02, 0.03, 0.35))
		"pawnshop", "backoffice":
			for x in range(40, int(footprint.x) - 40, 50):
				for y in range(40, int(footprint.y) - 40, 50):
					if (x / 50 + y / 50) % 2 == 0:
						draw_rect(Rect2(x, y, 50, 50), Color(1, 1, 1, 0.04))
		"lobby":
			_rug(Rect2(c - Vector2(150, 70), Vector2(300, 140)), theme.rug, theme.accent)
		"boss_office":
			_rug(Rect2(c - footprint * 0.32, footprint * 0.64), theme.rug.darkened(0.2), Palette.GOLD)
			draw_arc(c, 70, 0, TAU, 48, Palette.with_alpha(Palette.GOLD, 0.35), 3.0, true)
			draw_arc(c, 58, 0, TAU, 48, Palette.with_alpha(Palette.GOLD, 0.2), 1.5, true)
		"vault":
			draw_rect(Rect2(Vector2(60, 60), footprint - Vector2(120, 120)), Color(0, 0, 0, 0.2))
			for x in range(60, int(footprint.x) - 60, 30):
				draw_line(Vector2(x, 60), Vector2(x, footprint.y - 60), Color(1, 1, 1, 0.03), 1.0)
			draw_arc(c, 90, 0, TAU, 40, Palette.with_alpha(Palette.GOLD, 0.25), 2.0, true)
		"meeting":
			_rug(Rect2(c - Vector2(200, 110), Vector2(400, 220)), theme.rug, theme.accent)
		"casino", "lounge", "bar":
			var carpet := Color("5a1320")
			draw_rect(Rect2(Vector2(40, 40), footprint - Vector2(80, 80)), carpet)
			for x in range(60, int(footprint.x) - 60, 70):
				for y in range(60, int(footprint.y) - 60, 70):
					var p := Vector2(x + 35, y + 35)
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(12, 0), p + Vector2(0, 12), p + Vector2(-12, 0)]), Palette.with_alpha(Palette.GOLD, 0.16))
			draw_rect(Rect2(Vector2(40, 40), footprint - Vector2(80, 80)), Palette.with_alpha(Palette.GOLD, 0.5), false, 3.0)
		"gallery", "embassy_hall":
			_rug(Rect2(Vector2(footprint.x * 0.5 - 70, 50), Vector2(140, footprint.y - 100)), theme.rug, Palette.GOLD)
		"trading_floor":
			# Live ticker strips glowing through the glass.
			for y in [footprint.y * 0.33, footprint.y * 0.66]:
				draw_rect(Rect2(40, y - 7, footprint.x - 80, 14), Color("06161b"))
				for x in range(48, int(footprint.x) - 48, 22):
					var up := (x / 22) % 3 != 0
					draw_rect(Rect2(x, y - 3, 12, 6), Palette.with_alpha(Palette.UP if up else Palette.DOWN, 0.45))
		"server_room":
			for x in range(60, int(footprint.x) - 60, 90):
				draw_rect(Rect2(x, 40, 4, footprint.y - 80), Palette.with_alpha(Palette.NEON_CYAN, 0.12))
		"exec_office", "glass_hall":
			_rug(Rect2(c - Vector2(170, 100), Vector2(340, 200)), theme.rug, theme.accent)
		"office", "cubicles", "records":
			draw_rect(Rect2(Vector2(70, 70), footprint - Vector2(140, 140)), Palette.with_alpha(theme.accent, 0.04))

func _thresholds() -> void:
	for gap: Dictionary in open_gaps:
		var at: Vector2 = gap["local"]
		var horizontal: bool = gap["horizontal"]
		var size := Vector2(96, 26) if horizontal else Vector2(26, 96)
		draw_rect(Rect2(at - size * 0.5, size), theme.floor_b.darkened(0.25))
		var post := Vector2(10, 10)
		var offs := Vector2(53, 0) if horizontal else Vector2(0, 53)
		draw_rect(Rect2(at - offs - post * 0.5, post), theme.wall_face)
		draw_rect(Rect2(at + offs - post * 0.5, post), theme.wall_face)


class WallArt extends Node2D:
	## Repaints every wall slab of a room: lit top face, dark front face on
	## the lower third, a baseboard line. Collision is untouched.
	var room: Node2D
	var theme: EnvTheme
	var rects: Array = []

	func _ready() -> void:
		z_index = -2
		collect()

	func collect() -> void:
		rects.clear()
		for body in room.get_children():
			if body is StaticBody2D and (body.collision_layer & Layers.WALLS) != 0 and not body is Prop:
				for shape in body.get_children():
					if shape is CollisionShape2D and shape.shape is RectangleShape2D:
						var size: Vector2 = shape.shape.size
						var center: Vector2 = body.position + shape.position
						rects.append(Rect2(center - size * 0.5, size))
					elif shape is Polygon2D:
						shape.hide()
		queue_redraw()

	func _draw() -> void:
		for r: Rect2 in rects:
			var horizontal := r.size.x >= r.size.y
			draw_rect(r, theme.wall_top)
			if horizontal:
				var face := Rect2(Vector2(r.position.x, r.end.y - r.size.y * 0.38), Vector2(r.size.x, r.size.y * 0.38))
				draw_rect(face, theme.wall_face)
				draw_line(Vector2(r.position.x, r.position.y + 1), Vector2(r.end.x, r.position.y + 1), theme.wall_top.lightened(0.25), 2.0)
				draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), theme.baseboard, 2.0)
			else:
				draw_rect(Rect2(Vector2(r.end.x - r.size.x * 0.3, r.position.y), Vector2(r.size.x * 0.3, r.size.y)), theme.wall_face)
				draw_line(Vector2(r.position.x + 1, r.position.y), Vector2(r.position.x + 1, r.end.y), theme.wall_top.lightened(0.2), 2.0)
			draw_rect(r, Color(0, 0, 0, 0.55), false, 1.0)
